import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/runtime/windows_platform_bridge.dart';
import '../../models/account_operations.dart';
import '../../models/account_summary.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';
import '../formatters.dart';
import 'account_usage_sort_control.dart';
import 'codex_integration_panel.dart';
import 'feature_widgets.dart';

enum _AddAccountAction { oauthBrowser, oauthDevice, importJson }

enum _SubscriptionFilter { all, paid, free }

class AccountsPage extends StatefulWidget {
  const AccountsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final TextEditingController _search = TextEditingController();
  late final ValueNotifier<DateTime> _resetClock;
  Timer? _resetClockTimer;
  String _status = 'all';
  _SubscriptionFilter _subscription = _SubscriptionFilter.all;
  String? _selectedAccountId;
  String? _loadedDetailAccountId;
  AccountTrends? _trends;
  AccountUsageResetCredits? _resetCredits;
  bool _detailsBusy = false;
  ScrollController? _performanceScrollController;
  bool _performanceScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _resetClock = ValueNotifier<DateTime>(DateTime.now());
    _resetClockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _resetClock.value = DateTime.now();
    });
    if (widget.controller.performanceProbe?.syntheticAccountRows != null) {
      _performanceScrollController = ScrollController();
    }
  }

  @override
  void dispose() {
    _resetClockTimer?.cancel();
    _resetClock.dispose();
    _search.dispose();
    _performanceScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.controller.accounts;
    if (section.value == null && section.isBusy) {
      return const FeatureProgress(
        label: 'Loading encrypted account summaries…',
      );
    }
    if (section.value == null) {
      return FeatureFailure(
        title: 'Accounts unavailable',
        error: section.error,
        onRetry: widget.controller.refreshAccounts,
      );
    }

    final allAccounts = section.value!;
    final orderedAllAccounts = widget.controller.orderedAccounts(allAccounts);
    final selectedId =
        allAccounts.any((account) => account.accountId == _selectedAccountId)
        ? _selectedAccountId
        : orderedAllAccounts.firstOrNull?.accountId;

    final sessionStartedAt = widget.controller.sessionStartedAt;
    final refreshFailedIds = widget.controller.accountUsageRefreshFailedIds;
    final query = _search.text.trim().toLowerCase();
    final filtered = orderedAllAccounts
        .where((account) {
          final matchesText =
              query.isEmpty ||
              account.displayName.toLowerCase().contains(query) ||
              account.email.toLowerCase().contains(query) ||
              (account.alias?.toLowerCase().contains(query) ?? false) ||
              (account.workspaceLabel?.toLowerCase().contains(query) ?? false);
          final matchesStatus =
              _status == 'all' ||
              _accountLane(
                    account,
                    sessionStartedAt,
                    refreshFailedAccountIds: refreshFailedIds,
                  ).name ==
                  _status;
          final matchesSubscription = switch (_subscription) {
            _SubscriptionFilter.all => true,
            _SubscriptionFilter.paid => account.hasPaidSubscription,
            _SubscriptionFilter.free => account.isFreePlan,
          };
          return matchesText && matchesStatus && matchesSubscription;
        })
        .toList(growable: false);
    final routeCandidates = orderedAllAccounts
        .where(
          (account) =>
              _isRouteCandidate(account) &&
              _accountSignal(
                    account,
                    sessionStartedAt,
                    refreshFailedAccountIds: refreshFailedIds,
                  ).kind ==
                  _AccountSignalKind.fresh,
        )
        .take(3)
        .toList(growable: false);
    final readyCount = allAccounts
        .where(
          (account) =>
              _accountLane(
                account,
                sessionStartedAt,
                refreshFailedAccountIds: refreshFailedIds,
              ) ==
              _AccountLane.ready,
        )
        .length;
    final attentionCount = allAccounts
        .where(
          (account) =>
              _accountLane(
                account,
                sessionStartedAt,
                refreshFailedAccountIds: refreshFailedIds,
              ) ==
              _AccountLane.attention,
        )
        .length;
    final freeCount = allAccounts.where((account) => account.isFreePlan).length;
    final routableCount = allAccounts.where(_isRouteCandidate).length;
    final refreshSucceededCount =
        widget.controller.accountUsageRefreshSucceededIds.length;
    final refreshFailedCount = refreshFailedIds.length;
    final refreshDetail = section.isBusy
        ? 'Refreshing account quota and subscription signals…'
        : widget.controller.lastAccountUsageRefreshFinishedAt != null
        ? 'Last refresh finished ${formatRelative(widget.controller.lastAccountUsageRefreshFinishedAt)}: '
              '$refreshSucceededCount current, $refreshFailedCount failed. Failed accounts are excluded from Next Route.'
        : 'Choose the next route with current quota evidence. “Fresh this launch” means HUB checked that account after this app opened.';
    _schedulePerformanceScroll(filtered.length);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FeaturePageHeader(
                eyebrow:
                    '${allAccounts.length} TOTAL  ·  $readyCount READY NOW  ·  $routableCount ROUTABLE  ·  $freeCount FREE BLOCKED  ·  $attentionCount ATTENTION',
                title: 'Accounts',
                detail: refreshDetail,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: section.isBusy || !widget.controller.canWrite
                          ? null
                          : () => unawaited(
                              widget.controller.refreshAccountUsage(),
                            ),
                      icon: section.isBusy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        section.isBusy ? 'Refreshing…' : 'Refresh all',
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<_AddAccountAction>(
                      enabled:
                          widget.controller.canWrite &&
                          !widget.controller.accountGlobalActionBusy,
                      onSelected: _handleAddAccount,
                      itemBuilder: (context) =>
                          const <PopupMenuEntry<_AddAccountAction>>[
                            PopupMenuItem(
                              value: _AddAccountAction.oauthBrowser,
                              child: ListTile(
                                leading: Icon(Icons.open_in_browser),
                                title: Text('Sign in with browser'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: _AddAccountAction.oauthDevice,
                              child: ListTile(
                                leading: Icon(Icons.devices_outlined),
                                title: Text('Sign in with device code'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: _AddAccountAction.importJson,
                              child: ListTile(
                                leading: Icon(Icons.file_upload_outlined),
                                title: Text('Import auth.json'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                      child: IgnorePointer(
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add),
                          label: const Text('Add account'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 820;
                  final search = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search accounts',
                        prefixIcon: const Icon(Icons.search_rounded, size: 19),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded, size: 17),
                              ),
                        isDense: true,
                      ),
                    ),
                  );
                  final filters = Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _status,
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All states'),
                            ),
                            DropdownMenuItem(
                              value: 'ready',
                              child: Text('Ready now'),
                            ),
                            DropdownMenuItem(
                              value: 'attention',
                              child: Text('Needs attention'),
                            ),
                            DropdownMenuItem(
                              value: 'offline',
                              child: Text('Offline / exhausted'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _status = value ?? 'all'),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<_SubscriptionFilter>(
                          key: const ValueKey<String>(
                            'account-subscription-filter',
                          ),
                          value: _subscription,
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          items: const <DropdownMenuItem<_SubscriptionFilter>>[
                            DropdownMenuItem(
                              value: _SubscriptionFilter.all,
                              child: Text('All plans'),
                            ),
                            DropdownMenuItem(
                              value: _SubscriptionFilter.paid,
                              child: Text('Paid only'),
                            ),
                            DropdownMenuItem(
                              value: _SubscriptionFilter.free,
                              child: Text('Free only'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _subscription =
                                value ?? _SubscriptionFilter.all,
                          ),
                        ),
                      ),
                      AccountUsageSortControl(controller: widget.controller),
                      const _AccountStateGuideButton(),
                    ],
                  );
                  if (compact) {
                    return Column(
                      children: <Widget>[
                        search,
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerLeft, child: filters),
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: search),
                      const SizedBox(width: 14),
                      filters,
                    ],
                  );
                },
              ),
              if (section.isStale) ...<Widget>[
                const SizedBox(height: 12),
                FeatureWarning(
                  message:
                      'Showing cached account rows. Refresh failed: ${featureErrorText(section.error)}',
                ),
              ],
              if (widget.controller.accountActionError != null) ...<Widget>[
                const SizedBox(height: 12),
                FeatureWarning(
                  error: true,
                  message:
                      'Account action failed: ${featureErrorText(widget.controller.accountActionError)}',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: LayoutBuilder(
              builder: (_, _) {
                final list = _AccountList(
                  accounts: filtered,
                  resetClock: _resetClock,
                  selectedId: selectedId,
                  sessionStartedAt: sessionStartedAt,
                  refreshFailedAccountIds: refreshFailedIds,
                  scrollController: _performanceScrollController,
                  canLaunch:
                      widget.controller.canWrite &&
                      !widget.controller.codexLaunchActionBusy,
                  onSelected: (account) {
                    setState(() {
                      _selectedAccountId = account.accountId;
                      _loadedDetailAccountId = null;
                      _trends = null;
                      _resetCredits = null;
                    });
                  },
                  onOpenCodex: (account) =>
                      unawaited(_openCodexForAccount(account)),
                  onManage: (account) =>
                      unawaited(_showAccountManagement(account)),
                );
                final routes = _NextRouteRail(
                  accounts: routeCandidates,
                  selectedId: selectedId,
                  sessionStartedAt: sessionStartedAt,
                  refreshFailedAccountIds: refreshFailedIds,
                  compact: true,
                  canLaunch:
                      widget.controller.canWrite &&
                      !widget.controller.codexLaunchActionBusy,
                  onSelected: (account) =>
                      setState(() => _selectedAccountId = account.accountId),
                  onOpenCodex: (account) =>
                      unawaited(_openCodexForAccount(account)),
                );
                return Column(
                  children: <Widget>[
                    SizedBox(height: 104, child: routes),
                    const SizedBox(height: 10),
                    Expanded(child: list),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _schedulePerformanceScroll(int rowCount) {
    final targetRows = widget.controller.performanceProbe?.syntheticAccountRows;
    if (_performanceScrollScheduled ||
        targetRows == null ||
        rowCount < targetRows) {
      return;
    }
    _performanceScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runPerformanceScroll(rowCount));
    });
  }

  Future<void> _runPerformanceScroll(int rowCount) async {
    final scrollController = _performanceScrollController;
    final probe = widget.controller.performanceProbe;
    if (!mounted ||
        scrollController == null ||
        !scrollController.hasClients ||
        probe == null) {
      return;
    }
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> next) => timings.addAll(next);
    SchedulerBinding.instance.addTimingsCallback(collect);
    try {
      await scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.linear,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(collect);
      probe.recordAccountScrollTimings(timings, rowCount: rowCount);
    }
  }

  Future<void> _loadDetails(String accountId) async {
    if (_detailsBusy) {
      return;
    }
    setState(() => _detailsBusy = true);
    final results = await Future.wait<Object?>(<Future<Object?>>[
      widget.controller.getAccountTrends(accountId),
      widget.controller.getAccountUsageResetCredits(accountId),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _loadedDetailAccountId = accountId;
      _trends = results[0] as AccountTrends?;
      _resetCredits = results[1] as AccountUsageResetCredits?;
      _detailsBusy = false;
    });
  }

  void _handleAddAccount(_AddAccountAction action) {
    switch (action) {
      case _AddAccountAction.oauthBrowser:
        unawaited(_startOauth(forceMethod: 'browser'));
      case _AddAccountAction.oauthDevice:
        unawaited(_startOauth(forceMethod: 'device'));
      case _AddAccountAction.importJson:
        unawaited(_showImportDialog());
    }
  }

  Future<void> _showImportDialog() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => const _ImportAuthJsonDialog(),
    );
    if (raw == null || !mounted) {
      return;
    }
    final imported = await widget.controller.importAccountJson(raw);
    if (mounted && imported) {
      _showMessage('Account imported without changing the existing store key.');
    }
  }

  Future<void> _startOauth({String? forceMethod, String? accountId}) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continue to OpenAI'),
        content: const Text(
          'OpenAI hosts the authorization page and may identify it as the '
          'official Codex client. OpenHUB owns the local callback and never '
          'receives your password.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || proceed != true) {
      return;
    }
    final flow = await widget.controller.startOauth(
      forceMethod: forceMethod,
      accountId: accountId,
    );
    if (!mounted || flow == null) {
      return;
    }
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OauthFlowDialog(
        controller: widget.controller,
        flow: flow,
        reauthentication: accountId != null,
      ),
    );
    if (mounted && (success ?? false)) {
      _showMessage(
        accountId == null
            ? 'OAuth account added.'
            : 'Account reauthenticated safely.',
      );
    }
  }

  Future<void> _editAlias(AccountSummary account) async {
    final text = TextEditingController(text: account.alias ?? '');
    final value = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit account alias'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Alias',
            helperText: 'Leave blank to use the account identity.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: const Text('Save alias'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null || !mounted) {
      return;
    }
    await widget.controller.setAccountAlias(
      account.accountId,
      value.isEmpty ? null : value,
    );
  }

  Future<void> _probe(AccountSummary account) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Probe this account?',
      message:
          'A tiny upstream request will verify routing and refresh quota state for ${account.displayName}.',
      confirmLabel: 'Run probe',
    );
    if (!confirmed) {
      return;
    }
    final result = await widget.controller.probeAccount(account.accountId);
    if (!mounted || result == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Probe result'),
        content: Text(
          'HTTP ${result.probeStatusCode ?? 'unknown'} · '
          '${result.accountStatusBefore} → ${result.accountStatusAfter}',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetUsage(AccountSummary account) async {
    final count =
        _resetCredits?.availableCount ?? account.availableResetCredits;
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Redeem one reset credit?',
      message:
          '${account.displayName} currently reports $count available credit(s). The backend makes this action idempotent and refreshes quota afterward.',
      confirmLabel: 'Redeem credit',
    );
    if (!confirmed) {
      return;
    }
    final result = await widget.controller.consumeAccountUsageResetCredit(
      account.accountId,
    );
    if (!mounted || result == null) {
      return;
    }
    _showMessage(
      'Reset result: ${result.code.replaceAll('_', ' ')} · ${result.windowsReset} window(s) reset.',
    );
    _loadedDetailAccountId = null;
    await _loadDetails(account.accountId);
  }

  Future<void> _deleteAccount(AccountSummary account) async {
    final deleteHistory = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteAccountDialog(account: account),
    );
    if (deleteHistory == null || !mounted) {
      return;
    }
    await widget.controller.deleteAccount(
      account.accountId,
      deleteHistory: deleteHistory,
    );
    if (mounted && widget.controller.accountActionError == null) {
      setState(() {
        _selectedAccountId = null;
        _loadedDetailAccountId = null;
      });
      _showMessage(
        deleteHistory
            ? 'Account and its retained history were deleted.'
            : 'Account deleted; historical aggregates were retained.',
      );
    }
  }

  Future<void> _showAccountManagement(AccountSummary account) async {
    if (_loadedDetailAccountId != account.accountId && !_detailsBusy) {
      await _loadDetails(account.accountId);
    }
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
          child: Stack(
            children: <Widget>[
              _AccountDetail(
                account: account,
                controller: widget.controller,
                trends: _trends,
                resetCredits: _resetCredits,
                detailsBusy: _detailsBusy,
                onAlias: () => _editAlias(account),
                onProbe: () => _probe(account),
                onResetUsage: () => _resetUsage(account),
                onReauth: () => _startOauth(
                  forceMethod: 'browser',
                  accountId: account.accountId,
                ),
                onDelete: () => _deleteAccount(account),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filledTonal(
                  tooltip: 'Close account details',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCodexForAccount(AccountSummary account) async {
    final outcome = await _openCodexWithRestartOffer(
      context,
      widget.controller,
      account,
    );
    if (!mounted) {
      return;
    }
    final message = _accountLaunchMessage(widget.controller, account, outcome);
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AccountLane { ready, attention, offline }

enum _AccountSignalKind {
  freePlan,
  fresh,
  awaitingSessionRefresh,
  refreshFailed,
  stale,
  usageUnknown,
  rateLimited,
  reauthRequired,
  quotaExhausted,
  paused,
  unavailable,
}

class _AccountSignal {
  const _AccountSignal({
    required this.kind,
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final _AccountSignalKind kind;
  final String label;
  final String detail;
  final IconData icon;
  final Color color;
}

_AccountSignal _accountSignal(
  AccountSummary account,
  DateTime sessionStartedAt, {
  Set<String> refreshFailedAccountIds = const <String>{},
}) {
  final status = account.status.trim().toLowerCase();
  final remaining = account.visibleRemainingPercent;
  if (account.isFreePlan) {
    return const _AccountSignal(
      kind: _AccountSignalKind.freePlan,
      label: 'Free plan · not routable',
      detail: 'Excluded from Smart API, Auto Route, and manual launch',
      icon: Icons.lock_outline_rounded,
      color: AppPalette.red,
    );
  }
  if (status == 'reauth_required') {
    return const _AccountSignal(
      kind: _AccountSignalKind.reauthRequired,
      label: 'Reauth required',
      detail: 'Sign in again before routing',
      icon: Icons.key_off_rounded,
      color: Color(0xFFA78BFA),
    );
  }
  if (status == 'quota_exceeded' || (remaining != null && remaining <= 0)) {
    return const _AccountSignal(
      kind: _AccountSignalKind.quotaExhausted,
      label: 'Quota exhausted',
      detail: 'Unavailable until quota resets',
      icon: Icons.block_rounded,
      color: AppPalette.red,
    );
  }
  if (status == 'paused') {
    return const _AccountSignal(
      kind: _AccountSignalKind.paused,
      label: 'Paused',
      detail: 'Excluded from routing',
      icon: Icons.pause_circle_outline_rounded,
      color: AppPalette.textMuted,
    );
  }
  if (status == 'deactivated') {
    return const _AccountSignal(
      kind: _AccountSignalKind.unavailable,
      label: 'Offline',
      detail: 'Account is deactivated',
      icon: Icons.cloud_off_rounded,
      color: AppPalette.red,
    );
  }
  if (status == 'rate_limited') {
    return const _AccountSignal(
      kind: _AccountSignalKind.rateLimited,
      label: 'Temporarily limited',
      detail: 'Waiting for upstream cooldown',
      icon: Icons.timer_off_outlined,
      color: AppPalette.amber,
    );
  }
  if (account.isEmailDuplicate) {
    return const _AccountSignal(
      kind: _AccountSignalKind.usageUnknown,
      label: 'Duplicate identity',
      detail: 'Review this local account',
      icon: Icons.content_copy_rounded,
      color: AppPalette.amber,
    );
  }
  if (!account.isActive) {
    return _AccountSignal(
      kind: _AccountSignalKind.unavailable,
      label: account.status.replaceAll('_', ' '),
      detail: 'Not available for routing',
      icon: Icons.link_off_rounded,
      color: AppPalette.red,
    );
  }
  if (refreshFailedAccountIds.contains(account.accountId)) {
    return const _AccountSignal(
      kind: _AccountSignalKind.refreshFailed,
      label: 'Refresh failed',
      detail: 'No new quota sample; cached values are excluded',
      icon: Icons.sync_problem_rounded,
      color: AppPalette.amber,
    );
  }
  final sampledAt = account.usageSampleAt?.toUtc();
  if (sampledAt == null || sampledAt.isBefore(sessionStartedAt.toUtc())) {
    return const _AccountSignal(
      kind: _AccountSignalKind.awaitingSessionRefresh,
      label: 'Not refreshed this launch',
      detail: 'Showing the last cached sample',
      icon: Icons.hourglass_top_rounded,
      color: Color(0xFF72A7FF),
    );
  }
  final age = DateTime.now().toUtc().difference(sampledAt);
  if (age > const Duration(minutes: 3)) {
    return _AccountSignal(
      kind: _AccountSignalKind.stale,
      label: 'Refresh overdue',
      detail: 'Last checked ${formatRelative(sampledAt)}',
      icon: Icons.schedule_rounded,
      color: AppPalette.amber,
    );
  }
  if (remaining == null) {
    return const _AccountSignal(
      kind: _AccountSignalKind.usageUnknown,
      label: 'Quota unknown',
      detail: 'Upstream returned no percentage',
      icon: Icons.help_outline_rounded,
      color: AppPalette.amber,
    );
  }
  return _AccountSignal(
    kind: _AccountSignalKind.fresh,
    label: 'Fresh this launch',
    detail: 'Checked ${formatRelative(sampledAt)}',
    icon: Icons.check_circle_rounded,
    color: AppPalette.green,
  );
}

_AccountLane _accountLane(
  AccountSummary account,
  DateTime sessionStartedAt, {
  Set<String> refreshFailedAccountIds = const <String>{},
}) {
  return switch (_accountSignal(
    account,
    sessionStartedAt,
    refreshFailedAccountIds: refreshFailedAccountIds,
  ).kind) {
    _AccountSignalKind.fresh => _AccountLane.ready,
    _AccountSignalKind.awaitingSessionRefresh ||
    _AccountSignalKind.refreshFailed ||
    _AccountSignalKind.stale ||
    _AccountSignalKind.usageUnknown ||
    _AccountSignalKind.rateLimited ||
    _AccountSignalKind.reauthRequired => _AccountLane.attention,
    _AccountSignalKind.freePlan ||
    _AccountSignalKind.quotaExhausted ||
    _AccountSignalKind.paused ||
    _AccountSignalKind.unavailable => _AccountLane.offline,
  };
}

bool _isRouteCandidate(AccountSummary account) {
  final remaining = account.visibleRemainingPercent;
  return !account.isFreePlan &&
      account.isActive &&
      remaining != null &&
      remaining > 0;
}

bool _hasCurrentSessionSample(
  AccountSummary account,
  DateTime sessionStartedAt,
) {
  final sample = account.usageSampleAt?.toUtc();
  return sample != null && !sample.isBefore(sessionStartedAt.toUtc());
}

String _subscriptionStateLabel(
  AccountSummary account,
  DateTime sessionStartedAt,
) {
  final suffix = _hasCurrentSessionSample(account, sessionStartedAt)
      ? 'reported now'
      : 'cached';
  return '${account.subscriptionLabel} · $suffix';
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.accounts,
    required this.resetClock,
    required this.selectedId,
    required this.sessionStartedAt,
    required this.refreshFailedAccountIds,
    required this.onSelected,
    required this.onOpenCodex,
    required this.onManage,
    required this.canLaunch,
    this.scrollController,
  });

  final List<AccountSummary> accounts;
  final ValueListenable<DateTime> resetClock;
  final String? selectedId;
  final DateTime sessionStartedAt;
  final Set<String> refreshFailedAccountIds;
  final ValueChanged<AccountSummary> onSelected;
  final ValueChanged<AccountSummary> onOpenCodex;
  final ValueChanged<AccountSummary> onManage;
  final bool canLaunch;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: resetClock,
      builder: (context, resetNow, _) => _buildList(context, resetNow),
    );
  }

  Widget _buildList(BuildContext context, DateTime resetNow) {
    final compactRows = MediaQuery.sizeOf(context).width < 1150;
    final densePool = accounts.length > 80;
    final grouped = <_AccountLane, List<AccountSummary>>{
      for (final lane in _AccountLane.values)
        lane: accounts
            .where(
              (account) =>
                  _accountLane(
                    account,
                    sessionStartedAt,
                    refreshFailedAccountIds: refreshFailedAccountIds,
                  ) ==
                  lane,
            )
            .toList(growable: false),
    };
    return FeaturePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Expanded(
            child: accounts.isEmpty
                ? const _EmptyAccountList()
                : CustomScrollView(
                    key: const PageStorageKey<String>('native-account-list'),
                    controller: scrollController,
                    // ignore: deprecated_member_use
                    cacheExtent: densePool ? 0 : 250,
                    slivers: <Widget>[
                      const SliverToBoxAdapter(child: SizedBox(height: 2)),
                      for (final lane in _AccountLane.values)
                        if (grouped[lane]!.isNotEmpty) ...<Widget>[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: _AccountLaneHeader(
                                lane: lane,
                                count: grouped[lane]!.length,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            sliver: SliverFixedExtentList(
                              itemExtent: densePool ? 62 : 86,
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final account = grouped[lane]![index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _ConstellationAccountRow(
                                      key: ValueKey<String>(
                                        'account-row-${account.accountId}',
                                      ),
                                      account: account,
                                      now: resetNow,
                                      sessionStartedAt: sessionStartedAt,
                                      signal: _accountSignal(
                                        account,
                                        sessionStartedAt,
                                        refreshFailedAccountIds:
                                            refreshFailedAccountIds,
                                      ),
                                      selected: account.accountId == selectedId,
                                      compact: compactRows,
                                      dense: densePool,
                                      canLaunch: canLaunch,
                                      onSelected: () => onSelected(account),
                                      onOpenCodex: () => onOpenCodex(account),
                                      onManage: () => onManage(account),
                                    ),
                                  );
                                },
                                childCount: grouped[lane]!.length,
                                addAutomaticKeepAlives: false,
                                addSemanticIndexes: false,
                              ),
                            ),
                          ),
                        ],
                      const SliverToBoxAdapter(child: SizedBox(height: 5)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAccountList extends StatelessWidget {
  const _EmptyAccountList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.manage_search_rounded, size: 30),
          SizedBox(height: 9),
          Text('No accounts match this view.'),
          SizedBox(height: 3),
          Text(
            'Clear search or switch the state or plan filter.',
            style: TextStyle(color: AppPalette.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _AccountLaneHeader extends StatelessWidget {
  const _AccountLaneHeader({required this.lane, required this.count});

  final _AccountLane lane;
  final int count;

  @override
  Widget build(BuildContext context) {
    final (label, detail, icon, color) = switch (lane) {
      _AccountLane.ready => (
        'READY NOW',
        'Refreshed in this HUB session and available to route',
        Icons.bolt_rounded,
        AppPalette.green,
      ),
      _AccountLane.attention => (
        'NEEDS ATTENTION',
        'Cached, overdue, limited, or waiting for sign-in',
        Icons.visibility_outlined,
        AppPalette.amber,
      ),
      _AccountLane.offline => (
        'OFFLINE / EXHAUSTED',
        'Will not receive a new routed request',
        Icons.power_off_rounded,
        AppPalette.red,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.85,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.only(left: 10),
              color: color.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstellationAccountRow extends StatelessWidget {
  const _ConstellationAccountRow({
    super.key,
    required this.account,
    required this.now,
    required this.sessionStartedAt,
    required this.signal,
    required this.selected,
    required this.compact,
    required this.dense,
    required this.canLaunch,
    required this.onSelected,
    required this.onOpenCodex,
    required this.onManage,
  });

  final AccountSummary account;
  final DateTime now;
  final DateTime sessionStartedAt;
  final _AccountSignal signal;
  final bool selected;
  final bool compact;
  final bool dense;
  final bool canLaunch;
  final VoidCallback onSelected;
  final VoidCallback onOpenCodex;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    if (dense) {
      return _buildDense(context, now);
    }
    return _buildStandard(context, now);
  }

  Widget _buildStandard(BuildContext context, DateTime now) {
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${account.displayName}, ${_subscriptionStateLabel(account, sessionStartedAt)}, ${_percent(account.visibleRemainingPercent)} remaining, ${_quotaResetSemantics(account, now)}, ${signal.label}',
      child: Material(
        color: selected
            ? AppPalette.cyan.withValues(alpha: 0.085)
            : AppPalette.surfaceRaised.withValues(alpha: 0.58),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: selected
                ? AppPalette.cyan.withValues(alpha: 0.62)
                : AppPalette.outline,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onSelected,
          child: SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: selected ? 4 : 2,
                  color: selected ? AppPalette.cyan : signal.color,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 7, 9),
                    child: Row(
                      children: <Widget>[
                        _AccountAvatar(label: account.displayName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      account.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppPalette.text,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    _subscriptionStateLabel(
                                      account,
                                      sessionStartedAt,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppPalette.textMuted,
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 11.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Tooltip(
                                message:
                                    'Latest quota sample: ${formatTimestamp(account.usageSampleAt)}\nCredential refreshed: ${formatTimestamp(account.lastRefreshAt)}',
                                child: Text(
                                  'Quota checked ${formatRelative(account.usageSampleAt)} · Sign-in refreshed ${formatRelative(account.lastRefreshAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 10.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),
                        _QuotaRing(
                          remaining: account.visibleRemainingPercent,
                          color:
                              signal.kind == _AccountSignalKind.quotaExhausted
                              ? AppPalette.red
                              : AppPalette.cyan,
                        ),
                        const SizedBox(width: 11),
                        _QuotaResetIndicator(
                          account: account,
                          now: now,
                          compact: compact,
                        ),
                        const SizedBox(width: 11),
                        if (!compact)
                          SizedBox(
                            width: 158,
                            child: _AccountSignalBadge(signal: signal),
                          )
                        else
                          SizedBox(
                            width: 142,
                            child: Tooltip(
                              message: '${signal.label} · ${signal.detail}',
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    signal.icon,
                                    color: signal.color,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      signal.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: signal.color,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 5),
                        Tooltip(
                          message: account.isFreePlan
                              ? 'Free subscriptions are excluded from manual Codex launch and every routing mode.'
                              : 'Open Codex with ${account.displayName} for one new process',
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: canLaunch && _isRouteCandidate(account)
                                ? onOpenCodex
                                : null,
                            icon: const Icon(
                              Icons.rocket_launch_outlined,
                              size: 17,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Inspect and manage account',
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: onManage,
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDense(BuildContext context, DateTime now) {
    return Material(
      color: selected
          ? AppPalette.cyan.withValues(alpha: 0.085)
          : AppPalette.surfaceRaised.withValues(alpha: 0.48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? AppPalette.cyan.withValues(alpha: 0.58)
              : AppPalette.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onManage,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: signal.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        account.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Quota checked ${formatRelative(account.usageSampleAt)} · Sign-in refreshed ${formatRelative(account.lastRefreshAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 9.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_percent(account.visibleRemainingPercent)} left',
                  style: const TextStyle(
                    color: AppPalette.text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 9),
                _DenseQuotaResetIndicator(account: account, now: now),
                const SizedBox(width: 9),
                Icon(signal.icon, color: signal.color, size: 17),
                const SizedBox(width: 5),
                _DenseAccountAction(
                  tooltip: account.isFreePlan
                      ? 'Free subscriptions are excluded from manual Codex launch and every routing mode.'
                      : 'Open Codex with ${account.displayName} for one new process',
                  onPressed: canLaunch && _isRouteCandidate(account)
                      ? onOpenCodex
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuotaResetWindow {
  const _QuotaResetWindow({required this.label, required this.resetAt});

  final String label;
  final DateTime resetAt;
}

List<_QuotaResetWindow> _quotaResetWindows(AccountSummary account) {
  return <_QuotaResetWindow>[
    if (account.resetAtPrimary != null)
      _QuotaResetWindow(
        label: _quotaWindowLabel(account.windowMinutesPrimary, fallback: '5H'),
        resetAt: account.resetAtPrimary!,
      ),
    if (account.resetAtSecondary != null)
      _QuotaResetWindow(
        label: _quotaWindowLabel(
          account.windowMinutesSecondary,
          fallback: '7D',
        ),
        resetAt: account.resetAtSecondary!,
      ),
    if (account.resetAtMonthly != null)
      _QuotaResetWindow(
        label: _quotaWindowLabel(account.windowMinutesMonthly, fallback: '30D'),
        resetAt: account.resetAtMonthly!,
      ),
  ];
}

String _quotaWindowLabel(double? minutes, {required String fallback}) {
  if (minutes == null || !minutes.isFinite || minutes <= 0) {
    return fallback;
  }
  final rounded = minutes.round();
  if (rounded >= 1440 && rounded % 1440 == 0) {
    return '${rounded ~/ 1440}D';
  }
  if (rounded >= 60 && rounded % 60 == 0) {
    return '${rounded ~/ 60}H';
  }
  return '${rounded}M';
}

_QuotaResetWindow? _nextQuotaReset(AccountSummary account) {
  final windows = _quotaResetWindows(account);
  if (windows.isEmpty) {
    return null;
  }
  windows.sort((left, right) => left.resetAt.compareTo(right.resetAt));
  return windows.first;
}

String _quotaResetSemantics(AccountSummary account, DateTime now) {
  final windows = _quotaResetWindows(account);
  if (windows.isEmpty) {
    return 'quota reset not reported';
  }
  return windows
      .map(
        (window) =>
            '${window.label} resets ${formatResetCountdown(window.resetAt, now: now)}',
      )
      .join(', ');
}

Color _quotaResetColor(DateTime? resetAt, DateTime now) {
  if (resetAt == null) {
    return AppPalette.textMuted;
  }
  final remaining = resetAt.toUtc().difference(now.toUtc());
  if (remaining <= const Duration(hours: 1)) {
    return AppPalette.amber;
  }
  return AppPalette.cyan;
}

class _QuotaResetIndicator extends StatelessWidget {
  const _QuotaResetIndicator({
    required this.account,
    required this.now,
    required this.compact,
  });

  final AccountSummary account;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final allWindows = _quotaResetWindows(account);
    final windows = compact && allWindows.isNotEmpty
        ? <_QuotaResetWindow>[_nextQuotaReset(account)!]
        : allWindows;
    final resetAt = windows.isEmpty ? null : windows.first.resetAt;
    final accent = _quotaResetColor(resetAt, now);
    final tooltip = windows.isEmpty
        ? 'Quota reset schedule was not reported by the account.'
        : windows
              .map(
                (window) =>
                    '${window.label}: ${formatTimestamp(window.resetAt)}',
              )
              .join('\n');

    return Tooltip(
      message: tooltip,
      child: Container(
        key: ValueKey<String>('quota-reset-${account.accountId}'),
        width: compact ? 150 : 188,
        height: 62,
        padding: const EdgeInsets.fromLTRB(9, 3, 9, 3),
        decoration: BoxDecoration(
          color: AppPalette.surfaceStrong.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.34)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.schedule_rounded, size: 12, color: accent),
                const SizedBox(width: 5),
                Text(
                  compact ? 'NEXT RESET' : 'QUOTA RESET',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (windows.isEmpty)
              const Text(
                'Not reported',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              for (final window in windows)
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 30,
                      child: Text(
                        window.label,
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 9.5,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatResetCountdown(window.resetAt, now: now),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _quotaResetColor(window.resetAt, now),
                          fontSize: windows.length > 2 ? 11.4 : 12.8,
                          height: windows.length > 2 ? 1.05 : 1.18,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class _DenseQuotaResetIndicator extends StatelessWidget {
  const _DenseQuotaResetIndicator({required this.account, required this.now});

  final AccountSummary account;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final window = _nextQuotaReset(account);
    final color = _quotaResetColor(window?.resetAt, now);
    final countdown = formatResetCountdown(window?.resetAt, now: now);
    final label = window == null ? countdown : '${window.label} · $countdown';
    final text = Text(
      label,
      key: ValueKey<String>('quota-reset-dense-${account.accountId}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
    if (window == null) {
      return text;
    }
    return Tooltip(
      message: '${window.label}: ${formatTimestamp(window.resetAt)}',
      child: text,
    );
  }
}

class _DenseAccountAction extends StatelessWidget {
  const _DenseAccountAction({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: SizedBox.square(
          dimension: 32,
          child: InkResponse(
            onTap: onPressed,
            radius: 18,
            child: Icon(
              Icons.rocket_launch_outlined,
              size: 16,
              color: enabled ? AppPalette.text : AppPalette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuotaRing extends StatelessWidget {
  const _QuotaRing({required this.remaining, required this.color});

  final double? remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = ((remaining ?? 0) / 100).clamp(0.0, 1.0);
    return Tooltip(
      message: remaining == null
          ? 'Remaining usage was not reported'
          : '${_percent(remaining)} remaining',
      child: SizedBox.square(
        dimension: 50,
        child: CustomPaint(
          painter: _QuotaRingPainter(value: value, color: color),
          child: Center(
            child: Text(
              remaining == null ? '—' : '${remaining!.round()}',
              style: TextStyle(
                color: remaining == null
                    ? AppPalette.textMuted
                    : AppPalette.text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuotaRingPainter extends CustomPainter {
  const _QuotaRingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const start = -1.5707963267948966;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - 5) / 2;
    final background = Paint()
      ..color = AppPalette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, background);
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        6.283185307179586 * value,
        false,
        foreground,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QuotaRingPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class _AccountSignalBadge extends StatelessWidget {
  const _AccountSignalBadge({required this.signal});

  final _AccountSignal signal;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${signal.label} · ${signal.detail}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: signal.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: signal.color.withValues(alpha: 0.24)),
            ),
            child: Icon(signal.icon, color: signal.color, size: 17),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  signal.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: signal.color,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  signal.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 10.2,
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

class _AccountStateGuideButton extends StatelessWidget {
  const _AccountStateGuideButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'How account states and routing eligibility work',
      child: IconButton.outlined(
        visualDensity: VisualDensity.compact,
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Account state guide'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Ready now means HUB refreshed that paid account successfully after this app opened and it still has reported quota. Next Route ranks only those accounts.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Free subscriptions stay safely stored and refreshable, but OpenHUB excludes them from Smart API, Auto Route, manual Codex launch, and every fallback path.',
                  ),
                  SizedBox(height: 16),
                  _AccountsLegend(),
                ],
              ),
            ),
            actions: <Widget>[_CloseDialogButton()],
          ),
        ),
        icon: const Icon(Icons.info_outline_rounded, size: 18),
      ),
    );
  }
}

class _CloseDialogButton extends StatelessWidget {
  const _CloseDialogButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Got it'),
    );
  }
}

class _AccountsLegend extends StatelessWidget {
  const _AccountsLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 15,
      runSpacing: 6,
      children: <Widget>[
        _LegendItem(color: AppPalette.red, label: 'Free plan · not routable'),
        _LegendItem(color: AppPalette.green, label: 'Fresh this launch'),
        _LegendItem(
          color: Color(0xFF72A7FF),
          label: 'Cached · not refreshed since opening HUB',
        ),
        _LegendItem(color: AppPalette.amber, label: 'Stale / limited'),
        _LegendItem(color: AppPalette.red, label: 'Quota exhausted'),
        _LegendItem(color: Color(0xFFA78BFA), label: 'Reauth required'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppPalette.textMuted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _NextRouteRail extends StatelessWidget {
  const _NextRouteRail({
    required this.accounts,
    required this.selectedId,
    required this.sessionStartedAt,
    required this.refreshFailedAccountIds,
    required this.compact,
    required this.canLaunch,
    required this.onSelected,
    required this.onOpenCodex,
  });

  final List<AccountSummary> accounts;
  final String? selectedId;
  final DateTime sessionStartedAt;
  final Set<String> refreshFailedAccountIds;
  final bool compact;
  final bool canLaunch;
  final ValueChanged<AccountSummary> onSelected;
  final ValueChanged<AccountSummary> onOpenCodex;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      padding: const EdgeInsets.all(12),
      color: AppPalette.surface.withValues(alpha: 0.97),
      child: compact ? _buildCompact(context) : _buildWide(context),
    );
  }

  Widget _buildWide(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.alt_route_rounded,
              color: AppPalette.cyan,
              size: 18,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'NEXT ROUTE',
                style: TextStyle(
                  color: AppPalette.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            FeatureBadge(label: 'AUTO', color: AppPalette.cyan),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Only accounts refreshed successfully in this HUB session are ranked here. Confirm real traffic in Traffic.',
          style: TextStyle(
            color: AppPalette.textMuted,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: accounts.isEmpty
              ? const _NoRouteCandidates()
              : ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (context, index) => _RouteCandidateCard(
                    key: ValueKey<String>(
                      'next-route-${accounts[index].accountId}',
                    ),
                    account: accounts[index],
                    rank: index,
                    signal: _accountSignal(
                      accounts[index],
                      sessionStartedAt,
                      refreshFailedAccountIds: refreshFailedAccountIds,
                    ),
                    selected: accounts[index].accountId == selectedId,
                    compact: false,
                    canLaunch: canLaunch,
                    onSelected: () => onSelected(accounts[index]),
                    onOpenCodex: () => onOpenCodex(accounts[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.alt_route_rounded, color: AppPalette.cyan, size: 20),
              SizedBox(height: 6),
              Text(
                'NEXT ROUTE',
                style: TextStyle(
                  color: AppPalette.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Refreshed this launch',
                style: TextStyle(color: AppPalette.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 17),
        Expanded(
          child: accounts.isEmpty
              ? const _NoRouteCandidates()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (context, index) => SizedBox(
                    width: 238,
                    child: _RouteCandidateCard(
                      key: ValueKey<String>(
                        'next-route-${accounts[index].accountId}',
                      ),
                      account: accounts[index],
                      rank: index,
                      signal: _accountSignal(
                        accounts[index],
                        sessionStartedAt,
                        refreshFailedAccountIds: refreshFailedAccountIds,
                      ),
                      selected: accounts[index].accountId == selectedId,
                      compact: true,
                      canLaunch: canLaunch,
                      onSelected: () => onSelected(accounts[index]),
                      onOpenCodex: () => onOpenCodex(accounts[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoRouteCandidates extends StatelessWidget {
  const _NoRouteCandidates();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No account has finished a successful refresh in this HUB session.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.textMuted, fontSize: 11),
      ),
    );
  }
}

class _RouteCandidateCard extends StatelessWidget {
  const _RouteCandidateCard({
    required this.account,
    required this.rank,
    required this.signal,
    required this.selected,
    required this.compact,
    required this.canLaunch,
    required this.onSelected,
    required this.onOpenCodex,
    super.key,
  });

  final AccountSummary account;
  final int rank;
  final _AccountSignal signal;
  final bool selected;
  final bool compact;
  final bool canLaunch;
  final VoidCallback onSelected;
  final VoidCallback onOpenCodex;

  @override
  Widget build(BuildContext context) {
    final rankLabel = switch (rank) {
      0 => 'BEST NOW',
      1 => 'RUNNER-UP',
      _ => 'FALLBACK',
    };
    final rankColor = switch (rank) {
      0 => AppPalette.green,
      1 => AppPalette.cyan,
      _ => AppPalette.amber,
    };
    return Material(
      color: selected
          ? AppPalette.cyan.withValues(alpha: 0.09)
          : AppPalette.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: selected
              ? AppPalette.cyan.withValues(alpha: 0.55)
              : AppPalette.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelected,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 12,
            vertical: compact ? 9 : 10,
          ),
          child: Row(
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rankColor.withValues(alpha: 0.11),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: rankColor.withValues(alpha: 0.48),
                      ),
                    ),
                    child: Text(
                      '${rank + 1}',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!compact) ...<Widget>[
                    Container(
                      width: 1,
                      height: 28,
                      color: rankColor.withValues(alpha: 0.25),
                    ),
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: rankColor,
                      size: 12,
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      rankLabel,
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.72,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.text,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_percent(account.visibleRemainingPercent)} left · ${signal.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 10.6,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Open Codex with ${account.displayName}',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canLaunch ? onOpenCodex : null,
                  icon: const Icon(Icons.rocket_launch_outlined, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDetail extends StatelessWidget {
  const _AccountDetail({
    required this.account,
    required this.controller,
    required this.trends,
    required this.resetCredits,
    required this.detailsBusy,
    required this.onAlias,
    required this.onProbe,
    required this.onResetUsage,
    required this.onReauth,
    required this.onDelete,
  });

  final AccountSummary account;
  final AppController controller;
  final AccountTrends? trends;
  final AccountUsageResetCredits? resetCredits;
  final bool detailsBusy;
  final VoidCallback onAlias;
  final VoidCallback onProbe;
  final VoidCallback onResetUsage;
  final VoidCallback onReauth;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final busy = controller.mutatingAccountIds.contains(account.accountId);
    final freePlan = account.isFreePlan;
    return FeaturePanel(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AccountAvatar(label: account.displayName, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        account.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        account.email,
                        style: const TextStyle(color: AppPalette.textMuted),
                      ),
                      if (account.workspaceLabel != null)
                        Text(
                          '${account.workspaceLabel} · ${account.seatType ?? 'seat'}',
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                _AccountStatusBadge(status: account.status),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: controller.canWrite && !busy ? onAlias : null,
                  tooltip: 'Edit alias',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            if (freePlan) ...<Widget>[
              const SizedBox(height: 12),
              const FeatureWarning(
                error: true,
                message:
                    'Free subscription: this account remains stored and can be refreshed, but it is never used by Smart API, Auto Route, Next Route, manual Codex launch, sticky fallback, or single-account routing.',
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Tooltip(
                  message: freePlan
                      ? 'Unavailable: Free subscriptions are excluded from every routing mode.'
                      : 'Start a new managed Codex process with this account.',
                  child: FilledButton.icon(
                    onPressed:
                        controller.canWrite &&
                            account.isActive &&
                            !freePlan &&
                            !controller.codexLaunchActionBusy
                        ? () => unawaited(_openCodexWithThisAccount(context))
                        : null,
                    icon: controller.codexLaunchActionBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_new),
                    label: const Text('Open Codex with this account'),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: const Text(
                    'Starts a new routed process. If Codex is already open, HUB offers a confirmed full restart first. The selected account supplies API usage; the visible Codex profile, configuration, chats, and local data are not swapped.',
                    style: TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Subscription and connection'),
            const SizedBox(height: 9),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _MiniMetric(
                  label: 'Subscription',
                  value: _subscriptionStateLabel(
                    account,
                    controller.sessionStartedAt,
                  ),
                ),
                _MiniMetric(
                  label: 'Workspace',
                  value: account.workspaceSummary,
                ),
                _MiniMetric(
                  label: 'Seat',
                  value: account.seatType?.trim().isNotEmpty ?? false
                      ? account.seatType!.trim()
                      : 'Not reported',
                ),
                _MiniMetric(
                  label: 'Usage connection',
                  value: account.usageConnectionLabel,
                ),
                _MiniMetric(
                  label: 'Last quota sample',
                  value:
                      '${formatRelative(account.usageSampleAt)} · ${formatTimestamp(account.usageSampleAt)}',
                ),
                _MiniMetric(
                  label: 'Credential refreshed',
                  value:
                      '${formatRelative(account.lastRefreshAt)} · ${formatTimestamp(account.lastRefreshAt)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hasCurrentSessionSample(account, controller.sessionStartedAt)
                  ? 'The plan was reported alongside current-session account telemetry. HUB still labels it as reported data, not billing proof.'
                  : 'This plan label is cached and may be outdated. Refresh must finish successfully before HUB treats the account as current or offers it in Next Route.',
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _QuotaOverview(account: account),
            const SizedBox(height: 18),
            _RequestUsagePanel(account: account),
            const SizedBox(height: 18),
            _SectionTitle(
              title: 'Quota trend',
              trailing: detailsBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 9),
            _TrendPanel(trends: trends),
            const SizedBox(height: 18),
            _SectionTitle(title: 'Routing and safeguards'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: account.routingPolicy,
              decoration: const InputDecoration(labelText: 'Routing policy'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(
                  value: 'burn_first',
                  child: Text('Burn first'),
                ),
                DropdownMenuItem(value: 'preserve', child: Text('Preserve')),
              ],
              onChanged: !controller.canWrite || busy || freePlan
                  ? null
                  : (value) {
                      if (value != null && value != account.routingPolicy) {
                        unawaited(
                          controller.updateAccountRoutingPolicy(
                            account.accountId,
                            value,
                          ),
                        );
                      }
                    },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: account.limitWarmupEnabled,
              title: const Text('Limit warmup'),
              subtitle: const Text(
                'Allow safe background warmup near idle reset windows.',
              ),
              onChanged: !controller.canWrite || busy || freePlan
                  ? null
                  : (value) => unawaited(
                      controller.updateAccountLimitWarmup(
                        account.accountId,
                        value,
                      ),
                    ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: account.securityWorkAuthorized,
              title: const Text('Security work authorized'),
              subtitle: const Text(
                'Only enable for an account whose terms permit security work.',
              ),
              onChanged: !controller.canWrite || busy
                  ? null
                  : (value) => unawaited(
                      controller.updateAccountSecurityAuthorization(
                        account.accountId,
                        value,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: <Widget>[
                if (account.isActive)
                  OutlinedButton.icon(
                    onPressed: controller.canWrite && !busy
                        ? () => unawaited(_pause(context))
                        : null,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pause'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: controller.canWrite && !busy
                        ? () => unawaited(
                            controller.reactivateAccount(account.accountId),
                          )
                        : null,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Reactivate'),
                  ),
                OutlinedButton.icon(
                  onPressed: controller.canWrite && !busy ? onProbe : null,
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: const Text('Probe'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      controller.canWrite &&
                          !busy &&
                          (resetCredits?.availableCount ??
                                  account.availableResetCredits) >
                              0
                      ? onResetUsage
                      : null,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(
                    'Reset credit (${resetCredits?.availableCount ?? account.availableResetCredits})',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: controller.canWrite && !busy ? onReauth : null,
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: const Text('Reauthenticate'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.red,
                  ),
                  onPressed: controller.canWrite && !busy ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
            if (account.deactivationReason != null) ...<Widget>[
              const SizedBox(height: 14),
              FeatureWarning(
                message: 'Backend status: ${account.deactivationReason}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pause(BuildContext context) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Pause this account?',
      message:
          '${account.displayName} will stop receiving new routed requests. Credentials and history remain intact.',
      confirmLabel: 'Pause account',
    );
    if (confirmed) {
      await controller.pauseAccount(account.accountId);
    }
  }

  Future<void> _openCodexWithThisAccount(BuildContext context) async {
    final outcome = await _openCodexWithRestartOffer(
      context,
      controller,
      account,
    );
    if (!context.mounted) {
      return;
    }
    final message = _accountLaunchMessage(controller, account, outcome);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<CodexManagedLaunchOutcome?> _openCodexWithRestartOffer(
  BuildContext context,
  AppController controller,
  AccountSummary account,
) async {
  var outcome = await controller.openCodex(manualAccountId: account.accountId);
  if (!context.mounted ||
      outcome?.disposition != CodexManagedLaunchDisposition.alreadyRunning) {
    return outcome;
  }
  final confirmed = await showFeatureConfirmation(
    context,
    title: 'Restart Codex with this account?',
    message:
        'Codex is already running, so ${account.displayName} cannot be applied to that process. Save any unsent draft first. HUB will close only the installed Codex AppX processes, prepare this account route, and open Codex again. Chats, settings, and auth files are not replaced.',
    confirmLabel: 'Restart and route',
  );
  if (!confirmed || !context.mounted) {
    return outcome;
  }
  outcome = await controller.restartCodex(manualAccountId: account.accountId);
  return outcome;
}

String _accountLaunchMessage(
  AppController controller,
  AccountSummary account,
  CodexManagedLaunchOutcome? outcome,
) {
  return switch (outcome?.disposition) {
    CodexManagedLaunchDisposition.launchedManaged =>
      'Codex restarted with API usage routed through ${account.displayName}. The visible Codex profile stays unchanged by design; send a prompt and verify the account in Traffic.',
    CodexManagedLaunchDisposition.alreadyRunning =>
      'Codex stayed on its existing process, so ${account.displayName} was not applied.',
    CodexManagedLaunchDisposition.blocked => formatCodexLaunchExclusionSummary(
      outcome!.preparation,
    ),
    CodexManagedLaunchDisposition.launchedNormal =>
      'Codex opened normally; ${account.displayName} was not applied.',
    null =>
      'Codex was not opened. Codex files and local data remain unchanged: ${featureErrorText(controller.codexLaunchActionError)}',
  };
}

class _QuotaOverview extends StatelessWidget {
  const _QuotaOverview({required this.account});

  final AccountSummary account;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, double? remaining, DateTime? resetAt})>[
      (
        label: 'Primary',
        remaining: account.usage?.primaryRemainingPercent,
        resetAt: account.resetAtPrimary,
      ),
      (
        label: 'Secondary',
        remaining: account.usage?.secondaryRemainingPercent,
        resetAt: account.resetAtSecondary,
      ),
      if (account.usage?.monthlyRemainingPercent != null)
        (
          label: 'Monthly',
          remaining: account.usage?.monthlyRemainingPercent,
          resetAt: account.resetAtMonthly,
        ),
    ];
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(row.label)),
                      Text(
                        '${_percent(row.remaining)} remaining',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                    value: ((row.remaining ?? 0) / 100).clamp(0, 1),
                    backgroundColor: AppPalette.outline,
                    color: (row.remaining ?? 0) < 20
                        ? AppPalette.amber
                        : AppPalette.cyan,
                  ),
                  if (row.resetAt != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Resets ${formatRelative(row.resetAt)}',
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _RequestUsagePanel extends StatelessWidget {
  const _RequestUsagePanel({required this.account});

  final AccountSummary account;

  @override
  Widget build(BuildContext context) {
    final usage = account.requestUsage;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _MiniMetric(label: 'Requests', value: '${usage?.requestCount ?? 0}'),
        _MiniMetric(label: 'Tokens', value: '${usage?.totalTokens ?? 0}'),
        _MiniMetric(
          label: 'Cached input',
          value: '${usage?.cachedInputTokens ?? 0}',
        ),
        _MiniMetric(
          label: 'Cost',
          value: '\$${(usage?.totalCostUsd ?? 0).toStringAsFixed(2)}',
        ),
        _MiniMetric(
          label: 'Credit balance',
          value: account.creditsUnlimited == true
              ? 'Unlimited'
              : account.creditsBalance?.toStringAsFixed(1) ?? '—',
        ),
        _MiniMetric(
          label: 'Access token',
          value: account.auth?.access?.state ?? 'unknown',
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
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
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 10.5),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.trends});

  final AccountTrends? trends;

  @override
  Widget build(BuildContext context) {
    final points = trends?.primary ?? const <UsageTrendPoint>[];
    if (points.isEmpty) {
      return Container(
        height: 78,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.outline),
        ),
        child: const Text('No primary-window trend samples yet.'),
      );
    }
    return Container(
      height: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.outline),
      ),
      child: CustomPaint(
        painter: _TrendPainter(points.map((point) => point.value).toList()),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y = size.height * (1 - (values[index] / 100).clamp(0, 1));
      index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppPalette.cyan
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return !listEquals(values, oldDelegate.values);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        ...<Widget?>[trailing].whereType<Widget>(),
      ],
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.label, this.large = false});

  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty
        ? '?'
        : label.trim().characters.first.toUpperCase();
    return Container(
      width: large ? 48 : 36,
      height: large ? 48 : 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.cyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(large ? 14 : 10),
        border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.22)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: AppPalette.cyan,
          fontSize: large ? 18 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AccountStatusBadge extends StatelessWidget {
  const _AccountStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppPalette.green,
      'paused' => AppPalette.textMuted,
      'rate_limited' => AppPalette.amber,
      _ => AppPalette.red,
    };
    return FeatureBadge(label: status.replaceAll('_', ' '), color: color);
  }
}

class _ImportAuthJsonDialog extends StatefulWidget {
  const _ImportAuthJsonDialog();

  @override
  State<_ImportAuthJsonDialog> createState() => _ImportAuthJsonDialogState();
}

class _ImportAuthJsonDialogState extends State<_ImportAuthJsonDialog> {
  final TextEditingController _raw = TextEditingController();
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _raw.clear();
    _raw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import auth.json'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const FeatureWarning(
              message:
                  'Paste the file contents locally. The native client sends them only to the loopback backend and never writes them into its source tree.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _raw,
              autofocus: true,
              obscureText: !_visible,
              maxLines: _visible ? 9 : 1,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'auth.json content',
                errorText: _error,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Import locally')),
      ],
    );
  }

  void _submit() {
    final raw = _raw.text.trim();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('The root must be a JSON object.');
      }
      Navigator.pop(context, raw);
    } on FormatException catch (error) {
      setState(() => _error = 'Invalid JSON: ${error.message}');
    }
  }
}

class _OauthFlowDialog extends StatefulWidget {
  const _OauthFlowDialog({
    required this.controller,
    required this.flow,
    required this.reauthentication,
  });

  final AppController controller;
  final OauthStartResult flow;
  final bool reauthentication;

  @override
  State<_OauthFlowDialog> createState() => _OauthFlowDialogState();
}

class _OauthFlowDialogState extends State<_OauthFlowDialog>
    with WidgetsBindingObserver {
  final WindowsPlatformBridge _platform = const WindowsPlatformBridge();
  final TextEditingController _callback = TextEditingController();
  Timer? _timer;
  String _status = 'pending';
  String? _error;
  bool _busy = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (_visible == visible) {
      return;
    }
    _visible = visible;
    if (visible) {
      _startPolling();
      unawaited(_poll());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _callback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    return AlertDialog(
      title: Text(
        widget.reauthentication ? 'Reauthenticate account' : 'Add account',
      ),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                FeatureBadge(
                  label: _status,
                  color: _status == 'success'
                      ? AppPalette.green
                      : _status == 'error'
                      ? AppPalette.red
                      : AppPalette.cyan,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (flow.method == 'device') ...<Widget>[
              const Text('Open the verification page and enter this code:'),
              const SizedBox(height: 9),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SelectableText(
                      flow.userCode ?? 'Code unavailable',
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: flow.userCode == null
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: flow.userCode!),
                          ),
                    tooltip: 'Copy code',
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
            ] else ...<Widget>[
              const Text(
                'OpenAI hosts this authorization page and may show the official Codex client identity. Complete sign-in there; the local callback and this polling dialog belong to OpenHUB.',
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              FeatureWarning(error: true, message: _error!),
            ],
            if (flow.method == 'browser') ...<Widget>[
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Manual callback fallback'),
                children: <Widget>[
                  TextField(
                    controller: _callback,
                    decoration: const InputDecoration(
                      labelText: 'Paste the full callback URL',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _submitCallback,
                      child: const Text('Submit callback'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        if (flow.authorizationUrl != null || flow.verificationUrl != null)
          TextButton.icon(
            onPressed: _openUrl,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open sign-in page'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _begin() async {
    await _openUrl();
    if (widget.flow.method == 'device') {
      await _complete();
      if (!mounted || _status == 'success' || _status == 'error') {
        return;
      }
    }
    _startPolling();
  }

  void _startPolling() {
    if (!_visible ||
        !mounted ||
        _timer?.isActive == true ||
        _status == 'success' ||
        _status == 'error') {
      return;
    }
    final seconds = widget.flow.intervalSeconds ?? 2;
    _timer = Timer.periodic(
      Duration(seconds: seconds.clamp(1, 30)),
      (_) => unawaited(_poll()),
    );
  }

  Future<void> _openUrl() async {
    final url = widget.flow.method == 'device'
        ? widget.flow.verificationUrl
        : widget.flow.authorizationUrl;
    if (url == null) {
      return;
    }
    try {
      await _platform.openExternalUrl(url);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not open the browser: $error');
      }
    }
  }

  Future<void> _poll() async {
    if (_busy || _status == 'success' || _status == 'error') {
      return;
    }
    final status = await widget.controller.getOauthStatus(
      flowId: widget.flow.flowId,
    );
    if (!mounted || status == null) {
      return;
    }
    setState(() {
      _status = status.status;
      _error = status.errorMessage;
    });
    if (status.succeeded) {
      await _complete();
    } else if (status.failed) {
      _timer?.cancel();
    }
  }

  Future<void> _complete() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final status = await widget.controller.completeOauth(widget.flow);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (status != null) {
        _status = status.status;
        _error = status.errorMessage;
      }
    });
    if (status?.succeeded ?? false) {
      _timer?.cancel();
      Navigator.pop(context, true);
    }
  }

  Future<void> _submitCallback() async {
    final raw = _callback.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      setState(() => _error = 'Paste the complete callback URL.');
      return;
    }
    setState(() => _busy = true);
    final status = await widget.controller.submitManualOauthCallback(
      widget.flow,
      raw,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (status != null) {
        _status = status.status;
        _error = status.errorMessage;
      }
    });
    if (status?.succeeded ?? false) {
      _timer?.cancel();
      Navigator.pop(context, true);
    }
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.account});

  final AccountSummary account;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _confirmation = TextEditingController();
  bool _deleteHistory = false;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account permanently?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FeatureWarning(
              error: true,
              message:
                  'This removes ${widget.account.displayName} from the encrypted account store. This cannot be undone from the native UI.',
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _deleteHistory,
              title: const Text('Also delete retained usage history'),
              onChanged: (value) =>
                  setState(() => _deleteHistory = value ?? false),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmation,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
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
          style: FilledButton.styleFrom(backgroundColor: AppPalette.red),
          onPressed: _confirmation.text == 'DELETE'
              ? () => Navigator.pop(context, _deleteHistory)
              : null,
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}

String _percent(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(value < 10 ? 1 : 0)}%';
