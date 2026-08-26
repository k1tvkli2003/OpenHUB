import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/account_summary.dart';
import '../../models/advanced_settings.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';
import '../formatters.dart';
import 'feature_widgets.dart';

class SecurityManagementActions extends StatelessWidget {
  const SecurityManagementActions({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final auth = controller.auth.value;
    if (auth == null || !auth.passwordManagementEnabled) {
      return const SizedBox.shrink();
    }
    final busy = controller.authActionBusy || !controller.canWrite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 24),
        if (controller.authActionError != null) ...<Widget>[
          FeatureWarning(
            error: true,
            message:
                'Access-control action failed: ${featureErrorText(controller.authActionError)}',
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => unawaited(
                      auth.passwordRequired
                          ? _changePassword(context)
                          : _setupPassword(context),
                    ),
              icon: Icon(
                auth.passwordRequired
                    ? Icons.password_outlined
                    : Icons.lock_outline,
              ),
              label: Text(
                auth.passwordRequired ? 'Change password' : 'Set password',
              ),
            ),
            if (auth.passwordRequired)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => unawaited(_removePassword(context)),
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Remove password'),
              ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => unawaited(_setGuestPassword(context)),
              icon: const Icon(Icons.person_outline),
              label: Text(
                auth.guestPasswordRequired
                    ? 'Change guest password'
                    : 'Protect guest access',
              ),
            ),
            if (auth.guestPasswordRequired)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => unawaited(_removeGuestPassword(context)),
                icon: const Icon(Icons.person_off_outlined),
                label: const Text('Remove guest password'),
              ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => unawaited(
                      auth.totpConfigured
                          ? _disableTotp(context)
                          : _setupTotp(context),
                    ),
              icon: const Icon(Icons.phonelink_lock_outlined),
              label: Text(auth.totpConfigured ? 'Disable TOTP' : 'Enroll TOTP'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Passwords and authenticator secrets are submitted only to the loopback service and are never persisted by the native UI.',
          style: TextStyle(color: AppPalette.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _setupPassword(BuildContext context) async {
    final auth = controller.auth.value;
    final result = await _showPasswordEditor(
      context,
      title: 'Set dashboard password',
      bootstrapRequired: auth?.bootstrapRequired ?? false,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final ok = await controller.setupDashboardPassword(
      result.newPassword,
      bootstrapToken: result.bootstrapToken,
    );
    if (context.mounted) {
      _notifyResult(context, ok, 'Dashboard password configured.');
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final result = await _showPasswordEditor(
      context,
      title: 'Change dashboard password',
      currentRequired: true,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final ok = await controller.changeDashboardPassword(
      result.currentPassword!,
      result.newPassword,
    );
    if (context.mounted) {
      _notifyResult(context, ok, 'Dashboard password changed.');
    }
  }

  Future<void> _removePassword(BuildContext context) async {
    final password = await _showSecretPrompt(
      context,
      title: 'Remove dashboard password?',
      label: 'Current password',
      detail:
          'This removes password protection from the local dashboard. Account credentials remain encrypted.',
      destructive: true,
    );
    if (password == null || !context.mounted) {
      return;
    }
    final ok = await controller.removeDashboardPassword(password);
    if (context.mounted) {
      _notifyResult(context, ok, 'Dashboard password removed.');
    }
  }

  Future<void> _setGuestPassword(BuildContext context) async {
    final result = await _showPasswordEditor(
      context,
      title: 'Set guest password',
    );
    if (result == null || !context.mounted) {
      return;
    }
    final ok = await controller.setGuestPassword(result.newPassword);
    if (context.mounted) {
      _notifyResult(context, ok, 'Guest password updated.');
    }
  }

  Future<void> _removeGuestPassword(BuildContext context) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Remove guest password?',
      message:
          'Guest access will no longer require a password when the guest-access switch is enabled.',
      confirmLabel: 'Remove password',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final ok = await controller.removeGuestPassword();
    if (context.mounted) {
      _notifyResult(context, ok, 'Guest password removed.');
    }
  }

  Future<void> _setupTotp(BuildContext context) async {
    final setup = await controller.startTotpSetup();
    if (setup == null || !context.mounted) {
      return;
    }
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enroll authenticator'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Add this secret or URI to your authenticator, then enter the six-digit code. Keep the secret private.',
                ),
                const SizedBox(height: 14),
                SelectableText(
                  setup.secret,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: setup.secret)),
                      icon: const Icon(Icons.copy, size: 17),
                      label: const Text('Copy secret'),
                    ),
                    TextButton.icon(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: setup.otpauthUri),
                      ),
                      icon: const Icon(Icons.link, size: 17),
                      label: const Text('Copy setup URI'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Six-digit code',
                    counterText: '',
                  ),
                  validator: _validateTotpCode,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, codeController.text.trim());
              }
            },
            child: const Text('Confirm enrollment'),
          ),
        ],
      ),
    );
    codeController.clear();
    codeController.dispose();
    if (code == null || !context.mounted) {
      return;
    }
    final ok = await controller.confirmTotpSetup(setup.secret, code);
    if (context.mounted) {
      _notifyResult(context, ok, 'TOTP enrollment confirmed.');
    }
  }

  Future<void> _disableTotp(BuildContext context) async {
    final code = await _showSecretPrompt(
      context,
      title: 'Disable TOTP?',
      label: 'Six-digit authenticator code',
      detail: 'A current code is required to disable authenticator checks.',
      validator: _validateTotpCode,
      destructive: true,
      obscure: false,
    );
    if (code == null || !context.mounted) {
      return;
    }
    final ok = await controller.disableTotp(code);
    if (context.mounted) {
      _notifyResult(context, ok, 'TOTP disabled.');
    }
  }
}

