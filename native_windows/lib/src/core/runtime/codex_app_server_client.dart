import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _allThreadSourceKinds = <String>[
  'cli',
  'vscode',
  'exec',
  'appServer',
  'subAgent',
  'subAgentReview',
  'subAgentCompact',
  'subAgentThreadSpawn',
  'subAgentOther',
  'unknown',
];

class CodexAppServerException implements Exception {
  const CodexAppServerException(this.message, {this.code, this.data});

  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() => code == null ? message : '$message (code $code)';
}

class CodexAppServerInitializeInfo {
  const CodexAppServerInitializeInfo({
    required this.codexHome,
    required this.platformFamily,
    required this.platformOs,
    required this.userAgent,
  });

  factory CodexAppServerInitializeInfo.fromJson(Map<String, Object?> json) {
    return CodexAppServerInitializeInfo(
      codexHome: _requiredString(json, 'codexHome'),
      platformFamily: _requiredString(json, 'platformFamily'),
      platformOs: _requiredString(json, 'platformOs'),
      userAgent: _requiredString(json, 'userAgent'),
    );
  }

  final String codexHome;
  final String platformFamily;
  final String platformOs;
  final String userAgent;
}

class CodexAppServerTurn {
  const CodexAppServerTurn({required this.id, required this.status});

  factory CodexAppServerTurn.fromJson(Map<String, Object?> json) {
    return CodexAppServerTurn(
      id: _requiredString(json, 'id'),
      status: _requiredString(json, 'status'),
    );
  }

  final String id;
  final String status;

  bool get isInProgress => status == 'inProgress';
}

class CodexAppServerThread {
  const CodexAppServerThread({
    required this.id,
    required this.sessionId,
    required this.status,
    required this.turns,
    this.parentThreadId,
    this.agentNickname,
    this.agentRole,
    this.name,
    this.preview,
    this.modelProvider,
    this.cwd,
    this.canAcceptDirectInput,
  });

  factory CodexAppServerThread.fromJson(Map<String, Object?> json) {
    final statusMap = _mapOrNull(json['status']);
    final turns = _listOrEmpty(json['turns'])
        .map(_requiredMap)
        .map(CodexAppServerTurn.fromJson)
        .toList(growable: false);
    return CodexAppServerThread(
      id: _requiredString(json, 'id'),
      sessionId:
          _optionalString(json['sessionId']) ?? _requiredString(json, 'id'),
      status: _optionalString(statusMap?['type']) ?? 'notLoaded',
      turns: List<CodexAppServerTurn>.unmodifiable(turns),
      parentThreadId: _optionalString(json['parentThreadId']),
      agentNickname: _optionalString(json['agentNickname']),
      agentRole: _optionalString(json['agentRole']),
      name: _optionalString(json['name']),
      preview: _optionalString(json['preview']),
      modelProvider: _optionalString(json['modelProvider']),
      cwd: _optionalString(json['cwd']),
      canAcceptDirectInput: json['canAcceptDirectInput'] as bool?,
    );
  }

  final String id;
  final String sessionId;
  final String status;
  final List<CodexAppServerTurn> turns;
  final String? parentThreadId;
  final String? agentNickname;
  final String? agentRole;
  final String? name;
  final String? preview;
  final String? modelProvider;
  final String? cwd;
  final bool? canAcceptDirectInput;

  bool get isActive =>
      status == 'active' || turns.any((turn) => turn.isInProgress);

  String? get activeTurnId {
    for (final turn in turns.reversed) {
      if (turn.isInProgress) {
        return turn.id;
      }
    }
    return null;
  }
}

class CodexAppServerThreadPage {
  const CodexAppServerThreadPage({required this.data, this.nextCursor});

  factory CodexAppServerThreadPage.fromJson(Map<String, Object?> json) {
    return CodexAppServerThreadPage(
      data: List<CodexAppServerThread>.unmodifiable(
        _listOrEmpty(
          json['data'],
        ).map(_requiredMap).map(CodexAppServerThread.fromJson),
      ),
      nextCursor: _optionalString(json['nextCursor']),
    );
  }

  final List<CodexAppServerThread> data;
  final String? nextCursor;
}

class CodexAppServerTurnPage {
  const CodexAppServerTurnPage({required this.data, this.nextCursor});

  factory CodexAppServerTurnPage.fromJson(Map<String, Object?> json) {
    return CodexAppServerTurnPage(
      data: List<CodexAppServerTurn>.unmodifiable(
        _listOrEmpty(
          json['data'],
        ).map(_requiredMap).map(CodexAppServerTurn.fromJson),
      ),
      nextCursor: _optionalString(json['nextCursor']),
    );
  }

