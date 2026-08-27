import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/runtime/codex_pulse_service.dart';
import 'package:openhub_windows/src/models/codex_pulse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('stalled tasks remain visible but do not report as live', () {
    final now = DateTime.utc(2026, 8, 24, 18);
    final snapshot = CodexPulseSnapshot(
      tasks: <CodexTaskSignal>[
        CodexTaskSignal(
          id: '01a034bd-4062-7c40-80d2-407627226790',
          title: 'Stalled task',
          model: 'gpt-5.6-sol',
          provider: 'OpenAI',
          phase: CodexTaskPhase.stalled,
          totalTokens: 100,
          sessionTokens: 0,
          lastActivityAt: now.subtract(const Duration(minutes: 3)),
        ),
      ],
      usage: CodexPulseUsage(
        sinceStart: 0,
        lastMinute: 0,
        lastHour: 0,
        startedAt: now,
      ),
      sampledAt: now,
    );

    expect(snapshot.tasks.single.phase, CodexTaskPhase.stalled);
    expect(snapshot.liveTaskCount, 0);
  });

  test('task ordering keeps live work ahead of stale attention items', () {
    final now = DateTime.utc(2026, 8, 24, 18);
    final tasks = <CodexTaskSignal>[
      CodexTaskSignal(
        id: 'stalled',
        title: 'Old stalled work',
        model: 'gpt-5.6-sol',
        provider: 'OpenAI',
        phase: CodexTaskPhase.stalled,
        totalTokens: 100,
        sessionTokens: 0,
        lastActivityAt: now.subtract(const Duration(hours: 2)),
      ),
      CodexTaskSignal(
        id: 'active',
        title: 'Current work',
        model: 'gpt-5.6-sol',
        provider: 'OpenAI',
        phase: CodexTaskPhase.active,
        totalTokens: 200,
        sessionTokens: 10,
        lastActivityAt: now,
      ),
    ];

    tasks.sort(compareCodexPulseTasksForTest);
    expect(tasks.map((task) => task.id), <String>['active', 'stalled']);
  });

  test('rollout parser reports reasoning, context, and completion errors', () {
    final active = <String>[
      _line('2026-08-24T18:00:00Z', 'event_msg', <String, Object?>{
        'type': 'task_started',
        'model_context_window': 258400,
      }),
      _line('2026-08-24T18:00:01Z', 'event_msg', <String, Object?>{
        'type': 'token_count',
        'info': <String, Object?>{
          'model_context_window': 258400,
          'last_token_usage': <String, Object?>{'total_tokens': 72120},
        },
      }),
      _line('2026-08-24T18:00:02Z', 'event_msg', <String, Object?>{
        'type': 'agent_reasoning',
      }),
    ].join('\n');

    final parsed = parseCodexRolloutTail(active);
    expect(parsed.phase, CodexTaskPhase.reasoning);
    expect(parsed.contextTokens, 72120);
    expect(parsed.contextWindow, 258400);
    expect(parsed.uncertain, isFalse);

    final failed =
        '$active\n${_line('2026-08-24T18:00:03Z', 'event_msg', <String, Object?>{
          'type': 'task_complete',
          'error': <String, Object?>{'message': 'upstream rejected the request'},
        })}';
    final completed = parseCodexRolloutTail(failed);
    expect(completed.phase, CodexTaskPhase.failed);
    expect(completed.errorSummary, contains('upstream rejected'));
  });

  test(
    'service records positive session and rolling token deltas only',
    () async {
      final root = Directory.systemTemp.createTempSync('codex-pulse-test-');
      addTearDown(() => root.deleteSync(recursive: true));
      final codexHome = Directory(path.join(root.path, '.codex'))
        ..createSync(recursive: true);
      final rollout = File(path.join(codexHome.path, 'rollout.jsonl'))
        ..writeAsStringSync(
          <String>[
            _line('2026-08-24T18:00:00Z', 'event_msg', <String, Object?>{
              'type': 'task_started',
              'model_context_window': 258400,
            }),
            _line('2026-08-24T18:00:01Z', 'event_msg', <String, Object?>{
              'type': 'agent_message_delta',
            }),
          ].join('\n'),
        );
      File(path.join(codexHome.path, 'config.toml')).writeAsStringSync('''
model = "gpt-5.6-sol"
model_provider = "openai"
''');
      final stateFile = File(path.join(codexHome.path, 'state_5.sqlite'));
      final database = sqlite3.open(stateFile.path);
      database.execute('''
CREATE TABLE threads (
  id TEXT PRIMARY KEY,
  name TEXT,
  title TEXT,
  model TEXT,
  model_provider TEXT,
  reasoning_effort TEXT,
  updated_at_ms INTEGER,
  tokens_used INTEGER,
  rollout_path TEXT,
  archived INTEGER
)
''');
      database.execute(
        'INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          '01a034bd-4062-7c40-80d2-407627226790',
          'Provider bridge repair',
          '',
          'gpt-5.6-sol',
          'openai',
          'max',
          DateTime.utc(2026, 8, 24, 18, 0, 1).millisecondsSinceEpoch,
          100,
          rollout.path,
          0,
        ],
      );
      database.close();

      var now = DateTime.utc(2026, 8, 24, 18, 0, 2);
      final service = CodexPulseService(codexHome: codexHome, now: () => now);
      addTearDown(service.dispose);

      final baseline = await service.refresh();
      expect(baseline.usage.sinceStart, 0);

      final writer = sqlite3.open(stateFile.path);
      writer.execute(
        'UPDATE threads SET tokens_used = 160 WHERE id = ?',
        <Object?>['01a034bd-4062-7c40-80d2-407627226790'],
      );
      writer.close();
      now = now.add(const Duration(seconds: 10));

      final increased = await service.refresh();
      expect(increased.usage.sinceStart, 60);
      expect(increased.usage.lastMinute, 60);
      expect(increased.usage.lastHour, 60);
      expect(increased.tasks.single.sessionTokens, 60);

      now = now.add(const Duration(seconds: 61));
      final aged = await service.refresh();
      expect(aged.usage.sinceStart, 60);
      expect(aged.usage.lastMinute, 0);
      expect(aged.usage.lastHour, 60);

      final resetWriter = sqlite3.open(stateFile.path);
      resetWriter.execute(
        'UPDATE threads SET tokens_used = 12 WHERE id = ?',
        <Object?>['01a034bd-4062-7c40-80d2-407627226790'],
      );
      resetWriter.close();
      now = now.add(const Duration(seconds: 1));

      final reset = await service.refresh();
      expect(reset.usage.sinceStart, 60);
      expect(reset.tasks.single.sessionTokens, 60);
    },
  );

  test(
    'service groups subagents under one root without double counting',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'codex-pulse-tree-test-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final codexHome = Directory(path.join(root.path, '.codex'))
        ..createSync(recursive: true);
      File(path.join(codexHome.path, 'config.toml')).writeAsStringSync('''
model = "gpt-5.6-sol"
model_provider = "openai"
''');

      const rootId = '01a034bd-4062-7c40-80d2-407627226790';
      const childOneId = '01a034bd-4062-7c40-80d2-407627226791';
      const childTwoId = '01a034bd-4062-7c40-80d2-407627226792';
      File rollout(String id, {String? parentId, String? nickname}) {
        final file = File(path.join(codexHome.path, '$id.jsonl'));
        file.writeAsStringSync(
          <String>[
            _line('2026-08-24T18:00:00Z', 'session_meta', <String, Object?>{
              'id': id,
              'session_id': rootId,
              'parent_thread_id': parentId,
              'agent_nickname': nickname,
              'agent_role': nickname == null ? null : 'worker',
            }),
            _line('2026-08-24T18:00:01Z', 'event_msg', <String, Object?>{
              'type': 'task_started',
              'model_context_window': 258400,
            }),
            _line('2026-08-24T18:00:02Z', 'event_msg', <String, Object?>{
              'type': 'agent_reasoning',
            }),
          ].join('\n'),
        );
        return file;
      }

      final rootRollout = rollout(rootId);
      final childOneRollout = rollout(
        childOneId,
        parentId: rootId,
        nickname: 'Scout',
      );
      final childTwoRollout = rollout(
        childTwoId,
        parentId: rootId,
        nickname: 'Builder',
      );
      final stateFile = File(path.join(codexHome.path, 'state_5.sqlite'));
      final database = sqlite3.open(stateFile.path);
      database.execute('''
CREATE TABLE threads (
  id TEXT PRIMARY KEY,
  name TEXT,
  title TEXT,
  model TEXT,
  model_provider TEXT,
  reasoning_effort TEXT,
  updated_at_ms INTEGER,
  tokens_used INTEGER,
  rollout_path TEXT,
  archived INTEGER
)
''');
      void insertThread(String id, String title, int tokens, File rolloutFile) {
        database.execute(
          'INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            id,
            title,
            '',
            'gpt-5.6-sol',
            'openai',
            'max',
            DateTime.utc(2026, 8, 24, 18, 0, 2).millisecondsSinceEpoch,
            tokens,
            rolloutFile.path,
            0,
          ],
        );
      }

      insertThread(rootId, 'Root task', 100, rootRollout);
      insertThread(childOneId, 'Scout child', 40, childOneRollout);
      insertThread(childTwoId, 'Builder child', 60, childTwoRollout);
      database.close();

      final service = CodexPulseService(
        codexHome: codexHome,
        now: () => DateTime.utc(2026, 8, 24, 18, 0, 3),
      );
      addTearDown(service.dispose);

      final baseline = await service.refresh();
      expect(baseline.tasks, hasLength(1));
      expect(baseline.liveTaskCount, 1);
      expect(baseline.tasks.single.id, rootId);
      expect(baseline.tasks.single.totalTokens, 200);
      expect(baseline.tasks.single.children, hasLength(2));
      expect(
        baseline.tasks.single.children.map((child) => child.id).toSet(),
        <String>{childOneId, childTwoId},
      );
      expect(
        baseline.tasks.single.children
            .map((child) => child.agentNickname)
            .toSet(),
        <String?>{'Scout', 'Builder'},
      );

      final writer = sqlite3.open(stateFile.path);
      writer.execute(
        'UPDATE threads SET tokens_used = 75 WHERE id = ?',
        <Object?>[childOneId],
      );
      writer.close();

      final increased = await service.refresh();
      expect(increased.tasks, hasLength(1));
      expect(increased.tasks.single.totalTokens, 235);
      expect(increased.tasks.single.sessionTokens, 35);
      expect(increased.usage.sinceStart, 35);
    },
  );
}

String _line(String timestamp, String type, Map<String, Object?> payload) {
  return jsonEncode(<String, Object?>{
    'timestamp': timestamp,
    'type': type,
    'payload': payload,
  });
}