class AdvancedAdminSections extends StatefulWidget {
  const AdvancedAdminSections({required this.controller, super.key});

  final AppController controller;

  @override
  State<AdvancedAdminSections> createState() => _AdvancedAdminSectionsState();
}

class _AdvancedAdminSectionsState extends State<AdvancedAdminSections> {
  bool _modelSourcesExpanded = false;
  bool _firewallExpanded = false;
  bool _quotaExpanded = false;
  bool _stickyExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (widget.controller.advancedSettingsActionError != null) ...<Widget>[
          FeatureWarning(
            error: true,
            message:
                'Advanced settings action failed: ${featureErrorText(widget.controller.advancedSettingsActionError)}',
          ),
          const SizedBox(height: 14),
        ],
        _lazyPanel(
          icon: Icons.hub_outlined,
          title: 'Model sources',
          subtitle: 'OpenAI-compatible endpoints, capabilities, and models',
          expanded: _modelSourcesExpanded,
          onExpansionChanged: (value) {
            setState(() => _modelSourcesExpanded = value);
            if (value && widget.controller.modelSources.value == null) {
              unawaited(widget.controller.refreshModelSources());
            }
          },
          child: _ModelSourcesBody(controller: widget.controller),
        ),
        const SizedBox(height: 14),
        _lazyPanel(
          icon: Icons.shield_outlined,
          title: 'Firewall allowlist',
          subtitle: 'Explicit IP access policy for the local service',
          expanded: _firewallExpanded,
          onExpansionChanged: (value) {
            setState(() => _firewallExpanded = value);
            if (value && widget.controller.firewall.value == null) {
              unawaited(widget.controller.refreshFirewall());
            }
          },
          child: _FirewallBody(controller: widget.controller),
        ),
        const SizedBox(height: 14),
        _lazyPanel(
          icon: Icons.auto_graph_outlined,
          title: 'Quota planner',
          subtitle: 'Forecasting, warm-up decisions, and safety limits',
          expanded: _quotaExpanded,
          onExpansionChanged: (value) {
            setState(() => _quotaExpanded = value);
            if (value && widget.controller.quotaPlanner.value == null) {
              unawaited(widget.controller.refreshQuotaPlanner());
            }
          },
          child: _QuotaPlannerBody(controller: widget.controller),
        ),
        const SizedBox(height: 14),
        _lazyPanel(
          icon: Icons.link_outlined,
          title: 'Sticky sessions',
          subtitle: 'Inspect and remove account-affinity/session mappings',
          expanded: _stickyExpanded,
          onExpansionChanged: (value) {
            setState(() => _stickyExpanded = value);
            if (value && widget.controller.stickySessions.value == null) {
              unawaited(widget.controller.refreshStickySessions());
            }
          },
          child: _StickySessionsBody(controller: widget.controller),
        ),
      ],
    );
  }

  Widget _lazyPanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool expanded,
    required ValueChanged<bool> onExpansionChanged,
    required Widget child,
  }) {
    return FeaturePanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        leading: Icon(icon, color: AppPalette.cyan),
        title: Text(title),
        subtitle: Text(subtitle),
        children: <Widget>[
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }
}