  final List<CodexAppServerTurn> data;
  final String? nextCursor;
}

class CodexAppServerGoal {
  const CodexAppServerGoal({
    required this.threadId,
    required this.objective,
    required this.status,
    required this.tokensUsed,
    required this.timeUsedSeconds,
    this.tokenBudget,
  });

  factory CodexAppServerGoal.fromJson(Map<String, Object?> json) {
    return CodexAppServerGoal(
      threadId: _requiredString(json, 'threadId'),
      objective: _requiredString(json, 'objective'),
      status: _requiredString(json, 'status'),
      tokensUsed: _requiredInt(json, 'tokensUsed'),
      timeUsedSeconds: _requiredInt(json, 'timeUsedSeconds'),
      tokenBudget: _optionalInt(json['tokenBudget']),
    );
  }

  final String threadId;
  final String objective;
  final String status;
  final int tokensUsed;
  final int timeUsedSeconds;
  final int? tokenBudget;
}

class CodexAppServerNotification {
  const CodexAppServerNotification({required this.method, this.params});

  final String method;
  final Map<String, Object?>? params;
}

abstract interface class CodexAppServerControlPlane {
  Future<List<CodexAppServerThread>> listAllThreads({
    int maximum = 512,
    int pageSize = 100,
  });

  Future<CodexAppServerTurnPage> listRecentTurns(String threadId, {int limit});

  Future<CodexAppServerThread> resumeThread(String threadId);

  Future<CodexAppServerGoal?> getGoal(String threadId);

  Future<CodexAppServerGoal> setGoalStatus(String threadId, String status);

  Future<void> interruptTurn(String threadId, String turnId);

  Future<void> compactThread(String threadId);

  Future<CodexAppServerTurn> startContinuation(
    String threadId, {
    String message =
        'Continue the interrupted task from the latest persisted state. Re-check current workspace state before acting, preserve completed work, and finish the remaining user request.',
  });
}

class CodexAppServerClient implements CodexAppServerControlPlane {
  CodexAppServerClient._(
    this.endpoint,
    this._socket, {
    required this.requestTimeout,
  });

  final Uri endpoint;
  final WebSocket _socket;
  final Duration requestTimeout;
  final Map<int, _PendingRequest> _pending = <int, _PendingRequest>{};
  final StreamController<CodexAppServerNotification> _notifications =
      StreamController<CodexAppServerNotification>.broadcast();

  late final StreamSubscription<Object?> _subscription;
  late CodexAppServerInitializeInfo initializeInfo;
  var _nextRequestId = 1;
  var _closed = false;

  Stream<CodexAppServerNotification> get notifications => _notifications.stream;

  bool get isClosed => _closed;

  static Future<CodexAppServerClient> connect(
    Uri endpoint, {
    String clientVersion = '0.1.0',
    Duration requestTimeout = const Duration(seconds: 12),
  }) async {
    _validateEndpoint(endpoint);
    final socket = await WebSocket.connect(endpoint.toString()).timeout(
      requestTimeout,
      onTimeout: () => throw const CodexAppServerException(
        'Timed out while connecting to the Codex app-server.',
      ),
    );
    final client = CodexAppServerClient._(
      endpoint,
      socket,
      requestTimeout: requestTimeout,
    );
    client._subscription = socket.listen(
      client._handleMessage,
      onError: client._handleTransportError,
      onDone: client._handleTransportDone,
      cancelOnError: false,
    );
    try {
      final initialized = await client._request('initialize', <String, Object?>{
        'clientInfo': <String, Object?>{
          'name': 'openhub',
          'title': 'OpenHUB',
          'version': clientVersion,
        },
        'capabilities': <String, Object?>{
          'experimentalApi': true,
          'optOutNotificationMethods': const <String>[
            'item/agentMessage/delta',
            'item/reasoning/textDelta',
            'item/reasoning/summaryTextDelta',
            'item/commandExecution/outputDelta',
            'item/fileChange/outputDelta',
            'turn/diff/updated',
          ],
        },
      });
      client.initializeInfo = CodexAppServerInitializeInfo.fromJson(
        _requiredMap(initialized),
      );
      client._send(<String, Object?>{'method': 'initialized'});
      return client;
    } on Object {
      await client.close();
      rethrow;
    }
  }

