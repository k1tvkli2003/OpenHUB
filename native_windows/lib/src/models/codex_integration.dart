import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

class CodexProfileDefinition {
  const CodexProfileDefinition({
    required this.id,
    required this.label,
    required this.kind,
    required this.modelProvider,
    required this.model,
    required this.wireApi,
    required this.catalogSource,
    required this.accountRouting,
    required this.builtin,
    this.baseUrl,
    this.catalogUri,
    this.bridgeUri,
    this.contextWindow,
  });

  final String id;
  final String label;
  final String kind;
  final String modelProvider;
  final String model;
  final String wireApi;
  final String? baseUrl;
  final String catalogSource;
  final String? catalogUri;
  final String? bridgeUri;
  final int? contextWindow;
  final String accountRouting;
  final bool builtin;

  factory CodexProfileDefinition.fromJson(Map<String, Object?> json) {
    const context = 'codexProfiles.profiles[]';
    final id = readString(json, 'id', context);
    final label = readString(json, 'label', context);
    final kind = readString(json, 'kind', context);
    final modelProvider = readString(json, 'modelProvider', context);
    final model = readString(json, 'model', context);
    final wireApi = readString(json, 'wireApi', context);
    final baseUrl = readNullableString(json, 'baseUrl', context);
    final catalogSource = readString(json, 'catalogSource', context);
    final catalogUri = readNullableString(json, 'catalogUri', context);
    final bridgeUri = readNullableString(json, 'bridgeUri', context);
    final contextWindow = _readNullableInteger(json, 'contextWindow', context);
    final accountRouting = readString(json, 'accountRouting', context);
    if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$').hasMatch(id) ||
        label.isEmpty ||
        label.length > 80 ||
        !const <String>{'openai_pool', 'ox', 'custom'}.contains(kind) ||
        modelProvider.isEmpty ||
        modelProvider.length > 128 ||
        model.isEmpty ||
        model.length > 256 ||
        !const <String>{'responses', 'chat_completions'}.contains(wireApi) ||
        !const <String>{
          'live_managed',
          'bundled',
          'none',
        }.contains(catalogSource) ||
        !const <String>{
          'automatic',
          'manual',
          'none',
        }.contains(accountRouting) ||
        (contextWindow != null &&
            (contextWindow < 4096 || contextWindow > 4000000))) {
      throw const ApiSchemaException('Codex profile definition is invalid.');
    }
    if (baseUrl != null) {
      final uri = Uri.tryParse(baseUrl);
      if (uri == null ||
          !uri.hasAuthority ||
          !const <String>{'http', 'https'}.contains(uri.scheme) ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.scheme == 'http' &&
              !const <String>{'127.0.0.1', '::1'}.contains(uri.host))) {
        throw const ApiSchemaException('Codex profile endpoint is invalid.');
      }
    }
    for (final assetUri in <String?>[catalogUri, bridgeUri]) {
      if (assetUri != null &&
          (!assetUri.startsWith('asset://') &&
              !assetUri.startsWith('profile://'))) {
        throw const ApiSchemaException('Codex profile asset URI is invalid.');
      }
    }
    return CodexProfileDefinition(
      id: id,
      label: label,
      kind: kind,
      modelProvider: modelProvider,
      model: model,
      wireApi: wireApi,
      baseUrl: baseUrl,
      catalogSource: catalogSource,
      catalogUri: catalogUri,
      bridgeUri: bridgeUri,
      contextWindow: contextWindow,
      accountRouting: accountRouting,
      builtin: readBool(json, 'builtin', context),
    );
  }
}

class CodexProfileRegistry {
  const CodexProfileRegistry({
    required this.statePath,
    required this.revision,
    required this.activeProfileId,
    required this.profiles,
    required this.changed,
  });

  final String statePath;
  final int revision;
  final String activeProfileId;
  final List<CodexProfileDefinition> profiles;
  final bool changed;

  CodexProfileDefinition get activeProfile =>
      profiles.firstWhere((profile) => profile.id == activeProfileId);

  factory CodexProfileRegistry.fromJson(Map<String, Object?> json) {
    const context = 'codexProfiles';
    final revision = readInt(json, 'revision', context);
    final activeProfileId = readString(json, 'activeProfileId', context);
    final profiles = readList(json['profiles'], '$context.profiles')
        .map(
          (item) => CodexProfileDefinition.fromJson(
            readObject(item, '$context.profiles[]'),
          ),
        )
        .toList(growable: false);
    if (revision < 0 ||
        profiles.isEmpty ||
        profiles.length > 64 ||
        profiles.map((profile) => profile.id).toSet().length !=
            profiles.length ||
        !profiles.any((profile) => profile.id == activeProfileId)) {
      throw const ApiSchemaException('Codex profile registry is invalid.');
    }
    return CodexProfileRegistry(
      statePath: readString(json, 'statePath', context),
      revision: revision,
      activeProfileId: activeProfileId,
      profiles: List<CodexProfileDefinition>.unmodifiable(profiles),
      changed: readBool(json, 'changed', context),
    );
  }
}