class _ModelSourcesBody extends StatelessWidget {
  const _ModelSourcesBody({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final section = controller.modelSources;
    if (section.value == null && section.isBusy) {
      return const SizedBox(
        height: 150,
        child: FeatureProgress(label: 'Loading model sources…'),
      );
    }
    if (section.value == null) {
      return SizedBox(
        height: 210,
        child: FeatureFailure(
          title: 'Model sources unavailable',
          error: section.error,
          onRetry: controller.refreshModelSources,
        ),
      );
    }
    final sources = section.value!.sources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionToolbar(
          context,
          label:
              '${sources.length} source${sources.length == 1 ? '' : 's'} · fetched ${formatRelative(section.lastSuccessfulFetch)}',
          onRefresh: controller.refreshModelSources,
          action: FilledButton.icon(
            onPressed:
                controller.canWrite && !controller.advancedSettingsActionBusy
                ? () => unawaited(_editSource(context))
                : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add source'),
          ),
        ),
        if (section.isStale) ...<Widget>[
          const SizedBox(height: 10),
          FeatureWarning(
            message:
                'Showing the last model-source snapshot: ${featureErrorText(section.error)}',
          ),
        ],
        const SizedBox(height: 12),
        if (sources.isEmpty)
          const _InlineEmpty(
            icon: Icons.hub_outlined,
            title: 'No external model sources',
            detail:
                'Codex account routing still works. Add an OpenAI-compatible source only when you need one.',
          )
        else
          ...sources.map((source) => _sourceCard(context, source)),
      ],
    );
  }

  Widget _sourceCard(BuildContext context, ModelSource source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      source.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      source.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: source.isEnabled,
                onChanged:
                    controller.canWrite &&
                        !controller.advancedSettingsActionBusy
                    ? (value) => unawaited(
                        controller.updateModelSource(
                          source.id,
                          <String, Object?>{'isEnabled': value},
                        ),
                      )
                    : null,
              ),
              IconButton(
                tooltip: 'Edit source',
                onPressed:
                    controller.canWrite &&
                        !controller.advancedSettingsActionBusy
                    ? () => unawaited(_editSource(context, source: source))
                    : null,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete source',
                onPressed:
                    controller.canWrite &&
                        !controller.advancedSettingsActionBusy
                    ? () => unawaited(_deleteSource(context, source))
                    : null,
                icon: const Icon(Icons.delete_outline, color: AppPalette.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              FeatureBadge(
                label: source.healthStatus,
                color: source.healthStatus == 'healthy'
                    ? AppPalette.green
                    : AppPalette.amber,
              ),
              FeatureBadge(label: '${source.models.length} models'),
              if (source.supportsResponses)
                const FeatureBadge(label: 'Responses'),
              if (source.supportsChatCompletions)
                const FeatureBadge(label: 'Chat'),
              if (source.supportsAudioTranscriptions)
                const FeatureBadge(label: 'Audio'),
              if (source.maxConcurrency != null)
                FeatureBadge(label: 'Concurrency ${source.maxConcurrency}'),
            ],
          ),
          if (source.models.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              source.models
                  .take(12)
                  .map((model) => model.displayName ?? model.model)
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editSource(BuildContext context, {ModelSource? source}) async {
    final result = await showDialog<_SourceEditorResult>(
      context: context,
      builder: (context) => _SourceEditorDialog(source: source),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final existingByName = <String, ModelSourceModel>{
      for (final model in source?.models ?? const <ModelSourceModel>[])
        model.model: model,
    };
    final models = result.models
        .map((name) {
          final existing = existingByName[name];
          return <String, Object?>{
            'model': name,
            if (existing != null) ...<String, Object?>{
              'displayName': existing.displayName,
              'contextWindow': existing.contextWindow,
              'maxOutputTokens': existing.maxOutputTokens,
              'supportsStreaming': existing.supportsStreaming,
              'supportsTools': existing.supportsTools,
              'supportsVision': existing.supportsVision,
              'isEnabled': existing.isEnabled,
            },
          };
        })
        .toList(growable: false);
    final payload = <String, Object?>{
      'name': result.name,
      'baseUrl': result.baseUrl,
      if (result.apiKey != null) 'apiKey': result.apiKey,
      'supportsChatCompletions': result.supportsChatCompletions,
      'supportsResponses': result.supportsResponses,
      'supportsAudioTranscriptions': result.supportsAudioTranscriptions,
      'timeoutSeconds': result.timeoutSeconds,
      'maxConcurrency': result.maxConcurrency,
      'models': models,
    };
    final ok = source == null
        ? await controller.createModelSource(payload)
        : await controller.updateModelSource(source.id, payload);
    if (context.mounted) {
      _notifyResult(
        context,
        ok,
        source == null ? 'Model source added.' : 'Model source updated.',
      );
    }
  }

  Future<void> _deleteSource(BuildContext context, ModelSource source) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Delete ${source.name}?',
      message:
          'API-key assignments that depend on this source may stop routing. Stored Codex accounts are not affected.',
      confirmLabel: 'Delete source',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final ok = await controller.deleteModelSource(source.id);
    if (context.mounted) {
      _notifyResult(context, ok, 'Model source deleted.');
    }
  }
}

class _FirewallBody extends StatelessWidget {
  const _FirewallBody({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final section = controller.firewall;
    if (section.value == null && section.isBusy) {
      return const SizedBox(
        height: 150,
        child: FeatureProgress(label: 'Loading firewall policy…'),
      );
    }
    if (section.value == null) {
      return SizedBox(
        height: 210,
        child: FeatureFailure(
          title: 'Firewall policy unavailable',
          error: section.error,
          onRetry: controller.refreshFirewall,
        ),
      );
    }
    final policy = section.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionToolbar(
          context,
          label: policy.mode == 'allow_all'
              ? 'Allow all · no IP restriction active'
              : 'Allowlist active · ${policy.entries.length} IPs',
          onRefresh: controller.refreshFirewall,
          action: FilledButton.icon(
            onPressed:
                controller.canWrite && !controller.advancedSettingsActionBusy
                ? () => unawaited(_addIp(context, policy))
                : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add IP'),
          ),
        ),
        const SizedBox(height: 12),
        if (policy.entries.isEmpty)
          const _InlineEmpty(
            icon: Icons.public,
            title: 'No allowlist is active',
            detail:
                'Adding the first address activates the allowlist immediately. Include 127.0.0.1 to preserve local dashboard access.',
          )
        else
          ...policy.entries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language, color: AppPalette.cyan),
              title: SelectableText(entry.ipAddress),
              subtitle: Text('Added ${formatRelative(entry.createdAt)}'),
              trailing: IconButton(
                tooltip: 'Remove IP',
                onPressed:
                    controller.canWrite &&
                        !controller.advancedSettingsActionBusy
                    ? () => unawaited(_removeIp(context, entry, policy))
                    : null,
                icon: const Icon(Icons.delete_outline, color: AppPalette.red),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addIp(BuildContext context, FirewallPolicy policy) async {
    final text = TextEditingController(
      text: policy.entries.isEmpty ? '127.0.0.1' : '',
    );
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          policy.entries.isEmpty ? 'Activate firewall allowlist' : 'Add IP',
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: text,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'IPv4 or IPv6 address',
                helperText:
                    'The first address activates the allowlist immediately.',
              ),
              validator: (value) =>
                  InternetAddress.tryParse(value?.trim() ?? '') == null
                  ? 'Enter a valid IP address.'
                  : null,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, text.text.trim());
              }
            },
            child: const Text('Add IP'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null || !context.mounted) {
      return;
    }
    final ok = await controller.addFirewallIp(value);
    if (context.mounted) {
      _notifyResult(context, ok, 'Firewall IP added.');
    }
  }

  Future<void> _removeIp(
    BuildContext context,
    FirewallEntry entry,
    FirewallPolicy policy,
  ) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Remove ${entry.ipAddress}?',
      message: policy.entries.length == 1
          ? 'Removing the final entry disables the allowlist and returns the firewall to allow-all mode.'
          : 'Requests from this address will no longer be accepted by the allowlist.',
      confirmLabel: 'Remove IP',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final ok = await controller.deleteFirewallIp(entry.ipAddress);
    if (context.mounted) {
      _notifyResult(context, ok, 'Firewall IP removed.');
    }
  }
}

