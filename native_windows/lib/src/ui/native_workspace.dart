import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/runtime/backend_supervisor.dart';
import '../models/account_summary.dart';
import '../models/dashboard_overview.dart';
import '../models/dashboard_activity.dart';
import '../state/app_controller.dart';
import '../state/async_section.dart';
import 'app_theme.dart';
import 'features/api_keys_page.dart';
import 'features/accounts_page.dart';
import 'features/automations_page.dart';
import 'features/codex_pulse_page.dart';
import 'features/reports_page.dart';
import 'features/settings_page.dart';
import 'formatters.dart';

class NativeWorkspace extends StatelessWidget {
  const NativeWorkspace({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.runtime.isReady) {
          return _RuntimeGate(controller: controller);
        }
        if (controller.auth.value == null || controller.auth.isBusy) {
          if (controller.auth.error != null) {
            return _AuthLoadFailure(controller: controller);
          }
          return const _CenteredProgress(label: 'Establishing local session…');
        }
        if (!(controller.auth.value?.authenticated ?? false)) {
          return _LoginGate(controller: controller);
        }
        return _AppShell(controller: controller);
      },
    );
  }
}

class _RuntimeGate extends StatelessWidget {
  const _RuntimeGate({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final runtime = controller.runtime;
    final isBusy =
        runtime.phase == RuntimePhase.checking ||
        runtime.phase == RuntimePhase.starting;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppPalette.outline),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x50000000),
                    blurRadius: 36,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppPalette.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Center(child: OpenHubMark(size: 27)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'OpenHUB',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isBusy
                                    ? 'Checking the pinned local runtime'
                                    : 'Local runtime unavailable',
                              ),
                            ],
                          ),
                        ),
                        if (isBusy)
                          const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _PathFact(
                      label: 'Endpoint',
                      value: controller.config.endpoint.toString(),
                    ),
                    _PathFact(
                      label: 'Data',
                      value: controller.config.dataDirectory.path,
                    ),
                    _PathFact(
                      label: 'Backend',
                      value:
                          controller.config.backendExecutable?.path ??
                          'Attach-only; pinned sidecar not found',
                    ),
                    if (!isBusy) ...<Widget>[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppPalette.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppPalette.red.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          _errorText(runtime.error),
                          style: const TextStyle(color: AppPalette.red),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => unawaited(controller.initialize()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry local startup'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathFact extends StatelessWidget {
  const _PathFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 82,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AppPalette.text,
                fontFamily: 'Consolas',
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthLoadFailure extends StatelessWidget {
  const _AuthLoadFailure({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.lock_clock_outlined,
                  color: AppPalette.amber,
                  size: 42,
                ),
                const SizedBox(height: 18),
                Text(
                  'Could not establish dashboard access',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  _errorText(controller.auth.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => unawaited(controller.refreshAuth()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry session check'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginGate extends StatefulWidget {
  const _LoginGate({required this.controller});

  final AppController controller;

  @override
  State<_LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<_LoginGate> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _totp = TextEditingController();
  bool _obscure = true;
  bool _guestMode = false;

  @override
  void dispose() {
    _password.dispose();
    _totp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.auth.value!;
    final needsTotp =
        session.passwordSessionActive && session.totpRequiredOnLogin;
    final guestPasswordMode = _guestMode && session.guestPasswordRequired;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppPalette.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppPalette.cyan,
                      size: 34,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      needsTotp
                          ? 'Verify two-factor code'
                          : guestPasswordMode
                          ? 'Unlock read-only guest access'
                          : 'Unlock local dashboard',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      needsTotp
                          ? 'Complete the existing dashboard session. The code stays on loopback.'
                          : guestPasswordMode
                          ? 'Use the configured guest password. This session cannot mutate local data.'
                          : 'Use the password already configured for this OpenHUB store.',
                    ),
                    const SizedBox(height: 24),
                    if (needsTotp)
                      TextField(
                        controller: _totp,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Authenticator code',
                          prefixIcon: Icon(Icons.pin_outlined),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _submitTotp(),
                      )
                    else
                      TextField(
                        controller: _password,
                        autofocus: true,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: guestPasswordMode
                              ? 'Guest password'
                              : 'Dashboard password',
                          prefixIcon: const Icon(Icons.password_outlined),
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => guestPasswordMode
                            ? _submitGuestPassword()
                            : _submitPassword(),
                      ),
                    if (widget.controller.authActionError != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _errorText(widget.controller.authActionError),
                        style: const TextStyle(color: AppPalette.red),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.controller.authActionBusy
                            ? null
                            : needsTotp
                            ? _submitTotp
                            : guestPasswordMode
                            ? _submitGuestPassword
                            : _submitPassword,
                        child: widget.controller.authActionBusy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                needsTotp
                                    ? 'Verify'
                                    : guestPasswordMode
                                    ? 'Continue read-only'
                                    : 'Sign in',
                              ),
                      ),
                    ),
                    if (guestPasswordMode) ...<Widget>[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: widget.controller.authActionBusy
                              ? null
                              : () => setState(() {
                                  _guestMode = false;
                                  _password.clear();
                                }),
                          child: const Text('Use administrator password'),
                        ),
                      ),
                    ] else if (session.guestAccessEnabled &&
                        !needsTotp) ...<Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: widget.controller.authActionBusy
                              ? null
                              : () {
                                  if (session.guestPasswordRequired) {
                                    setState(() {
                                      _guestMode = true;
                                      _password.clear();
                                    });
                                  } else {
                                    unawaited(widget.controller.loginGuest());
                                  }
                                },
                          child: Text(
                            session.guestPasswordRequired
                                ? 'Guest password required'
                                : 'Continue read-only as guest',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitPassword() {
    if (_password.text.isNotEmpty) {
      unawaited(widget.controller.loginPassword(_password.text));
    }
  }

  void _submitGuestPassword() {
    if (_password.text.isNotEmpty) {
      unawaited(widget.controller.loginGuest(password: _password.text));
    }
  }

  void _submitTotp() {
    if (_totp.text.length == 6) {
      unawaited(widget.controller.verifyTotp(_totp.text));
    }
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final minimal = constraints.maxWidth <= 640;
          final expanded = constraints.maxWidth >= 920;
          final content = ColoredBox(
            color: AppPalette.background,
            child: _DestinationBody(controller: controller),
          );
          if (minimal) {
            return Column(
              children: <Widget>[
                Expanded(child: content),
                _BottomNavigation(controller: controller),
              ],
            );
          }
          return Row(
            children: <Widget>[
              _SideNavigation(controller: controller, expanded: expanded),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _DestinationInfo {
  const _DestinationInfo(
    this.destination,
    this.label,
    this.icon, {
    required this.group,
  });

  final AppDestination destination;
  final String label;
  final IconData icon;
  final String group;
}

const _destinations = <_DestinationInfo>[
  _DestinationInfo(
    AppDestination.pulse,
    'Pulse',
    Icons.monitor_heart_outlined,
    group: 'CORE',
  ),
  _DestinationInfo(
    AppDestination.accounts,
    'Accounts',
    Icons.account_tree_outlined,
    group: 'CORE',
  ),
  _DestinationInfo(
    AppDestination.reports,
    'Traffic',
    Icons.query_stats_outlined,
    group: 'CORE',
  ),
  _DestinationInfo(
    AppDestination.apis,
    'API access',
    Icons.key_outlined,
    group: 'TOOLS',
  ),
  _DestinationInfo(
    AppDestination.automations,
    'Automations',
    Icons.schedule_outlined,
    group: 'TOOLS',
  ),
  _DestinationInfo(
    AppDestination.settings,
    'Settings',
    Icons.tune_outlined,
    group: 'SYSTEM',
  ),
];

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.controller, required this.expanded});

  final AppController controller;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final dense = MediaQuery.sizeOf(context).height < 760;
    final coreItems = _destinations
        .where((item) => item.group == 'CORE')
        .toList(growable: false);
    final toolItems = _destinations
        .where((item) => item.group == 'TOOLS')
        .toList(growable: false);
    final settings = _destinations.firstWhere(
      (item) => item.destination == AppDestination.settings,
    );
    return Container(
      width: expanded ? 248 : 76,
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(right: BorderSide(color: AppPalette.outline)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 22 : 16,
                dense ? 14 : (expanded ? 24 : 18),
                expanded ? 18 : 16,
                dense ? 12 : (expanded ? 22 : 18),
              ),
              child: Align(
                alignment: expanded ? Alignment.centerLeft : Alignment.center,
                child: OpenHubBrandLockup(compact: !expanded),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  dense ? 8 : (expanded ? 18 : 12),
                  0,
                  dense ? 4 : 8,
                ),
                children: <Widget>[
                  _NavigationGroup(
                    label: 'CORE',
                    items: coreItems,
                    controller: controller,
                    expanded: expanded,
                    dense: dense,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      expanded ? 22 : 16,
                      dense ? 6 : (expanded ? 14 : 10),
                      expanded ? 22 : 16,
                      dense ? 6 : (expanded ? 12 : 10),
                    ),
                    child: const Divider(height: 1),
                  ),
                  _NavigationGroup(
                    label: 'TOOLS',
                    items: toolItems,
                    controller: controller,
                    expanded: expanded,
                    dense: dense,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: dense ? 2 : 4),
              child: _NavigationButton(
                controller: controller,
                item: settings,
                expanded: expanded,
                dense: dense,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 12 : 10,
                0,
                expanded ? 12 : 10,
                dense ? 8 : (expanded ? 16 : 14),
              ),
              child: _RuntimeChip(
                connection: controller.runtime.connection,
                compact: !expanded,
                dense: dense,
                onTap: () =>
                    controller.selectDestination(AppDestination.settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationGroup extends StatelessWidget {
  const _NavigationGroup({
    required this.label,
    required this.items,
    required this.controller,
    required this.expanded,
    required this.dense,
  });

  final String label;
  final List<_DestinationInfo> items;
  final AppController controller;
  final bool expanded;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (expanded)
          Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, dense ? 4 : 8),
            child: Text(
              label,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.05,
              ),
            ),
          ),
        for (final item in items)
          _NavigationButton(
            controller: controller,
            item: item,
            expanded: expanded,
            dense: dense,
          ),
      ],
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.controller,
    required this.item,
    required this.expanded,
    required this.dense,
  });

  final AppController controller;
  final _DestinationInfo item;
  final bool expanded;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final selected = controller.destination == item.destination;
    final button = Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppPalette.cyan.withValues(alpha: 0.055),
        focusColor: AppPalette.cyan.withValues(alpha: 0.11),
        highlightColor: AppPalette.cyan.withValues(alpha: 0.08),
        onTap: () => controller.selectDestination(item.destination),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          height: dense ? 42 : 50,
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.cyan.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppPalette.cyan.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                width: 3,
                height: selected ? (dense ? 24 : 30) : 0,
                decoration: BoxDecoration(
                  color: selected ? AppPalette.cyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(width: expanded ? 12 : 0),
              Icon(
                item.icon,
                size: dense ? 20 : (expanded ? 21 : 22),
                color: selected ? AppPalette.cyan : AppPalette.textMuted,
              ),
              if (expanded) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppPalette.text : AppPalette.textMuted,
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 12 : 9,
        vertical: dense ? 1 : 3,
      ),
      child: expanded ? button : Tooltip(message: item.label, child: button),
    );
  }
}