  Future<CodexAppServerThreadPage> listThreads({
    String? cursor,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 1000.');
    }
    final result = await _request('thread/list', <String, Object?>{
      'archived': false,
      'cursor': cursor,
      'limit': limit,
      'sortKey': 'recency_at',
      'sortDirection': 'desc',
      'sourceKinds': _allThreadSourceKinds,
      // Listing from SQLite avoids scanning or transferring rollout history.
      'useStateDbOnly': true,
    });
    return CodexAppServerThreadPage.fromJson(_requiredMap(result));
  }

  @override
  Future<List<CodexAppServerThread>> listAllThreads({
    int maximum = 512,
    int pageSize = 100,
  }) async {
    if (maximum < 1) {
      throw ArgumentError.value(maximum, 'maximum', 'Must be positive.');
    }
    final threads = <CodexAppServerThread>[];
    String? cursor;
    do {
      final page = await listThreads(
        cursor: cursor,
        limit: pageSize.clamp(1, maximum).toInt(),
      );
      threads.addAll(page.data.take(maximum - threads.length));
      cursor = page.nextCursor;
    } while (cursor != null && threads.length < maximum);
    return List<CodexAppServerThread>.unmodifiable(threads);
  }

  Future<CodexAppServerThread> readThread(
    String threadId, {
    bool includeTurns = true,
  }) async {
    final result = await _request('thread/read', <String, Object?>{
      'threadId': _validatedId(threadId),
      'includeTurns': includeTurns,
    });
    final thread = _requiredMap(_requiredMap(result)['thread']);
    return CodexAppServerThread.fromJson(thread);
  }

  @override
  Future<CodexAppServerTurnPage> listRecentTurns(
    String threadId, {
    int limit = 2,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 100.');
    }
    final result = await _request('thread/turns/list', <String, Object?>{
      'threadId': _validatedId(threadId),
      'limit': limit,
      'sortDirection': 'desc',
      // Lifecycle checks need IDs and status only, never historical items.
      'itemsView': 'notLoaded',
    });
    return CodexAppServerTurnPage.fromJson(_requiredMap(result));
  }

  @override
  Future<CodexAppServerThread> resumeThread(String threadId) async {
    final result = await _request('thread/resume', <String, Object?>{
      'threadId': _validatedId(threadId),
      // Lifecycle control needs metadata and live state, not the full history.
      'excludeTurns': true,
    });
    return CodexAppServerThread.fromJson(
      _requiredMap(_requiredMap(result)['thread']),
    );
  }

  @override
  Future<CodexAppServerGoal?> getGoal(String threadId) async {
    final result = _requiredMap(
      await _request('thread/goal/get', <String, Object?>{
        'threadId': _validatedId(threadId),
      }),
    );
    final goal = result['goal'];
    return goal == null
        ? null
        : CodexAppServerGoal.fromJson(_requiredMap(goal));
  }

  @override
  Future<CodexAppServerGoal> setGoalStatus(
    String threadId,
    String status,
  ) async {
    const statuses = <String>{
      'active',
      'paused',
      'blocked',
      'usageLimited',
      'budgetLimited',
      'complete',
    };
    if (!statuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported goal status.');
    }
    final result = _requiredMap(
      await _request('thread/goal/set', <String, Object?>{
        'threadId': _validatedId(threadId),
        'status': status,
      }),
    );
    return CodexAppServerGoal.fromJson(_requiredMap(result['goal']));
  }

  @override
  Future<void> interruptTurn(String threadId, String turnId) async {
    await _request('turn/interrupt', <String, Object?>{
      'threadId': _validatedId(threadId),
      'turnId': _validatedId(turnId),
    });
  }

  @override
  Future<void> compactThread(String threadId) async {
    await _request('thread/compact/start', <String, Object?>{
      'threadId': _validatedId(threadId),
    });
  }