class _QuotaPlannerBody extends StatelessWidget {
  const _QuotaPlannerBody({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final section = controller.quotaPlanner;
    if (section.value == null && section.isBusy) {
      return const SizedBox(
        height: 150,
        child: FeatureProgress(label: 'Loading quota planner…'),
      );
    }
    if (section.value == null) {
      return SizedBox(
        height: 210,
        child: FeatureFailure(
          title: 'Quota planner unavailable',
          error: section.error,
          onRetry: controller.refreshQuotaPlanner,
        ),
      );
    }
    final snapshot = section.value!;
    final settings = snapshot.settings;
    final forecast = snapshot.forecast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionToolbar(
          context,
          label:
              '${settings.mode.toUpperCase()} · ${settings.dryRun ? 'dry run' : 'live actions'} · ${settings.timezone}',
          onRefresh: controller.refreshQuotaPlanner,
          action: Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed:
                    controller.canWrite &&
                        !controller.advancedSettingsActionBusy
                    ? () => unawaited(_warmNow(context))
                    : null,
                icon: const Icon(Icons.local_fire_department_outlined),
                label: const Text('Warm now'),
              ),
              FilledButton.icon(
                onPressed:
                    controller.canWrite &&
                        !controller.advancedSettingsActionBusy
                    ? () => unawaited(_editSettings(context, settings))
                    : null,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Planner settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 680;
            final cards = <Widget>[
              _MiniMetric(
                label: 'Forecast demand',
                value: forecast.totalDemandUnits.toStringAsFixed(2),
                detail:
                    '${forecast.horizonHours}h · ${forecast.slotCount} slots',
              ),
              _MiniMetric(
                label: 'Projected served',
                value: forecast.simulation.servedUnits.toStringAsFixed(2),
                detail:
                    'unmet ${forecast.simulation.unmetDemand.toStringAsFixed(2)}',
              ),
              _MiniMetric(
                label: 'Peak demand',
                value: forecast.peakDemandUnits.toStringAsFixed(2),
                detail: forecast.peakSlotStart == null
                    ? 'no peak'
                    : formatRelative(forecast.peakSlotStart),
              ),
            ];
            if (stacked) {
              return Column(
                children: cards
                    .map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: card,
                      ),
                    )
                    .toList(growable: false),
              );
            }
            return Row(
              children: cards
                  .map(
                    (card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: card,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Recent decisions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (snapshot.decisions.isEmpty)
          const _InlineEmpty(
            icon: Icons.history,
            title: 'No planner decisions yet',
            detail: 'The planner has not recorded an action in this fixture.',
          )
        else
          ...snapshot.decisions
              .take(10)
              .map(
                (decision) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    decision.action == 'no_op'
                        ? Icons.remove_circle_outline
                        : Icons.bolt_outlined,
                    color: decision.status == 'executed'
                        ? AppPalette.green
                        : AppPalette.textMuted,
                  ),
                  title: Text(
                    '${decision.action} · ${decision.status}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${formatRelative(decision.createdAt)} · ${decision.reason ?? 'No reason'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: decision.status == 'scheduled'
                      ? TextButton(
                          onPressed:
                              controller.canWrite &&
                                  !controller.advancedSettingsActionBusy
                              ? () => unawaited(
                                  controller.cancelQuotaPlannerDecision(
                                    decision.id,
                                  ),
                                )
                              : null,
                          child: const Text('Cancel'),
                        )
                      : FeatureBadge(label: decision.mode),
                ),
              ),
      ],
    );
  }

  Future<void> _editSettings(
    BuildContext context,
    QuotaPlannerSettings current,
  ) async {
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _QuotaPlannerSettingsDialog(current: current),
    );
    if (payload == null || !context.mounted) {
      return;
    }
    final ok = await controller.updateQuotaPlannerSettings(payload);
    if (context.mounted) {
      _notifyResult(context, ok, 'Quota planner settings updated.');
    }
  }

  Future<void> _warmNow(BuildContext context) async {
    final result = await showDialog<_WarmNowResult>(
      context: context,
      builder: (context) => _WarmNowDialog(controller: controller),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final action = await controller.warmQuotaPlannerAccount(
      result.accountId,
      model: result.model,
      forceProbe: result.forceProbe,
    );
    if (context.mounted) {
      _notifyResult(
        context,
        action != null,
        action == null
            ? ''
            : 'Planner result: ${action.status} · ${action.reason}',
      );
    }
  }
}

