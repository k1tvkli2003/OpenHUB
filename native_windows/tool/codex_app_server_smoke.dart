import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/runtime/codex_app_server_client.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/codex_app_server_smoke.dart ws://127.0.0.1:PORT/',
    );
    exitCode = 64;
    return;
  }
  final client = await CodexAppServerClient.connect(
    Uri.parse(arguments.single),
  );
  try {
    final threads = await client.listAllThreads(maximum: 32);
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'protocol': 'ready',
        'platform': client.initializeInfo.platformOs,
        'sampledThreads': threads.length,
        'activeRoots': threads
            .where((thread) => thread.parentThreadId == null && thread.isActive)
            .length,
        'sampledSubagents': threads
            .where((thread) => thread.parentThreadId != null)
            .length,
      }),
    );
  } finally {
    await client.close();
  }
}
