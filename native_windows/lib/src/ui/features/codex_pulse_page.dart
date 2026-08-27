import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/runtime/codex_pulse_service.dart';
import '../../core/runtime/codex_task_lifecycle_service.dart';
import '../../core/runtime/windows_platform_bridge.dart';
import '../../models/codex_pulse.dart';
import '../../models/runtime_control.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';
import 'codex_pulse_components.dart';

class CodexPulsePage extends StatefulWidget {
  const CodexPulsePage({
    this.controller,
    this.source,
    this.onOpenTask,
    super.key,
  });

  final AppController? controller;
  final CodexPulseSource? source;
  final Future<void> Function(String threadId)? onOpenTask;

  @override
  State<CodexPulsePage> createState() => _CodexPulsePageState();
}

class _CodexPulsePageState extends State<CodexPulsePage>
    with SingleTickerProviderStateMixin {
  static const WindowsPlatformBridge _platform = WindowsPlatformBridge();

  late final CodexPulseSource _source;
  late final bool _ownsSource;
  late final AnimationController _heartbeat;
  Timer? _refreshTimer;
  CodexPulseSnapshot? _snapshot;
  Object? _refreshError;
  bool _refreshing = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _ownsSource = widget.source == null;
    _source =
        widget.source ??
        CodexPulseService(
          runtimeSnapshotReader: widget.controller?.getRuntimeControlSnapshot,
        );
    _heartbeat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    unawaited(_refresh(showSpinner: true));
    _refreshTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final nextReduced = media.disableAnimations || media.accessibleNavigation;
    if (_reducedMotion == nextReduced &&
        (_heartbeat.isAnimating || nextReduced)) {
      return;
    }
    _reducedMotion = nextReduced;
    if (_reducedMotion) {
      _heartbeat.stop();
      _heartbeat.value = 0.38;
    } else {
      unawaited(_heartbeat.repeat());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _heartbeat.dispose();
    if (_ownsSource) {
      _source.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh({bool showSpinner = false}) async {
    if (_refreshing || !mounted) {
      return;
    }
    _refreshing = true;
    if (showSpinner) {
      setState(() {});
    }
    try {
      final next = await _source.refresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = next;
        _refreshError = null;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _refreshError = error);
    } finally {
      _refreshing = false;
      if (mounted && showSpinner) {
        setState(() {});
      }
    }
  }

  Future<void> _pauseTask(CodexTaskSignal task) async {
    final controller = widget.controller;
    if (controller == null || task.runtime != AgentRuntime.codex) {
      return;
    }
    final taskId = task.sessionId ?? task.id;
    final result = await controller.pauseCodexTask(taskId);
    if (!mounted) {
      return;
    }
    final message = result == null
        ? 'Could not pause the task: ${controller.codexTaskActionError ?? 'unknown error'}'
        : result.requiresContinuation
        ? 'Paused ${result.interruptedTurnCount} active turn(s). This task has no persistent goal, so use Continue to start a new bounded turn.'
        : 'Paused the root task and ${result.interruptedTurnCount} active turn(s).';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
    await _refresh(showSpinner: true);
  }

  Future<void> _resumeTask(CodexTaskSignal task) async {
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    final taskId = task.sessionId ?? task.id;
    if (task.runtime != AgentRuntime.codex) {
      final result = await controller.controlRuntimeTask(
        task.runtime,
        taskId,
        'resume',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? 'Could not resume the ${task.runtime.label} task: ${controller.runtimeTaskActionError ?? 'unknown error'}'
                : '${task.runtime.label} resumed the durable task session.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      await _refresh(showSpinner: true);
      return;
    }
    final result = await controller.resumeCodexTask(taskId);
    if (!mounted) {
      return;
    }
    final message = switch (result?.disposition) {
      CodexTaskResumeDisposition.goalResumed => 'Persistent task goal resumed.',
      CodexTaskResumeDisposition.alreadyActive =>
        'The persistent task goal is already active.',
      CodexTaskResumeDisposition.continuationRequired =>
        'This task has no persistent goal. Use Continue to start a new bounded turn from its saved state.',
      CodexTaskResumeDisposition.continuationStarted =>
        'A continuation turn started.',
      null =>
        'Could not resume the task: ${controller.codexTaskActionError ?? 'unknown error'}',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
    await _refresh(showSpinner: true);
  }

  Future<void> _continueTask(CodexTaskSignal task) async {
    final controller = widget.controller;
    if (controller == null || task.runtime != AgentRuntime.codex) {
      return;
    }
    final taskId = task.sessionId ?? task.id;
    final result = await controller.continueCodexTask(taskId);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Could not continue the task: ${controller.codexTaskActionError ?? 'unknown error'}'
              : 'Continuation turn started from the saved task state.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    await _refresh(showSpinner: true);
  }

  Future<void> _stopTask(CodexTaskSignal task) async {
    final controller = widget.controller;
    if (controller == null || task.runtime == AgentRuntime.codex) {
      return;
    }
    final result = await controller.controlRuntimeTask(
      task.runtime,
      task.sessionId ?? task.id,
      'stop',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Could not stop the ${task.runtime.label} turn: ${controller.runtimeTaskActionError ?? 'unknown error'}'
              : '${task.runtime.label} acknowledged the native interrupt.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    await _refresh(showSpinner: true);
  }

  Future<void> _openTask(CodexTaskSignal task) async {
    try {
      final callback = widget.onOpenTask;
      if (callback != null) {
        await callback(task.id);
      } else {
        switch (task.runtime) {
          case AgentRuntime.codex:
            await _platform.openCodexThread(task.id);
          case AgentRuntime.hermes:
            await _platform.openHermesSession(
              task.id,
              workingDirectory: task.cwd,
            );
          case AgentRuntime.opencode:
            await _platform.openOpenCodeSession(
              task.id,
              workingDirectory: task.cwd,
            );
        }
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${task.runtime.label} task: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return ColoredBox(
      color: AppPalette.background,
      child: snapshot == null
          ? _PulseLoading(
              error: _refreshError,
              onRetry: () => unawaited(_refresh(showSpinner: true)),
            )
          : Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PulsePageHeader(
                      snapshot: snapshot,
                      refreshing: _refreshing,
                      onRefresh: () => unawaited(_refresh(showSpinner: true)),
                    ),
                    if (snapshot.sourceError != null || _refreshError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: PulseSourceWarning(
                          message:
                              snapshot.sourceError ?? _refreshError.toString(),
                        ),
                      ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final primary = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            PulseSignalPanel(
                              snapshot: snapshot,
                              heartbeat: _heartbeat,
                              reducedMotion: _reducedMotion,
                            ),
                            const SizedBox(height: 16),
                            PulseTaskLedger(
                              tasks: snapshot.tasks,
                              heartbeat: _heartbeat,
                              reducedMotion: _reducedMotion,
                              onOpenTask: (task) => unawaited(_openTask(task)),
                              onPauseTask: widget.controller == null
                                  ? null
                                  : (task) => unawaited(_pauseTask(task)),
                              onResumeTask: widget.controller == null
                                  ? null
                                  : (task) => unawaited(_resumeTask(task)),
                              onContinueTask: widget.controller == null
                                  ? null
                                  : (task) => unawaited(_continueTask(task)),
                              onStopTask: widget.controller == null
                                  ? null
                                  : (task) => unawaited(_stopTask(task)),
                              isTaskBusy: (task) =>
                                  widget.controller?.mutatingCodexTaskIds
                                          .contains(
                                            task.sessionId ?? task.id,
                                          ) ==
                                      true ||
                                  (widget.controller?.mutatingRuntimeTaskIds
                                          .contains(task.qualifiedId) ??
                                      false),
                              isTaskPaused: (task) =>
                                  widget.controller?.pausedCodexTaskIds
                                      .contains(task.sessionId ?? task.id) ??
                                  false,
                              requiresContinuation: (task) =>
                                  widget
                                      .controller
                                      ?.codexTaskContinuationRequiredIds
                                      .contains(task.sessionId ?? task.id) ??
                                  false,
                            ),
                          ],
                        );
                        final rail = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            PulseRuntimePanel(
                              health: snapshot.runtimeHealth,
                              usage: snapshot.runtimeUsage,
                              tasks: snapshot.tasks,
                            ),
                            const SizedBox(height: 16),
                            PulseSessionPanel(
                              snapshot: snapshot,
                              reducedMotion: _reducedMotion,
                            ),
                          ],
                        );
                        if (constraints.maxWidth >= 1180) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: primary),
                              const SizedBox(width: 18),
                              SizedBox(width: 326, child: rail),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            primary,
                            const SizedBox(height: 16),
                            rail,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class PulsePageHeader extends StatelessWidget {
  const PulsePageHeader({
    required this.snapshot,
    required this.refreshing,
    required this.onRefresh,
    super.key,
  });

  final CodexPulseSnapshot snapshot;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final identity = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppPalette.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.feature),
                border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                color: AppPalette.cyan,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'OpenHUB Pulse',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Codex + Hermes + OpenCode activity, lineage, native controls and token ledger',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
        final controls = Wrap(
          spacing: 9,
          runSpacing: 9,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _HeaderBadge(
              icon: Icons.play_circle_outline_rounded,
              label: '${snapshot.liveTaskCount} live',
              color: snapshot.liveTaskCount > 0
                  ? AppPalette.green
                  : AppPalette.textMuted,
            ),
            _HeaderBadge(
              icon: Icons.route_outlined,
              label: '${snapshot.runtimeHealth.length} runtimes',
              color: AppPalette.cyan,
            ),
            Tooltip(
              message: 'Refresh OpenHUB Pulse now',
              child: IconButton.outlined(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        );
        if (constraints.maxWidth >= 780) {
          return Row(
            children: <Widget>[
              Expanded(child: identity),
              const SizedBox(width: 18),
              controls,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            identity,
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: controls),
          ],
        );
      },
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PulseSourceWarning extends StatelessWidget {
  const PulseSourceWarning({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppPalette.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: AppPalette.amber,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.amber,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PulseSessionPanel extends StatelessWidget {
  const PulseSessionPanel({
    required this.snapshot,
    required this.reducedMotion,
    super.key,
  });

  final CodexPulseSnapshot snapshot;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return PulseSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.shield_outlined,
                color: AppPalette.green,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Telemetry boundary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SessionFact(
            label: 'Pulse started',
            value: _formatClock(snapshot.usage.startedAt),
          ),
          _SessionFact(
            label: 'Last sample',
            value: _formatClock(snapshot.sampledAt),
          ),
          _SessionFact(
            label: 'Motion',
            value: reducedMotion ? 'Reduced' : 'Live heartbeat',
          ),
          _SessionFact(label: 'Task stores', value: 'Read-only'),
          const SizedBox(height: 10),
          const Text(
            'Pulse never displays prompt bodies, credentials, or hidden reasoning text. It observes lifecycle and counters only.',
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

class _SessionFact extends StatelessWidget {
  const _SessionFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 10.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppPalette.text,
              fontSize: 10.8,
              fontFamily: 'Cascadia Mono',
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseLoading extends StatelessWidget {
  const _PulseLoading({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: PulseSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (error == null)
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else
                  const Icon(
                    Icons.monitor_heart_outlined,
                    color: AppPalette.red,
                    size: 34,
                  ),
                const SizedBox(height: 15),
                Text(
                  error == null
                      ? 'Reading agent runtime signals…'
                      : 'OpenHUB Pulse could not start',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppPalette.red, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatClock(DateTime timestamp) {
  final local = timestamp.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