class _StickySessionsBody extends StatefulWidget {
  const _StickySessionsBody({required this.controller});

  final AppController controller;

  @override
  State<_StickySessionsBody> createState() => _StickySessionsBodyState();
}

class _StickySessionsBodyState extends State<_StickySessionsBody> {
  @override
  Widget build(BuildContext context) {
    final section = widget.controller.stickySessions;
    if (section.value == null && section.isBusy) {
      return const SizedBox(
        height: 150,
        child: FeatureProgress(label: 'Loading sticky sessions…'),
      );
    }
    if (section.value == null) {
      return SizedBox(
        height: 210,
        child: FeatureFailure(
          title: 'Sticky sessions unavailable',
          error: section.error,
          onRetry: widget.controller.refreshStickySessions,
        ),
      );
    }
    final page = section.value!;
    final query = widget.controller.stickySessionsQuery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildFilterBar(context, page, query),
        const SizedBox(height: 12),
        Text(
          '${page.total} matching sessions · showing ${page.entries.length}',
          style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        if (page.entries.isEmpty)
          const _InlineEmpty(
            icon: Icons.link_off_outlined,
            title: 'No sticky sessions match',
            detail:
                'No Codex sessions, sticky threads, or prompt-cache mappings match these filters.',
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 430),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: page.entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = page.entries[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    entry.kind == 'prompt_cache'
                        ? Icons.cached_outlined
                        : Icons.link_outlined,
                    color: entry.isStale ? AppPalette.amber : AppPalette.cyan,
                  ),
                  title: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${entry.kind} · updated ${formatRelative(entry.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (entry.isStale)
                        const FeatureBadge(
                          label: 'stale',
                          color: AppPalette.amber,
                        ),
                      IconButton(
                        tooltip: 'Delete mapping',
                        onPressed:
                            widget.controller.canWrite &&
                                !widget.controller.advancedSettingsActionBusy
                            ? () => unawaited(_deleteEntry(context, entry))
                            : null,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppPalette.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (query.offset > 0 || page.hasMore) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              OutlinedButton(
                onPressed: query.offset > 0
                    ? () => _goToOffset(
                        (query.offset - query.limit).clamp(0, page.total),
                      )
                    : null,
                child: const Text('Previous'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: page.hasMore
                    ? () => _goToOffset(query.offset + query.limit)
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    StickySessionsPage page,
    StickySessionsQuery query,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => unawaited(
            _editTextFilter(
              context,
              title: 'Filter by account',
              hint: 'Account name, email, alias, or ID',
              currentValue: query.accountQuery,
              onApply: (value) => _applyFilters(accountQuery: value),
            ),
          ),
          icon: const Icon(Icons.person_search_outlined, size: 18),
          label: Text(
            query.accountQuery.isEmpty
                ? 'All accounts'
                : 'Account: ${query.accountQuery}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => unawaited(
            _editTextFilter(
              context,
              title: 'Filter by session key',
              hint: 'Full or partial sticky-session key',
              currentValue: query.keyQuery,
              onApply: (value) => _applyFilters(keyQuery: value),
            ),
          ),
          icon: const Icon(Icons.key_outlined, size: 18),
          label: Text(
            query.keyQuery.isEmpty
                ? 'All session keys'
                : 'Key: ${query.keyQuery}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilterChip(
          label: const Text('Stale only'),
          selected: query.staleOnly,
          onSelected: (value) => _applyFilters(staleOnly: value),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => unawaited(widget.controller.refreshStickySessions()),
          icon: const Icon(Icons.refresh),
        ),
        OutlinedButton.icon(
          onPressed:
              widget.controller.canWrite &&
                  !widget.controller.advancedSettingsActionBusy &&
                  page.stalePromptCacheCount > 0
              ? () => unawaited(_purgeStale(context))
              : null,
          icon: const Icon(Icons.cleaning_services_outlined, size: 18),
          label: Text('Purge stale (${page.stalePromptCacheCount})'),
        ),
      ],
    );
  }

  Future<void> _editTextFilter(
    BuildContext context, {
    required String title,
    required String hint,
    required String currentValue,
    required ValueChanged<String> onApply,
  }) async {
    final text = TextEditingController(text: currentValue);
    final result = await showDialog<_TextFilterResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: text,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) =>
                Navigator.pop(dialogContext, _TextFilterResult(value.trim())),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (currentValue.isNotEmpty)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, const _TextFilterResult('')),
              child: const Text('Clear'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _TextFilterResult(text.text.trim()),
            ),
            child: const Text('Apply filter'),
          ),
        ],
      ),
    );
    text.dispose();
    if (result != null && context.mounted) {
      onApply(result.value);
    }
  }

  void _applyFilters({
    bool? staleOnly,
    String? accountQuery,
    String? keyQuery,
  }) {
    final current = widget.controller.stickySessionsQuery;
    unawaited(
      widget.controller.refreshStickySessions(
        query: current.copyWith(
          staleOnly: staleOnly,
          accountQuery: accountQuery,
          keyQuery: keyQuery,
          offset: 0,
        ),
      ),
    );
  }

  void _goToOffset(int offset) {
    unawaited(
      widget.controller.refreshStickySessions(
        query: widget.controller.stickySessionsQuery.copyWith(offset: offset),
      ),
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    StickySessionEntry entry,
  ) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Delete this sticky mapping?',
      message:
          '${entry.displayName} will be reallocated on its next eligible request. No account credentials or usage history are deleted.',
      confirmLabel: 'Delete mapping',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final ok = await widget.controller.deleteStickySession(entry);
    if (context.mounted) {
      _notifyResult(context, ok, 'Sticky mapping deleted.');
    }
  }

  Future<void> _purgeStale(BuildContext context) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Purge stale prompt-cache mappings?',
      message:
          'Only stale prompt-cache mappings are removed. Active sessions and account data remain intact.',
      confirmLabel: 'Purge stale',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final count = await widget.controller.purgeStaleStickySessions();
    if (context.mounted) {
      _notifyResult(
        context,
        count != null,
        count == null ? '' : 'Purged $count stale mappings.',
      );
    }
  }
}

