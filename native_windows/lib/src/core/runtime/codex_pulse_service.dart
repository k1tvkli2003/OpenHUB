import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../../models/codex_pulse.dart';
import '../../models/runtime_control.dart';

abstract interface class CodexPulseSource {
  DateTime get sessionStartedAt;

  Future<CodexPulseSnapshot> refresh();

  void dispose();
}

typedef RuntimeSnapshotReader = Future<RuntimeControlSnapshot> Function();

class CodexPulseService implements CodexPulseSource {
  CodexPulseService({
    Directory? codexHome,
    DateTime Function()? now,
    this._runtimeSnapshotReader,
    this.recentTaskLimit = 14,
    this.stallAfter = const Duration(seconds: 45),
    this.rolloutTailBytes = 786432,
  }) : _codexHome = codexHome ?? _defaultCodexHome(),
       _clock = now ?? DateTime.now {
    sessionStartedAt = _clock().toUtc();
  }

  final Directory _codexHome;
  final DateTime Function() _clock;
  final RuntimeSnapshotReader? _runtimeSnapshotReader;
  final int recentTaskLimit;
  final Duration stallAfter;
  final int rolloutTailBytes;
  final Map<String, _RolloutCacheEntry> _rolloutCache =
      <String, _RolloutCacheEntry>{};
  final Map<String, _RolloutIdentity> _rolloutIdentityCache =
      <String, _RolloutIdentity>{};
  final Map<String, int> _lastTaskTokens = <String, int>{};
  final Map<String, int> _taskSessionTokens = <String, int>{};
  final List<_TokenDelta> _tokenDeltas = <_TokenDelta>[];
  RuntimeControlSnapshot? _lastRuntimeSnapshot;
  DateTime? _runtimeReadFailureSince;

  CodexPulseSnapshot? _lastSnapshot;
  int _sessionTokens = 0;
  bool _disposed = false;

  @override
  late final DateTime sessionStartedAt;

  @override
  Future<CodexPulseSnapshot> refresh() async {
    if (_disposed) {
      throw StateError('CodexPulseService is disposed.');
    }
    final now = _clock().toUtc();
    final runtimeRead = await _readRuntimeSnapshot(now);

    List<_ThreadRow> rows;
    String? stateReadError;
    try {
      rows = _readRecentThreads();
    } on Object catch (error) {
      final previous = _lastSnapshot;
      final sourceError = _boundedMessage(error);
      if (previous != null) {
        final fallback = CodexPulseSnapshot(
          tasks: previous.tasks,
          usage: _combinedUsage(now, runtimeRead.snapshot),
          sampledAt: now,
          runtimeHealth: runtimeRead.snapshot?.health ?? previous.runtimeHealth,
          runtimeUsage: runtimeRead.snapshot?.usage ?? previous.runtimeUsage,
          sourceError: _joinErrors(
            'Codex state read degraded: $sourceError',
            runtimeRead.error,
          ),
        );
        _lastSnapshot = fallback;
        return fallback;
      }
      stateReadError = 'Codex state read degraded: $sourceError';
      rows = const <_ThreadRow>[];
    }

    _pruneTaskState(rows);
    _recordTokenDeltas(rows, now);
    final threadTasks = await Future.wait(
      rows.map((row) => _buildTask(row, now)),
    );
    final aggregatedTasks = _aggregateRootTasks(threadTasks)
      ..sort(_compareTasks);
    final runtimeTasks = runtimeRead.snapshot == null
        ? const <CodexTaskSignal>[]
        : _externalRuntimeRootTasks(
            runtimeRead.snapshot!,
            forceUncertain: runtimeRead.uncertain,
          );
    final allTasks = <CodexTaskSignal>[...aggregatedTasks, ...runtimeTasks]
      ..sort(_compareTasks);
    final tasks = allTasks.take(recentTaskLimit).toList(growable: false);
    final snapshot = CodexPulseSnapshot(
      tasks: List<CodexTaskSignal>.unmodifiable(tasks),
      usage: _combinedUsage(now, runtimeRead.snapshot),
      sampledAt: now,
      runtimeHealth: runtimeRead.snapshot?.health ?? const <RuntimeHealth>[],
      runtimeUsage: runtimeRead.snapshot?.usage,
      sourceError: _joinErrors(stateReadError, runtimeRead.error),
    );
    _lastSnapshot = snapshot;
    return snapshot;
  }