  @override
  Future<CodexAppServerTurn> startContinuation(
    String threadId, {
    String message =
        'Continue the interrupted task from the latest persisted state. Re-check current workspace state before acting, preserve completed work, and finish the remaining user request.',
  }) async {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty || normalizedMessage.length > 4000) {
      throw ArgumentError.value(
        message,
        'message',
        'Continuation message must be non-empty and at most 4000 characters.',
      );
    }
    final result = _requiredMap(
      await _request('turn/start', <String, Object?>{
        'threadId': _validatedId(threadId),
        'input': <Object?>[
          <String, Object?>{'type': 'text', 'text': normalizedMessage},
        ],
      }),
    );
    return CodexAppServerTurn.fromJson(_requiredMap(result['turn']));
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _failPending(
      const CodexAppServerException('Codex app-server connection closed.'),
    );
    await _subscription.cancel();
    await _socket.close(
      WebSocketStatus.normalClosure,
      'OpenHUB control connection closed',
    );
    await _notifications.close();
  }

  Future<Object?> _request(String method, Map<String, Object?> params) {
    if (_closed) {
      return Future<Object?>.error(
        const CodexAppServerException(
          'Codex app-server connection is already closed.',
        ),
      );
    }
    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    final timer = Timer(requestTimeout, () {
      final pending = _pending.remove(id);
      pending?.completer.completeError(
        CodexAppServerException('Codex app-server request timed out: $method.'),
      );
    });
    _pending[id] = _PendingRequest(completer: completer, timer: timer);
    try {
      _send(<String, Object?>{'id': id, 'method': method, 'params': params});
    } on Object catch (error, stackTrace) {
      _pending.remove(id)?.timer.cancel();
      completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  void _send(Map<String, Object?> message) {
    if (_closed) {
      throw const CodexAppServerException(
        'Codex app-server connection is already closed.',
      );
    }
    _socket.add(jsonEncode(message));
  }

  void _handleMessage(Object? raw) {
    try {
      final text = switch (raw) {
        String value => value,
        List<int> value => utf8.decode(value),
        _ => throw const FormatException('Unsupported WebSocket message.'),
      };
      final message = _requiredMap(jsonDecode(text));
      final responseId = _optionalInt(message['id']);
      if (responseId != null && !message.containsKey('method')) {
        final pending = _pending.remove(responseId);
        if (pending == null) {
          return;
        }
        pending.timer.cancel();
        final error = _mapOrNull(message['error']);
        if (error != null) {
          pending.completer.completeError(
            CodexAppServerException(
              _optionalString(error['message']) ?? 'App-server request failed.',
              code: _optionalInt(error['code']),
              data: error['data'],
            ),
          );
        } else {
          pending.completer.complete(message['result']);
        }
        return;
      }
      final method = _optionalString(message['method']);
      if (method == null) {
        return;
      }
      if (responseId != null) {
        _send(<String, Object?>{
          'id': responseId,
          'error': <String, Object?>{
            'code': -32601,
            'message': 'OpenHUB control connection does not handle requests.',
          },
        });
        return;
      }
      _notifications.add(
        CodexAppServerNotification(
          method: method,
          params: _mapOrNull(message['params']),
        ),
      );
    } on Object catch (error, stackTrace) {
      _notifications.addError(error, stackTrace);
    }
  }

  void _handleTransportError(Object error, StackTrace stackTrace) {
    _failPending(
      CodexAppServerException('Codex app-server transport failed: $error'),
      stackTrace,
    );
  }

  void _handleTransportDone() {
    _closed = true;
    _failPending(
      const CodexAppServerException('Codex app-server transport disconnected.'),
    );
    if (!_notifications.isClosed) {
      unawaited(_notifications.close());
    }
  }

  void _failPending(Object error, [StackTrace? stackTrace]) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final request in pending) {
      request.timer.cancel();
      request.completer.completeError(error, stackTrace);
    }
  }
}

class _PendingRequest {
  const _PendingRequest({required this.completer, required this.timer});

  final Completer<Object?> completer;
  final Timer timer;
}

void _validateEndpoint(Uri endpoint) {
  final address = InternetAddress.tryParse(endpoint.host);
  if (endpoint.scheme != 'ws' ||
      !endpoint.hasPort ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.hasQuery ||
      endpoint.hasFragment ||
      endpoint.path != '/' ||
      address == null ||
      !address.isLoopback) {
    throw ArgumentError.value(
      endpoint,
      'endpoint',
      'Codex app-server endpoint must be numeric loopback ws://IP:PORT/.',
    );
  }
}

String _validatedId(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 256) {
    throw ArgumentError.value(value, 'id', 'Must be a non-empty bounded id.');
  }
  return normalized;
}

Map<String, Object?> _requiredMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Expected a JSON object.');
}

Map<String, Object?>? _mapOrNull(Object? value) {
  return value == null ? null : _requiredMap(value);
}

List<Object?> _listOrEmpty(Object? value) {
  return value is List<Object?> ? value : const <Object?>[];
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) {
    throw FormatException('Expected non-empty string: $key.');
  }
  return value;
}

String? _optionalString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = _optionalInt(json[key]);
  if (value == null) {
    throw FormatException('Expected integer: $key.');
  }
  return value;
}

int? _optionalInt(Object? value) {
  return switch (value) {
    int item => item,
    num item when item.isFinite && item == item.roundToDouble() => item.toInt(),
    _ => null,
  };
}
