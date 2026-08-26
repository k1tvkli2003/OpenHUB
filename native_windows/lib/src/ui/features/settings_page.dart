import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/account_summary.dart';
import '../../models/dashboard_settings.dart';
import '../../models/storage_cleanup.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';
import '../formatters.dart';
import 'advanced_settings_sections.dart';
import 'codex_integration_panel.dart';
import 'feature_widgets.dart';

const _routingStrategies = <String, String>{
  'usage_weighted': 'Usage weighted',
  'round_robin': 'Round robin',
  'capacity_weighted': 'Capacity weighted',
  'relative_availability': 'Relative availability',
  'fill_first': 'Fill first',
  'sequential_drain': 'Sequential drain',
  'reset_drain': 'Reset drain',
  'single_account': 'Single account',
};

const _routingDescriptions = <String, String>{
  'usage_weighted':
      'Prefer accounts with more usable quota while spreading load.',
  'round_robin': 'Cycle evenly through eligible accounts.',
  'capacity_weighted': 'Weight selection by the account capacity estimate.',
  'relative_availability':
      'Bias toward the strongest relative remaining quota.',
  'fill_first': 'Use the fullest eligible account before moving onward.',
  'sequential_drain': 'Drain accounts in a stable sequence.',
  'reset_drain': 'Prioritize accounts by reset-window opportunity.',
  'single_account': 'Route only through one explicitly selected account.',
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _advancedExpanded = false;
  bool _cleanupExpanded = false;
  bool _proxyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.controller.settings;
    if (section.value == null && section.isBusy) {
      return const FeatureProgress(label: 'Loading local routing settings…');
    }
    if (section.value == null) {
      return FeatureFailure(
        title: 'Settings unavailable',
        error: section.error,
        onRetry: widget.controller.refreshSettings,
      );
    }
    final settings = section.value!;
    return CustomScrollView(
      key: const PageStorageKey<String>('settings-scroll'),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 14),
          sliver: SliverToBoxAdapter(
            child: FeaturePageHeader(
              eyebrow: 'LOCAL CONTROL PLANE',
              title: 'Routing and policy settings',
              detail:
                  'Control how the local backend selects accounts, protects access, retains activity, and preserves session affinity. These settings affect OpenHUB/openhub only unless a control explicitly says otherwise. Version ${settings.version} · fetched ${formatRelative(section.lastSuccessfulFetch)}',
              trailing: FeatureBadge(
                label: widget.controller.canWrite
                    ? 'admin writes enabled'
                    : 'read only',
                color: widget.controller.canWrite
                    ? AppPalette.green
                    : AppPalette.textMuted,
              ),
            ),
          ),
        ),
        if (section.isStale)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
            sliver: SliverToBoxAdapter(
              child: FeatureWarning(
                message:
                    'Showing the last successful settings snapshot. Refresh failed: ${featureErrorText(section.error)}',
              ),
            ),
          ),
        if (widget.controller.settingsActionError != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
            sliver: SliverToBoxAdapter(
              child: FeatureWarning(
                error: true,
                message:
                    'Settings update failed: ${featureErrorText(widget.controller.settingsActionError)}',
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(
            child: _RoutingPanel(
              controller: widget.controller,
              settings: settings,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(
            child: _TransportPanel(
              controller: widget.controller,
              settings: settings,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(
            child: _SecurityPanel(
              controller: widget.controller,
              settings: settings,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(
            child: CodexIntegrationInfoPanel(controller: widget.controller),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(
            child: _ResetCreditsPanel(
              controller: widget.controller,
              settings: settings,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(
            child: FeaturePanel(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: _cleanupExpanded,
                onExpansionChanged: (value) =>
                    setState(() => _cleanupExpanded = value),
                leading: const Icon(
                  Icons.cleaning_services_outlined,
                  color: AppPalette.cyan,
                ),
                title: const Text('Safe storage cleanup'),
                subtitle: const Text(
                  'Preview and select only OpenHUB-owned archives, diagnostics, and temporary files',
                ),
                children: <Widget>[
                  const Divider(height: 1),
                  _StorageCleanupPanel(controller: widget.controller),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(
            child: FeaturePanel(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: _advancedExpanded,
                onExpansionChanged: (value) =>
                    setState(() => _advancedExpanded = value),
                leading: const Icon(
                  Icons.tune_outlined,
                  color: AppPalette.cyan,
                ),
                title: const Text('Advanced runtime settings'),
                subtitle: const Text(
                  'Session bridges, warm-up, pacing, thresholds, and retention',
                ),
                children: <Widget>[
                  const Divider(height: 1),
                  _AdvancedSettings(
                    controller: widget.controller,
                    settings: settings,
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(
            child: FeaturePanel(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: _proxyExpanded,
                onExpansionChanged: (value) {
                  setState(() => _proxyExpanded = value);
                  if (value && widget.controller.upstreamProxy.value == null) {
                    unawaited(widget.controller.refreshUpstreamProxy());
                  }
                },
                leading: const Icon(Icons.lan_outlined, color: AppPalette.cyan),
                title: const Text('Upstream proxy routing'),
                subtitle: const Text(
                  'Loaded only when expanded; passwords never return from the backend',
                ),
                children: <Widget>[
                  const Divider(height: 1),
                  _UpstreamProxySettings(controller: widget.controller),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
          sliver: SliverToBoxAdapter(
            child: AdvancedAdminSections(controller: widget.controller),
          ),
        ),
      ],
    );
  }
}

class _RoutingPanel extends StatelessWidget {
  const _RoutingPanel({required this.controller, required this.settings});

  final AppController controller;
  final DashboardSettings settings;

  @override
  Widget build(BuildContext context) {
    final strategy = settings.routingStrategy;
    final accounts = controller.orderedAccounts(
      controller.accounts.value ?? const <AccountSummary>[],
    );
    final configuredAccount = settings.nullableStringValue('singleAccountId');
    final singleAccount =
        accounts.any((account) => account.accountId == configuredAccount)
        ? configuredAccount
        : null;
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionTitle(
            icon: Icons.alt_route,
            title: 'Account routing',
            detail: _routingDescriptions[strategy] ?? strategy,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('routing-$strategy'),
            initialValue: strategy,
            decoration: const InputDecoration(labelText: 'Routing strategy'),
            items: _routingStrategies.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(growable: false),
            onChanged: controller.canWrite && !controller.settingsActionBusy
                ? (value) {
                    if (value != null) {
                      unawaited(
                        controller.updateSettings(<String, Object?>{
                          'routingStrategy': value,
                        }),
                      );
                    }
                  }
                : null,
          ),
          if (strategy == 'single_account') ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey<String?>('single-$singleAccount'),
              initialValue: singleAccount,
              decoration: const InputDecoration(
                labelText: 'Pinned account',
                helperText: 'Required before single-account routing is useful.',
              ),
              items: accounts
                  .map(
                    (account) => DropdownMenuItem<String?>(
                      value: account.accountId,
                      child: Text(account.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: controller.canWrite && !controller.settingsActionBusy
                  ? (value) => unawaited(
                      controller.updateSettings(<String, Object?>{
                        'singleAccountId': value,
                      }),
                    )
                  : null,
            ),
          ],
          const SizedBox(height: 8),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'stickyThreadsEnabled',
            title: 'Sticky threads',
            subtitle:
                'Keep compatible conversation threads on the same account.',
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'preferEarlierResetAccounts',
            title: 'Prefer earlier resets',
            subtitle: 'Use reset timing as an additional routing signal.',
          ),
          if (settings.routingStrategy == 'relative_availability') ...<Widget>[
            _NumberSetting(
              controller: controller,
              settings: settings,
              keyName: 'relativeAvailabilityPower',
              title: 'Availability power',
              subtitle:
                  'Higher values increase preference for stronger accounts.',
              min: 0.1,
              decimal: true,
            ),
            _NumberSetting(
              controller: controller,
              settings: settings,
              keyName: 'relativeAvailabilityTopK',
              title: 'Top-K candidates',
              subtitle: 'Eligible candidates sampled per routing choice.',
              min: 1,
              max: 20,
            ),
          ],
        ],
      ),
    );
  }
}

class _TransportPanel extends StatelessWidget {
  const _TransportPanel({required this.controller, required this.settings});

  final AppController controller;
  final DashboardSettings settings;

  @override
  Widget build(BuildContext context) {
    final upstream = settings.stringValue('upstreamStreamTransport');
    final downstream = settings.stringValue('httpDownstreamTransportPolicy');
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle(
            icon: Icons.swap_vert_circle_outlined,
            title: 'Transport policy',
            detail:
                'Explicit upstream and downstream behavior; no hidden web defaults.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              final fields = <Widget>[
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('upstream-$upstream'),
                  initialValue: upstream,
                  decoration: const InputDecoration(
                    labelText: 'Upstream streaming transport',
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'default', child: Text('Default')),
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(value: 'http', child: Text('HTTP')),
                    DropdownMenuItem(
                      value: 'websocket',
                      child: Text('WebSocket'),
                    ),
                  ],
                  onChanged:
                      controller.canWrite && !controller.settingsActionBusy
                      ? (value) => value == null
                            ? null
                            : unawaited(
                                controller.updateSettings(<String, Object?>{
                                  'upstreamStreamTransport': value,
                                }),
                              )
                      : null,
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('downstream-$downstream'),
                  initialValue: downstream,
                  decoration: const InputDecoration(
                    labelText: 'HTTP downstream policy',
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'smart', child: Text('Smart')),
                    DropdownMenuItem(
                      value: 'always_http',
                      child: Text('Always HTTP'),
                    ),
                    DropdownMenuItem(
                      value: 'always_websocket',
                      child: Text('Always WebSocket'),
                    ),
                    DropdownMenuItem(value: 'pinned', child: Text('Pinned')),
                  ],
                  onChanged:
                      controller.canWrite && !controller.settingsActionBusy
                      ? (value) => value == null
                            ? null
                            : unawaited(
                                controller.updateSettings(<String, Object?>{
                                  'httpDownstreamTransportPolicy': value,
                                }),
                              )
                      : null,
                ),
              ];
              if (stacked) {
                return Column(
                  children: <Widget>[
                    fields[0],
                    const SizedBox(height: 12),
                    fields[1],
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: fields[0]),
                  const SizedBox(width: 12),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'prohibitFastMode',
            title: 'Prohibit fast mode',
            subtitle:
                'Reject fast/priority shortcuts even when requested by a client.',
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'proxyAccountResponseCreateLimit',
            title: 'Create-response concurrency',
            subtitle: 'Zero keeps the backend default behavior.',
            min: 0,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'proxyAccountStreamLimit',
            title: 'Per-account stream limit',
            subtitle: 'Maximum concurrent streams; zero means backend default.',
            min: 0,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'proxyAccountStreamRecoveryReserve',
            title: 'Stream recovery reserve',
            subtitle: 'Capacity held back for transport recovery.',
            min: 0,
          ),
        ],
      ),
    );
  }
}

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel({required this.controller, required this.settings});

  final AppController controller;
  final DashboardSettings settings;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle(
            icon: Icons.security_outlined,
            title: 'Access and import policy',
            detail: 'These switches never reveal stored account credentials.',
          ),
          const SizedBox(height: 8),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'apiKeyAuthEnabled',
            title: 'Require API-key authentication',
            subtitle: 'Protect proxy API routes with the local key policy.',
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'hideUpstreamQuotaFromApiKeys',
            title: 'Hide upstream quota from API keys',
            subtitle:
                'Do not expose aggregate provider quota to scoped clients.',
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'importWithoutOverwrite',
            title: 'Import without overwrite',
            subtitle: 'Preserve existing encrypted account rows during import.',
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'guestAccessEnabled',
            title: 'Read-only guest access',
            subtitle: settings.boolValue('guestPasswordConfigured')
                ? 'Guest access is protected by an existing password.'
                : 'Guest access currently has no configured password.',
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'totpRequiredOnLogin',
            title: 'Require TOTP after password login',
            subtitle: settings.boolValue('totpConfigured')
                ? 'Authenticator enrollment is configured.'
                : 'Unavailable until TOTP enrollment exists.',
            enabled: settings.boolValue('totpConfigured'),
          ),
          SecurityManagementActions(controller: controller),
        ],
      ),
    );
  }
}

class _ResetCreditsPanel extends StatelessWidget {
  const _ResetCreditsPanel({required this.controller, required this.settings});

  final AppController controller;
  final DashboardSettings settings;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle(
            icon: Icons.restart_alt,
            title: 'Reset-credit behavior',
            detail:
                'Visibility and expiry redemption controls for stored credits.',
          ),
          const SizedBox(height: 8),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'showResetCreditBadges',
            title: 'Show reset-credit badges',
            subtitle: 'Surface available credits on account rows.',
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'showResetCreditExpiryBadge',
            title: 'Show expiry warnings',
            subtitle: 'Highlight reset credits close to expiration.',
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'autoRedeemResetCreditsBeforeExpiry',
            title: 'Auto-redeem before expiry',
            subtitle:
                'Let the backend redeem eligible credits before they lapse.',
          ),
        ],
      ),
    );
  }
}