  Future<_RuntimeRead> _readRuntimeSnapshot(DateTime now) async {
    final reader = _runtimeSnapshotReader;
    if (reader == null) {
      return const _RuntimeRead();
    }
    try {
      final snapshot = await reader();
      _lastRuntimeSnapshot = snapshot;
      _runtimeReadFailureSince = null;
      return _RuntimeRead(snapshot: snapshot);
    } on Object catch (error) {
      _runtimeReadFailureSince ??= now;
      final elapsed = now.difference(_runtimeReadFailureSince!);
      final reconnecting = elapsed < const Duration(seconds: 20);
      return _RuntimeRead(
        snapshot: _lastRuntimeSnapshot,
        uncertain: true,
        error: reconnecting
            ? null
            : 'Runtime telemetry degraded: ${_boundedMessage(error)}',
      );
    }
  }

  CodexPulseUsage _combinedUsage(
    DateTime now,
    RuntimeControlSnapshot? runtimeSnapshot,
  ) {
    final codex = _usageAt(now);
    if (runtimeSnapshot == null) {
      return codex;
    }
    final external = <RuntimeUsageWindow>[
      runtimeSnapshot.usage.hermes,
      runtimeSnapshot.usage.opencode,
    ];
    final startedAt = external.fold<DateTime>(
      codex.startedAt,
      (earliest, usage) =>
          usage.startedAt.isBefore(earliest) ? usage.startedAt : earliest,
    );
    return CodexPulseUsage(
      sinceStart: external.fold<int>(
        codex.sinceStart,
        (total, usage) => total + usage.sinceStart,
      ),
      lastMinute: external.fold<int>(
        codex.lastMinute,
        (total, usage) => total + usage.lastMinute,
      ),
      lastHour: external.fold<int>(
        codex.lastHour,
        (total, usage) => total + usage.lastHour,
      ),
      startedAt: startedAt,
    );
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _rolloutCache.clear();
    _rolloutIdentityCache.clear();
    _lastTaskTokens.clear();
    _taskSessionTokens.clear();
    _tokenDeltas.clear();
  }

