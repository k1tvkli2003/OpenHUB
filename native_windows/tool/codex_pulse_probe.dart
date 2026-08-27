import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/runtime/codex_pulse_service.dart';
import 'package:openhub_windows/src/models/codex_pulse.dart';

Future<void> main() async {
  final service = CodexPulseService();
  try {
    final snapshot = await service.refresh();
    final payload = <String, Object?>{
      'sampled_at': snapshot.sampledAt.toIso8601String(),
      'usage': <String, Object?>{
        'since_start': snapshot.usage.sinceStart,
        'last_minute': snapshot.usage.lastMinute,
        'last_hour': snapshot.usage.lastHour,
      },
      'runtimes': snapshot.runtimeHealth
          .map(
            (health) => <String, Object?>{
              'runtime': health.runtime.name,
              'status': health.status,
              'reconnecting': health.reconnecting,
              'gateway_reachable': health.gatewayReachable,
              'message': health.message,
            },
          )
          .toList(growable: false),
      'source_error': snapshot.sourceError,
      'live_tasks': snapshot.liveTaskCount,
      'tasks': snapshot.tasks
          .map(
            (task) => <String, Object?>{
              'id': task.id,
              'title': task.title,
              'model': task.model,
              'provider': task.provider,
              'phase': task.phase.label,
              'uncertain': task.uncertain,
              'total_tokens': task.totalTokens,
              'session_tokens': task.sessionTokens,
              'context_tokens': task.contextTokens,
              'context_window': task.contextWindow,
              'last_activity_at': task.lastActivityAt?.toIso8601String(),
              'retry_attempt': task.retryAttempt,
              'retry_maximum': task.retryMaximum,
              'error': task.errorSummary,
            },
          )
          .toList(growable: false),
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(payload));
  } finally {
    service.dispose();
  }
}