class _AdvancedSettings extends StatelessWidget {
  const _AdvancedSettings({required this.controller, required this.settings});

  final AppController controller;
  final DashboardSettings settings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'openaiCacheAffinityMaxAgeSeconds',
            title: 'Cache affinity max age',
            subtitle: 'Seconds before cache affinity is no longer reused.',
            min: 1,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'dashboardSessionTtlSeconds',
            title: 'Dashboard session TTL',
            subtitle: 'Minimum accepted value is one hour.',
            min: 3600,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'httpResponsesSessionBridgePromptCacheIdleTtlSeconds',
            title: 'HTTP bridge idle TTL',
            subtitle: 'Prompt-cache bridge lifetime in seconds.',
            min: 1,
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'httpResponsesSessionBridgeGatewaySafeMode',
            title: 'Gateway-safe session bridge',
            subtitle:
                'Use the conservative HTTP bridge path for gateway clients.',
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'stickyReallocationBudgetThresholdPct',
            title: 'Sticky reallocation threshold',
            subtitle: 'Overall remaining-budget percentage threshold.',
            min: 0,
            max: 100,
            decimal: true,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'stickyReallocationPrimaryBudgetThresholdPct',
            title: 'Primary-window reallocation threshold',
            subtitle: 'Primary remaining-budget percentage threshold.',
            min: 0,
            max: 100,
            decimal: true,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'stickyReallocationSecondaryBudgetThresholdPct',
            title: 'Secondary-window reallocation threshold',
            subtitle: 'Secondary remaining-budget percentage threshold.',
            min: 0,
            max: 100,
            decimal: true,
          ),
          const Divider(height: 24),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'limitWarmupEnabled',
            title: 'Limit warm-up scheduler',
            subtitle:
                'Run controlled background warm-up near quota thresholds.',
          ),
          _SettingSwitch(
            controller: controller,
            settings: settings,
            keyName: 'limitWarmupStaggeredIdleEnabled',
            title: 'Stagger idle warm-ups',
            subtitle:
                'Avoid bursts when several accounts become idle together.',
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'limitWarmupCooldownSeconds',
            title: 'Warm-up cooldown',
            subtitle: 'At least 60 seconds between eligible attempts.',
            min: 60,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'limitWarmupExhaustedThresholdPercent',
            title: 'Exhausted threshold',
            subtitle: 'Percentage that marks a quota window exhausted.',
            min: 0.1,
            max: 100,
            decimal: true,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'limitWarmupIdleThresholdPercent',
            title: 'Idle threshold',
            subtitle: 'Percentage threshold for idle warm-up eligibility.',
            min: 0.1,
            max: 100,
            decimal: true,
          ),
          _NumberSetting(
            controller: controller,
            settings: settings,
            keyName: 'limitWarmupMinAvailablePercent',
            title: 'Minimum available quota',
            subtitle: 'Do not warm accounts below this remaining percentage.',
            min: 0.1,
            max: 100,
            decimal: true,
          ),
          _ChoiceSetting(
            controller: controller,
            settings: settings,
            keyName: 'weeklyPaceSmoothingMinutes',
            title: 'Weekly pace smoothing',
            subtitle: 'Window used for quota pace calculations.',
            choices: const <int, String>{
              15: '15 minutes',
              30: '30 minutes',
              60: '1 hour',
              120: '2 hours',
              240: '4 hours',
            },
          ),
          const Divider(height: 24),
          _RetentionSetting(
            controller: controller,
            settings: settings,
            title: 'Request-log retention',
            effectiveKey: 'requestLogRetentionDays',
            overrideKey: 'requestLogRetentionOverrideDays',
            minimumNonZero: 30,
          ),
          _RetentionSetting(
            controller: controller,
            settings: settings,
            title: 'Usage-history retention',
            effectiveKey: 'usageHistoryRetentionDays',
            overrideKey: 'usageHistoryRetentionOverrideDays',
            minimumNonZero: 45,
          ),
        ],
      ),
    );
  }
}