  List<_ThreadRow> _readRecentThreads() {
    final databaseFile = _resolveStateDatabase();
    final database = sqlite3.open(databaseFile.path, mode: OpenMode.readOnly);
    try {
      final result = database.select(
        '''
SELECT
  id,
  COALESCE(NULLIF(name, ''), NULLIF(title, ''), id) AS display_title,
  COALESCE(model, '') AS model,
  COALESCE(model_provider, '') AS model_provider,
  reasoning_effort,
  updated_at_ms,
  COALESCE(tokens_used, 0) AS tokens_used,
  rollout_path
FROM threads
WHERE archived = 0 AND rollout_path IS NOT NULL
ORDER BY updated_at_ms DESC
LIMIT ?
''',
        <Object?>[(recentTaskLimit * 8).clamp(recentTaskLimit, 256).toInt()],
      );
      return <_ThreadRow>[
        for (final row in result)
          _threadRowWithIdentity(
            id: row['id'] as String,
            title: row['display_title'] as String,
            model: row['model'] as String,
            modelProvider: row['model_provider'] as String,
            reasoningEffort: row['reasoning_effort'] as String?,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              row['updated_at_ms'] as int,
              isUtc: true,
            ),
            tokensUsed: row['tokens_used'] as int,
            rolloutPath: _normalizeWindowsDevicePath(
              row['rollout_path'] as String,
            ),
          ),
      ]..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    } finally {
      database.close();
    }
  }

  _ThreadRow _threadRowWithIdentity({
    required String id,
    required String title,
    required String model,
    required String modelProvider,
    required String? reasoningEffort,
    required DateTime updatedAt,
    required int tokensUsed,
    required String rolloutPath,
  }) {
    final identity = _rolloutIdentityCache.putIfAbsent(rolloutPath, () {
      try {
        return _readRolloutIdentity(File(rolloutPath), fallbackId: id);
      } on Object {
        return _RolloutIdentity(sessionId: id);
      }
    });
    return _ThreadRow(
      id: id,
      title: title,
      model: model,
      modelProvider: modelProvider,
      reasoningEffort: reasoningEffort,
      updatedAt: updatedAt,
      tokensUsed: tokensUsed,
      rolloutPath: rolloutPath,
      sessionId: identity.sessionId,
      parentThreadId: identity.parentThreadId,
      agentNickname: identity.agentNickname,
      agentRole: identity.agentRole,
    );
  }

  File _resolveStateDatabase() {
    if (!_codexHome.existsSync()) {
      throw FileSystemException('Codex home does not exist.', _codexHome.path);
    }
    final candidates = _codexHome
        .listSync(followLinks: false)
        .whereType<File>()
        .where(
          (file) =>
              RegExp(r'^state_\d+\.sqlite$').hasMatch(path.basename(file.path)),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      throw FileSystemException(
        'No Codex state database was found.',
        _codexHome.path,
      );
    }
    candidates.sort((left, right) {
      final pattern = RegExp(r'^state_(\d+)\.sqlite$');
      final leftVersion = int.parse(
        pattern.firstMatch(path.basename(left.path))!.group(1)!,
      );
      final rightVersion = int.parse(
        pattern.firstMatch(path.basename(right.path))!.group(1)!,
      );
      final versionOrder = rightVersion.compareTo(leftVersion);
      if (versionOrder != 0) {
        return versionOrder;
      }
      return right.lastModifiedSync().compareTo(left.lastModifiedSync());
    });
    return candidates.first;
  }

  void _recordTokenDeltas(List<_ThreadRow> rows, DateTime now) {
    for (final row in rows) {
      final previous = _lastTaskTokens[row.id];
      _lastTaskTokens[row.id] = row.tokensUsed;
      _taskSessionTokens.putIfAbsent(row.id, () => 0);
      if (previous == null || row.tokensUsed <= previous) {
        continue;
      }
      final delta = row.tokensUsed - previous;
      _sessionTokens += delta;
      _taskSessionTokens[row.id] = (_taskSessionTokens[row.id] ?? 0) + delta;
      _tokenDeltas.add(_TokenDelta(at: now, tokens: delta));
    }
    final oldest = now.subtract(const Duration(hours: 1));
    _tokenDeltas.removeWhere((sample) => sample.at.isBefore(oldest));
  }

  void _pruneTaskState(List<_ThreadRow> rows) {
    final taskIds = rows.map((row) => row.id).toSet();
    final rolloutPaths = rows.map((row) => row.rolloutPath).toSet();
    _lastTaskTokens.removeWhere((taskId, _) => !taskIds.contains(taskId));
    _taskSessionTokens.removeWhere((taskId, _) => !taskIds.contains(taskId));
    _rolloutCache.removeWhere(
      (rolloutPath, _) => !rolloutPaths.contains(rolloutPath),
    );
    _rolloutIdentityCache.removeWhere(
      (rolloutPath, _) => !rolloutPaths.contains(rolloutPath),
    );
  }

  CodexPulseUsage _usageAt(DateTime now) {
    final minuteBoundary = now.subtract(const Duration(minutes: 1));
    final hourBoundary = now.subtract(const Duration(hours: 1));
    var lastMinute = 0;
    var lastHour = 0;
    for (final sample in _tokenDeltas) {
      if (!sample.at.isBefore(hourBoundary)) {
        lastHour += sample.tokens;
      }
      if (!sample.at.isBefore(minuteBoundary)) {
        lastMinute += sample.tokens;
      }
    }
    return CodexPulseUsage(
      sinceStart: _sessionTokens,
      lastMinute: lastMinute,
      lastHour: lastHour,
      startedAt: sessionStartedAt,
    );
  }

  Future<CodexTaskSignal> _buildTask(_ThreadRow row, DateTime now) async {
    CodexRolloutPulse rollout;
    try {
      rollout = await _readRollout(row.rolloutPath);
    } on Object {
      rollout = CodexRolloutPulse(
        phase: CodexTaskPhase.unknown,
        lastActivityAt: row.updatedAt,
        uncertain: true,
      );
    }

    var phase = rollout.phase;
    var lastActivityAt = rollout.lastActivityAt ?? row.updatedAt;
    var uncertain = rollout.uncertain;

    if (phase == CodexTaskPhase.unknown &&
        now.difference(row.updatedAt) <= const Duration(seconds: 18)) {
      phase = CodexTaskPhase.active;
      uncertain = true;
    }

    if (phase.isLive && now.difference(lastActivityAt) > stallAfter) {
      phase = CodexTaskPhase.stalled;
    }

    return CodexTaskSignal(
      id: row.id,
      title: row.title,
      model: row.model.isEmpty ? 'Unknown model' : row.model,
      provider: _providerLabel(row.modelProvider),
      phase: phase,
      totalTokens: row.tokensUsed,
      sessionTokens: _taskSessionTokens[row.id] ?? 0,
      lastActivityAt: lastActivityAt,
      sessionId: row.sessionId,
      parentThreadId: row.parentThreadId,
      agentNickname: row.agentNickname,
      agentRole: row.agentRole,
      startedAt: rollout.startedAt,
      reasoningEffort: row.reasoningEffort,
      contextTokens: rollout.contextTokens,
      contextWindow: rollout.contextWindow,
      retryAttempt: rollout.retryAttempt,
      errorSummary: rollout.errorSummary,
      uncertain: uncertain,
    );
  }

  Future<CodexRolloutPulse> _readRollout(String rolloutPath) async {
    final file = File(rolloutPath);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw FileSystemException('Rollout is not a file.', rolloutPath);
    }
    final cached = _rolloutCache[rolloutPath];
    if (cached != null &&
        cached.length == stat.size &&
        cached.modifiedAt == stat.modified.toUtc()) {
      return cached.pulse;
    }
    final tail = await _readBoundedTail(file, rolloutTailBytes);
    final pulse = parseCodexRolloutTail(tail, now: _clock().toUtc());
    _rolloutCache[rolloutPath] = _RolloutCacheEntry(
      length: stat.size,
      modifiedAt: stat.modified.toUtc(),
      pulse: pulse,
    );
    return pulse;
  }
}

