import 'package:openhub_windows/src/core/runtime/windows_platform_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('openhub/native');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('managed Codex launch crosses the narrow native bridge', () async {
    MethodCall? observed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          observed = call;
          return 4242;
        });

    const bridge = WindowsPlatformBridge();
    final processId = await bridge.launchManagedCodex(
      executablePath:
          r'C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app\ChatGPT.exe',
      workingDirectory:
          r'C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app',
      chatGptBaseUrl: Uri.parse(
        'http://127.0.0.1:2455/backend-api/codex-managed',
      ),
      openAiBaseUrl: Uri.parse(
        'http://127.0.0.1:2455/backend-api/codex-managed/v1',
      ),
      appServerWebSocketUrl: Uri.parse('ws://127.0.0.1:45911/'),
    );

    expect(processId, 4242);
    expect(observed?.method, 'launchManagedCodex');
    expect(observed?.arguments, <String, String>{
      'executablePath':
          r'C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app\ChatGPT.exe',
      'workingDirectory':
          r'C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app',
      'chatGptBaseUrl': 'http://127.0.0.1:2455/backend-api/codex-managed',
      'openAiBaseUrl': 'http://127.0.0.1:2455/backend-api/codex-managed/v1',
      'appServerWebSocketUrl': 'ws://127.0.0.1:45911/',
    });
  });

  test('managed Codex bridge permits a WebSocket-only profile launch', () async {
    MethodCall? observed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          observed = call;
          return 4243;
        });

    const bridge = WindowsPlatformBridge();
    final processId = await bridge.launchManagedCodex(
      executablePath:
          r'C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app\ChatGPT.exe',
      workingDirectory:
          r'C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app',
      appServerWebSocketUrl: Uri.parse('ws://127.0.0.1:45912/'),
    );

    expect(processId, 4243);
    expect(
      observed?.arguments,
      containsPair('appServerWebSocketUrl', 'ws://127.0.0.1:45912/'),
    );
    expect(observed?.arguments, isNot(contains('openAiBaseUrl')));
  });

  test('managed Codex bridge rejects an arbitrary executable', () {
    const bridge = WindowsPlatformBridge();

    expect(
      bridge.launchManagedCodex(
        executablePath: r'C:\Windows\System32\notepad.exe',
        workingDirectory: r'C:\Windows\System32',
        chatGptBaseUrl: Uri.parse(
          'http://127.0.0.1:2455/backend-api/codex-managed',
        ),
        openAiBaseUrl: Uri.parse(
          'http://127.0.0.1:2455/backend-api/codex-managed/v1',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('managed Codex bridge rejects a non-loopback route', () {
    const bridge = WindowsPlatformBridge();

    expect(
      bridge.launchManagedCodex(
        executablePath:
            r'C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app\ChatGPT.exe',
        workingDirectory:
            r'C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app',
        chatGptBaseUrl: Uri.parse(
          'https://example.com/backend-api/codex-managed',
        ),
        openAiBaseUrl: Uri.parse(
          'http://127.0.0.1:2455/backend-api/codex-managed/v1',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('Codex task deep link crosses the validated native bridge', () async {
    MethodCall? observed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          observed = call;
          return true;
        });

    const bridge = WindowsPlatformBridge();
    await bridge.openCodexThread('01A034BD-4062-7C40-80D2-407627226790');

    expect(observed?.method, 'openCodexThread');
    expect(observed?.arguments, '01a034bd-4062-7c40-80d2-407627226790');
  });

  test('Codex task deep link rejects a non-UUID identifier', () {
    const bridge = WindowsPlatformBridge();

    expect(
      bridge.openCodexThread('codex://threads/not-a-uuid'),
      throwsArgumentError,
    );
  });

  test('Hermes session open crosses the native runtime bridge', () async {
    MethodCall? observed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          observed = call;
          return true;
        });

    const bridge = WindowsPlatformBridge();
    await bridge.openHermesSession(
      'session_20260826',
      workingDirectory: r'C:\workspace\Hermes project',
    );

    expect(observed?.method, 'openRuntimeSession');
    expect(observed?.arguments, <String, String>{
      'runtime': 'hermes',
      'sessionId': 'session_20260826',
      'workingDirectory': r'C:\workspace\Hermes project',
    });
  });

  test('OpenCode session open uses its exact native identifier', () async {
    MethodCall? observed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          observed = call;
          return true;
        });

    const bridge = WindowsPlatformBridge();
    await bridge.openOpenCodeSession('ses_openhub.01');

    expect(observed?.method, 'openRuntimeSession');
    expect(observed?.arguments, <String, String>{
      'runtime': 'opencode',
      'sessionId': 'ses_openhub.01',
    });
  });

  test('runtime session open rejects shell-shaped identifiers', () {
    const bridge = WindowsPlatformBridge();

    expect(bridge.openHermesSession('session & calc.exe'), throwsArgumentError);
  });
}
