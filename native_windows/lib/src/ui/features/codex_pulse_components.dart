import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/codex_pulse.dart';
import '../../models/runtime_control.dart';
import '../app_theme.dart';

Color pulsePhaseColor(CodexTaskPhase phase) => switch (phase) {
  CodexTaskPhase.queued => AppPalette.amber,
  CodexTaskPhase.active => AppPalette.green,
  CodexTaskPhase.reasoning || CodexTaskPhase.tool => AppPalette.cyan,
  CodexTaskPhase.retrying || CodexTaskPhase.stalled => AppPalette.amber,
  CodexTaskPhase.failed => AppPalette.red,
  CodexTaskPhase.cancelled => const Color(0xFFB68CFF),
  CodexTaskPhase.idle || CodexTaskPhase.unknown => AppPalette.textMuted,
};

IconData pulsePhaseIcon(CodexTaskPhase phase) => switch (phase) {
  CodexTaskPhase.queued => Icons.hourglass_top_rounded,
  CodexTaskPhase.active => Icons.play_arrow_rounded,
  CodexTaskPhase.reasoning => Icons.psychology_outlined,
  CodexTaskPhase.tool => Icons.terminal_rounded,
  CodexTaskPhase.retrying => Icons.sync_rounded,
  CodexTaskPhase.stalled => Icons.timer_off_outlined,
  CodexTaskPhase.failed => Icons.error_outline_rounded,
  CodexTaskPhase.cancelled => Icons.block_outlined,
  CodexTaskPhase.idle => Icons.pause_rounded,
  CodexTaskPhase.unknown => Icons.help_outline_rounded,
};

Color runtimeAccent(AgentRuntime runtime) => switch (runtime) {
  AgentRuntime.codex => AppPalette.cyan,
  AgentRuntime.hermes => const Color(0xFFB68CFF),
  AgentRuntime.opencode => AppPalette.amber,
};

