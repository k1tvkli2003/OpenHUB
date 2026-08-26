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

enum CodexProviderMode { openai, ox, unknown }

extension CodexProviderModePresentation on CodexProviderMode {
  String get label => switch (this) {
    CodexProviderMode.openai => 'OpenAI',
    CodexProviderMode.ox => 'Ox',
    CodexProviderMode.unknown => 'Unknown',
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

class CodexBridgeRequest {
  const CodexBridgeRequest({
    required this.requestId,
    required this.phase,
    required this.attempt,
    this.threadId,
    this.lastActivityAt,
    this.streamedCharacters = 0,
    this.reasoningCharacters = 0,
    this.retryReason,
  });

  final String requestId;
  final String? threadId;
  final String phase;
  final int attempt;
  final DateTime? lastActivityAt;
  final int streamedCharacters;
  final int reasoningCharacters;
  final String? retryReason;
}

class CodexBridgeStatus {
  const CodexBridgeStatus({
    required this.reachable,
    required this.healthy,
    required this.supportsMetrics,
    required this.activeRequests,
    required this.requests,
    this.version,
    this.model,
    this.provider,
    this.lastMinuteTokens = 0,
    this.lastHourTokens = 0,
    this.queuedRequests = 0,
    this.admissionLimit,
    this.admissionMaximum,
    this.inFlightBytes = 0,
    this.byteBudgetBytes,
    this.cooldownUntil,
    this.maxAttempts,
    this.message,
  });

  const CodexBridgeStatus.unavailable([String? message])
    : this(
        reachable: false,
        healthy: false,
        supportsMetrics: false,
        activeRequests: 0,
        requests: const <CodexBridgeRequest>[],
        message: message,
      );

  final bool reachable;
  final bool healthy;
  final bool supportsMetrics;
  final int activeRequests;
  final List<CodexBridgeRequest> requests;
  final String? version;
  final String? model;
  final String? provider;
  final int lastMinuteTokens;
  final int lastHourTokens;
  final int queuedRequests;
  final int? admissionLimit;
  final int? admissionMaximum;
  final int inFlightBytes;
  final int? byteBudgetBytes;
  final DateTime? cooldownUntil;
  final int? maxAttempts;
  final String? message;

  double? get bytePressureRatio {
    final budget = byteBudgetBytes;
    if (budget == null || budget <= 0) {
      return null;
    }
    return (inFlightBytes / budget).clamp(0, 1).toDouble();
  }
}

class CodexPulseSnapshot {
  const CodexPulseSnapshot({
    required this.tasks,
    required this.usage,
    required this.bridge,
    required this.profileMode,
    required this.sampledAt,
    this.runtimeHealth = const <RuntimeHealth>[],
    this.runtimeUsage,
    this.profileModel,
    this.sourceError,
  });

  final List<CodexTaskSignal> tasks;
  final CodexPulseUsage usage;
  final CodexBridgeStatus bridge;
  final CodexProviderMode profileMode;
  final String? profileModel;
  final DateTime sampledAt;
  final List<RuntimeHealth> runtimeHealth;
  final RuntimeUsageSummary? runtimeUsage;
  final String? sourceError;

  int get liveTaskCount => tasks.where((task) => task.phase.isLive).length;
}

class ProviderSwitchResult {
  const ProviderSwitchResult({
    required this.succeeded,
    required this.cancelled,
    required this.message,
  });

  const ProviderSwitchResult.success(String message)
    : this(succeeded: true, cancelled: false, message: message);

  const ProviderSwitchResult.cancelled(String message)
    : this(succeeded: false, cancelled: true, message: message);

  const ProviderSwitchResult.failure(String message)
    : this(succeeded: false, cancelled: false, message: message);

  final bool succeeded;
  final bool cancelled;
  final String message;
}