class CodexIntegrationStatus {
  const CodexIntegrationStatus({
    required this.statePath,
    required this.enabled,
    required this.revision,
    required this.managedBaseUrl,
    required this.toggledAt,
    required this.codexStatePolicy,
  });

  final String statePath;
  final bool enabled;
  final int revision;
  final String managedBaseUrl;
  final DateTime? toggledAt;
  final String codexStatePolicy;

  factory CodexIntegrationStatus.fromJson(Map<String, Object?> json) {
    const context = 'codexIntegration';
    final statePath = readString(json, 'statePath', context);
    final managedBaseUrl = readString(json, 'managedBaseUrl', context);
    final revision = readInt(json, 'revision', context);
    final policy = readString(json, 'codexStatePolicy', context);
    final managedUri = Uri.tryParse(managedBaseUrl);
    if (statePath.isEmpty ||
        statePath.length > 32768 ||
        revision < 0 ||
        policy != 'never_mutate' ||
        managedUri == null ||
        managedUri.scheme != 'http' ||
        !managedUri.hasPort ||
        managedUri.userInfo.isNotEmpty ||
        managedUri.path != '/backend-api/codex-managed/v1') {
      throw const ApiSchemaException(
        'OpenHUB managed-launch status is invalid.',
      );
    }
    return CodexIntegrationStatus(
      statePath: statePath,
      enabled: readBool(json, 'enabled', context),
      revision: revision,
      managedBaseUrl: managedBaseUrl,
      toggledAt: readNullableDateTime(json, 'toggledAt', context),
      codexStatePolicy: policy,
    );
  }
}

class CodexIntegrationMutation {
  const CodexIntegrationMutation({required this.status, required this.changed});

  final CodexIntegrationStatus status;
  final bool changed;

  factory CodexIntegrationMutation.fromJson(Map<String, Object?> json) {
    return CodexIntegrationMutation(
      status: CodexIntegrationStatus.fromJson(json),
      changed: readBool(json, 'changed', 'codexIntegration.mutation'),
    );
  }
}

class CodexLaunchRoute {
  const CodexLaunchRoute({
    required this.prepared,
    required this.selectionMode,
    required this.accountId,
    required this.accountLabel,
    required this.accountEmail,
    required this.planType,
    required this.effectiveRemainingPercent,
    required this.primaryRemainingPercent,
    required this.secondaryRemainingPercent,
    required this.monthlyRemainingPercent,
    required this.limitingRemainingCredits,
    required this.sampledAt,
    required this.preparedAt,
    required this.revision,
  });

  final bool prepared;
  final String? selectionMode;
  final String? accountId;
  final String? accountLabel;
  final String? accountEmail;
  final String? planType;
  final double? effectiveRemainingPercent;
  final double? primaryRemainingPercent;
  final double? secondaryRemainingPercent;
  final double? monthlyRemainingPercent;
  final double? limitingRemainingCredits;
  final DateTime? sampledAt;
  final DateTime? preparedAt;
  final int revision;

  factory CodexLaunchRoute.fromJson(Map<String, Object?> json) {
    const context = 'codexLaunch.route';
    final prepared = readBool(json, 'prepared', context);
    final selectionMode = readNullableString(json, 'selectionMode', context);
    final accountId = readNullableString(json, 'accountId', context);
    final revision = readInt(json, 'revision', context);
    if (revision < 0 ||
        (prepared &&
            (accountId == null ||
                accountId.isEmpty ||
                !const <String>{'auto', 'manual'}.contains(selectionMode))) ||
        (!prepared && selectionMode != null)) {
      throw const ApiSchemaException('Codex launch route is invalid.');
    }
    return CodexLaunchRoute(
      prepared: prepared,
      selectionMode: selectionMode,
      accountId: accountId,
      accountLabel: readNullableString(json, 'accountLabel', context),
      accountEmail: readNullableString(json, 'accountEmail', context),
      planType: readNullableString(json, 'planType', context),
      effectiveRemainingPercent: _readPercent(
        json,
        'effectiveRemainingPercent',
        context,
      ),
      primaryRemainingPercent: _readPercent(
        json,
        'primaryRemainingPercent',
        context,
      ),
      secondaryRemainingPercent: _readPercent(
        json,
        'secondaryRemainingPercent',
        context,
      ),
      monthlyRemainingPercent: _readPercent(
        json,
        'monthlyRemainingPercent',
        context,
      ),
      limitingRemainingCredits: _readNonNegative(
        json,
        'limitingRemainingCredits',
        context,
      ),
      sampledAt: readNullableDateTime(json, 'sampledAt', context),
      preparedAt: readNullableDateTime(json, 'preparedAt', context),
      revision: revision,
    );
  }
}

