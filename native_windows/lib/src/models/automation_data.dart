import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

const automationWeekdays = <String>[
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

class AutomationSchedule {
  const AutomationSchedule({
    required this.type,
    required this.time,
    required this.timezone,
    required this.thresholdMinutes,
    required this.days,
  });

  final String type;
  final String time;
  final String timezone;
  final int thresholdMinutes;
  final List<String> days;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'time': time,
    'timezone': timezone,
    'thresholdMinutes': thresholdMinutes,
    'days': days,
  };

  factory AutomationSchedule.fromJson(Map<String, Object?> json) {
    const context = 'automation.schedule';
    final days = _readStringList(json['days'], '$context.days');
    if (days.isEmpty ||
        days.length > automationWeekdays.length ||
        days.any((day) => !automationWeekdays.contains(day)) ||
        days.toSet().length != days.length) {
      throw const ApiSchemaException(
        'automation.schedule.days contains invalid weekday values.',
      );
    }
    return AutomationSchedule(
      type: readString(json, 'type', context),
      time: readString(json, 'time', context),
      timezone: readString(json, 'timezone', context),
      thresholdMinutes: readInt(json, 'thresholdMinutes', context),
      days: days,
    );
  }
}

class AutomationRun {
  const AutomationRun({
    required this.id,
    required this.jobId,
    required this.jobName,
    required this.model,
    required this.reasoningEffort,
    required this.trigger,
    required this.status,
    required this.scheduledFor,
    required this.startedAt,
    required this.finishedAt,
    required this.accountId,
    required this.errorCode,
    required this.errorMessage,
    required this.attemptCount,
    required this.effectiveStatus,
    required this.totalAccounts,
    required this.completedAccounts,
    required this.pendingAccounts,
    required this.cycleKey,
  });

  final String id;
  final String jobId;
  final String? jobName;
  final String? model;
  final String? reasoningEffort;
  final String trigger;
  final String status;
  final DateTime scheduledFor;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? accountId;
  final String? errorCode;
  final String? errorMessage;
  final int attemptCount;
  final String? effectiveStatus;
  final int? totalAccounts;
  final int? completedAccounts;
  final int? pendingAccounts;
  final String? cycleKey;

  String get visibleStatus => effectiveStatus ?? status;

  factory AutomationRun.fromJson(Map<String, Object?> json) {
    const context = 'automation.run';
    final scheduledFor = readNullableDateTime(json, 'scheduledFor', context);
    final startedAt = readNullableDateTime(json, 'startedAt', context);
    if (scheduledFor == null || startedAt == null) {
      throw const ApiSchemaException(
        'automation.run timestamps must not be null.',
      );
    }
    return AutomationRun(
      id: readString(json, 'id', context),
      jobId: readString(json, 'jobId', context),
      jobName: readNullableString(json, 'jobName', context),
      model: readNullableString(json, 'model', context),
      reasoningEffort: readNullableString(json, 'reasoningEffort', context),
      trigger: readString(json, 'trigger', context),
      status: readString(json, 'status', context),
      scheduledFor: scheduledFor,
      startedAt: startedAt,
      finishedAt: readNullableDateTime(json, 'finishedAt', context),
      accountId: readNullableString(json, 'accountId', context),
      errorCode: readNullableString(json, 'errorCode', context),
      errorMessage: readNullableString(json, 'errorMessage', context),
      attemptCount: readInt(json, 'attemptCount', context),
      effectiveStatus: readNullableString(json, 'effectiveStatus', context),
      totalAccounts: readNullableNumber(
        json,
        'totalAccounts',
        context,
      )?.toInt(),
      completedAccounts: readNullableNumber(
        json,
        'completedAccounts',
        context,
      )?.toInt(),
      pendingAccounts: readNullableNumber(
        json,
        'pendingAccounts',
        context,
      )?.toInt(),
      cycleKey: readNullableString(json, 'cycleKey', context),
    );
  }
}

class AutomationJob {
  const AutomationJob({
    required this.id,
    required this.name,
    required this.enabled,
    required this.includePausedAccounts,
    required this.accountScopeAll,
    required this.schedule,
    required this.model,
    required this.reasoningEffort,
    required this.prompt,
    required this.accountIds,
    required this.nextRunAt,
    required this.lastRun,
  });

  final String id;
  final String name;
  final bool enabled;
  final bool includePausedAccounts;
  final bool accountScopeAll;
  final AutomationSchedule schedule;
  final String model;
  final String? reasoningEffort;
  final String prompt;
  final List<String> accountIds;
  final DateTime? nextRunAt;
  final AutomationRun? lastRun;