class _StorageCleanupPanel extends StatefulWidget {
  const _StorageCleanupPanel({required this.controller});

  final AppController controller;

  @override
  State<_StorageCleanupPanel> createState() => _StorageCleanupPanelState();
}

class _StorageCleanupPanelState extends State<_StorageCleanupPanel> {
  final TextEditingController _days = TextEditingController(text: '30');
  final Set<StorageCleanupCategory> _selected = <StorageCleanupCategory>{
    StorageCleanupCategory.conversationArchives,
    StorageCleanupCategory.debugDumps,
    StorageCleanupCategory.temporaryFiles,
  };

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final preview = controller.storageCleanupPreview;
    final result = controller.lastStorageCleanupResult;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Runtime task databases, pinned chats, skills, memories, account credentials, and active files are always excluded.',
            style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StorageCleanupCategory.values
                .map(
                  (category) => FilterChip(
                    label: Text(category.label),
                    selected: _selected.contains(category),
                    onSelected: controller.storageCleanupActionBusy
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _selected.add(category);
                            } else {
                              _selected.remove(category);
                            }
                            controller.storageCleanupPreview = null;
                          }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  enabled: !controller.storageCleanupActionBusy,
                  decoration: const InputDecoration(
                    labelText: 'Older than days',
                    helperText: '1–3650 days',
                  ),
                  onChanged: (_) => controller.storageCleanupPreview = null,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton.icon(
                  onPressed:
                      controller.canWrite &&
                          !controller.storageCleanupActionBusy &&
                          _selected.isNotEmpty &&
                          _validDays != null
                      ? () => unawaited(_preview())
                      : null,
                  icon: controller.storageCleanupActionBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_outlined),
                  label: const Text('Preview cleanup'),
                ),
              ),
            ],
          ),
          if (controller.storageCleanupActionError != null) ...<Widget>[
            const SizedBox(height: 12),
            FeatureWarning(
              error: true,
              message: featureErrorText(controller.storageCleanupActionError),
            ),
          ],
          if (preview != null) ...<Widget>[
            const Divider(height: 26),
            Text(
              preview.fileCount == 0
                  ? 'Nothing eligible in the selected categories.'
                  : '${preview.fileCount} files · ${_formatStorageBytes(preview.totalBytes)} eligible',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 5),
            Text(
              'Cutoff ${preview.cutoff.toLocal()} · exact file list is revalidated before deletion.',
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
            ),
            if (preview.candidates.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppPalette.outline),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: preview.candidates.length,
                  itemBuilder: (context, index) {
                    final item = preview.candidates[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${item.relativePath} · ${_formatStorageBytes(item.sizeBytes)}',
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: controller.storageCleanupActionBusy
                    ? null
                    : () => unawaited(_confirmAndApply(preview)),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text('Delete ${preview.fileCount} reviewed files'),
              ),
            ],
          ],
          if (result != null) ...<Widget>[
            const SizedBox(height: 12),
            FeatureWarning(
              message:
                  'Cleanup removed ${result.deletedFiles} files (${_formatStorageBytes(result.deletedBytes)}). ${result.skippedFiles} changed or unavailable files were safely skipped.',
            ),
          ],
        ],
      ),
    );
  }

  int? get _validDays {
    final value = int.tryParse(_days.text.trim());
    return value != null && value >= 1 && value <= 3650 ? value : null;
  }

  List<StorageCleanupCategory> get _categories =>
      _selected.toList(growable: false)
        ..sort((left, right) => left.index.compareTo(right.index));

  Future<void> _preview() async {
    await widget.controller.previewStorageCleanup(
      categories: _categories,
      olderThanDays: _validDays!,
    );
  }

  Future<void> _confirmAndApply(StorageCleanupPreview preview) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reviewed OpenHUB files?'),
        content: Text(
          'Delete exactly ${preview.fileCount} files totaling ${_formatStorageBytes(preview.totalBytes)}? '
          'Runtime task stores, chats, skills, memories, and credentials are not included. '
          'If any candidate changed after preview, OpenHUB refuses the operation and asks for a new preview.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete reviewed files'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.controller.applyStorageCleanup(
      categories: _categories,
      olderThanDays: preview.olderThanDays,
      confirmationToken: preview.confirmationToken,
    );
  }
}