class CodexLaunchCandidate {
  const CodexLaunchCandidate({
    required this.accountId,
    required this.accountLabel,
    required this.accountEmail,
    required this.planType,
    required this.effectiveRemainingPercent,
    required this.primaryRemainingPercent,
    required this.secondaryRemainingPercent,
    required this.monthlyRemainingPercent,
    required this.limitingRemainingCredits,
    required this.sampledAt,
  });

  final String accountId;
  final String accountLabel;
  final String accountEmail;
  final String planType;
  final double effectiveRemainingPercent;
  final double? primaryRemainingPercent;
  final double? secondaryRemainingPercent;
  final double? monthlyRemainingPercent;
  final double? limitingRemainingCredits;
  final DateTime sampledAt;

  factory CodexLaunchCandidate.fromJson(Map<String, Object?> json) {
    const context = 'codexLaunch.candidates[]';
    final sampledAt = readNullableDateTime(json, 'sampledAt', context);
    final effective = _readPercent(json, 'effectiveRemainingPercent', context);
    final primary = _readPercent(json, 'primaryRemainingPercent', context);
    if (sampledAt == null || effective == null) {
      throw const ApiSchemaException('Codex launch candidate is incomplete.');
    }
    return CodexLaunchCandidate(
      accountId: readString(json, 'accountId', context),
      accountLabel: readString(json, 'accountLabel', context),
      accountEmail: readString(json, 'accountEmail', context),
      planType: readString(json, 'planType', context),
      effectiveRemainingPercent: effective,
      primaryRemainingPercent: primary,
      secondaryRemainingPercent: _readPercent(
        json,
        'secondaryRemainingPercent',
        context,
      ),
      monthlyRemainingPercent: _readPercent(
        json,
        'monthlyRemainingPercent',
        context,
      ),
      limitingRemainingCredits: _readNonNegative(
        json,
        'limitingRemainingCredits',
        context,
      ),
      sampledAt: sampledAt,
    );
  }
}

class CodexLaunchExclusion {
  const CodexLaunchExclusion({
    required this.accountId,
    required this.accountLabel,
    required this.reason,
  });

  final String accountId;
  final String accountLabel;
  final String reason;

  factory CodexLaunchExclusion.fromJson(Map<String, Object?> json) {
    const context = 'codexLaunch.exclusions[]';
    return CodexLaunchExclusion(
      accountId: readString(json, 'accountId', context),
      accountLabel: readString(json, 'accountLabel', context),
      reason: readString(json, 'reason', context),
    );
  }
}

class CodexLaunchPreparation {
  const CodexLaunchPreparation({
    required this.readyToLaunch,
    required this.changed,
    required this.route,
    required this.candidates,
    required this.exclusions,
  });

  final bool readyToLaunch;
  final bool changed;
  final CodexLaunchRoute route;
  final List<CodexLaunchCandidate> candidates;
  final List<CodexLaunchExclusion> exclusions;

  factory CodexLaunchPreparation.fromJson(Map<String, Object?> json) {
    const context = 'codexLaunch';
    final candidates = readList(json['candidates'], '$context.candidates')
        .map(
          (item) => CodexLaunchCandidate.fromJson(
            readObject(item, '$context.candidates[]'),
          ),
        )
        .toList(growable: false);
    final exclusions = readList(json['exclusions'], '$context.exclusions')
        .map(
          (item) => CodexLaunchExclusion.fromJson(
            readObject(item, '$context.exclusions[]'),
          ),
        )
        .toList(growable: false);
    if (candidates.length > 500 || exclusions.length > 500) {
      throw const ApiSchemaException(
        'Codex launch evidence exceeds native safety limits.',
      );
    }
    return CodexLaunchPreparation(
      readyToLaunch: readBool(json, 'readyToLaunch', context),
      changed: readBool(json, 'changed', context),
      route: CodexLaunchRoute.fromJson(
        readObject(json['route'], '$context.route'),
      ),
      candidates: candidates,
      exclusions: exclusions,
    );
  }
}

double? _readPercent(Map<String, Object?> json, String key, String context) {
  final value = readNullableNumber(json, key, context)?.toDouble();
  if (value != null && (!value.isFinite || value < 0 || value > 100)) {
    throw ApiSchemaException('$context.$key must be between 0 and 100.');
  }
  return value;
}

int? _readNullableInteger(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final raw = json[key];
  if (raw == null) {
    return null;
  }
  if (raw is! int) {
    throw ApiSchemaException('$context.$key must be an integer or null.');
  }
  return raw;
}

double? _readNonNegative(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = readNullableNumber(json, key, context)?.toDouble();
  if (value != null && (!value.isFinite || value < 0)) {
    throw ApiSchemaException('$context.$key must be non-negative.');
  }
  return value;
}