class PulseSurface extends StatelessWidget {
  const PulseSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppPalette.surface,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(color: AppPalette.outline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class PulseSignalPanel extends StatelessWidget {
  const PulseSignalPanel({
    required this.snapshot,
    required this.heartbeat,
    required this.reducedMotion,
    super.key,
  });

  final CodexPulseSnapshot snapshot;
  final Animation<double> heartbeat;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final livePhases = snapshot.tasks
        .where((task) => task.phase.isLive)
        .map((task) => task.phase)
        .toList(growable: false);
    final phases = livePhases.isEmpty
        ? const <CodexTaskPhase>[CodexTaskPhase.idle]
        : livePhases;
    return PulseSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Wrap(
              spacing: 18,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _StatusCount(
                  phase: CodexTaskPhase.queued,
                  count: _count(snapshot, CodexTaskPhase.queued),
                ),
                _StatusCount(
                  phase: CodexTaskPhase.active,
                  count: _count(snapshot, CodexTaskPhase.active),
                ),
                _StatusCount(
                  phase: CodexTaskPhase.reasoning,
                  count: _count(snapshot, CodexTaskPhase.reasoning),
                ),
                _StatusCount(
                  phase: CodexTaskPhase.tool,
                  count: _count(snapshot, CodexTaskPhase.tool),
                ),
                _StatusCount(
                  phase: CodexTaskPhase.retrying,
                  count: _count(snapshot, CodexTaskPhase.retrying),
                ),
                _StatusCount(
                  phase: CodexTaskPhase.stalled,
                  count: _count(snapshot, CodexTaskPhase.stalled),
                ),
                _StatusCount(
                  phase: CodexTaskPhase.failed,
                  count: _count(snapshot, CodexTaskPhase.failed),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Semantics(
            image: true,
            label:
                '${snapshot.liveTaskCount} live agent tasks. ${reducedMotion ? 'Reduced motion enabled.' : 'Heartbeat animation active.'}',
            child: SizedBox(
              height: 132,
              child: CustomPaint(
                painter: PulseHeartbeatPainter(
                  phases: phases,
                  progress: 0.38,
                  animation: reducedMotion ? null : heartbeat,
                  showGrid: true,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = <Widget>[
                PulseMetric(
                  label: 'Last minute',
                  value: formatPulseInteger(snapshot.usage.lastMinute),
                  accent: AppPalette.green,
                ),
                PulseMetric(
                  label: 'Last hour',
                  value: formatPulseInteger(snapshot.usage.lastHour),
                  accent: AppPalette.cyan,
                ),
                PulseMetric(
                  label: 'Since Pulse started',
                  value: formatPulseInteger(snapshot.usage.sinceStart),
                  accent: AppPalette.amber,
                ),
              ];
              if (constraints.maxWidth >= 660) {
                return IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      for (var index = 0; index < metrics.length; index++) ...[
                        Expanded(child: metrics[index]),
                        if (index != metrics.length - 1)
                          const VerticalDivider(width: 1),
                      ],
                    ],
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (var index = 0; index < metrics.length; index++) ...[
                    metrics[index],
                    if (index != metrics.length - 1) const Divider(height: 1),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static int _count(CodexPulseSnapshot snapshot, CodexTaskPhase phase) {
    return snapshot.tasks.where((task) => task.phase == phase).length;
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({required this.phase, required this.count});

  final CodexTaskPhase phase;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = pulsePhaseColor(phase);
    return Semantics(
      label: '${phase.label}: $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(pulsePhaseIcon(phase), size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            phase.label,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class PulseMetric extends StatelessWidget {
  const PulseMetric({
    required this.label,
    required this.value,
    required this.accent,
    super.key,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.72,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.text,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cascadia Mono',
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  'tokens',
                  style: TextStyle(color: accent, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PulseHeartbeatPainter extends CustomPainter {
  PulseHeartbeatPainter({
    required this.phases,
    required this.progress,
    this.animation,
    this.showGrid = false,
  }) : super(repaint: animation);

  final List<CodexTaskPhase> phases;
  final double progress;
  final Animation<double>? animation;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    if (showGrid) {
      final grid = Paint()
        ..color = AppPalette.outline.withValues(alpha: 0.34)
        ..strokeWidth = 1;
      for (var row = 1; row < 4; row++) {
        final y = size.height * row / 4;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
      for (var column = 1; column < 8; column++) {
        final x = size.width * column / 8;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
    }

    final center = size.height / 2;
    final segmentWidth = size.width / phases.length;
    for (var index = 0; index < phases.length; index++) {
      final phase = phases[index];
      final color = pulsePhaseColor(phase);
      final left = segmentWidth * index;
      final right = index == phases.length - 1
          ? size.width
          : left + segmentWidth;
      final path = Path()..moveTo(left, center);
      const sampleCount = 96;
      for (var sample = 1; sample <= sampleCount; sample++) {
        final local = sample / sampleCount;
        final x = left + (right - left) * local;
        final moving =
            (local + (animation?.value ?? progress) * 0.42 + index * 0.11) % 1;
        final envelope = math.exp(-math.pow((moving - 0.54) * 10, 2));
        final base = math.sin((local * 31 + index) * math.pi) * 0.045;
        final signal = _phaseSignal(phase, moving) * envelope + base;
        path.lineTo(x, center - signal * size.height * 0.42);
      }
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(
          alpha: phase == CodexTaskPhase.idle ? 0.48 : 0.94,
        );
      canvas.drawPath(path, glow);
      canvas.drawPath(path, stroke);

      if (phase.isLive) {
        final markerX = left + (right - left) * 0.55;
        canvas.drawCircle(
          Offset(markerX, center),
          7,
          Paint()
            ..color = color.withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        canvas.drawCircle(Offset(markerX, center), 2.7, Paint()..color = color);
      }
    }
  }

  static double _phaseSignal(CodexTaskPhase phase, double x) {
    final pulse = math.sin(x * math.pi * 10);
    final spike = math.sin(x * math.pi * 2) * math.sin(x * math.pi * 18);
    return switch (phase) {
      CodexTaskPhase.queued => math.sin(x * math.pi * 4) * 0.2,
      CodexTaskPhase.active => pulse * 0.52 + spike * 0.72,
      CodexTaskPhase.reasoning =>
        math.sin(x * math.pi * 22) * 0.44 + spike * 0.28,
      CodexTaskPhase.tool => math.sin(x * math.pi * 8) * 0.34 + spike * 0.82,
      CodexTaskPhase.retrying => math.sin(x * math.pi * 5) * 0.28 + spike * 0.9,
      CodexTaskPhase.stalled => math.sin(x * math.pi * 3) * 0.16,
      CodexTaskPhase.failed => spike * 0.96,
      CodexTaskPhase.cancelled => math.sin(x * math.pi * 4) * 0.12,
      CodexTaskPhase.idle ||
      CodexTaskPhase.unknown => math.sin(x * math.pi * 14) * 0.07,
    };
  }

  @override
  bool shouldRepaint(covariant PulseHeartbeatPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animation != animation ||
        oldDelegate.showGrid != showGrid ||
        !_samePhases(oldDelegate.phases, phases);
  }

  static bool _samePhases(
    List<CodexTaskPhase> left,
    List<CodexTaskPhase> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}

String formatPulseInteger(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

String formatPulseBytes(int value) {
  final bytes = math.max(0, value);
  if (bytes >= 1024 * 1024) {
    final mebibytes = bytes / (1024 * 1024);
    return '${mebibytes.toStringAsFixed(mebibytes >= 10 ? 1 : 2)} MiB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  }
  return '$bytes B';
}

class PulseTaskLedger extends StatelessWidget {
  const PulseTaskLedger({
    required this.tasks,
    required this.heartbeat,
    required this.reducedMotion,
    required this.onOpenTask,
    this.onPauseTask,
    this.onResumeTask,
    this.onContinueTask,
    this.onStopTask,
    this.isTaskBusy,
    this.isTaskPaused,
    this.requiresContinuation,
    super.key,
  });

  final List<CodexTaskSignal> tasks;
  final Animation<double> heartbeat;
  final bool reducedMotion;
  final ValueChanged<CodexTaskSignal> onOpenTask;
  final ValueChanged<CodexTaskSignal>? onPauseTask;
  final ValueChanged<CodexTaskSignal>? onResumeTask;
  final ValueChanged<CodexTaskSignal>? onContinueTask;
  final ValueChanged<CodexTaskSignal>? onStopTask;
  final bool Function(CodexTaskSignal task)? isTaskBusy;
  final bool Function(CodexTaskSignal task)? isTaskPaused;
  final bool Function(CodexTaskSignal task)? requiresContinuation;

  @override
  Widget build(BuildContext context) {
    return PulseSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.monitor_heart_outlined,
                  color: AppPalette.cyan,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Text(
                  'Task signal ledger',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${tasks.length} recent',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (tasks.isEmpty)
            const _PulseEmptyState()
          else
            for (var index = 0; index < tasks.length; index++) ...[
              PulseTaskRow(
                task: tasks[index],
                heartbeat: heartbeat,
                reducedMotion: reducedMotion,
                onTap: () => onOpenTask(tasks[index]),
                onPauseTask: onPauseTask,
                onResumeTask: onResumeTask,
                onContinueTask: onContinueTask,
                onStopTask: onStopTask,
                isBusy: isTaskBusy?.call(tasks[index]) ?? false,
                isPaused: isTaskPaused?.call(tasks[index]) ?? false,
                requiresContinuation:
                    requiresContinuation?.call(tasks[index]) ?? false,
              ),
              if (index != tasks.length - 1)
                const Divider(height: 1, indent: 18, endIndent: 18),
            ],
        ],
      ),
    );
  }
}

class _PulseEmptyState extends StatelessWidget {
  const _PulseEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.monitor_heart_outlined,
            color: AppPalette.textMuted,
            size: 34,
          ),
          SizedBox(height: 12),
          Text(
            'No recent Codex, Hermes, or OpenCode tasks were discovered.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.text),
          ),
          SizedBox(height: 5),
          Text(
            'Pulse reads both local runtime stores without changing them.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class PulseTaskRow extends StatelessWidget {
  const PulseTaskRow({
    required this.task,
    required this.heartbeat,
    required this.reducedMotion,
    required this.onTap,
    this.onPauseTask,
    this.onResumeTask,
    this.onContinueTask,
    this.onStopTask,
    this.isBusy = false,
    this.isPaused = false,
    this.requiresContinuation = false,
    super.key,
  });

  final CodexTaskSignal task;
  final Animation<double> heartbeat;
  final bool reducedMotion;
  final VoidCallback onTap;
  final ValueChanged<CodexTaskSignal>? onPauseTask;
  final ValueChanged<CodexTaskSignal>? onResumeTask;
  final ValueChanged<CodexTaskSignal>? onContinueTask;
  final ValueChanged<CodexTaskSignal>? onStopTask;
  final bool isBusy;
  final bool isPaused;
  final bool requiresContinuation;

  @override
  Widget build(BuildContext context) {
    final color = pulsePhaseColor(task.phase);
    return Semantics(
      button: true,
      label:
          'Open ${task.runtime.label} task ${task.title}. ${task.model}, ${task.provider}, ${task.phase.label}.',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 760) {
                return _buildWide(context, color);
              }
              return _buildCompact(context, color);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _TaskStatusGlyph(task: task, color: color),
            const SizedBox(width: 13),
            Expanded(
              flex: 7,
              child: _TaskIdentity(task: task, color: color),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 150,
              height: 48,
              child: CustomPaint(
                painter: PulseHeartbeatPainter(
                  phases: <CodexTaskPhase>[task.phase],
                  progress: 0.38,
                  animation: reducedMotion ? null : heartbeat,
                ),
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(width: 96, child: _TaskActivity(task: task)),
            const SizedBox(width: 16),
            SizedBox(
              width: 106,
              child: _TaskContext(task: task, color: color),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 86,
              child: _TaskTokens(task: task, color: color),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.open_in_new_rounded,
              size: 17,
              color: AppPalette.textMuted,
            ),
          ],
        ),
        if (onPauseTask != null ||
            onResumeTask != null ||
            onStopTask != null) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (onPauseTask != null &&
                  task.capabilities.pause &&
                  task.phase.isLive &&
                  !isPaused)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onPauseTask!(task),
                  icon: const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 16,
                  ),
                  label: const Text('Pause'),
                ),
              if (onStopTask != null &&
                  task.capabilities.stop &&
                  task.phase.isLive)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onStopTask!(task),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('Stop turn'),
                ),
              if (onResumeTask != null &&
                  (isPaused || task.capabilities.resume))
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onResumeTask!(task),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Resume'),
                ),
              if (onContinueTask != null &&
                  task.runtime == AgentRuntime.codex &&
                  (requiresContinuation || (isPaused && !task.phase.isLive)))
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onContinueTask!(task),
                  icon: const Icon(Icons.fast_forward_rounded, size: 16),
                  label: const Text('Continue'),
                ),
              if (isBusy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompact(BuildContext context, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _TaskStatusGlyph(task: task, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: _TaskIdentity(task: task, color: color),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_new_rounded,
              size: 17,
              color: AppPalette.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: CustomPaint(
            painter: PulseHeartbeatPainter(
              phases: <CodexTaskPhase>[task.phase],
              progress: 0.38,
              animation: reducedMotion ? null : heartbeat,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          children: <Widget>[
            _TaskActivity(task: task),
            SizedBox(
              width: 150,
              child: _TaskContext(task: task, color: color),
            ),
            _TaskTokens(task: task, color: color),
          ],
        ),
        if (onPauseTask != null ||
            onResumeTask != null ||
            onStopTask != null) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (onPauseTask != null &&
                  task.capabilities.pause &&
                  task.phase.isLive &&
                  !isPaused)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onPauseTask!(task),
                  icon: const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 16,
                  ),
                  label: const Text('Pause'),
                ),
              if (onStopTask != null &&
                  task.capabilities.stop &&
                  task.phase.isLive)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onStopTask!(task),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('Stop turn'),
                ),
              if (onResumeTask != null &&
                  (isPaused || task.capabilities.resume))
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onResumeTask!(task),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Resume'),
                ),
              if (onContinueTask != null &&
                  task.runtime == AgentRuntime.codex &&
                  (requiresContinuation || (isPaused && !task.phase.isLive)))
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onContinueTask!(task),
                  icon: const Icon(Icons.fast_forward_rounded, size: 16),
                  label: const Text('Continue'),
                ),
              if (isBusy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TaskStatusGlyph extends StatelessWidget {
  const _TaskStatusGlyph({required this.task, required this.color});

  final CodexTaskSignal task;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Icon(pulsePhaseIcon(task.phase), color: color, size: 19),
    );
  }
}

class _TaskIdentity extends StatelessWidget {
  const _TaskIdentity({required this.task, required this.color});

  final CodexTaskSignal task;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppPalette.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _PulseChip(
              label: task.runtime.label,
              accent: runtimeAccent(task.runtime),
            ),
            _PulseChip(label: task.model),
            _PulseChip(label: task.provider, accent: color),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(pulsePhaseIcon(task.phase), color: color, size: 13),
                const SizedBox(width: 4),
                Text(
                  task.uncertain
                      ? '${task.phase.label} · inferred'
                      : task.phase.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (task.retryAttempt != null &&
                task.phase == CodexTaskPhase.retrying)
              Text(
                'attempt ${task.retryAttempt}/${task.retryMaximum ?? '—'}',
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 10.5,
                ),
              ),
          ],
        ),
        if (task.errorSummary != null) ...[
          const SizedBox(height: 6),
          Text(
            task.errorSummary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppPalette.red, fontSize: 10.5),
          ),
        ],
      ],
    );
  }
}

class _PulseChip extends StatelessWidget {
  const _PulseChip({required this.label, this.accent});

  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppPalette.textMuted;
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accent == null ? AppPalette.text : color,
          fontSize: 10.5,
          fontFamily: 'Cascadia Mono',
        ),
      ),
    );
  }
}

class _TaskActivity extends StatelessWidget {
  const _TaskActivity({required this.task});

  final CodexTaskSignal task;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'ACTIVITY',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.58,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatPulseRelative(task.lastActivityAt),
          style: const TextStyle(
            color: AppPalette.text,
            fontSize: 11.5,
            fontFamily: 'Cascadia Mono',
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _TaskContext extends StatelessWidget {
  const _TaskContext({required this.task, required this.color});

  final CodexTaskSignal task;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = task.contextRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'CONTEXT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.58,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              ratio == null ? '—' : '${(ratio * 100).round()}%',
              style: TextStyle(
                color: ratio != null && ratio >= 0.84
                    ? AppPalette.amber
                    : AppPalette.text,
                fontSize: 10.5,
                fontFamily: 'Cascadia Mono',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio ?? 0,
            minHeight: 5,
            backgroundColor: AppPalette.outline,
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio != null && ratio >= 0.84 ? AppPalette.amber : color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskTokens extends StatelessWidget {
  const _TaskTokens({required this.task, required this.color});

  final CodexTaskSignal task;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Δ TOKENS',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.58,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '+${formatPulseInteger(task.sessionTokens)}',
          style: TextStyle(
            color: task.sessionTokens == 0 ? AppPalette.textMuted : color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'Cascadia Mono',
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class PulseRuntimePanel extends StatelessWidget {
  const PulseRuntimePanel({
    required this.health,
    required this.usage,
    required this.tasks,
    super.key,
  });

  final List<RuntimeHealth> health;
  final RuntimeUsageSummary? usage;
  final List<CodexTaskSignal> tasks;

  @override
  Widget build(BuildContext context) {
    return PulseSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.memory_rounded,
                  color: AppPalette.cyan,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Agent runtimes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Text(
                  '20s grace',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 10.5,
                    fontFamily: 'Cascadia Mono',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < AgentRuntime.values.length; index++) ...[
            _RuntimePulseRow(
              runtime: AgentRuntime.values[index],
              health: _healthFor(AgentRuntime.values[index]),
              usage: _usageFor(AgentRuntime.values[index]),
              tasks: tasks
                  .where((task) => task.runtime == AgentRuntime.values[index])
                  .toList(growable: false),
            ),
            if (index != AgentRuntime.values.length - 1)
              const Divider(height: 1, indent: 18, endIndent: 18),
          ],
        ],
      ),
    );
  }

  RuntimeHealth? _healthFor(AgentRuntime runtime) {
    for (final item in health) {
      if (item.runtime == runtime) {
        return item;
      }
    }
    return null;
  }

  RuntimeUsageWindow? _usageFor(AgentRuntime runtime) => switch (runtime) {
    AgentRuntime.codex => usage?.codex,
    AgentRuntime.hermes => usage?.hermes,
    AgentRuntime.opencode => usage?.opencode,
  };
}

class _RuntimePulseRow extends StatelessWidget {
  const _RuntimePulseRow({
    required this.runtime,
    required this.health,
    required this.usage,
    required this.tasks,
  });

  final AgentRuntime runtime;
  final RuntimeHealth? health;
  final RuntimeUsageWindow? usage;
  final List<CodexTaskSignal> tasks;

  @override
  Widget build(BuildContext context) {
    final live = tasks
        .where((task) => task.phase.isLive)
        .toList(growable: false);
    final accent = _statusColor(live.length);
    final models = <String>{
      for (final task in [...live, ...tasks])
        if (task.model.trim().isNotEmpty) task.model.trim(),
    }.take(2).join(' · ');
    return Semantics(
      label:
          '${runtime.label}, ${_statusLabel(live.length)}, ${models.isEmpty ? 'model unavailable' : models}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.32),
                        blurRadius: live.isEmpty ? 3 : 9,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    runtime.label,
                    style: const TextStyle(
                      color: AppPalette.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _statusLabel(live.length),
                    style: TextStyle(
                      color: accent,
                      fontSize: 9.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              models.isEmpty ? 'No model reported' : models,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 10.5,
                fontFamily: 'Cascadia Mono',
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: <Widget>[
                Expanded(
                  child: _RuntimeTokenValue(
                    label: '1 MIN',
                    value: usage?.lastMinute,
                  ),
                ),
                Expanded(
                  child: _RuntimeTokenValue(
                    label: '1 HOUR',
                    value: usage?.lastHour,
                  ),
                ),
                Expanded(
                  child: _RuntimeTokenValue(
                    label: 'SESSION',
                    value: usage?.sinceStart,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(int liveCount) {
    if (liveCount > 0) {
      return AppPalette.green;
    }
    if (health?.reconnecting ?? false) {
      return AppPalette.amber;
    }
    if (!(health?.available ?? false)) {
      return AppPalette.red;
    }
    return runtimeAccent(runtime);
  }

  String _statusLabel(int liveCount) {
    if (liveCount > 0) {
      return '$liveCount active';
    }
    if (health?.reconnecting ?? false) {
      return 'Reconnecting';
    }
    if (!(health?.available ?? false)) {
      return 'Unavailable';
    }
    if (health?.gatewayReachable == true) {
      return 'Ready';
    }
    return 'Idle';
  }
}

class _RuntimeTokenValue extends StatelessWidget {
  const _RuntimeTokenValue({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.textMuted,
            fontSize: 8.8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value == null ? '—' : formatPulseInteger(value!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppPalette.text,
            fontSize: 10.8,
            fontWeight: FontWeight.w700,
            fontFamily: 'Cascadia Mono',
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class PulseProviderPanel extends StatelessWidget {
  const PulseProviderPanel({
    required this.mode,
    required this.model,
    required this.switchBusy,
    required this.onSwitch,
    super.key,
  });

  final CodexProviderMode mode;
  final String? model;
  final bool switchBusy;
  final ValueChanged<CodexProviderMode> onSwitch;

  @override
  Widget build(BuildContext context) {
    return PulseSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.route_outlined,
                color: AppPalette.cyan,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Codex profile provider',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (switchBusy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadii.panel),
              border: Border.all(color: AppPalette.outline),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: mode == CodexProviderMode.unknown
                        ? AppPalette.textMuted
                        : AppPalette.green,
                    shape: BoxShape.circle,
                    boxShadow: mode == CodexProviderMode.unknown
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: AppPalette.green.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        mode.label,
                        style: const TextStyle(
                          color: AppPalette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model ?? 'Model not reported',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 11,
                          fontFamily: 'Cascadia Mono',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: mode == CodexProviderMode.openai
                    ? FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: const Text('OpenAI'),
                      )
                    : OutlinedButton.icon(
                        onPressed: switchBusy
                            ? null
                            : () => onSwitch(CodexProviderMode.openai),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                        label: const Text('OpenAI'),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: mode == CodexProviderMode.ox
                    ? FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: const Text('Ox'),
                      )
                    : OutlinedButton.icon(
                        onPressed: switchBusy
                            ? null
                            : () => onSwitch(CodexProviderMode.ox),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                        label: const Text('Ox'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Switching uses the existing atomic provider switcher. If Codex is open, it asks before closing and relaunching it.',
            style: TextStyle(
              color: AppPalette.textMuted,
              fontSize: 10.8,
              height: 1.42,
            ),
          ),
        ],
      ),
    );
  }
}

class PulseBridgePanel extends StatelessWidget {
  const PulseBridgePanel({required this.bridge, super.key});

  final CodexBridgeStatus bridge;

  @override
  Widget build(BuildContext context) {
    final accent = !bridge.reachable || !bridge.healthy
        ? AppPalette.red
        : bridge.cooldownUntil != null || bridge.queuedRequests > 0
        ? AppPalette.amber
        : bridge.activeRequests > 0
        ? AppPalette.green
        : AppPalette.textMuted;
    return PulseSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.hub_outlined, color: accent, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Ox adapter telemetry',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              _BridgeStateBadge(bridge: bridge, color: accent),
            ],
          ),
          const SizedBox(height: 16),
          _BridgeFact(label: 'Version', value: bridge.version ?? 'Unavailable'),
          _BridgeFact(label: 'Model', value: bridge.model ?? 'Not reported'),
          _BridgeFact(
            label: 'Active slots',
            value: bridge.admissionLimit == null
                ? '${bridge.activeRequests}'
                : '${bridge.activeRequests} / ${bridge.admissionLimit}',
          ),
          _BridgeFact(
            label: 'Queue',
            value: '${bridge.queuedRequests} waiting',
          ),
          _BridgeFact(
            label: 'Adaptive range',
            value: bridge.admissionLimit == null
                ? 'Not reported'
                : '${bridge.admissionLimit} / ${bridge.admissionMaximum ?? bridge.admissionLimit}',
          ),
          _BridgeFact(
            label: 'Request bytes',
            value: bridge.byteBudgetBytes == null
                ? formatPulseBytes(bridge.inFlightBytes)
                : '${formatPulseBytes(bridge.inFlightBytes)} / ${formatPulseBytes(bridge.byteBudgetBytes!)}',
          ),
          _BridgeFact(
            label: 'Cooldown',
            value: _bridgeCooldownLabel(bridge.cooldownUntil),
          ),
          _BridgeFact(
            label: 'Telemetry',
            value: bridge.supportsMetrics ? 'Detailed metrics' : 'Health only',
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _BridgeTokenWindow(
                  label: '1 minute',
                  tokens: bridge.lastMinuteTokens,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BridgeTokenWindow(
                  label: '1 hour',
                  tokens: bridge.lastHourTokens,
                ),
              ),
            ],
          ),
          if (bridge.message != null) ...[
            const SizedBox(height: 12),
            Text(
              bridge.message!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: accent, fontSize: 10.5, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _BridgeStateBadge extends StatelessWidget {
  const _BridgeStateBadge({required this.bridge, required this.color});

  final CodexBridgeStatus bridge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = !bridge.reachable
        ? 'Offline'
        : !bridge.healthy
        ? 'Degraded'
        : bridge.cooldownUntil != null
        ? 'Cooling'
        : bridge.queuedRequests > 0
        ? '${bridge.queuedRequests} queued'
        : bridge.activeRequests > 0
        ? 'Active'
        : 'Idle';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            bridge.reachable ? Icons.circle : Icons.cloud_off_outlined,
            size: bridge.reachable ? 7 : 12,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _bridgeCooldownLabel(DateTime? until) {
  if (until == null) {
    return 'Ready';
  }
  final local = until.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return 'Until ${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}

class _BridgeFact extends StatelessWidget {
  const _BridgeFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 10.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppPalette.text,
                fontSize: 10.8,
                fontFamily: 'Cascadia Mono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BridgeTokenWindow extends StatelessWidget {
  const _BridgeTokenWindow({required this.label, required this.tokens});

  final String label;
  final int tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 9.5),
          ),
          const SizedBox(height: 4),
          Text(
            formatPulseInteger(tokens),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Cascadia Mono',
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String formatPulseRelative(DateTime? timestamp, {DateTime? now}) {
  if (timestamp == null) {
    return 'unknown';
  }
  final current = (now ?? DateTime.now()).toUtc();
  final delta = current.difference(timestamp.toUtc());
  if (delta.isNegative || delta < const Duration(seconds: 3)) {
    return 'now';
  }
  if (delta < const Duration(minutes: 1)) {
    return '${delta.inSeconds}s ago';
  }
  if (delta < const Duration(hours: 1)) {
    return '${delta.inMinutes}m ago';
  }
  if (delta < const Duration(days: 1)) {
    return '${delta.inHours}h ago';
  }
  return '${delta.inDays}d ago';
}