class _TextFilterResult {
  const _TextFilterResult(this.value);

  final String value;
}

class _SourceEditorResult {
  const _SourceEditorResult({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.supportsChatCompletions,
    required this.supportsResponses,
    required this.supportsAudioTranscriptions,
    required this.timeoutSeconds,
    required this.maxConcurrency,
    required this.models,
  });

  final String name;
  final String baseUrl;
  final String? apiKey;
  final bool supportsChatCompletions;
  final bool supportsResponses;
  final bool supportsAudioTranscriptions;
  final int? timeoutSeconds;
  final int? maxConcurrency;
  final List<String> models;
}

class _SourceEditorDialog extends StatefulWidget {
  const _SourceEditorDialog({this.source});

  final ModelSource? source;

  @override
  State<_SourceEditorDialog> createState() => _SourceEditorDialogState();
}

class _SourceEditorDialogState extends State<_SourceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _timeout;
  late final TextEditingController _concurrency;
  late final TextEditingController _models;
  late bool _chat;
  late bool _responses;
  late bool _audio;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _name = TextEditingController(text: source?.name ?? '');
    _baseUrl = TextEditingController(text: source?.baseUrl ?? '');
    _apiKey = TextEditingController();
    _timeout = TextEditingController(text: source?.timeoutSeconds?.toString());
    _concurrency = TextEditingController(
      text: source?.maxConcurrency?.toString(),
    );
    _models = TextEditingController(
      text: source?.models.map((model) => model.model).join('\n') ?? '',
    );
    _chat = source?.supportsChatCompletions ?? true;
    _responses = source?.supportsResponses ?? true;
    _audio = source?.supportsAudioTranscriptions ?? false;
  }

  @override
  void dispose() {
    _apiKey.clear();
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    _timeout.dispose();
    _concurrency.dispose();
    _models.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.source == null ? 'Add model source' : 'Edit source'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 128,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value?.trim().isEmpty ?? true
                      ? 'Name is required.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _baseUrl,
                  maxLength: 2048,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://provider.example/v1',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    return uri == null ||
                            !uri.hasAuthority ||
                            (uri.scheme != 'https' && uri.scheme != 'http')
                        ? 'Enter an HTTP or HTTPS URL.'
                        : null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _apiKey,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: widget.source == null
                        ? 'API key (optional)'
                        : 'New API key (blank keeps current)',
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fields = <Widget>[
                      TextFormField(
                        controller: _timeout,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Timeout seconds (optional)',
                        ),
                        validator: _optionalPositiveInteger,
                      ),
                      TextFormField(
                        controller: _concurrency,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max concurrency (optional)',
                        ),
                        validator: _optionalPositiveInteger,
                      ),
                    ];
                    if (constraints.maxWidth < 520) {
                      return Column(
                        children: <Widget>[
                          fields[0],
                          const SizedBox(height: 10),
                          fields[1],
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(child: fields[0]),
                        const SizedBox(width: 10),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _responses,
                  title: const Text('Responses API'),
                  onChanged: (value) => setState(() => _responses = value!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _chat,
                  title: const Text('Chat Completions API'),
                  onChanged: (value) => setState(() => _chat = value!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _audio,
                  title: const Text('Audio transcriptions'),
                  onChanged: (value) => setState(() => _audio = value!),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _models,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Model IDs',
                    helperText: 'One per line or comma-separated.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => _parseModels(value ?? '').length > 500
                      ? 'Use at most 500 model IDs per source.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.source == null ? 'Add source' : 'Save changes'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final secret = _apiKey.text.trim();
    Navigator.pop(
      context,
      _SourceEditorResult(
        name: _name.text.trim(),
        baseUrl: _baseUrl.text.trim(),
        apiKey: secret.isEmpty ? null : secret,
        supportsChatCompletions: _chat,
        supportsResponses: _responses,
        supportsAudioTranscriptions: _audio,
        timeoutSeconds: int.tryParse(_timeout.text.trim()),
        maxConcurrency: int.tryParse(_concurrency.text.trim()),
        models: _parseModels(_models.text),
      ),
    );
  }
}

class _QuotaPlannerSettingsDialog extends StatefulWidget {
  const _QuotaPlannerSettingsDialog({required this.current});

  final QuotaPlannerSettings current;

  @override
  State<_QuotaPlannerSettingsDialog> createState() =>
      _QuotaPlannerSettingsDialogState();
}

class _QuotaPlannerSettingsDialogState
    extends State<_QuotaPlannerSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _mode;
  late String _quantile;
  late Set<int> _workingDays;
  late bool _prewarm;
  late bool _synthetic;
  late bool _dryRun;
  late final TextEditingController _timezone;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _lead;
  late final TextEditingController _maxWarmups;
  late final TextEditingController _credits;
  late final TextEditingController _gain;
  late final TextEditingController _model;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _mode = current.mode;
    _quantile = current.forecastQuantile;
    _workingDays = current.workingDays.toSet();
    _prewarm = current.prewarmEnabled;
    _synthetic = current.allowSyntheticTraffic;
    _dryRun = current.dryRun;
    _timezone = TextEditingController(text: current.timezone);
    _start = TextEditingController(text: current.workingHoursStart);
    _end = TextEditingController(text: current.workingHoursEnd);
    _lead = TextEditingController(text: current.prewarmLeadMinutes.toString());
    _maxWarmups = TextEditingController(
      text: current.maxWarmupsPerDay.toString(),
    );
    _credits = TextEditingController(
      text: current.maxWarmupCreditsPerDay.toString(),
    );
    _gain = TextEditingController(text: current.minExpectedGain.toString());
    _model = TextEditingController(text: current.warmupModelPreference ?? '');
  }

  @override
  void dispose() {
    _timezone.dispose();
    _start.dispose();
    _end.dispose();
    _lead.dispose();
    _maxWarmups.dispose();
    _credits.dispose();
    _gain.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quota planner settings'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _mode,
                        decoration: const InputDecoration(labelText: 'Mode'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'off', child: Text('Off')),
                          DropdownMenuItem(
                            value: 'shadow',
                            child: Text('Shadow'),
                          ),
                          DropdownMenuItem(
                            value: 'suggest',
                            child: Text('Suggest'),
                          ),
                          DropdownMenuItem(value: 'auto', child: Text('Auto')),
                        ],
                        onChanged: (value) => setState(() => _mode = value!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _quantile,
                        decoration: const InputDecoration(
                          labelText: 'Forecast quantile',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'p50', child: Text('P50')),
                          DropdownMenuItem(value: 'p75', child: Text('P75')),
                          DropdownMenuItem(value: 'p90', child: Text('P90')),
                        ],
                        onChanged: (value) =>
                            setState(() => _quantile = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _timezone,
                  decoration: const InputDecoration(
                    labelText: 'IANA timezone',
                    hintText: 'Asia/Tehran',
                  ),
                  validator: (value) => value?.trim().isEmpty ?? true
                      ? 'Timezone is required.'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _start,
                        decoration: const InputDecoration(
                          labelText: 'Work starts (HH:mm)',
                        ),
                        validator: _validateClock,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _end,
                        decoration: const InputDecoration(
                          labelText: 'Work ends (HH:mm)',
                        ),
                        validator: _validateClock,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: List<Widget>.generate(7, (day) {
                      const names = <String>[
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      return FilterChip(
                        label: Text(names[day]),
                        selected: _workingDays.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _workingDays.add(day);
                          } else {
                            _workingDays.remove(day);
                          }
                        }),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _lead,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Prewarm lead (minutes)',
                        ),
                        validator: (value) => _integerRange(value, 0, 1440),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _maxWarmups,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max warmups/day',
                        ),
                        validator: _nonNegativeInteger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _credits,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Max warmup credits/day',
                        ),
                        validator: _nonNegativeNumber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _gain,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Minimum expected gain',
                        ),
                        validator: _nonNegativeNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: 'Warmup model preference (optional)',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _prewarm,
                  title: const Text('Enable scheduled prewarming'),
                  onChanged: (value) => setState(() => _prewarm = value!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _synthetic,
                  title: const Text('Allow synthetic traffic'),
                  onChanged: (value) => setState(() => _synthetic = value!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _dryRun,
                  title: const Text('Dry run'),
                  subtitle: const Text(
                    'Keep enabled until planner behavior has been reviewed.',
                  ),
                  onChanged: (value) => setState(() => _dryRun = value!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save planner settings'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_workingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one working day.')),
      );
      return;
    }
    final days = _workingDays.toList()..sort();
    Navigator.pop(context, <String, Object?>{
      'mode': _mode,
      'timezone': _timezone.text.trim(),
      'workingDays': days,
      'workingHoursStart': _start.text.trim(),
      'workingHoursEnd': _end.text.trim(),
      'prewarmEnabled': _prewarm,
      'prewarmLeadMinutes': int.parse(_lead.text.trim()),
      'maxWarmupsPerDay': int.parse(_maxWarmups.text.trim()),
      'maxWarmupCreditsPerDay': double.parse(_credits.text.trim()),
      'minExpectedGain': double.parse(_gain.text.trim()),
      'forecastQuantile': _quantile,
      'allowSyntheticTraffic': _synthetic,
      'warmupModelPreference': _model.text.trim().isEmpty
          ? null
          : _model.text.trim(),
      'dryRun': _dryRun,
    });
  }
}