String _formatStorageBytes(int value) {
  if (value < 1024) return '$value B';
  const units = <String>['KiB', 'MiB', 'GiB', 'TiB'];
  var amount = value.toDouble();
  var unit = -1;
  do {
    amount /= 1024;
    unit += 1;
  } while (amount >= 1024 && unit < units.length - 1);
  return '${amount.toStringAsFixed(amount >= 10 ? 1 : 2)} ${units[unit]}';
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.controller,
    required this.settings,
    required this.keyName,
    required this.title,
    required this.subtitle,
    this.enabled = true,
  });

  final AppController controller;
  final DashboardSettings settings;
  final String keyName;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: settings.boolValue(keyName),
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged:
          enabled && controller.canWrite && !controller.settingsActionBusy
          ? (value) => unawaited(
              controller.updateSettings(<String, Object?>{keyName: value}),
            )
          : null,
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.controller,
    required this.settings,
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.min,
    this.max,
    this.decimal = false,
  });

  final AppController controller;
  final DashboardSettings settings;
  final String keyName;
  final String title;
  final String subtitle;
  final num min;
  final num? max;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final value = decimal
        ? settings.numberValue(keyName)
        : settings.intValue(keyName);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: OutlinedButton(
        onPressed: controller.canWrite && !controller.settingsActionBusy
            ? () => unawaited(_edit(context, value))
            : null,
        child: Text(decimal ? value.toStringAsFixed(1) : value.toString()),
      ),
    );
  }

  Future<void> _edit(BuildContext context, num current) async {
    final text = TextEditingController(text: current.toString());
    final formKey = GlobalKey<FormState>();
    final next = await showDialog<num>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: text,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              helperText: max == null
                  ? 'Minimum $min'
                  : 'Allowed range: $min–$max',
            ),
            validator: (raw) {
              final parsed = decimal
                  ? double.tryParse(raw ?? '')
                  : int.tryParse(raw ?? '');
              if (parsed == null) {
                return decimal ? 'Enter a number.' : 'Enter a whole number.';
              }
              if (parsed < min || (max != null && parsed > max!)) {
                return max == null
                    ? 'Minimum is $min.'
                    : 'Use a value from $min to $max.';
              }
              return null;
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(
                  context,
                  decimal ? double.parse(text.text) : int.parse(text.text),
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    text.dispose();
    if (next != null) {
      await controller.updateSettings(<String, Object?>{keyName: next});
    }
  }
}