List<CodexTaskSignal> _aggregateRootTasks(List<CodexTaskSignal> threads) {
  final groups = <String, List<CodexTaskSignal>>{};
  for (final thread in threads) {
    final sessionId = thread.sessionId?.trim();
    groups
        .putIfAbsent(
          sessionId == null || sessionId.isEmpty ? thread.id : sessionId,
          () => <CodexTaskSignal>[],
        )
        .add(thread);
  }

  final roots = <CodexTaskSignal>[];
  for (final entry in groups.entries) {
    final group = entry.value;
    group.sort(_compareTasks);
    CodexTaskSignal? persistedRoot;
    for (final candidate in group) {
      if (candidate.id == entry.key) {
        persistedRoot = candidate;
        break;
      }
    }
    final representative = persistedRoot ?? group.first;
    if (group.length == 1 && representative.id == entry.key) {
      roots.add(representative);
      continue;
    }

    final phaseOwner = group.reduce(
      (left, right) =>
          _phaseRank(left.phase) <= _phaseRank(right.phase) ? left : right,
    );
    final children =
        group
            .where(
              (thread) =>
                  persistedRoot == null || thread.id != persistedRoot.id,
            )
            .toList(growable: false)
          ..sort(_compareTasks);
    roots.add(
      CodexTaskSignal(
        id: entry.key,
        title: representative.title,
        model: representative.model,
        provider: representative.provider,
        phase: phaseOwner.phase,
        totalTokens: group.fold<int>(0, (sum, item) => sum + item.totalTokens),
        sessionTokens: group.fold<int>(
          0,
          (sum, item) => sum + item.sessionTokens,
        ),
        lastActivityAt: _latestDate(group.map((item) => item.lastActivityAt)),
        runtime: representative.runtime,
        capabilities: representative.capabilities,
        sessionId: entry.key,
        children: List<CodexTaskSignal>.unmodifiable(children),
        startedAt: _earliestDate(group.map((item) => item.startedAt)),
        reasoningEffort: representative.reasoningEffort,
        contextTokens: representative.contextTokens,
        contextWindow: representative.contextWindow,
        retryAttempt: phaseOwner.retryAttempt,
        retryMaximum: phaseOwner.retryMaximum,
        streamedCharacters: phaseOwner.streamedCharacters,
        errorSummary: _firstNonNullString(
          group.map((item) => item.errorSummary),
        ),
        uncertain: group.every((item) => item.uncertain),
      ),
    );
  }
  return roots;
}