class _WarmNowResult {
  const _WarmNowResult({
    required this.accountId,
    required this.model,
    required this.forceProbe,
  });

  final String accountId;
  final String? model;
  final bool forceProbe;
}

class _WarmNowDialog extends StatefulWidget {
  const _WarmNowDialog({required this.controller});

  final AppController controller;

  @override
  State<_WarmNowDialog> createState() => _WarmNowDialogState();
}

class _WarmNowDialogState extends State<_WarmNowDialog> {
  String? _accountId;
  String? _model;
  bool _forceProbe = false;

  @override
  Widget build(BuildContext context) {
    final accounts = widget.controller.orderedAccounts(
      widget.controller.accounts.value ?? const <AccountSummary>[],
    );
    final models = widget.controller.models.value ?? const [];
    _accountId ??= accounts.firstOrNull?.accountId;
    return AlertDialog(
      title: const Text('Warm account now'),
      content: SizedBox(
        width: 500,
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
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _model,
              decoration: const InputDecoration(labelText: 'Model (optional)'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Planner default'),
                ),
                ...models.map(
                  (model) => DropdownMenuItem<String?>(
                    value: model.id,
                    child: Text(model.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _model = value),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _forceProbe,
              title: const Text('Force quota probe first'),
              onChanged: (value) => setState(() => _forceProbe = value!),
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
          onPressed: _accountId == null
              ? null
              : () => Navigator.pop(
                  context,
                  _WarmNowResult(
                    accountId: _accountId!,
                    model: _model,
                    forceProbe: _forceProbe,
                  ),
                ),
          child: const Text('Run warm-up'),
        ),
      ],
    );
  }
}

class _PasswordEditorResult {
  const _PasswordEditorResult({
    required this.currentPassword,
    required this.newPassword,
    required this.bootstrapToken,
  });