class _RuntimeChip extends StatelessWidget {
  const _RuntimeChip({
    required this.connection,
    required this.onTap,
    this.compact = false,
    this.dense = false,
  });

  final BackendConnection? connection;
  final VoidCallback onTap;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final owned = connection?.ownership == BackendOwnership.owned;
    if (compact) {
      return Tooltip(
        message: owned
            ? 'Local runtime · managed · open Settings'
            : 'Local runtime · attached · open Settings',
        child: Semantics(
          button: true,
          label: 'Local runtime status, open Settings',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppPalette.green.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.green.withValues(alpha: 0.24),
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppPalette.green,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Local runtime is running, open Settings',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 7 : 11,
          ),
          decoration: BoxDecoration(
            color: AppPalette.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.outlineStrong),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppPalette.green.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox.square(
                    dimension: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppPalette.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Local runtime',
                      style: TextStyle(
                        color: AppPalette.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owned ? 'Running · managed' : 'Running · attached',
                      style: const TextStyle(
                        color: AppPalette.green,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _destinations.indexWhere(
      (item) => item.destination == controller.destination,
    );
    return NavigationBar(
      height: 72,
      selectedIndex: selectedIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (index) =>
          controller.selectDestination(_destinations[index].destination),
      destinations: <Widget>[
        for (final item in _destinations)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.icon, color: AppPalette.cyan),
            label: item.label,
          ),
      ],
    );
  }
}

class _DestinationBody extends StatelessWidget {
  const _DestinationBody({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return switch (controller.destination) {
      AppDestination.pulse => CodexPulsePage(controller: controller),
      AppDestination.accounts => AccountsPage(controller: controller),
      AppDestination.reports => _TrafficPage(controller: controller),
      AppDestination.apis => ApiKeysPage(controller: controller),
      AppDestination.settings => SettingsPage(controller: controller),
      AppDestination.automations => AutomationsPage(controller: controller),
    };
  }
}

enum _TrafficView { live, analytics }

class _TrafficPage extends StatefulWidget {
  const _TrafficPage({required this.controller});

  final AppController controller;

  @override
  State<_TrafficPage> createState() => _TrafficPageState();
}

class _TrafficPageState extends State<_TrafficPage> {
  _TrafficView _view = _TrafficView.live;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
          child: Row(
            children: <Widget>[
              const Icon(Icons.query_stats_outlined, color: AppPalette.cyan),
              const SizedBox(width: 10),
              Text('Traffic', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              SegmentedButton<_TrafficView>(
                segments: const <ButtonSegment<_TrafficView>>[
                  ButtonSegment<_TrafficView>(
                    value: _TrafficView.live,
                    icon: Icon(Icons.route_outlined),
                    label: Text('Live routing'),
                  ),
                  ButtonSegment<_TrafficView>(
                    value: _TrafficView.analytics,
                    icon: Icon(Icons.analytics_outlined),
                    label: Text('Analytics'),
                  ),
                ],
                selected: <_TrafficView>{_view},
                onSelectionChanged: (selection) {
                  setState(() => _view = selection.single);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _view == _TrafficView.live
                ? _LiveTrafficPage(
                    key: const ValueKey<String>('traffic-live'),
                    controller: widget.controller,
                  )
                : ReportsPage(
                    key: const ValueKey<String>('traffic-analytics'),
                    controller: widget.controller,
                  ),
          ),
        ),
      ],
    );
  }
}

class _LiveTrafficPage extends StatefulWidget {
  const _LiveTrafficPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<_LiveTrafficPage> createState() => _LiveTrafficPageState();
}

class _LiveTrafficPageState extends State<_LiveTrafficPage> {
  late final TextEditingController _requestSearch = TextEditingController(
    text: widget.controller.requestLogsQuery.search,
  );
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _requestSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final section = controller.overview;
    if (section.value == null && section.isBusy) {
      return const _CenteredProgress(
        label: 'Loading live routing and quota signals…',
      );
    }
    if (section.value == null) {
      return _SectionFailure(
        title: 'Live traffic unavailable',
        error: section.error,
        onRetry: controller.refreshOverview,
      );
    }
    final overview = section.value!;
    return CustomScrollView(
      key: const PageStorageKey<String>('traffic-live-scroll'),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
          sliver: SliverToBoxAdapter(
            child: _PageIntro(
              eyebrow: '',
              title: 'Live routing',
              detail:
                  'Fleet capacity and exact request-to-account attribution. ${overview.activeAccounts} of ${overview.accounts.length} accounts active · quota sample ${formatRelative(section.sourceSampleAt)}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Refresh live traffic',
                    onPressed: section.isBusy
                        ? null
                        : () => unawaited(controller.refreshOverview()),
                    icon: const Icon(Icons.refresh, size: 19),
                  ),
                  const SizedBox(width: 6),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: '1d', label: Text('24h')),
                      ButtonSegment<String>(value: '7d', label: Text('7d')),
                      ButtonSegment<String>(value: '30d', label: Text('30d')),
                    ],
                    selected: <String>{controller.overviewTimeframe},
                    onSelectionChanged: section.isBusy
                        ? null
                        : (selection) => unawaited(
                            controller.refreshOverview(
                              timeframe: selection.single,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (section.isStale)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: _InlineWarning(
                message:
                    'Showing the last successful live-traffic snapshot. Refresh failed: ${_errorText(section.error)}',
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          sliver: SliverToBoxAdapter(
            child: _DashboardMetricsGrid(overview: overview),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 16),
          sliver: SliverToBoxAdapter(child: _QuotaRow(overview: overview)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 16),
          sliver: SliverToBoxAdapter(
            child: _ProjectionPanel(
              section: controller.projections,
              onRetry: controller.refreshDashboardProjections,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
          sliver: SliverToBoxAdapter(
            child: _RequestLogsSection(
              controller: controller,
              searchController: _requestSearch,
              onSearchChanged: _onRequestSearchChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _onRequestSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      unawaited(
        widget.controller.updateRequestLogsQuery(
          widget.controller.requestLogsQuery.copyWith(search: value, offset: 0),
        ),
      );
    });
  }
}

class _ProjectionPanel extends StatelessWidget {
  const _ProjectionPanel({required this.section, required this.onRetry});

  final AsyncSection<DashboardProjections> section;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final value = section.value;
    if (value == null && section.isBusy) {
      return const _Panel(
        child: SizedBox(
          height: 96,
          child: _CenteredProgress(label: 'Calculating capacity pace…'),
        ),
      );
    }
    if (value == null) {
      return _Panel(
        child: Row(
          children: <Widget>[
            const Icon(Icons.insights_outlined, color: AppPalette.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Routing pulse is unavailable: ${_errorText(section.error)}',
              ),
            ),
            OutlinedButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Retry projections'),
            ),
          ],
        ),
      );
    }
    final pace = value.weeklyCreditPace;
    final projections = <({String label, DepletionProjection value})>[
      if (value.primary != null) (label: 'Primary', value: value.primary!),
      if (value.secondary != null)
        (label: 'Secondary', value: value.secondary!),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.insights_outlined, color: AppPalette.cyan),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Routing pulse',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (section.phase == SectionPhase.refreshing)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (pace != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 680;
                final chart = Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${pace.actualUsedPercent.toStringAsFixed(1)}% actual',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: pace.status.replaceAll('_', ' '),
                            color: _paceColor(pace.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(999),
                        value: (pace.actualUsedPercent / 100).clamp(0, 1),
                        backgroundColor: AppPalette.outline,
                        color: _paceColor(pace.status),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${pace.scheduledUsedPercent.toStringAsFixed(1)}% scheduled · '
                        '${pace.deltaPercent >= 0 ? '+' : ''}${pace.deltaPercent.toStringAsFixed(1)}% delta · '
                        '${pace.confidence} confidence',
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
                final guidance = SizedBox(
                  width: stacked ? double.infinity : 250,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ProjectionFact(
                        label: 'Projected depletion',
                        value: pace.projectedDepletionHours == null
                            ? 'Not projected'
                            : '${pace.projectedDepletionHours!.toStringAsFixed(1)}h',
                      ),
                      _ProjectionFact(
                        label: 'Suggested throttle',
                        value: pace.throttleToPercent == null
                            ? 'None'
                            : '${pace.throttleToPercent!.toStringAsFixed(0)}%',
                      ),
                      _ProjectionFact(
                        label: 'Sample coverage',
                        value:
                            '${pace.accountCount - pace.staleAccountCount}/${pace.accountCount} fresh',
                      ),
                    ],
                  ),
                );
                if (stacked) {
                  return Column(
                    children: <Widget>[
                      Row(children: <Widget>[chart]),
                      const SizedBox(height: 14),
                      guidance,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    chart,
                    const SizedBox(width: 24),
                    guidance,
                  ],
                );
              },
            )
          else
            const Text('Weekly pace is not available for this account mix.'),
          if (projections.isNotEmpty) ...<Widget>[
            const SizedBox(height: 15),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: projections
                  .map(
                    (item) => _StatusPill(
                      label:
                          '${item.label}: ${item.value.riskLevel} · burn ${item.value.burnRate.toStringAsFixed(2)}',
                      color: _riskColor(item.value.riskLevel),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (section.isStale) ...<Widget>[
            const SizedBox(height: 12),
            _InlineWarning(
              message:
                  'Showing the last successful projection. Refresh failed: ${_errorText(section.error)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectionFact extends StatelessWidget {
  const _ProjectionFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RequestLogsSection extends StatelessWidget {
  const _RequestLogsSection({
    required this.controller,
    required this.searchController,
    required this.onSearchChanged,
  });

  final AppController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final section = controller.requestLogs;
    final optionsSection = controller.requestLogOptions;
    final query = controller.requestLogsQuery;
    final options = optionsSection.value;
    final orderedAccounts = controller.orderedAccounts(
      controller.overview.value?.accounts ?? const <AccountSummary>[],
    );
    final accountLabels = <String, String>{
      for (final account in orderedAccounts)
        account.accountId: account.displayName,
    };
    final accountRanks = <String, int>{
      for (var index = 0; index < orderedAccounts.length; index++)
        orderedAccounts[index].accountId: index,
    };
    final orderedFilterAccountIds = <String>[...?options?.accountIds]
      ..sort((left, right) {
        final leftRank = accountRanks[left];
        final rightRank = accountRanks[right];
        if (leftRank != null || rightRank != null) {
          if (leftRank == null) {
            return 1;
          }
          if (rightRank == null) {
            return -1;
          }
          return leftRank.compareTo(rightRank);
        }
        return (accountLabels[left] ?? left).toLowerCase().compareTo(
          (accountLabels[right] ?? right).toLowerCase(),
        );
      });
    final apiLabels = <String, String>{
      for (final option in options?.apiKeys ?? const <RequestLogApiKeyOption>[])
        option.id: option.keyPrefix == null
            ? option.name
            : '${option.name} · ${option.keyPrefix}',
    };
    final modelLabels = <String, String>{
      for (final option
          in options?.modelOptions ?? const <RequestLogModelOption>[])
        option.encoded: option.label,
    };
    final statusLabels = <String, String>{
      for (final status in options?.statuses ?? const <String>[])
        status: status.replaceAll('_', ' '),
    };
    final hasFilters =
        query.search.isNotEmpty ||
        query.timeframe != 'all' ||
        query.accountIds.isNotEmpty ||
        query.apiKeyIds.isNotEmpty ||
        query.modelOptions.isNotEmpty ||
        query.statuses.isNotEmpty ||
        query.conversationId != null;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.receipt_long_outlined, color: AppPalette.cyan),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Recent requests',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'fetched ${formatRelative(section.lastSuccessfulFetch)}',
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;
              final search = TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search request, conversation, model, or error',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              );
              final timeframe = DropdownButton<String>(
                value: query.timeframe,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'all', child: Text('All time')),
                  DropdownMenuItem(value: '1h', child: Text('Last hour')),
                  DropdownMenuItem(value: '24h', child: Text('Last 24h')),
                  DropdownMenuItem(value: '7d', child: Text('Last 7d')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    unawaited(
                      controller.updateRequestLogsQuery(
                        query.copyWith(timeframe: value, offset: 0),
                      ),
                    );
                  }
                },
              );
              if (narrow) {
                return Column(
                  children: <Widget>[
                    search,
                    const SizedBox(height: 9),
                    Align(alignment: Alignment.centerLeft, child: timeframe),
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  timeframe,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MultiFilterButton(
                label: 'Accounts',
                values: query.accountIds,
                options: <String, String>{
                  for (final id in orderedFilterAccountIds)
                    id: accountLabels[id] ?? id,
                },
                onChanged: (values) => controller.updateRequestLogsQuery(
                  query.copyWith(accountIds: values, offset: 0),
                ),
              ),
              _MultiFilterButton(
                label: 'API keys',
                values: query.apiKeyIds,
                options: apiLabels,
                onChanged: (values) => controller.updateRequestLogsQuery(
                  query.copyWith(apiKeyIds: values, offset: 0),
                ),
              ),
              _MultiFilterButton(
                label: 'Models',
                values: query.modelOptions,
                options: modelLabels,
                onChanged: (values) => controller.updateRequestLogsQuery(
                  query.copyWith(modelOptions: values, offset: 0),
                ),
              ),
              _MultiFilterButton(
                label: 'Statuses',
                values: query.statuses,
                options: statusLabels,
                onChanged: (values) => controller.updateRequestLogsQuery(
                  query.copyWith(statuses: values, offset: 0),
                ),
              ),
              if (query.conversationId != null)
                InputChip(
                  label: Text('Conversation ${query.conversationId}'),
                  onDeleted: () => unawaited(
                    controller.updateRequestLogsQuery(
                      query.copyWith(clearConversationId: true, offset: 0),
                    ),
                  ),
                ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: () {
                    searchController.clear();
                    unawaited(
                      controller.updateRequestLogsQuery(
                        const RequestLogsQuery(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
          if (optionsSection.error != null && options == null) ...<Widget>[
            const SizedBox(height: 10),
            _InlineWarning(
              message:
                  'Filter options failed, but request rows can still load: ${_errorText(optionsSection.error)}',
            ),
          ],
          const SizedBox(height: 12),
          if (section.value == null && section.isBusy)
            const SizedBox(
              height: 150,
              child: _CenteredProgress(label: 'Loading request ledger…'),
            )
          else if (section.value == null)
            _SectionLocalFailure(
              message: 'Request logs failed: ${_errorText(section.error)}',
              onRetry: controller.refreshRequestLogs,
            )
          else ...<Widget>[
            if (section.isStale) ...<Widget>[
              _InlineWarning(
                message:
                    'Showing the last successful request page. Refresh failed: ${_errorText(section.error)}',
              ),
              const SizedBox(height: 10),
            ],
            _RequestLogTable(
              page: section.value!,
              accounts: accountLabels,
              onConversation: (conversationId) => unawaited(
                controller.updateRequestLogsQuery(
                  query.copyWith(conversationId: conversationId, offset: 0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _RequestLogPagination(controller: controller),
          ],
        ],
      ),
    );
  }
}

class _MultiFilterButton extends StatelessWidget {
  const _MultiFilterButton({
    required this.label,
    required this.values,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final List<String> values;
  final Map<String, String> options;
  final Future<void> Function(List<String>) onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: options.isEmpty ? null : () => _show(context),
      icon: const Icon(Icons.filter_list, size: 17),
      label: Text(values.isEmpty ? label : '$label · ${values.length}'),
    );
  }

  Future<void> _show(BuildContext context) async {
    final selected = <String>{...values};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Filter by ${label.toLowerCase()}'),
          content: SizedBox(
            width: 480,
            height: (options.length * 48.0).clamp(100, 430),
            child: ListView(
              children: options.entries
                  .map(
                    (entry) => CheckboxListTile(
                      value: selected.contains(entry.key),
                      title: Text(entry.value),
                      onChanged: (checked) => setState(() {
                        checked ?? false
                            ? selected.add(entry.key)
                            : selected.remove(entry.key);
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => setState(selected.clear),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await onChanged(result.toList(growable: false));
    }
  }
}

class _RequestLogTable extends StatelessWidget {
  const _RequestLogTable({
    required this.page,
    required this.accounts,
    required this.onConversation,
  });

  final RequestLogsPage page;
  final Map<String, String> accounts;
  final ValueChanged<String> onConversation;

  @override
  Widget build(BuildContext context) {
    if (page.requests.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No requests match these filters.')),
      );
    }
    final height = (page.requests.length * 62.0 + 40).clamp(150.0, 520.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.outline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showAccount = constraints.maxWidth >= 760;
          final showUsage = constraints.maxWidth >= 980;
          return Column(
            children: <Widget>[
              SizedBox(
                height: 38,
                child: _RequestLogRow(
                  header: true,
                  cells: <Widget>[
                    const Text('Time'),
                    const Text('Model'),
                    if (showAccount) const Text('Account'),
                    const Text('Status'),
                    if (showUsage) const Text('Tokens / cost / latency'),
                  ],
                  showAccount: showAccount,
                  showUsage: showUsage,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  key: const PageStorageKey<String>('request-log-list'),
                  itemCount: page.requests.length,
                  itemExtent: 61,
                  itemBuilder: (context, index) {
                    final request = page.requests[index];
                    return InkWell(
                      onTap: request.conversationId == null
                          ? null
                          : () => onConversation(request.conversationId!),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: _RequestLogRow(
                              cells: <Widget>[
                                Text(_relativeTimestamp(request.requestedAt)),
                                Tooltip(
                                  message: request.requestId,
                                  child: Text(
                                    request.reasoningEffort == null
                                        ? request.model
                                        : '${request.model} · ${request.reasoningEffort}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (showAccount)
                                  Text(
                                    accounts[request.accountId] ??
                                        request.apiKeyName ??
                                        request.accountId ??
                                        'unassigned',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                _StatusPill(
                                  label: request.status.replaceAll('_', ' '),
                                  color: _requestStatusColor(request.status),
                                ),
                                if (showUsage)
                                  Text(
                                    '${formatCompactNumber(request.tokens)} · '
                                    '\$${(request.costUsd ?? 0).toStringAsFixed(3)} · '
                                    '${request.latencyMs ?? 0}ms',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                              showAccount: showAccount,
                              showUsage: showUsage,
                            ),
                          ),
                          if (index != page.requests.length - 1)
                            const Divider(height: 1),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestLogRow extends StatelessWidget {
  const _RequestLogRow({
    required this.cells,
    required this.showAccount,
    required this.showUsage,
    this.header = false,
  });

  final List<Widget> cells;
  final bool showAccount;
  final bool showUsage;
  final bool header;

  @override
  Widget build(BuildContext context) {
    var index = 0;
    Widget next(int flex) {
      final cell = cells[index++];
      return Expanded(
        flex: flex,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: header ? AppPalette.textMuted : null,
            fontSize: header ? 10.5 : 11.5,
            fontWeight: header ? FontWeight.w600 : null,
          ),
          child: cell,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          next(2),
          next(3),
          if (showAccount) next(3),
          next(2),
          if (showUsage) next(3),
        ],
      ),
    );
  }
}

class _RequestLogPagination extends StatelessWidget {
  const _RequestLogPagination({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final page = controller.requestLogs.value!;
    final query = controller.requestLogsQuery;
    final first = page.total == 0 ? 0 : query.offset + 1;
    final last = (query.offset + page.requests.length).clamp(0, page.total);
    return Row(
      children: <Widget>[
        Text(
          '$first–$last of ${page.total}',
          style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
        ),
        const Spacer(),
        DropdownButton<int>(
          value: query.limit,
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem(value: 25, child: Text('25 rows')),
            DropdownMenuItem(value: 50, child: Text('50 rows')),
            DropdownMenuItem(value: 100, child: Text('100 rows')),
          ],
          onChanged: (value) {
            if (value != null) {
              unawaited(
                controller.updateRequestLogsQuery(
                  query.copyWith(limit: value, offset: 0),
                ),
              );
            }
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: query.offset <= 0
              ? null
              : () => unawaited(
                  controller.updateRequestLogsQuery(
                    query.copyWith(
                      offset: (query.offset - query.limit).clamp(0, page.total),
                    ),
                  ),
                ),
          tooltip: 'Previous page',
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: !page.hasMore
              ? null
              : () => unawaited(
                  controller.updateRequestLogsQuery(
                    query.copyWith(offset: query.offset + query.limit),
                  ),
                ),
          tooltip: 'Next page',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SectionLocalFailure extends StatelessWidget {
  const _SectionLocalFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.red.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppPalette.red),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          OutlinedButton(
            onPressed: () => unawaited(onRetry()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 10.5),
      ),
    );
  }
}

Color _paceColor(String status) => switch (status) {
  'ahead' || 'on_track' => AppPalette.green,
  'behind' => AppPalette.amber,
  _ => AppPalette.red,
};

Color _riskColor(String risk) => switch (risk) {
  'safe' => AppPalette.green,
  'warning' => AppPalette.amber,
  _ => AppPalette.red,
};

Color _requestStatusColor(String status) => switch (status) {
  'success' || 'completed' || 'ok' => AppPalette.green,
  'pending' || 'streaming' => AppPalette.cyan,
  'cancelled' => AppPalette.textMuted,
  _ => AppPalette.red,
};

String _relativeTimestamp(DateTime value) {
  final difference = DateTime.now().toUtc().difference(value.toUtc());
  if (difference.inMinutes < 1) {
    return '${difference.inSeconds.clamp(0, 59)}s ago';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  return '${difference.inDays}d ago';
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.eyebrow,
    required this.title,
    required this.detail,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (eyebrow.isNotEmpty) ...<Widget>[
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: AppPalette.cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(detail),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 18), trailing!],
      ],
    );
  }
}

class _DashboardMetricsGrid extends StatelessWidget {
  const _DashboardMetricsGrid({required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final metrics = overview.metrics;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >= 660
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            _MetricCard(
              width: width,
              label: 'Account readiness',
              value: '${overview.activeAccounts}',
              footnote: overview.attentionAccounts == 0
                  ? 'All accounts healthy'
                  : '${overview.attentionAccounts} need attention',
              icon: Icons.account_tree_outlined,
              color: AppPalette.green,
            ),
            _MetricCard(
              width: width,
              label: 'Request activity · ${overview.timeframe}',
              value: formatCompactNumber(metrics?.requests),
              footnote:
                  '${formatCompactNumber(metrics?.conversations)} conversations',
              icon: Icons.arrow_outward_rounded,
              color: AppPalette.cyan,
            ),
            _MetricCard(
              width: width,
              label: 'Token volume · ${overview.timeframe}',
              value: formatCompactNumber(metrics?.tokens),
              footnote: 'Backend-recorded traffic',
              icon: Icons.data_usage_outlined,
              color: const Color(0xFFB49AF7),
            ),
            _MetricCard(
              width: width,
              label: 'Recorded cost · ${overview.timeframe}',
              value: formatMoney(overview.totalUsd, overview.currency),
              footnote: metrics?.errorRate == null
                  ? 'No error-rate sample'
                  : '${formatPercent((metrics!.errorRate ?? 0) * 100)} errors',
              icon: Icons.payments_outlined,
              color: AppPalette.amber,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.footnote,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final String footnote;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 148),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            footnote,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _QuotaCard(
        title: 'Primary capacity',
        window: overview.primaryWindow,
        color: AppPalette.cyan,
      ),
      if (overview.secondaryWindow != null)
        _QuotaCard(
          title: 'Secondary capacity',
          window: overview.secondaryWindow!,
          color: const Color(0xFFB49AF7),
        ),
    ];
    final capacityLayout = LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        if (stacked) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(growable: false),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map(
                (child) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: child,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.battery_charging_full, color: AppPalette.cyan),
              SizedBox(width: 9),
              Text(
                'Available capacity',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          capacityLayout,
        ],
      ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({
    required this.title,
    required this.window,
    required this.color,
  });

  final String title;
  final QuotaWindow window;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = (window.remainingPercent / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                formatPercent(window.remainingPercent),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 8,
              backgroundColor: AppPalette.outline,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${window.remainingCredits.toStringAsFixed(1)} of ${window.capacityCredits.toStringAsFixed(1)} credits · reset ${formatTimestamp(window.resetAt)}',
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.outline),
      ),
      child: child,
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppPalette.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.24)),
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
              style: const TextStyle(color: AppPalette.amber, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionFailure extends StatelessWidget {
  const _SectionFailure({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.cloud_off_outlined,
                color: AppPalette.red,
                size: 38,
              ),
              const SizedBox(height: 15),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_errorText(error), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => unawaited(onRetry()),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry this section'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 15),
            Text(label),
          ],
        ),
      ),
    );
  }
}

String _errorText(Object? error) {
  if (error is ApiException) {
    return error.message;
  }
  if (error is BackendStartupException) {
    return error.message;
  }
  return error?.toString() ?? 'Unknown local error';
}
