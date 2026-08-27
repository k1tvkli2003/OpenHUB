import 'dart:async';

import 'codex_app_server_client.dart';

class CodexTaskLifecycleException implements Exception {
  const CodexTaskLifecycleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CodexTaskGroup {
  const CodexTaskGroup({required this.root, required this.descendants});

  final CodexAppServerThread root;
  final List<CodexAppServerThread> descendants;

  String get sessionId => root.sessionId;
  List<CodexAppServerThread> get allThreads =>
      List<CodexAppServerThread>.unmodifiable(<CodexAppServerThread>[
        root,
        ...descendants,
      ]);
  bool get isLive => allThreads.any((thread) => thread.isActive);
}

class CodexTaskSwitchPreflight {
  const CodexTaskSwitchPreflight({required this.groups});

  final List<CodexTaskGroup> groups;

  List<CodexTaskGroup> get liveGroups =>
      groups.where((group) => group.isLive).toList(growable: false);
  int get liveRootCount => liveGroups.length;
  int get liveDescendantCount => liveGroups.fold<int>(
    0,
    (sum, group) =>
        sum + group.descendants.where((thread) => thread.isActive).length,
  );
}

class CodexTaskPauseResult {
  const CodexTaskPauseResult({
    required this.rootThreadId,
    required this.interruptedTurnCount,
    required this.persistentGoalPaused,
    required this.requiresContinuation,
  });

  final String rootThreadId;
  final int interruptedTurnCount;
  final bool persistentGoalPaused;
  final bool requiresContinuation;
}

enum CodexTaskResumeDisposition {
  goalResumed,
  alreadyActive,
  continuationRequired,
  continuationStarted,
}

class CodexTaskResumeResult {
  const CodexTaskResumeResult({
    required this.rootThreadId,
    required this.disposition,
    this.turnId,
  });

  final String rootThreadId;
  final CodexTaskResumeDisposition disposition;
  final String? turnId;
}

class CodexTaskLifecycleService {
  const CodexTaskLifecycleService(this._controlPlane);

  final CodexAppServerControlPlane _controlPlane;

  Future<CodexTaskSwitchPreflight> preflight() async {
    final threads = await _controlPlane.listAllThreads();
    return CodexTaskSwitchPreflight(groups: _groupThreads(threads));
  }

  Future<CodexTaskPauseResult> pause(String sessionId) async {
    final group = await _findGroup(sessionId);
    final activeTurns = <({String threadId, String turnId})>[];
    for (final thread in group.allThreads) {
      final recent = await _controlPlane.listRecentTurns(thread.id, limit: 1);
      for (final turn in recent.data) {
        if (turn.isInProgress) {
          activeTurns.add((threadId: thread.id, turnId: turn.id));
          break;
        }
      }
    }

    final goal = await _controlPlane.getGoal(group.root.id);
    final canPauseGoal =
        goal != null &&
        !const <String>{'complete', 'paused'}.contains(goal.status);
    if (canPauseGoal) {
      await _controlPlane.setGoalStatus(group.root.id, 'paused');
    }

    for (final active in activeTurns) {
      try {
        await _controlPlane.interruptTurn(active.threadId, active.turnId);
      } on CodexAppServerException {
        final latest = await _controlPlane.listRecentTurns(
          active.threadId,
          limit: 1,
        );
        final stillActive = latest.data.any(
          (turn) => turn.id == active.turnId && turn.isInProgress,
        );
        if (stillActive) {
          rethrow;
        }
      }
    }

    await _verifyNoActiveTurns(group);
    final persistentGoalPaused = goal?.status == 'paused' || canPauseGoal;
    return CodexTaskPauseResult(
      rootThreadId: group.root.id,
      interruptedTurnCount: activeTurns.length,
      persistentGoalPaused: persistentGoalPaused,
      requiresContinuation: !persistentGoalPaused && activeTurns.isNotEmpty,
    );
  }