class _ChoiceSetting extends StatelessWidget {
  const _ChoiceSetting({
    required this.controller,
    required this.settings,
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.choices,
  });

  final AppController controller;
  final DashboardSettings settings;
  final String keyName;
  final String title;
  final String subtitle;
  final Map<int, String> choices;

  @override
  Widget build(BuildContext context) {
    final value = settings.intValue(keyName);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<int>(
        value: value,
        items: choices.entries
            .map(
              (entry) => DropdownMenuItem<int>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(growable: false),
        onChanged: controller.canWrite && !controller.settingsActionBusy
            ? (next) => next == null
                  ? null
                  : unawaited(
                      controller.updateSettings(<String, Object?>{
                        keyName: next,
                      }),
                    )
            : null,
      ),
    );
  }
}

class _RetentionSetting extends StatelessWidget {
  const _RetentionSetting({
    required this.controller,
    required this.settings,
    required this.title,
    required this.effectiveKey,
    required this.overrideKey,
    required this.minimumNonZero,
  });

  final AppController controller;
  final DashboardSettings settings;
  final String title;
  final String effectiveKey;
  final String overrideKey;
  final int minimumNonZero;

  @override
  Widget build(BuildContext context) {
    final effective = settings.intValue(effectiveKey);
    final override = settings.nullableIntValue(overrideKey);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        override == null
            ? 'Effective $effective days · inherited setting'
            : override == 0
            ? 'Retention disabled by local override'
            : '$override-day local override',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (override != null)
            IconButton(
              tooltip: 'Return to inherited value',
              onPressed: controller.canWrite && !controller.settingsActionBusy
                  ? () => unawaited(
                      controller.updateSettings(<String, Object?>{
                        overrideKey: null,
                      }),
                    )
                  : null,
              icon: const Icon(Icons.undo),
            ),
          OutlinedButton(
            onPressed: controller.canWrite && !controller.settingsActionBusy
                ? () => unawaited(_edit(context, override ?? effective))
                : null,
            child: Text(override?.toString() ?? 'Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, int current) async {
    final text = TextEditingController(text: current.toString());
    final formKey = GlobalKey<FormState>();
    final next = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: text,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Days',
              helperText: 'Use 0 to disable, or at least $minimumNonZero days.',
            ),
            validator: (raw) {
              final parsed = int.tryParse(raw ?? '');
              if (parsed == null || parsed < 0) {
                return 'Enter zero or a positive whole number.';
              }
              if (parsed != 0 && parsed < minimumNonZero) {
                return 'Use 0 or at least $minimumNonZero.';
              }
              return null;
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, int.parse(text.text));
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    text.dispose();
    if (next != null) {
      await controller.updateSettings(<String, Object?>{overrideKey: next});
    }
  }
}

class _UpstreamProxySettings extends StatelessWidget {
  const _UpstreamProxySettings({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final section = controller.upstreamProxy;
    if (section.value == null && section.isBusy) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: FeatureProgress(label: 'Loading proxy topology…'),
      );
    }
    if (section.value == null) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: FeatureFailure(
          title: 'Proxy topology unavailable',
          error: section.error,
          onRetry: controller.refreshUpstreamProxy,
        ),
      );
    }
    final admin = section.value!;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (controller.proxyActionError != null) ...<Widget>[
            FeatureWarning(
              error: true,
              message: featureErrorText(controller.proxyActionError),
            ),
            const SizedBox(height: 12),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: admin.routingEnabled,
            title: const Text('Enable upstream proxy routing'),
            subtitle: const Text(
              'Only configured account bindings or the default pool are used.',
            ),
            onChanged: controller.canWrite && !controller.settingsActionBusy
                ? (value) => unawaited(
                    controller
                        .updateSettings(<String, Object?>{
                          'upstreamProxyRoutingEnabled': value,
                        })
                        .then((_) => controller.refreshUpstreamProxy()),
                  )
                : null,
          ),
          DropdownButtonFormField<String?>(
            key: ValueKey<String?>('proxy-default-${admin.defaultPoolId}'),
            initialValue: admin.defaultPoolId,
            decoration: const InputDecoration(labelText: 'Default proxy pool'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No default pool'),
              ),
              ...admin.pools.map(
                (pool) => DropdownMenuItem<String?>(
                  value: pool.id,
                  child: Text(pool.name),
                ),
              ),
            ],
            onChanged: controller.canWrite && !controller.settingsActionBusy
                ? (value) => unawaited(
                    controller
                        .updateSettings(<String, Object?>{
                          'upstreamProxyDefaultPoolId': value,
                        })
                        .then((_) => controller.refreshUpstreamProxy()),
                  )
                : null,
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Text('Endpoints', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: controller.canWrite
                    ? () => unawaited(_createEndpoint(context))
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Endpoint'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (admin.endpoints.isEmpty)
            const Text('No upstream endpoints configured.')
          else
            for (final endpoint in admin.endpoints)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.dns_outlined,
                  color: endpoint.isActive
                      ? AppPalette.green
                      : AppPalette.textMuted,
                ),
                title: Text(endpoint.name),
                subtitle: Text(
                  '${endpoint.scheme}://${endpoint.host}:${endpoint.port}'
                  '${endpoint.username == null ? '' : ' · authenticated'}',
                ),
                trailing: OutlinedButton(
                  onPressed: controller.canWrite && !controller.proxyActionBusy
                      ? () => unawaited(_testEndpoint(context, endpoint))
                      : null,
                  child: const Text('Test'),
                ),
              ),
          const Divider(height: 24),
          Row(
            children: <Widget>[
              Text('Pools', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: controller.canWrite && admin.endpoints.isNotEmpty
                    ? () => unawaited(_createPool(context, admin))
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Pool'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (admin.pools.isEmpty)
            const Text('No proxy pools configured.')
          else
            for (final pool in admin.pools)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.hub_outlined,
                  color: pool.isActive ? AppPalette.cyan : AppPalette.textMuted,
                ),
                title: Text(pool.name),
                subtitle: Text('${pool.endpointIds.length} endpoints'),
                trailing: FeatureBadge(
                  label: pool.id == admin.defaultPoolId
                      ? 'default'
                      : 'available',
                  color: pool.id == admin.defaultPoolId
                      ? AppPalette.green
                      : AppPalette.textMuted,
                ),
              ),
          if (admin.pools.isNotEmpty &&
              (controller.accounts.value?.isNotEmpty ?? false)) ...<Widget>[
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: controller.canWrite
                    ? () => unawaited(_bindAccount(context, admin))
                    : null,
                icon: const Icon(Icons.link),
                label: const Text('Bind account to pool'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createEndpoint(BuildContext context) async {
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => const _ProxyEndpointDialog(),
    );
    if (payload != null) {
      await controller.createUpstreamProxyEndpoint(payload);
    }
  }

  Future<void> _testEndpoint(
    BuildContext context,
    UpstreamProxyEndpoint endpoint,
  ) async {
    final result = await controller.testUpstreamProxyEndpoint(endpoint.id);
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.ok
                ? '${endpoint.name} reachable in ${result.elapsedMs ?? 0} ms (HTTP ${result.statusCode ?? 'n/a'}).'
                : '${endpoint.name} failed: ${result.error ?? 'unknown error'}.',
          ),
        ),
      );
    }
  }

  Future<void> _createPool(
    BuildContext context,
    UpstreamProxyAdmin admin,
  ) async {
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _ProxyPoolDialog(endpoints: admin.endpoints),
    );
    if (payload != null) {
      await controller.createUpstreamProxyPool(payload);
    }
  }

  Future<void> _bindAccount(
    BuildContext context,
    UpstreamProxyAdmin admin,
  ) async {
    final value = await showDialog<(String, String)>(
      context: context,
      builder: (context) =>
          _ProxyBindingDialog(controller: controller, pools: admin.pools),
    );
    if (value != null) {
      await controller.putAccountProxyBinding(value.$1, value.$2);
    }
  }
}