  factory AutomationJob.fromJson(Map<String, Object?> json) {
    const context = 'automation.job';
    return AutomationJob(
      id: readString(json, 'id', context),
      name: readString(json, 'name', context),
      enabled: readBool(json, 'enabled', context),
      includePausedAccounts: readBool(
        json,
        'includePausedAccounts',
        context,
        fallback: false,
      ),
      accountScopeAll: readBool(
        json,
        'accountScopeAll',
        context,
        fallback: true,
      ),
      schedule: AutomationSchedule.fromJson(
        readObject(json['schedule'], '$context.schedule'),
      ),
      model: readString(json, 'model', context),
      reasoningEffort: readNullableString(json, 'reasoningEffort', context),
      prompt: readString(json, 'prompt', context),
      accountIds: _readStringList(json['accountIds'], '$context.accountIds'),
      nextRunAt: readNullableDateTime(json, 'nextRunAt', context),
      lastRun: json['lastRun'] == null
          ? null
          : AutomationRun.fromJson(
              readObject(json['lastRun'], '$context.lastRun'),
            ),
    );
  }
}

class AutomationJobsPage {
  const AutomationJobsPage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<AutomationJob> items;
  final int total;
  final bool hasMore;

  factory AutomationJobsPage.fromJson(Map<String, Object?> json) {
    final items = readList(json['items'], 'automations.items')
        .map(
          (item) =>
              AutomationJob.fromJson(readObject(item, 'automations.items[]')),
        )
        .toList(growable: false);
    if (items.length > 200) {
      throw const ApiSchemaException(
        'Automation page exceeds the native safety limit.',
      );
    }
    return AutomationJobsPage(
      items: items,
      total: readInt(json, 'total', 'automations'),
      hasMore: readBool(json, 'hasMore', 'automations'),
    );
  }
}

class AutomationRunsPage {
  const AutomationRunsPage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<AutomationRun> items;
  final int total;
  final bool hasMore;

  factory AutomationRunsPage.fromJson(Map<String, Object?> json) {
    final items = readList(json['items'], 'automationRuns.items')
        .map(
          (item) => AutomationRun.fromJson(
            readObject(item, 'automationRuns.items[]'),
          ),
        )
        .toList(growable: false);
    if (items.length > 200) {
      throw const ApiSchemaException(
        'Automation run page exceeds the native safety limit.',
      );
    }
    return AutomationRunsPage(
      items: items,
      total: readInt(json, 'total', 'automationRuns'),
      hasMore: readBool(json, 'hasMore', 'automationRuns'),
    );
  }
}

class AutomationRunAccountState {
  const AutomationRunAccountState({
    required this.accountId,
    required this.status,
    required this.errorCode,
    required this.errorMessage,
  });

  final String accountId;
  final String status;
  final String? errorCode;
  final String? errorMessage;

  factory AutomationRunAccountState.fromJson(Map<String, Object?> json) {
    const context = 'automationRunDetails.accounts[]';
    return AutomationRunAccountState(
      accountId: readString(json, 'accountId', context),
      status: readString(json, 'status', context),
      errorCode: readNullableString(json, 'errorCode', context),
      errorMessage: readNullableString(json, 'errorMessage', context),
    );
  }
}

class AutomationRunDetails {
  const AutomationRunDetails({
    required this.run,
    required this.accounts,
    required this.totalAccounts,
    required this.completedAccounts,
    required this.pendingAccounts,
  });

  final AutomationRun run;
  final List<AutomationRunAccountState> accounts;
  final int totalAccounts;
  final int completedAccounts;
  final int pendingAccounts;

  factory AutomationRunDetails.fromJson(Map<String, Object?> json) {
    final accounts = readList(json['accounts'], 'automationRunDetails.accounts')
        .map(
          (item) => AutomationRunAccountState.fromJson(
            readObject(item, 'automationRunDetails.accounts[]'),
          ),
        )
        .toList(growable: false);
    if (accounts.length > 10000) {
      throw const ApiSchemaException(
        'Automation run details exceed the native safety limit.',
      );
    }
    return AutomationRunDetails(
      run: AutomationRun.fromJson(
        readObject(json['run'], 'automationRunDetails.run'),
      ),
      accounts: accounts,
      totalAccounts: readInt(json, 'totalAccounts', 'automationRunDetails'),
      completedAccounts: readInt(
        json,
        'completedAccounts',
        'automationRunDetails',
      ),
      pendingAccounts: readInt(json, 'pendingAccounts', 'automationRunDetails'),
    );
  }
}

List<String> _readStringList(Object? value, String context) {
  return readList(value, context)
      .map((item) {
        if (item is! String) {
          throw ApiSchemaException('$context[] must be a string.');
        }
        return item;
      })
      .toList(growable: false);
}
