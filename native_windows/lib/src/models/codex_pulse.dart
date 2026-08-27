import 'runtime_control.dart';

enum CodexTaskPhase {
  queued,
  active,
  reasoning,
  tool,
  retrying,
  stalled,
  failed,
  cancelled,
  idle,
  unknown,
}

extension CodexTaskPhasePresentation on CodexTaskPhase {
  String get label => switch (this) {
    CodexTaskPhase.queued => 'Queued',
    CodexTaskPhase.active => 'Active',
    CodexTaskPhase.reasoning => 'Reasoning',
    CodexTaskPhase.tool => 'Using tool',
    CodexTaskPhase.retrying => 'Retrying',
    CodexTaskPhase.stalled => 'Stalled',
    CodexTaskPhase.failed => 'Failed',
    CodexTaskPhase.cancelled => 'Cancelled',
    CodexTaskPhase.idle => 'Ready',
    CodexTaskPhase.unknown => 'Unknown',
  };

  bool get isLive => switch (this) {
    CodexTaskPhase.queued ||
    CodexTaskPhase.active ||
    CodexTaskPhase.reasoning ||
    CodexTaskPhase.tool ||
    CodexTaskPhase.retrying => true,
    _ => false,
  };
}

class CodexTaskSignal {
  const CodexTaskSignal({
    required this.id,
    required this.title,
    required this.model,
    required this.provider,
    required this.phase,
    required this.totalTokens,
    required this.sessionTokens,
    required this.lastActivityAt,
    this.runtime = AgentRuntime.codex,
    this.capabilities = const RuntimeTaskCapabilities.codexNative(),
    this.sessionId,
    this.cwd,
    this.parentThreadId,
    this.agentNickname,
    this.agentRole,
    this.children = const <CodexTaskSignal>[],
    this.startedAt,
    this.reasoningEffort,
    this.contextTokens,
    this.contextWindow,
    this.retryAttempt,
    this.retryMaximum,
    this.streamedCharacters,
    this.errorSummary,
    this.uncertain = false,
  });

  final String id;
  final String title;
  final String model;
  final String provider;
  final CodexTaskPhase phase;
  final int totalTokens;
  final int sessionTokens;
  final DateTime? lastActivityAt;
  final AgentRuntime runtime;
  final RuntimeTaskCapabilities capabilities;
  final String? sessionId;
  final String? cwd;
  final String? parentThreadId;
  final String? agentNickname;
  final String? agentRole;
  final List<CodexTaskSignal> children;
  final DateTime? startedAt;
  final String? reasoningEffort;
  final int? contextTokens;
  final int? contextWindow;
  final int? retryAttempt;
  final int? retryMaximum;
  final int? streamedCharacters;
  final String? errorSummary;
  final bool uncertain;

  int get childThreadCount => children.length;

  String get qualifiedId => '${runtime.name}:$id';

  double? get contextRatio {
    final used = contextTokens;
    final capacity = contextWindow;
    if (used == null || capacity == null || capacity <= 0) {
      return null;
    }
    return (used / capacity).clamp(0, 1).toDouble();
  }
}

class CodexPulseUsage {
  const CodexPulseUsage({
    required this.sinceStart,
    required this.lastMinute,
    required this.lastHour,
    required this.startedAt,
  });

  final int sinceStart;
  final int lastMinute;
  final int lastHour;
  final DateTime startedAt;
}

class CodexPulseSnapshot {
  const CodexPulseSnapshot({
    required this.tasks,
    required this.usage,
    required this.sampledAt,
    this.runtimeHealth = const <RuntimeHealth>[],
    this.runtimeUsage,
    this.sourceError,
  });

  final List<CodexTaskSignal> tasks;
  final CodexPulseUsage usage;
  final DateTime sampledAt;
  final List<RuntimeHealth> runtimeHealth;
  final RuntimeUsageSummary? runtimeUsage;
  final String? sourceError;

  int get liveTaskCount => tasks.where((task) => task.phase.isLive).length;
}