class _ProxyEndpointDialog extends StatefulWidget {
  const _ProxyEndpointDialog();

  @override
  State<_ProxyEndpointDialog> createState() => _ProxyEndpointDialogState();
}

class _ProxyEndpointDialogState extends State<_ProxyEndpointDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8080');
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _scheme = 'http';

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add upstream endpoint'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _scheme,
                      decoration: const InputDecoration(labelText: 'Scheme'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'http', child: Text('HTTP')),
                        DropdownMenuItem(value: 'https', child: Text('HTTPS')),
                        DropdownMenuItem(
                          value: 'socks5',
                          child: Text('SOCKS5'),
                        ),
                        DropdownMenuItem(
                          value: 'socks5h',
                          child: Text('SOCKS5H'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _scheme = value ?? 'http'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _host,
                      decoration: const InputDecoration(labelText: 'Host'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port'),
                      validator: (value) {
                        final port = int.tryParse(value ?? '');
                        return port == null || port < 1 || port > 65535
                            ? '1–65535'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Username (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password (optional)',
                  helperText:
                      'Sent over loopback and stored encrypted; never returned.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState?.validate() ?? false) {
              Navigator.pop(context, <String, Object?>{
                'name': _name.text.trim(),
                'scheme': _scheme,
                'host': _host.text.trim(),
                'port': int.parse(_port.text),
                if (_username.text.trim().isNotEmpty)
                  'username': _username.text.trim(),
                if (_password.text.isNotEmpty) 'password': _password.text,
                'isActive': true,
              });
            }
          },
          child: const Text('Add endpoint'),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _ProxyPoolDialog extends StatefulWidget {
  const _ProxyPoolDialog({required this.endpoints});

  final List<UpstreamProxyEndpoint> endpoints;

  @override
  State<_ProxyPoolDialog> createState() => _ProxyPoolDialogState();
}

class _ProxyPoolDialogState extends State<_ProxyPoolDialog> {
  final _name = TextEditingController();
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create proxy pool'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Pool name'),
            ),
            const SizedBox(height: 14),
            const Text('Initial endpoints'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: widget.endpoints
                  .map(
                    (endpoint) => FilterChip(
                      label: Text(endpoint.name),
                      selected: _selected.contains(endpoint.id),
                      onSelected: (selected) => setState(() {
                        selected
                            ? _selected.add(endpoint.id)
                            : _selected.remove(endpoint.id);
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, <String, Object?>{
                  'name': _name.text.trim(),
                  'endpointIds': _selected.toList(growable: false),
                  'isActive': true,
                }),
          child: const Text('Create pool'),
        ),
      ],
    );
  }
}

class _ProxyBindingDialog extends StatefulWidget {
  const _ProxyBindingDialog({required this.controller, required this.pools});

  final AppController controller;
  final List<UpstreamProxyPool> pools;

  @override
  State<_ProxyBindingDialog> createState() => _ProxyBindingDialogState();
}

class _ProxyBindingDialogState extends State<_ProxyBindingDialog> {
  String? _accountId;
  String? _poolId;

  @override
  Widget build(BuildContext context) {
    final accounts = widget.controller.orderedAccounts(
      widget.controller.accounts.value ?? const <AccountSummary>[],
    );
    return AlertDialog(
      title: const Text('Bind account to proxy pool'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: accounts
                  .map(
                    (account) => DropdownMenuItem<String>(
                      value: account.accountId,
                      child: Text(account.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _poolId,
              decoration: const InputDecoration(labelText: 'Pool'),
              items: widget.pools
                  .map(
                    (pool) => DropdownMenuItem<String>(
                      value: pool.id,
                      child: Text(pool.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _poolId = value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _accountId == null || _poolId == null
              ? null
              : () => Navigator.pop(context, (_accountId!, _poolId!)),
          child: const Text('Bind account'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: AppPalette.cyan),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
