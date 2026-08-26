import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';

/// Opt-in release diagnostics used by the local performance gate.
///
/// The probe is inert unless `OPENHUB_NATIVE_PERF_FILE` points at a JSON file.
/// It records timings only and never includes endpoint, account, path, request,
/// or credential data.
class NativePerformanceProbe {
  NativePerformanceProbe._(
    this._output,
    this._clock, {
    required this.syntheticAccountRows,
  }) : _startedAt = DateTime.now().toUtc();

  factory NativePerformanceProbe.fromEnvironment({
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final rawPath = env['OPENHUB_NATIVE_PERF_FILE']?.trim() ?? '';
    final output = rawPath.isEmpty ? null : File(rawPath).absolute;
    final requestedRows = int.tryParse(
      env['OPENHUB_NATIVE_PERF_SYNTHETIC_ACCOUNT_ROWS']?.trim() ?? '',
    );
    final syntheticRows =
        output == null || requestedRows == null || requestedRows < 1
        ? null
        : requestedRows.clamp(1, 10000);
    return NativePerformanceProbe._(
      output,
      Stopwatch()..start(),
      syntheticAccountRows: syntheticRows,
    );
  }

  final File? _output;
  final Stopwatch _clock;
  final DateTime _startedAt;
  final Map<String, Object?> _measurements = <String, Object?>{};
  final int? syntheticAccountRows;

  bool get enabled => _output != null;

  void markShellVisible() {
    _recordOnce('shellVisibleMs', _clock.elapsedMicroseconds / 1000);
  }

  void markRuntimeActionable(String state) {
    if (_measurements.containsKey('runtimeActionableMs')) {
      return;
    }
    _measurements['runtimeActionableMs'] = _clock.elapsedMicroseconds / 1000;
    _measurements['runtimeState'] = state;
    _flush();
  }

  void markCachedNavigationAfterNextFrame(String destination) {
    if (!enabled || _measurements.containsKey('cachedNavigationMs')) {
      return;
    }
    final startedMicros = _clock.elapsedMicroseconds;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measurements['cachedNavigationMs'] =
          (_clock.elapsedMicroseconds - startedMicros) / 1000;
      _measurements['cachedNavigationDestination'] = destination;
      _flush();
    });
  }

  void recordAccountScrollTimings(
    List<FrameTiming> timings, {
    required int rowCount,
  }) {
    if (!enabled || _measurements.containsKey('accountScrollP95WorkMs')) {
      return;
    }
    final work =
        timings
            .map(
              (timing) =>
                  (timing.buildDuration.inMicroseconds +
                      timing.rasterDuration.inMicroseconds) /
                  1000,
            )
            .toList(growable: false)
          ..sort();
    final total =
        timings
            .map((timing) => timing.totalSpan.inMicroseconds / 1000)
            .toList(growable: false)
          ..sort();
    _measurements['accountScrollRows'] = rowCount;
    _measurements['accountScrollFrameCount'] = timings.length;
    if (work.isNotEmpty) {
      _measurements['accountScrollP95WorkMs'] = _percentile(work, 0.95);
      _measurements['accountScrollWorstWorkMs'] = work.last;
      _measurements['accountScrollP95TotalSpanMs'] = _percentile(total, 0.95);
      _measurements['accountScrollWithinFrameBudget'] =
          (_measurements['accountScrollP95WorkMs']! as double) < 16.67;
    }
    _flush();
  }

  void _recordOnce(String key, Object value) {
    if (_measurements.containsKey(key)) {
      return;
    }
    _measurements[key] = value;
    _flush();
  }

  void _flush() {
    final output = _output;
    if (output == null) {
      return;
    }
    try {
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'schemaVersion': 1,
          'processStartedAt': _startedAt.toIso8601String(),
          ..._measurements,
        }),
        flush: true,
      );
    } on FileSystemException {
      // Diagnostics must never make the operator application fail to start.
    }
  }
}

double _percentile(List<double> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index];
}