  Future<CodexTaskResumeResult> resume(String sessionId) async {
    final group = await _findGroup(sessionId);
    await _controlPlane.resumeThread(group.root.id);
    final goal = await _controlPlane.getGoal(group.root.id);
    if (goal?.status == 'paused') {
      await _controlPlane.setGoalStatus(group.root.id, 'active');
      return CodexTaskResumeResult(
        rootThreadId: group.root.id,
        disposition: CodexTaskResumeDisposition.goalResumed,
      );
    }
    if (goal?.status == 'active') {
      return CodexTaskResumeResult(
        rootThreadId: group.root.id,
        disposition: CodexTaskResumeDisposition.alreadyActive,
      );
    }
    return CodexTaskResumeResult(
      rootThreadId: group.root.id,
      disposition: CodexTaskResumeDisposition.continuationRequired,
    );
  }

  Future<CodexTaskResumeResult> continueTask(
    String sessionId, {
    String message =
        'Continue the interrupted task from the latest persisted state. Re-check current workspace state before acting, preserve completed work, and finish the remaining user request.',
  }) async {
    final group = await _findGroup(sessionId);
    await _controlPlane.resumeThread(group.root.id);
    final turn = await _controlPlane.startContinuation(
      group.root.id,
      message: message,
    );
    return CodexTaskResumeResult(
      rootThreadId: group.root.id,
      disposition: CodexTaskResumeDisposition.continuationStarted,
      turnId: turn.id,
    );
  }

  Future<void> compact(
    String sessionId, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final group = await _findGroup(sessionId);
    final before = await _controlPlane.listRecentTurns(group.root.id, limit: 1);
    final previousId = before.data.isEmpty ? null : before.data.first.id;
    await _controlPlane.compactThread(group.root.id);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final recent = await _controlPlane.listRecentTurns(
        group.root.id,
        limit: 2,
      );
      for (final turn in recent.data) {
        if (turn.id == previousId) {
          continue;
        }
        if (turn.status == 'completed') {
          return;
        }
        if (turn.status == 'failed' || turn.status == 'interrupted') {
          throw CodexTaskLifecycleException(
            'Codex context compaction ended with ${turn.status}.',
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw const CodexTaskLifecycleException(
      'Codex context compaction did not complete before the safety timeout.',
    );
  }

  Future<CodexTaskGroup> _findGroup(String sessionId) async {
    final normalized = sessionId.trim();
    final groups = _groupThreads(await _controlPlane.listAllThreads());
    for (final group in groups) {
      if (group.sessionId == normalized || group.root.id == normalized) {
        return group;
      }
    }
    throw CodexTaskLifecycleException(
      'Codex task group was not found: $normalized.',
    );
  }

  Future<void> _verifyNoActiveTurns(CodexTaskGroup group) async {
    for (final thread in group.allThreads) {
      final recent = await _controlPlane.listRecentTurns(thread.id, limit: 1);
      if (recent.data.any((turn) => turn.isInProgress)) {
        throw CodexTaskLifecycleException(
          'Task ${thread.id} still has an in-progress turn after pause.',
        );
      }
    }
  }
}

List<CodexTaskGroup> _groupThreads(List<CodexAppServerThread> threads) {
  final groups = <String, List<CodexAppServerThread>>{};
  for (final thread in threads) {
    groups
        .putIfAbsent(thread.sessionId, () => <CodexAppServerThread>[])
        .add(thread);
  }
  final result = <CodexTaskGroup>[];
  for (final entry in groups.entries) {
    final members = entry.value;
    CodexAppServerThread? root;
    for (final member in members) {
      if (member.id == entry.key) {
        root = member;
        break;
      }
    }
    root ??= members
        .where((member) => member.parentThreadId == null)
        .firstOrNull;
    final rootThread = root ?? members.first;
    result.add(
      CodexTaskGroup(
        root: rootThread,
        descendants: List<CodexAppServerThread>.unmodifiable(
          members.where((member) => member.id != rootThread.id),
        ),
      ),
    );
  }
  return List<CodexTaskGroup>.unmodifiable(result);
}