  final String? currentPassword;
  final String newPassword;
  final String? bootstrapToken;
}

Future<_PasswordEditorResult?> _showPasswordEditor(
  BuildContext context, {
  required String title,
  bool currentRequired = false,
  bool bootstrapRequired = false,
}) async {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  final bootstrap = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<_PasswordEditorResult>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (currentRequired) ...<Widget>[
                TextFormField(
                  controller: current,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Current password is required.'
                      : null,
                ),
                const SizedBox(height: 10),
              ],
              if (bootstrapRequired) ...<Widget>[
                TextFormField(
                  controller: bootstrap,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Bootstrap token',
                  ),
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Bootstrap token is required.'
                      : null,
                ),
                const SizedBox(height: 10),
              ],
              TextFormField(
                controller: next,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText:
                      'At least 8 characters and at most 72 UTF-8 bytes.',
                ),
                validator: _validateDashboardPassword,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirm,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (value) =>
                    value != next.text ? 'Passwords do not match.' : null,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(
                dialogContext,
                _PasswordEditorResult(
                  currentPassword: currentRequired ? current.text : null,
                  newPassword: next.text,
                  bootstrapToken: bootstrapRequired ? bootstrap.text : null,
                ),
              );
            }
          },
          child: const Text('Apply'),
        ),
      ],
    ),
  );
  current.clear();
  next.clear();
  confirm.clear();
  bootstrap.clear();
  current.dispose();
  next.dispose();
  confirm.dispose();
  bootstrap.dispose();
  return result;
}

Future<String?> _showSecretPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String detail,
  String? Function(String?)? validator,
  bool destructive = false,
  bool obscure = true,
}) async {
  final text = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 450,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(detail),
              const SizedBox(height: 14),
              TextFormField(
                controller: text,
                autofocus: true,
                obscureText: obscure,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(labelText: label),
                validator:
                    validator ??
                    (value) => value?.isEmpty ?? true
                        ? 'This value is required.'
                        : null,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppPalette.red)
              : null,
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(dialogContext, text.text.trim());
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  text.clear();
  text.dispose();
  return result;
}

Widget _sectionToolbar(
  BuildContext context, {
  required String label,
  required Future<void> Function() onRefresh,
  required Widget action,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final labelWidget = Text(
        label,
        style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
      );
      final controls = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Refresh section',
            onPressed: () => unawaited(onRefresh()),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
          action,
        ],
      );
      if (constraints.maxWidth < 650) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[labelWidget, const SizedBox(height: 8), controls],
        );
      }
      return Row(
        children: <Widget>[
          Expanded(child: labelWidget),
          controls,
        ],
      );
    },
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppPalette.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

void _notifyResult(BuildContext context, bool ok, String successMessage) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? successMessage : 'The local action failed.'),
      backgroundColor: ok ? null : AppPalette.red,
    ),
  );
}

String? _validateDashboardPassword(String? value) {
  final password = value ?? '';
  if (password.length < 8) {
    return 'Use at least 8 characters.';
  }
  if (utf8.encode(password).length > 72) {
    return 'Password exceeds the 72-byte UTF-8 limit.';
  }
  return null;
}

String? _validateTotpCode(String? value) =>
    RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Enter exactly six digits.';

String? _optionalPositiveInteger(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(raw);
  return parsed == null || parsed <= 0 ? 'Use a positive whole number.' : null;
}

String? _nonNegativeInteger(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  return parsed == null || parsed < 0 ? 'Use zero or a whole number.' : null;
}

String? _nonNegativeNumber(String? value) {
  final parsed = double.tryParse(value?.trim() ?? '');
  return parsed == null || parsed < 0 ? 'Use zero or a positive number.' : null;
}

String? _integerRange(String? value, int min, int max) {
  final parsed = int.tryParse(value?.trim() ?? '');
  return parsed == null || parsed < min || parsed > max
      ? 'Use a whole number from $min to $max.'
      : null;
}

String? _validateClock(String? value) =>
    RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Use 24-hour HH:mm format.';

List<String> _parseModels(String raw) {
  final models = raw
      .split(RegExp(r'[,\r\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
  return models;
}
