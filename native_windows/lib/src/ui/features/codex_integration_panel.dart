import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/account_summary.dart';
import '../../models/codex_integration.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';
import '../formatters.dart';
import 'feature_widgets.dart';

class CodexIntegrationPanel extends StatelessWidget {
  const CodexIntegrationPanel({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final section = controller.codexIntegration;
    final status = section.value;
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const OpenHubMark(size: 24),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Codex account routing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Launch-scoped routing. Codex config, login, chats, sessions, and local data stay untouched.',
                    ),
                  ],
                ),
              ),
              if (status != null)
                FeatureBadge(
                  label: status.enabled ? 'enabled' : 'normal mode',
                  color: status.enabled
                      ? AppPalette.cyan
                      : AppPalette.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ManagedCodexLaunchCard(controller: controller, status: status),
          const SizedBox(height: 14),
          ManualCodexLaunchCard(controller: controller),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          if (status == null && section.isBusy)
            const SizedBox(
              height: 120,
              child: FeatureProgress(label: 'Reading OpenHUB launch mode…'),
            )
          else if (status == null)
            SizedBox(
              height: 220,
              child: FeatureFailure(
                title: 'Codex launch mode unavailable',
                error: section.error,
                onRetry: controller.refreshCodexIntegration,
              ),
            )
          else ...<Widget>[
            if (section.isStale) ...<Widget>[
              FeatureWarning(
                message:
                    'Showing the last known HUB mode. Refresh failed: ${featureErrorText(section.error)}',
              ),
              const SizedBox(height: 12),
            ],
            if (controller.codexIntegrationActionError != null) ...<Widget>[
              FeatureWarning(
                error: true,
                message:
                    'Launch-mode change failed safely: ${featureErrorText(controller.codexIntegrationActionError)}',
              ),
              const SizedBox(height: 12),
            ],
            if (controller.codexModeChangeAffectsNextLaunch) ...<Widget>[
              const FeatureWarning(
                message:
                    'Codex is already running. Nothing changed in the current process; this mode applies after Codex is fully closed and opened again.',
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.outline),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.lock_outline, size: 19, color: AppPalette.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Zero-mutation contract: OpenHUB never writes config.toml, auth.json, Codex SQLite, history, sessions, or the Chromium profile. Disabling routing restores normal launch without a restore operation.',
                      style: TextStyle(
                        color: AppPalette.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: <Widget>[
                _Fact(label: 'HUB state', value: status.statePath),
                _Fact(label: 'Mode revision', value: '#${status.revision}'),
                _Fact(
                  label: 'Last changed',
                  value: formatRelative(status.toggledAt),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed:
                      controller.canWrite &&
                          !controller.codexIntegrationActionBusy
                      ? () => unawaited(
                          _setMode(context, status, !status.enabled),
                        )
                      : null,
                  icon: controller.codexIntegrationActionBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          status.enabled
                              ? Icons.toggle_off_outlined
                              : Icons.toggle_on_outlined,
                        ),
                  label: Text(
                    status.enabled
                        ? 'Disable account routing'
                        : 'Enable account routing',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: controller.codexIntegrationActionBusy
                      ? null
                      : () => unawaited(controller.refreshCodexIntegration()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh mode'),
                ),
                Text(
                  status.enabled
                      ? 'The best eligible account will be selected before the next Codex start.'
                      : 'Open Codex uses its normal connection and current account.',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setMode(
    BuildContext context,
    CodexIntegrationStatus status,
    bool enabled,
  ) async {
    final result = await controller.setCodexManagedRoutingEnabled(enabled);
    if (!context.mounted || result == null) {
      return;
    }
    final message = enabled
        ? 'Account routing enabled for the next Codex start. No Codex file or data was changed.'
        : 'Account routing disabled. The next Codex start will be completely normal.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class CodexIntegrationInfoPanel extends StatelessWidget {
  const CodexIntegrationInfoPanel({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final section = controller.codexIntegration;
    final status = section.value;
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const OpenHubMark(size: 38),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'How Codex launch routing works',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Settings owns the global launch mode. Account-specific launches stay beside each account.',
                    ),
                  ],
                ),
              ),
              if (status != null)
                FeatureBadge(
                  label: status.enabled ? 'Auto Route on' : 'normal launch',
                  color: status.enabled
                      ? AppPalette.cyan
                      : AppPalette.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 18),
          ManagedCodexLaunchCard(controller: controller, status: status),
          const SizedBox(height: 18),
          const _IntegrationExplanationRow(
            icon: Icons.tune_outlined,
            title: 'Settings owns Auto Route',
            detail:
                'Enable or disable automatic best-account selection here. A change applies only before a new Codex process starts.',
          ),
          const _IntegrationExplanationRow(
            icon: Icons.manage_accounts_outlined,
            title: 'Accounts owns one-launch selection',
            detail:
                'Use the launch button on any active account to prepare that exact usage route for one new process. The visible Codex login stays unchanged; Traffic verifies which account served the request.',
          ),
          const _IntegrationExplanationRow(
            icon: Icons.verified_user_outlined,
            title: 'Codex data stays untouched',
            detail:
                'OpenHUB does not write config.toml, auth.json, chats, sessions, SQLite state, history, skills, logs, or the Chromium profile.',
          ),
          const Divider(height: 28),
          if (status == null && section.isBusy)
            const FeatureProgress(label: 'Reading OpenHUB launch mode…')
          else if (status == null)
            FeatureFailure(
              title: 'Codex launch mode unavailable',
              error: section.error,
              onRetry: controller.refreshCodexIntegration,
            )
          else
            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _Fact(
                  label: 'Current behavior',
                  value: status.enabled
                      ? 'Select the best eligible account before the next start'
                      : 'Open Codex with its normal connection',
                ),
                _Fact(
                  label: 'Last changed',
                  value: formatRelative(status.toggledAt),
                ),
                OutlinedButton.icon(
                  onPressed: section.isBusy
                      ? null
                      : () => unawaited(controller.refreshCodexIntegration()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh status'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IntegrationExplanationRow extends StatelessWidget {
  const _IntegrationExplanationRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: AppPalette.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    height: 1.45,
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

class ManualCodexLaunchCard extends StatelessWidget {
  const ManualCodexLaunchCard({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final accountSection = controller.accounts;
    final accounts = controller.orderedAccounts(
      accountSection.value ?? const <AccountSummary>[],
    );
    final selectedId =
        accounts.any(
          (account) =>
              account.accountId == controller.selectedManualCodexAccountId &&
              account.isActive &&
              !account.isFreePlan,
        )
        ? controller.selectedManualCodexAccountId
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.green.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppPalette.green.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppPalette.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.person_pin_circle_outlined,
                  color: AppPalette.green,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Open with a selected account',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose one local account for this launch only. HUB refreshes its usage and verifies eligibility before opening Codex. This does not enable, disable, or otherwise change Auto route.',
                    ),
                  ],
                ),
              ),
              const FeatureBadge(label: 'one launch', color: AppPalette.green),
            ],
          ),
          const SizedBox(height: 15),
          if (accountSection.error != null && accounts.isEmpty)
            FeatureFailure(
              title: 'Local accounts could not be loaded',
              error: accountSection.error,
              onRetry: controller.refreshAccounts,
            )
          else ...<Widget>[
            DropdownButtonFormField<String>(
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Account for the next Codex launch',
                helperText:
                    'Only active paid accounts are selectable. Free subscriptions never enter routing.',
              ),
              items: accounts
                  .map(
                    (account) => DropdownMenuItem<String>(
                      value: account.accountId,
                      enabled: account.isActive && !account.isFreePlan,
                      child: Text(
                        '${account.displayName} — ${account.email}${account.isFreePlan
                            ? ' · Free · unavailable'
                            : account.isActive
                            ? ''
                            : ' · unavailable'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: controller.codexLaunchActionBusy
                  ? null
                  : controller.selectManualCodexAccount,
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed:
                      controller.canWrite &&
                          selectedId != null &&
                          !controller.codexLaunchActionBusy
                      ? () =>
                            unawaited(_openSelectedAccount(context, selectedId))
                      : null,
                  icon: controller.codexLaunchActionBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_pin_outlined),
                  label: const Text('Open with selected account'),
                ),
                OutlinedButton.icon(
                  onPressed: accountSection.isBusy
                      ? null
                      : () => unawaited(controller.refreshAccountUsage()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh usage and connections'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'The selected route stays fixed until that Codex process closes. The visible ChatGPT sign-in identity does not change, OAuth is not repeated, and no token is copied into Codex.',
              style: TextStyle(color: AppPalette.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSelectedAccount(
    BuildContext context,
    String accountId,
  ) async {
    final accountLabel = controller.accounts.value
        ?.where((account) => account.accountId == accountId)
        .firstOrNull
        ?.displayName;
    final outcome = await _openCodexWithOptionalRestart(
      context,
      controller,
      manualAccountId: accountId,
      routeLabel: accountLabel ?? 'the selected account',
      offerRestart: true,
    );
    if (!context.mounted) {
      return;
    }
    final message = switch (outcome?.disposition) {
      CodexManagedLaunchDisposition.launchedManaged =>
        'Codex restarted with API usage routed through ${outcome!.route.accountLabel ?? outcome.route.accountEmail ?? 'the selected account'}. The visible profile stays unchanged; verify the routed account in Traffic.',
      CodexManagedLaunchDisposition.alreadyRunning =>
        'Codex stayed on its existing process, so the selected account was not applied.',
      CodexManagedLaunchDisposition.blocked =>
        formatCodexLaunchExclusionSummary(outcome!.preparation),
      CodexManagedLaunchDisposition.launchedNormal =>
        'Codex opened normally; the selected account was not applied.',
      null =>
        'Codex was not opened. Codex files and local data remain unchanged: ${featureErrorText(controller.codexLaunchActionError)}',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class ManagedCodexLaunchCard extends StatelessWidget {
  const ManagedCodexLaunchCard({
    required this.controller,
    required this.status,
    super.key,
  });

  final AppController controller;
  final CodexIntegrationStatus? status;

  @override
  Widget build(BuildContext context) {
    final section = controller.codexLaunchRoute;
    final route = section.value;
    final preparation = controller.lastCodexLaunchPreparation;
    final accountLabel = route?.accountLabel ?? route?.accountEmail;
    final managed = status?.enabled ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.cyan.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const OpenHubMark(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      managed
                          ? 'Open Codex with the best account'
                          : 'Open Codex normally',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      managed
                          ? 'Refresh usage, select one trustworthy account, lock it for this process, then start Codex.'
                          : 'Start the exact installed Codex executable with no proxy override or account preparation.',
                    ),
                  ],
                ),
              ),
              FeatureBadge(
                label: controller.codexLaunchActionBusy
                    ? 'opening'
                    : managed
                    ? 'managed next start'
                    : 'normal next start',
                color: controller.codexLaunchActionBusy
                    ? AppPalette.amber
                    : managed
                    ? AppPalette.cyan
                    : AppPalette.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (controller.codexLaunchActionError != null) ...<Widget>[
            FeatureWarning(
              error: true,
              message:
                  'Codex was not opened: ${featureErrorText(controller.codexLaunchActionError)}',
            ),
            const SizedBox(height: 12),
          ],
          if (controller.codexIntegrationActionError != null) ...<Widget>[
            FeatureWarning(
              error: true,
              message:
                  'Auto Route was not changed: ${featureErrorText(controller.codexIntegrationActionError)}',
            ),
            const SizedBox(height: 12),
          ],
          if (controller.codexModeChangeAffectsNextLaunch) ...<Widget>[
            const FeatureWarning(
              message:
                  'Codex is already running. This mode applies only after Codex fully closes; the current process and account route remain unchanged.',
            ),
            const SizedBox(height: 12),
          ],
          if (route != null) ...<Widget>[
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: <Widget>[
                _Fact(
                  label: 'Last selected account',
                  value: accountLabel ?? 'None yet',
                ),
                _Fact(
                  label: 'Effective capacity',
                  value: _formatPercent(route.effectiveRemainingPercent),
                ),
                _Fact(
                  label: 'Usage sample',
                  value: formatRelative(route.sampledAt),
                ),
              ],
            ),
            if (preparation != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                preparation.readyToLaunch
                    ? '${preparation.candidates.length} eligible account${preparation.candidates.length == 1 ? '' : 's'} evaluated; ${preparation.exclusions.length} excluded.'
                    : formatCodexLaunchExclusionSummary(preparation),
                style: TextStyle(
                  color: preparation.readyToLaunch
                      ? AppPalette.textMuted
                      : AppPalette.amber,
                  fontSize: 12,
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton.icon(
                onPressed: !controller.codexLaunchActionBusy
                    ? () => unawaited(_openCodex(context, managed))
                    : null,
                icon: controller.codexLaunchActionBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  controller.codexLaunchActionBusy ? 'Opening…' : 'Open Codex',
                ),
              ),
              if (status != null)
                FilledButton.tonalIcon(
                  onPressed:
                      controller.canWrite &&
                          !controller.codexIntegrationActionBusy &&
                          !controller.codexLaunchActionBusy
                      ? () => unawaited(
                          _setMode(context, status!, !status!.enabled),
                        )
                      : null,
                  icon: controller.codexIntegrationActionBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          status!.enabled
                              ? Icons.toggle_off_outlined
                              : Icons.toggle_on_outlined,
                        ),
                  label: Text(
                    status!.enabled
                        ? 'Disable Auto Route'
                        : 'Enable Auto Route',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: controller.codexLaunchActionBusy
                    ? null
                    : () => unawaited(controller.refreshCodexLaunchRoute()),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh route'),
              ),
              Text(
                managed
                    ? 'Selection happens before a new process. If Codex is already open, HUB offers a confirmed full restart so the new route can actually apply.'
                    : 'Normal launch never prepares an account. If Codex is open, HUB brings the existing window forward.',
                style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCodex(BuildContext context, bool managed) async {
    final outcome = await _openCodexWithOptionalRestart(
      context,
      controller,
      routeLabel: 'the best eligible account',
      offerRestart: managed,
    );
    if (!context.mounted) {
      return;
    }
    final message = switch (outcome?.disposition) {
      CodexManagedLaunchDisposition.launchedManaged =>
        'Codex restarted with API usage routed through ${outcome!.route.accountLabel ?? outcome.route.accountEmail ?? 'the selected account'}. The visible profile stays unchanged; verify the account in Traffic.',
      CodexManagedLaunchDisposition.launchedNormal =>
        'Codex opened normally. No account routing or Codex data change was applied.',
      CodexManagedLaunchDisposition.alreadyRunning =>
        'Codex is already open and was brought forward. Its current account route was not changed.',
      CodexManagedLaunchDisposition.blocked =>
        formatCodexLaunchExclusionSummary(outcome!.preparation),
      null =>
        'Codex was not opened: ${featureErrorText(controller.codexLaunchActionError)}',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setMode(
    BuildContext context,
    CodexIntegrationStatus status,
    bool enabled,
  ) async {
    final result = await controller.setCodexManagedRoutingEnabled(enabled);
    if (!context.mounted || result == null) {
      return;
    }
    final message = enabled
        ? 'Auto Route is enabled for the next Codex start. Codex files, chats, and local data were not changed.'
        : 'Auto Route is disabled. The next Codex start will use its normal connection.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<CodexManagedLaunchOutcome?> _openCodexWithOptionalRestart(
  BuildContext context,
  AppController controller, {
  String? manualAccountId,
  required String routeLabel,
  required bool offerRestart,
}) async {
  var outcome = await controller.openCodex(manualAccountId: manualAccountId);
  if (!context.mounted ||
      !offerRestart ||
      outcome?.disposition != CodexManagedLaunchDisposition.alreadyRunning) {
    return outcome;
  }
  final confirmed = await showFeatureConfirmation(
    context,
    title: 'Restart Codex and apply this route?',
    message:
        'Codex is already running, so $routeLabel cannot be applied to that process. Save any unsent draft first. HUB will close only the installed Codex AppX processes, refresh and prepare the route, then open Codex again. Chats, settings, and auth files are not replaced.',
    confirmLabel: 'Restart and route',
  );
  if (!confirmed || !context.mounted) {
    return outcome;
  }
  outcome = await controller.restartCodex(manualAccountId: manualAccountId);
  return outcome;
}

String _formatPercent(double? value) {
  if (value == null) {
    return 'Not selected';
  }
  final digits = value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(digits)}% remaining';
}

String formatCodexLaunchExclusionSummary(CodexLaunchPreparation? preparation) {
  if (preparation == null || preparation.exclusions.isEmpty) {
    return 'No trustworthy account is currently eligible, so Codex was not opened.';
  }
  final details = preparation.exclusions
      .take(3)
      .map(
        (item) => '${item.accountLabel}: ${_exclusionReasonLabel(item.reason)}',
      )
      .join(' · ');
  final remaining = preparation.exclusions.length - 3;
  return 'Codex was not opened. $details${remaining > 0 ? ' · +$remaining more' : ''}';
}

String _exclusionReasonLabel(String reason) {
  return switch (reason) {
    'usage_all_windows_unknown' => 'no trustworthy usage window is available',
    'usage_sample_missing' => 'usage has never been sampled',
    'usage_sample_stale' => 'the last usage sample is too old',
    'usage_sample_invalid' => 'the usage sample is invalid',
    'quota_exhausted' => 'remaining quota is exhausted',
    'account_paused' => 'the account is paused',
    'account_reauth_required' => 'sign-in needs to be refreshed',
    'account_quota_exceeded' => 'quota is exceeded',
    'account_rate_limited' => 'the account is rate limited',
    'account_deactivated' => 'the account is deactivated',
    _ => reason.replaceAll('_', ' '),
  };
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppPalette.text, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