List<CodexTaskSignal> _externalRuntimeRootTasks(
  RuntimeControlSnapshot snapshot, {
  required bool forceUncertain,
}) {
  final records = snapshot.tasks
      .where((task) => task.runtime != AgentRuntime.codex)
      .toList(growable: false);
  final groups = <String, List<RuntimeTaskRecord>>{};
  for (final record in records) {
    groups.putIfAbsent(record.rootId, () => <RuntimeTaskRecord>[]).add(record);
  }
  final roots = <CodexTaskSignal>[];
  for (final entry in groups.entries) {
    final group = entry.value..sort(_compareRuntimeRecords);
    final representative =
        group.where((item) => item.isRoot).firstOrNull ?? group.first;
    final runtime = representative.runtime;
    final phaseOwner = group.reduce(
      (left, right) =>
          _phaseRank(_runtimePhase(left.state)) <=
              _phaseRank(_runtimePhase(right.state))
          ? left
          : right,
    );
    final runtimePrefix = '${runtime.name}:';
    final rootNativeId = entry.key.startsWith(runtimePrefix)
        ? entry.key.substring(runtimePrefix.length)
        : representative.nativeId;
    final children =
        group
            .where((item) => item.nativeId != rootNativeId)
            .map(
              (item) => _runtimeTaskSignal(
                item,
                totalTokens: item.usage.totalTokens,
                sessionTokens: item.usage.sessionTokens,
                forceUncertain: forceUncertain,
              ),
            )
            .toList(growable: false)
          ..sort(_compareTasks);
    final capabilities = RuntimeTaskCapabilities(
      open: group.any((item) => item.capabilities.open),
      pause: group.any((item) => item.capabilities.pause),
      resume: group.any((item) => item.capabilities.resume),
      stop: group.any((item) => item.capabilities.stop),
    );
    roots.add(
      CodexTaskSignal(
        id: rootNativeId,
        title: representative.title,
        model: phaseOwner.model,
        provider: phaseOwner.provider,
        phase: _runtimePhase(phaseOwner.state),
        totalTokens: representative.aggregateUsage.totalTokens,
        sessionTokens: representative.aggregateUsage.sessionTokens,
        lastActivityAt: _latestDate(group.map((item) => item.lastActivityAt)),
        runtime: runtime,
        capabilities: capabilities,
        sessionId: rootNativeId,
        cwd: representative.cwd,
        children: List<CodexTaskSignal>.unmodifiable(children),
        startedAt: _earliestDate(group.map((item) => item.startedAt)),
        errorSummary: group
            .map((item) => item.errorSummary)
            .whereType<String>()
            .firstOrNull,
        uncertain: forceUncertain || group.any((item) => item.uncertain),
      ),
    );
  }
  return roots;
}

CodexTaskSignal _runtimeTaskSignal(
  RuntimeTaskRecord record, {
  required int totalTokens,
  required int sessionTokens,
  required bool forceUncertain,
}) {
  String? parentNativeId;
  if (record.parentId case final parent?) {
    parentNativeId = parent.startsWith('${record.runtime.name}:')
        ? parent.substring(record.runtime.name.length + 1)
        : parent;
  }
  return CodexTaskSignal(
    id: record.nativeId,
    title: record.title,
    model: record.model,
    provider: record.provider,
    phase: _runtimePhase(record.state),
    totalTokens: totalTokens,
    sessionTokens: sessionTokens,
    lastActivityAt: record.lastActivityAt,
    runtime: record.runtime,
    capabilities: record.capabilities,
    sessionId: record.nativeId,
    cwd: record.cwd,
    parentThreadId: parentNativeId,
    startedAt: record.startedAt,
    errorSummary: record.errorSummary,
    uncertain: forceUncertain || record.uncertain,
  );
}

CodexTaskPhase _runtimePhase(String state) => switch (state) {
  'queued' => CodexTaskPhase.queued,
  'active' => CodexTaskPhase.active,
  'reasoning' => CodexTaskPhase.reasoning,
  'tool' => CodexTaskPhase.tool,
  'retrying' || 'reconnecting' => CodexTaskPhase.retrying,
  'stalled' => CodexTaskPhase.stalled,
  'failed' => CodexTaskPhase.failed,
  'cancelled' => CodexTaskPhase.cancelled,
  'idle' => CodexTaskPhase.idle,
  _ => CodexTaskPhase.unknown,
};

