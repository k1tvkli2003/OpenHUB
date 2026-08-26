import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

enum AgentRuntime { codex, hermes, opencode }

extension AgentRuntimePresentation on AgentRuntime {
  String get label => switch (this) {
    AgentRuntime.codex => 'Codex',
    AgentRuntime.hermes => 'Hermes',
    AgentRuntime.opencode => 'OpenCode',
  };
}

class RuntimeTaskCapabilities {
  const RuntimeTaskCapabilities({
    required this.open,
    required this.pause,
    required this.resume,
    required this.stop,
  });

  const RuntimeTaskCapabilities.codexNative()
    : this(open: true, pause: true, resume: true, stop: false);

  final bool open;
  final bool pause;
  final bool resume;
  final bool stop;

  factory RuntimeTaskCapabilities.fromJson(Map<String, Object?> json) {
    const context = 'runtimeControl.tasks[].capabilities';
    return RuntimeTaskCapabilities(
      open: readBool(json, 'open', context),
      pause: readBool(json, 'pause', context),
      resume: readBool(json, 'resume', context),
      stop: readBool(json, 'stop', context),
    );
  }
}

class RuntimeTaskUsage {
  const RuntimeTaskUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheWriteTokens,
    required this.reasoningTokens,
    required this.totalTokens,
    required this.sessionTokens,
  });

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  final int reasoningTokens;
  final int totalTokens;
  final int sessionTokens;

  factory RuntimeTaskUsage.fromJson(Map<String, Object?> json, String context) {
    final values = RuntimeTaskUsage(
      inputTokens: readInt(json, 'inputTokens', context),
      outputTokens: readInt(json, 'outputTokens', context),
      cacheReadTokens: readInt(json, 'cacheReadTokens', context),
      cacheWriteTokens: readInt(json, 'cacheWriteTokens', context),
      reasoningTokens: readInt(json, 'reasoningTokens', context),
      totalTokens: readInt(json, 'totalTokens', context),
      sessionTokens: readInt(json, 'sessionTokens', context),
    );
    if (values.inputTokens < 0 ||
        values.outputTokens < 0 ||
        values.cacheReadTokens < 0 ||
        values.cacheWriteTokens < 0 ||
        values.reasoningTokens < 0 ||
        values.totalTokens < 0 ||
        values.sessionTokens < 0) {
      throw ApiSchemaException('$context token counters must be non-negative.');
    }
    return values;
  }
}

class RuntimeTaskRecord {
  const RuntimeTaskRecord({
    required this.id,
    required this.nativeId,
    required this.runtime,
    required this.rootId,
    required this.isRoot,
    required this.childCount,
    required this.title,
    required this.provider,
    required this.model,
    required this.state,
    required this.usage,
    required this.aggregateUsage,
    required this.capabilities,
    required this.uncertain,
    this.parentId,
    this.cwd,
    this.startedAt,
    this.lastActivityAt,
    this.endedAt,
    this.errorSummary,
  });

  final String id;
  final String nativeId;
  final AgentRuntime runtime;
  final String rootId;
  final String? parentId;
  final bool isRoot;
  final int childCount;
  final String title;
  final String? cwd;
  final String provider;
  final String model;
  final String state;
  final DateTime? startedAt;
  final DateTime? lastActivityAt;
  final DateTime? endedAt;
  final RuntimeTaskUsage usage;
  final RuntimeTaskUsage aggregateUsage;
  final RuntimeTaskCapabilities capabilities;
  final bool uncertain;
  final String? errorSummary;

  factory RuntimeTaskRecord.fromJson(Map<String, Object?> json) {
    const context = 'runtimeControl.tasks[]';
    final runtime = _runtime(readString(json, 'runtime', context), context);
    final childCount = readInt(json, 'childCount', context);
    if (childCount < 0) {
      throw const ApiSchemaException(
        'runtimeControl.tasks[].childCount must be non-negative.',
      );
    }
    return RuntimeTaskRecord(
      id: readString(json, 'id', context),
      nativeId: readString(json, 'nativeId', context),
      runtime: runtime,
      rootId: readString(json, 'rootId', context),
      parentId: readNullableString(json, 'parentId', context),
      isRoot: readBool(json, 'isRoot', context),
      childCount: childCount,
      title: readString(json, 'title', context),
      cwd: readNullableString(json, 'cwd', context),
      provider: readString(json, 'provider', context),
      model: readString(json, 'model', context),
      state: readString(json, 'state', context),
      startedAt: readNullableDateTime(json, 'startedAt', context),
      lastActivityAt: readNullableDateTime(json, 'lastActivityAt', context),
      endedAt: readNullableDateTime(json, 'endedAt', context),
      usage: RuntimeTaskUsage.fromJson(
        readObject(json['usage'], '$context.usage'),
        '$context.usage',
      ),
      aggregateUsage: RuntimeTaskUsage.fromJson(
        readObject(json['aggregateUsage'], '$context.aggregateUsage'),
        '$context.aggregateUsage',
      ),
      capabilities: RuntimeTaskCapabilities.fromJson(
        readObject(json['capabilities'], '$context.capabilities'),
      ),
      uncertain: readBool(json, 'uncertain', context),
      errorSummary: readNullableString(json, 'errorSummary', context),
    );
  }
}

class RuntimeHealth {
  const RuntimeHealth({
    required this.runtime,
    required this.status,
    required this.databasePath,
    this.gatewayReachable,
    this.reconnectDeadline,
    this.message,
  });

  final AgentRuntime runtime;
  final String status;
  final String databasePath;
  final bool? gatewayReachable;
  final DateTime? reconnectDeadline;
  final String? message;

