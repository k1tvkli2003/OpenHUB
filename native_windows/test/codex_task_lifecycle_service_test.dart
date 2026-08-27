import 'package:openhub_windows/src/core/runtime/codex_app_server_client.dart';
import 'package:openhub_windows/src/core/runtime/codex_task_lifecycle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pause interrupts root and children and pauses a persistent goal',
    () async {
      final control = _FakeControlPlane(withGoal: true);
      final service = CodexTaskLifecycleService(control);

      final preflight = await service.preflight();
      expect(preflight.liveRootCount, 1);
      expect(preflight.liveDescendantCount, 1);

      final paused = await service.pause('root');
      expect(paused.interruptedTurnCount, 2);
      expect(paused.persistentGoalPaused, isTrue);
      expect(paused.requiresContinuation, isFalse);
      expect(control.goal?.status, 'paused');
      expect(control.interruptions, <String>[
        'root:root-turn',
        'child:child-turn',
      ]);

      final resumed = await service.resume('root');
      expect(resumed.disposition, CodexTaskResumeDisposition.goalResumed);
      expect(control.goal?.status, 'active');
    },
  );

  test('non-goal pause requires an explicit continuation turn', () async {
    final control = _FakeControlPlane(withGoal: false);
    final service = CodexTaskLifecycleService(control);

    final paused = await service.pause('root');
    expect(paused.persistentGoalPaused, isFalse);
    expect(paused.requiresContinuation, isTrue);

    final resumed = await service.resume('root');
    expect(
      resumed.disposition,
      CodexTaskResumeDisposition.continuationRequired,
    );
    final continued = await service.continueTask('root');
    expect(
      continued.disposition,
      CodexTaskResumeDisposition.continuationStarted,
    );
    expect(continued.turnId, 'continuation-turn');
  });
}

class _FakeControlPlane implements CodexAppServerControlPlane {
  _FakeControlPlane({required bool withGoal})
    : goal = withGoal ? _goal('active') : null;

  CodexAppServerGoal? goal;
  final interruptions = <String>[];
  final turns = <String, List<CodexAppServerTurn>>{
    'root': <CodexAppServerTurn>[
      const CodexAppServerTurn(id: 'root-turn', status: 'inProgress'),
    ],
    'child': <CodexAppServerTurn>[
      const CodexAppServerTurn(id: 'child-turn', status: 'inProgress'),
    ],
  };

  @override
  Future<void> compactThread(String threadId) async {}

  @override
  Future<CodexAppServerGoal?> getGoal(String threadId) async => goal;

  @override
  Future<void> interruptTurn(String threadId, String turnId) async {
    interruptions.add('$threadId:$turnId');
    turns[threadId] = <CodexAppServerTurn>[
      CodexAppServerTurn(id: turnId, status: 'interrupted'),
    ];
  }

  @override
  Future<List<CodexAppServerThread>> listAllThreads({
    int maximum = 512,
    int pageSize = 100,
  }) async {
    return <CodexAppServerThread>[
      CodexAppServerThread(
        id: 'root',
        sessionId: 'root',
        status: turns['root']!.single.isInProgress ? 'active' : 'idle',
        turns: const <CodexAppServerTurn>[],
      ),
      CodexAppServerThread(
        id: 'child',
        sessionId: 'root',
        parentThreadId: 'root',
        status: turns['child']!.single.isInProgress ? 'active' : 'idle',
        turns: const <CodexAppServerTurn>[],
      ),
    ];
  }

  @override
  Future<CodexAppServerTurnPage> listRecentTurns(
    String threadId, {
    int limit = 2,
  }) async {
    return CodexAppServerTurnPage(data: turns[threadId]!.take(limit).toList());
  }

  @override
  Future<CodexAppServerThread> resumeThread(String threadId) async {
    return CodexAppServerThread(
      id: threadId,
      sessionId: 'root',
      status: 'idle',
      turns: const <CodexAppServerTurn>[],
    );
  }

  @override
  Future<CodexAppServerGoal> setGoalStatus(
    String threadId,
    String status,
  ) async {
    goal = _goal(status);
    return goal!;
  }

  @override
  Future<CodexAppServerTurn> startContinuation(
    String threadId, {
    String message = '',
  }) async {
    const turn = CodexAppServerTurn(
      id: 'continuation-turn',
      status: 'inProgress',
    );
    turns[threadId] = <CodexAppServerTurn>[turn];
    return turn;
  }
}

CodexAppServerGoal _goal(String status) {
  return CodexAppServerGoal(
    threadId: 'root',
    objective: 'Finish the task',
    status: status,
    tokensUsed: 10,
    timeUsedSeconds: 2,
  );
}