int _compareRuntimeRecords(RuntimeTaskRecord left, RuntimeTaskRecord right) {
  final leftRank = _phaseRank(_runtimePhase(left.state));
  final rightRank = _phaseRank(_runtimePhase(right.state));
  if (leftRank != rightRank) {
    return leftRank.compareTo(rightRank);
  }
  final activity = _compareNullableDates(
    right.lastActivityAt,
    left.lastActivityAt,
  );
  return activity != 0 ? activity : left.id.compareTo(right.id);
}

int _compareNullableDates(DateTime? left, DateTime? right) {
  if (left == null) {
    return right == null ? 0 : -1;
  }
  return right == null ? 1 : left.compareTo(right);
}

String? _joinErrors(String? left, String? right) {
  final values = <String>{
    if (left != null && left.trim().isNotEmpty) left.trim(),
    if (right != null && right.trim().isNotEmpty) right.trim(),
  };
  return values.isEmpty ? null : values.join(' ');
}

DateTime? _latestDate(Iterable<DateTime?> values) {
  DateTime? latest;
  for (final value in values) {
    if (value != null && (latest == null || value.isAfter(latest))) {
      latest = value;
    }
  }
  return latest;
}

DateTime? _earliestDate(Iterable<DateTime?> values) {
  DateTime? earliest;
  for (final value in values) {
    if (value != null && (earliest == null || value.isBefore(earliest))) {
      earliest = value;
    }
  }
  return earliest;
}

String? _firstNonNullString(Iterable<String?> values) {
  for (final value in values) {
    if (value != null) {
      return value;
    }
  }
  return null;
}

_RolloutIdentity _readRolloutIdentity(File file, {required String fallbackId}) {
  final handle = file.openSync(mode: FileMode.read);
  try {
    final length = handle.lengthSync();
    final bytes = handle.readSync(length.clamp(0, 131072).toInt());
    final text = utf8.decode(bytes, allowMalformed: true);
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) {
        continue;
      }
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, Object?> ||
          decoded['type'] != 'session_meta') {
        break;
      }
      final payload = decoded['payload'];
      if (payload is! Map<String, Object?>) {
        break;
      }
      final sessionId = (_string(payload['session_id']) ?? fallbackId).trim();
      final parentThreadId = _string(payload['parent_thread_id'])?.trim();
      return _RolloutIdentity(
        sessionId: sessionId.isEmpty ? fallbackId : sessionId,
        parentThreadId: parentThreadId == null || parentThreadId.isEmpty
            ? null
            : parentThreadId,
        agentNickname: _string(payload['agent_nickname'])?.trim(),
        agentRole: _string(payload['agent_role'])?.trim(),
      );
    }
    return _RolloutIdentity(sessionId: fallbackId);
  } finally {
    handle.closeSync();
  }
}

class CodexRolloutPulse {
  const CodexRolloutPulse({
    required this.phase,
    required this.lastActivityAt,
    this.startedAt,
    this.contextTokens,
    this.contextWindow,
    this.retryAttempt,
    this.errorSummary,
    this.uncertain = false,
  });

  final CodexTaskPhase phase;
  final DateTime? lastActivityAt;
  final DateTime? startedAt;
  final int? contextTokens;
  final int? contextWindow;
  final int? retryAttempt;
  final String? errorSummary;
  final bool uncertain;
}

