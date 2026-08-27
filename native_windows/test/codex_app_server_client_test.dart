import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/runtime/codex_app_server_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client negotiates and exposes bounded lifecycle methods', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final requests = <Map<String, Object?>>[];
    final initialized = Completer<void>();
    final serverDone = Completer<void>();
    late WebSocket serverSocket;
    server.listen((request) async {
      serverSocket = await WebSocketTransformer.upgrade(request);
      serverSocket.listen(
        (raw) {
          final message = _map(jsonDecode(raw as String));
          requests.add(message);
          final method = message['method'];
          if (method == 'initialized') {
            if (!initialized.isCompleted) {
              initialized.complete();
            }
            return;
          }
          final id = message['id'];
          final params = _map(message['params']);
          final result = switch (method) {
            'initialize' => <String, Object?>{
              'codexHome': r'C:\Users\test\.codex',
              'platformFamily': 'windows',
              'platformOs': 'windows',
              'userAgent': 'codex-cli/1.0',
            },
            'thread/list' => <String, Object?>{
              'data': <Object?>[
                _thread('root', sessionId: 'root'),
                _thread('child', sessionId: 'root', parentThreadId: 'root'),
              ],
              'nextCursor': null,
            },
            'thread/read' => <String, Object?>{
              'thread': _thread(
                params['threadId']! as String,
                sessionId: 'root',
                turns: const <Object?>[
                  <String, Object?>{'id': 'turn-live', 'status': 'inProgress'},
                ],
              ),
            },
            'thread/turns/list' => <String, Object?>{
              'data': const <Object?>[
                <String, Object?>{'id': 'turn-live', 'status': 'inProgress'},
              ],
              'nextCursor': null,
            },
            'thread/resume' => <String, Object?>{
              'thread': _thread(params['threadId']! as String),
            },
            'thread/goal/get' => <String, Object?>{
              'goal': _goal(params['threadId']! as String, 'paused'),
            },
            'thread/goal/set' => <String, Object?>{
              'goal': _goal(
                params['threadId']! as String,
                params['status']! as String,
              ),
            },
            'turn/interrupt' || 'thread/compact/start' => <String, Object?>{},
            'turn/start' => <String, Object?>{
              'turn': const <String, Object?>{
                'id': 'turn-continuation',
                'status': 'inProgress',
              },
            },
            _ => throw StateError('Unexpected method $method'),
          };
          serverSocket.add(
            jsonEncode(<String, Object?>{'id': id, 'result': result}),
          );
        },
        onDone: () {
          if (!serverDone.isCompleted) {
            serverDone.complete();
          }
        },
      );
    });

    final client = await CodexAppServerClient.connect(
      Uri.parse('ws://127.0.0.1:${server.port}/'),
      requestTimeout: const Duration(seconds: 2),
    );
    addTearDown(client.close);
    await initialized.future.timeout(const Duration(seconds: 2));

    expect(client.initializeInfo.platformOs, 'windows');
    final threads = await client.listAllThreads();
    expect(threads, hasLength(2));
    expect(threads.last.parentThreadId, 'root');
    final read = await client.readThread('root');
    expect(read.activeTurnId, 'turn-live');
    expect((await client.listRecentTurns('root')).data.single.id, 'turn-live');
    expect((await client.getGoal('root'))?.status, 'paused');
    expect((await client.setGoalStatus('root', 'active')).status, 'active');
    expect((await client.resumeThread('root')).id, 'root');
    await client.interruptTurn('root', 'turn-live');
    await client.compactThread('root');
    expect((await client.startContinuation('root')).id, 'turn-continuation');

    final initializeRequest = requests.first;
    final initializeParams = _map(initializeRequest['params']);
    expect(_map(initializeParams['clientInfo'])['name'], 'openhub');
    expect(_map(initializeParams['capabilities'])['experimentalApi'], isTrue);
    final listParams = _map(
      requests.firstWhere(
        (message) => message['method'] == 'thread/list',
      )['params'],
    );
    expect(listParams['useStateDbOnly'], isTrue);
    expect((listParams['sourceKinds']! as List<Object?>), contains('subAgent'));
    final resumeParams = _map(
      requests.firstWhere(
        (message) => message['method'] == 'thread/resume',
      )['params'],
    );
    expect(resumeParams['excludeTurns'], isTrue);
    final recentTurnsParams = _map(
      requests.firstWhere(
        (message) => message['method'] == 'thread/turns/list',
      )['params'],
    );
    expect(recentTurnsParams['itemsView'], 'notLoaded');

    await client.close();
    await serverDone.future.timeout(const Duration(seconds: 2));
  });

  test('client rejects non-loopback or credential-bearing endpoints', () {
    expect(
      CodexAppServerClient.connect(Uri.parse('ws://example.com:45911/')),
      throwsArgumentError,
    );
    expect(
      CodexAppServerClient.connect(Uri.parse('ws://user@127.0.0.1:45911/')),
      throwsArgumentError,
    );
  });
}

Map<String, Object?> _thread(
  String id, {
  String? sessionId,
  String? parentThreadId,
  List<Object?> turns = const <Object?>[],
}) {
  return <String, Object?>{
    'id': id,
    'sessionId': sessionId ?? id,
    'parentThreadId': parentThreadId,
    'status': <String, Object?>{
      'type': turns.isEmpty ? 'idle' : 'active',
      if (turns.isNotEmpty) 'activeFlags': <Object?>[],
    },
    'turns': turns,
    'preview': id,
    'modelProvider': 'openai',
  };
}

Map<String, Object?> _goal(String threadId, String status) {
  return <String, Object?>{
    'threadId': threadId,
    'objective': 'Test goal',
    'status': status,
    'tokensUsed': 10,
    'timeUsedSeconds': 2,
    'createdAt': 1,
    'updatedAt': 2,
    'tokenBudget': null,
  };
}

Map<String, Object?> _map(Object? value) {
  return (value! as Map).map((key, item) => MapEntry(key.toString(), item));
}