  bool get available => status == 'available';
  bool get reconnecting => status == 'reconnecting';

  factory RuntimeHealth.fromJson(Map<String, Object?> json) {
    const context = 'runtimeControl.health[]';
    final rawGateway = json['gatewayReachable'];
    if (rawGateway != null && rawGateway is! bool) {
      throw const ApiSchemaException(
        'runtimeControl.health[].gatewayReachable must be a boolean or null.',
      );
    }
    return RuntimeHealth(
      runtime: _runtime(readString(json, 'runtime', context), context),
      status: readString(json, 'status', context),
      databasePath: readString(json, 'databasePath', context),
      gatewayReachable: rawGateway as bool?,
      reconnectDeadline: readNullableDateTime(
        json,
        'reconnectDeadline',
        context,
      ),
      message: readNullableString(json, 'message', context),
    );
  }
}

class RuntimeUsageWindow {
  const RuntimeUsageWindow({
    required this.sinceStart,
    required this.lastMinute,
    required this.lastHour,
    required this.startedAt,
  });

  final int sinceStart;
  final int lastMinute;
  final int lastHour;
  final DateTime startedAt;

  factory RuntimeUsageWindow.fromJson(
    Map<String, Object?> json,
    String context,
  ) {
    final startedAt = readNullableDateTime(json, 'startedAt', context);
    final window = RuntimeUsageWindow(
      sinceStart: readInt(json, 'sinceStart', context),
      lastMinute: readInt(json, 'lastMinute', context),
      lastHour: readInt(json, 'lastHour', context),
      startedAt:
          startedAt ??
          (throw ApiSchemaException('$context.startedAt must not be null.')),
    );
    if (window.sinceStart < 0 || window.lastMinute < 0 || window.lastHour < 0) {
      throw ApiSchemaException('$context counters must be non-negative.');
    }
    return window;
  }
}

class RuntimeUsageSummary {
  const RuntimeUsageSummary({
    required this.total,
    required this.codex,
    required this.hermes,
    required this.opencode,
  });

  final RuntimeUsageWindow total;
  final RuntimeUsageWindow codex;
  final RuntimeUsageWindow hermes;
  final RuntimeUsageWindow opencode;

  factory RuntimeUsageSummary.fromJson(Map<String, Object?> json) {
    const context = 'runtimeControl.usage';
    return RuntimeUsageSummary(
      total: RuntimeUsageWindow.fromJson(
        readObject(json['total'], '$context.total'),
        '$context.total',
      ),
      codex: RuntimeUsageWindow.fromJson(
        readObject(json['codex'], '$context.codex'),
        '$context.codex',
      ),
      hermes: RuntimeUsageWindow.fromJson(
        readObject(json['hermes'], '$context.hermes'),
        '$context.hermes',
      ),
      opencode: RuntimeUsageWindow.fromJson(
        readObject(json['opencode'], '$context.opencode'),
        '$context.opencode',
      ),
    );
  }
}

class RuntimeControlSnapshot {
  const RuntimeControlSnapshot({
    required this.sampledAt,
    required this.reconnectGraceSeconds,
    required this.tasks,
    required this.health,
    required this.usage,
  });

  final DateTime sampledAt;
  final int reconnectGraceSeconds;
  final List<RuntimeTaskRecord> tasks;
  final List<RuntimeHealth> health;
  final RuntimeUsageSummary usage;

  factory RuntimeControlSnapshot.fromJson(Map<String, Object?> json) {
    const context = 'runtimeControl';
    final sampledAt = readNullableDateTime(json, 'sampledAt', context);
    final grace = readInt(json, 'reconnectGraceSeconds', context);
    final tasks = readList(json['tasks'], '$context.tasks')
        .map(
          (item) =>
              RuntimeTaskRecord.fromJson(readObject(item, '$context.tasks[]')),
        )
        .toList(growable: false);
    final health = readList(json['health'], '$context.health')
        .map(
          (item) =>
              RuntimeHealth.fromJson(readObject(item, '$context.health[]')),
        )
        .toList(growable: false);
    if (sampledAt == null ||
        grace < 1 ||
        tasks.length > 500 ||
        health.length > 8) {
      throw const ApiSchemaException(
        'runtimeControl response is out of bounds.',
      );
    }
    return RuntimeControlSnapshot(
      sampledAt: sampledAt,
      reconnectGraceSeconds: grace,
      tasks: tasks,
      health: health,
      usage: RuntimeUsageSummary.fromJson(
        readObject(json['usage'], '$context.usage'),
      ),
    );
  }
}

class RuntimeTaskActionResult {
  const RuntimeTaskActionResult({
    required this.runtime,
    required this.nativeId,
    required this.action,
    required this.detail,
  });

  final AgentRuntime runtime;
  final String nativeId;
  final String action;
  final String detail;

  factory RuntimeTaskActionResult.fromJson(Map<String, Object?> json) {
    const context = 'runtimeAction';
    if (!readBool(json, 'succeeded', context)) {
      throw const ApiSchemaException('runtimeAction did not succeed.');
    }
    return RuntimeTaskActionResult(
      runtime: _runtime(readString(json, 'runtime', context), context),
      nativeId: readString(json, 'nativeId', context),
      action: readString(json, 'action', context),
      detail: readString(json, 'detail', context),
    );
  }
}

AgentRuntime _runtime(String value, String context) => switch (value) {
  'codex' => AgentRuntime.codex,
  'hermes' => AgentRuntime.hermes,
  'opencode' => AgentRuntime.opencode,
  _ => throw ApiSchemaException('$context.runtime is unsupported.'),
};