CodexRolloutPulse parseCodexRolloutTail(String text, {DateTime? now}) {
  DateTime? lastActivityAt;
  DateTime? startedAt;
  DateTime? completionAt;
  DateTime? phaseAt;
  var phaseCandidate = CodexTaskPhase.unknown;
  var completionPhase = CodexTaskPhase.unknown;
  int? contextTokens;
  int? contextWindow;
  int? retryAttempt;
  String? errorSummary;
  var sawLifecycleEvidence = false;

  for (final rawLine in const LineSplitter().convert(text)) {
    if (rawLine.trim().isEmpty) {
      continue;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(rawLine);
    } on FormatException {
      continue;
    }
    if (decoded is! Map<String, Object?>) {
      continue;
    }
    final timestamp = DateTime.tryParse(
      _string(decoded['timestamp']) ?? '',
    )?.toUtc();
    if (timestamp != null &&
        (lastActivityAt == null || timestamp.isAfter(lastActivityAt))) {
      lastActivityAt = timestamp;
    }
    final topType = _string(decoded['type']);
    final payload = decoded['payload'];
    if (payload is! Map<String, Object?>) {
      continue;
    }
    final payloadType = _string(payload['type']) ?? '';

    if (topType == 'event_msg') {
      if (payloadType == 'task_started') {
        startedAt = timestamp ?? _epochSeconds(payload['started_at']);
        phaseAt = timestamp ?? startedAt;
        phaseCandidate = CodexTaskPhase.active;
        contextWindow = _nullableInteger(payload['model_context_window']);
        errorSummary = null;
        sawLifecycleEvidence = true;
        continue;
      }
      if (payloadType == 'task_complete') {
        completionAt = timestamp ?? _epochSeconds(payload['completed_at']);
        final error = payload['error'];
        completionPhase = error == null
            ? CodexTaskPhase.idle
            : CodexTaskPhase.failed;
        if (error != null) {
          errorSummary = _boundedMessage(error);
        }
        sawLifecycleEvidence = true;
        continue;
      }
      if (payloadType.contains('cancel') || payloadType.contains('abort')) {
        completionAt = timestamp;
        completionPhase = CodexTaskPhase.cancelled;
        sawLifecycleEvidence = true;
        continue;
      }
      if (payloadType == 'token_count') {
        final info = payload['info'];
        if (info is Map<String, Object?>) {
          contextWindow =
              _nullableInteger(info['model_context_window']) ?? contextWindow;
          final lastUsage = info['last_token_usage'];
          if (lastUsage is Map<String, Object?>) {
            contextTokens =
                _nullableInteger(lastUsage['total_tokens']) ?? contextTokens;
          }
        }
        continue;
      }
      if (payloadType.contains('reason')) {
        phaseAt = timestamp;
        phaseCandidate = CodexTaskPhase.reasoning;
        sawLifecycleEvidence = true;
        continue;
      }
      if (payloadType == 'item_started') {
        phaseAt = timestamp;
        final item = payload['item'];
        final itemType = item is Map<String, Object?>
            ? _string(item['type']) ?? ''
            : '';
        phaseCandidate =
            itemType.toLowerCase().contains('command') ||
                itemType.toLowerCase().contains('tool')
            ? CodexTaskPhase.tool
            : CodexTaskPhase.active;
        sawLifecycleEvidence = true;
        continue;
      }
      if (payloadType == 'item_completed' ||
          payloadType.contains('agent_message')) {
        phaseAt = timestamp;
        phaseCandidate = CodexTaskPhase.active;
        sawLifecycleEvidence = true;
        continue;
      }
    }

    if (topType == 'response_item') {
      if (payloadType == 'reasoning') {
        phaseAt = timestamp;
        phaseCandidate = CodexTaskPhase.reasoning;
        sawLifecycleEvidence = true;
      } else if (payloadType == 'function_call' ||
          payloadType == 'custom_tool_call') {
        phaseAt = timestamp;
        phaseCandidate = CodexTaskPhase.tool;
        sawLifecycleEvidence = true;
      } else if (payloadType == 'message' && payload['role'] == 'assistant') {
        phaseAt = timestamp;
        phaseCandidate = CodexTaskPhase.active;
        sawLifecycleEvidence = true;
      }
    }
  }

  final phase =
      phaseAt != null && (completionAt == null || phaseAt.isAfter(completionAt))
      ? phaseCandidate
      : completionPhase;
  return CodexRolloutPulse(
    phase: phase,
    lastActivityAt: lastActivityAt,
    startedAt: startedAt,
    contextTokens: contextTokens,
    contextWindow: contextWindow,
    retryAttempt: retryAttempt,
    errorSummary: errorSummary,
    uncertain: !sawLifecycleEvidence || phase == CodexTaskPhase.unknown,
  );
}

class _RuntimeRead {
  const _RuntimeRead({this.snapshot, this.error, this.uncertain = false});

  final RuntimeControlSnapshot? snapshot;
  final String? error;
  final bool uncertain;
}

class _ThreadRow {
  const _ThreadRow({
    required this.id,
    required this.title,
    required this.model,
    required this.modelProvider,
    required this.updatedAt,
    required this.tokensUsed,
    required this.rolloutPath,
    required this.sessionId,
    this.parentThreadId,
    this.agentNickname,
    this.agentRole,
    this.reasoningEffort,
  });

  final String id;
  final String title;
  final String model;
  final String modelProvider;
  final String? reasoningEffort;
  final DateTime updatedAt;
  final int tokensUsed;
  final String rolloutPath;
  final String sessionId;
  final String? parentThreadId;
  final String? agentNickname;
  final String? agentRole;
}

class _RolloutIdentity {
  const _RolloutIdentity({
    required this.sessionId,
    this.parentThreadId,
    this.agentNickname,
    this.agentRole,
  });

  final String sessionId;
  final String? parentThreadId;
  final String? agentNickname;
  final String? agentRole;
}

class _RolloutCacheEntry {
  const _RolloutCacheEntry({
    required this.length,
    required this.modifiedAt,
    required this.pulse,
  });

  final int length;
  final DateTime modifiedAt;
  final CodexRolloutPulse pulse;
}

class _TokenDelta {
  const _TokenDelta({required this.at, required this.tokens});

  final DateTime at;
  final int tokens;
}

Future<String> _readBoundedTail(File file, int maximumBytes) async {
  final handle = await file.open(mode: FileMode.read);
  try {
    final length = await handle.length();
    final start = length > maximumBytes ? length - maximumBytes : 0;
    await handle.setPosition(start);
    final bytes = await handle.read(length - start);
    var text = utf8.decode(bytes, allowMalformed: true);
    if (start > 0) {
      final newline = text.indexOf('\n');
      text = newline == -1 ? '' : text.substring(newline + 1);
    }
    return text;
  } finally {
    await handle.close();
  }
}

Directory _defaultCodexHome() {
  final profile = Platform.environment['USERPROFILE'];
  if (profile == null || profile.trim().isEmpty) {
    throw const FileSystemException(
      'USERPROFILE is unavailable; Codex home cannot be resolved.',
    );
  }
  return Directory(path.join(profile, '.codex'));
}

String _normalizeWindowsDevicePath(String value) {
  const devicePrefix = r'\\?\';
  return value.startsWith(devicePrefix)
      ? value.substring(devicePrefix.length)
      : value;
}

String _providerLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'openai' => 'OpenAI',
    'opencode_zen' => 'OpenCode Zen',
    '' => 'Unknown',
    _ => value,
  };
}

int _compareTasks(CodexTaskSignal left, CodexTaskSignal right) {
  final phase = _phaseRank(left.phase).compareTo(_phaseRank(right.phase));
  if (phase != 0) {
    return phase;
  }
  final leftAt = left.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final rightAt =
      right.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return rightAt.compareTo(leftAt);
}

int compareCodexPulseTasksForTest(
  CodexTaskSignal left,
  CodexTaskSignal right,
) => _compareTasks(left, right);

int _phaseRank(CodexTaskPhase phase) => switch (phase) {
  CodexTaskPhase.retrying => 0,
  CodexTaskPhase.queued => 1,
  CodexTaskPhase.reasoning => 2,
  CodexTaskPhase.tool => 3,
  CodexTaskPhase.active => 4,
  CodexTaskPhase.failed => 5,
  CodexTaskPhase.stalled => 6,
  CodexTaskPhase.cancelled => 7,
  CodexTaskPhase.idle => 8,
  CodexTaskPhase.unknown => 9,
};

DateTime? _epochSeconds(Object? value) {
  final seconds = _nullableInteger(value);
  if (seconds == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

String? _string(Object? value) => value is String ? value : null;

int _integer(Object? value) {
  return switch (value) {
    int item => item,
    double item => item.round(),
    String item => int.tryParse(item) ?? 0,
    _ => 0,
  };
}

int? _nullableInteger(Object? value) {
  if (value == null) {
    return null;
  }
  return _integer(value);
}

String _boundedMessage(Object? value, {int maximum = 220}) {
  final normalized = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maximum) {
    return normalized;
  }
  return '${normalized.substring(0, maximum - 1)}…';
}
