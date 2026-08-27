import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/account_summary.dart';
import '../../models/api_key_info.dart';
import '../../models/automation_data.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';
import '../formatters.dart';
import 'feature_widgets.dart';

class AutomationsPage extends StatefulWidget {
  const AutomationsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<AutomationsPage> createState() => _AutomationsPageState();
}

class _AutomationsPageState extends State<AutomationsPage> {
  final TextEditingController _search = TextEditingController();
  String _view = 'jobs';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = widget.controller.automations;
    final runs = widget.controller.automationRuns;
    final active = _view == 'jobs' ? jobs : runs;
    if (active.value == null && active.isBusy) {
      return const FeatureProgress(label: 'Loading scheduled work…');
    }
    if (active.value == null) {
      return FeatureFailure(
        title: _view == 'jobs'
            ? 'Automations unavailable'
            : 'Automation runs unavailable',
        error: active.error,
        onRetry: _view == 'jobs'
            ? widget.controller.refreshAutomations
            : widget.controller.refreshAutomationRuns,
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FeaturePageHeader(
                eyebrow: 'SCHEDULED LOCAL WORK',
                title: _view == 'jobs'
                    ? '${jobs.value?.total ?? 0} automation jobs'
                    : '${runs.value?.total ?? 0} recorded runs',
                detail:
                    'Create, pause, run, and inspect scheduled local jobs. Work executes in the existing backend; OpenHUB manages schedules, inputs, run history, and status without becoming a second scheduler.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SegmentedButton<String>(
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'jobs',
                          icon: Icon(Icons.schedule_outlined),
                          label: Text('Jobs'),
                        ),
                        ButtonSegment<String>(
                          value: 'runs',
                          icon: Icon(Icons.history),
                          label: Text('Runs'),
                        ),
                      ],
                      selected: <String>{_view},
                      onSelectionChanged: (selection) =>
                          setState(() => _view = selection.single),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: widget.controller.canWrite
                          ? () => unawaited(_openEditor())
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('New job'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _view == 'jobs'
                      ? 'Search job, model, prompt, or account'
                      : 'Search run, job, model, status, or error',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
              if (active.isStale) ...<Widget>[
                const SizedBox(height: 12),
                FeatureWarning(
                  message:
                      'Showing cached automation data. Refresh failed: ${featureErrorText(active.error)}',
                ),
              ],
              if (widget.controller.automationActionError != null) ...<Widget>[
                const SizedBox(height: 12),
                FeatureWarning(
                  error: true,
                  message:
                      'Automation action failed: ${featureErrorText(widget.controller.automationActionError)}',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _view == 'jobs'
              ? _buildJobs(jobs.value!)
              : _buildRuns(runs.value!),
        ),
      ],
    );
  }

  Widget _buildJobs(AutomationJobsPage page) {
    final query = _search.text.trim().toLowerCase();
    final items = page.items
        .where((job) {
          if (query.isEmpty) {
            return true;
          }
          return job.name.toLowerCase().contains(query) ||
              job.model.toLowerCase().contains(query) ||
              job.prompt.toLowerCase().contains(query) ||
              job.accountIds.any((id) => id.toLowerCase().contains(query));
        })
        .toList(growable: false);
    if (items.isEmpty) {
      return const Center(child: Text('No automation jobs match this filter.'));
    }
    return ListView.builder(
      key: const PageStorageKey<String>('automation-jobs-list'),
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
      itemCount: items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _AutomationJobCard(
          job: items[index],
          controller: widget.controller,
          onEdit: () => unawaited(_openEditor(items[index])),
          onDelete: () => unawaited(_deleteJob(items[index])),
        ),
      ),
    );
  }

  Widget _buildRuns(AutomationRunsPage page) {
    final query = _search.text.trim().toLowerCase();
    final items = page.items
        .where((run) {
          if (query.isEmpty) {
            return true;
          }
          return run.id.toLowerCase().contains(query) ||
              run.jobId.toLowerCase().contains(query) ||
              (run.jobName?.toLowerCase().contains(query) ?? false) ||
              (run.model?.toLowerCase().contains(query) ?? false) ||
              run.visibleStatus.toLowerCase().contains(query) ||
              (run.errorMessage?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
    if (items.isEmpty) {
      return const Center(child: Text('No automation runs match this filter.'));
    }
    return ListView.builder(
      key: const PageStorageKey<String>('automation-runs-list'),
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
      itemCount: items.length,
      itemExtent: 94,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: _AutomationRunCard(
          run: items[index],
          onOpen: () => unawaited(_showRunDetails(items[index])),
        ),
      ),
    );
  }

  Future<void> _openEditor([AutomationJob? current]) async {
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AutomationEditorDialog(
        current: current,
        models: widget.controller.models.value ?? const <ModelItem>[],
        accounts: widget.controller.orderedAccounts(
          widget.controller.accounts.value ?? const <AccountSummary>[],
        ),
      ),
    );
    if (payload == null) {
      return;
    }
    if (current == null) {
      await widget.controller.createAutomation(payload);
    } else {
      await widget.controller.updateAutomation(current.id, payload);
    }
  }

  Future<void> _deleteJob(AutomationJob job) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Delete ${job.name}?',
      message:
          'The schedule is removed. Historical runs and account credentials are not modified.',
      confirmLabel: 'Delete automation',
      destructive: true,
    );
    if (confirmed) {
      await widget.controller.deleteAutomation(job.id);
    }
  }

  Future<void> _showRunDetails(AutomationRun run) async {
    final future = widget.controller.getAutomationRunDetails(run.id);
    await showDialog<void>(
      context: context,
      builder: (context) => FutureBuilder<AutomationRunDetails?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AlertDialog(
              content: SizedBox(
                width: 520,
                height: 180,
                child: FeatureProgress(label: 'Loading run details…'),
              ),
            );
          }
          final details = snapshot.data;
          if (details == null) {
            return AlertDialog(
              title: const Text('Run details unavailable'),
              content: Text(
                featureErrorText(widget.controller.automationActionError),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }
          return _AutomationRunDetailsDialog(details: details);
        },
      ),
    );
  }
}

class _AutomationJobCard extends StatelessWidget {
  const _AutomationJobCard({
    required this.job,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final AutomationJob job;
  final AppController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final busy = controller.mutatingAutomationIds.contains(job.id);
    return FeaturePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 800;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      job.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FeatureBadge(
                    label: job.enabled ? 'enabled' : 'paused',
                    color: job.enabled
                        ? AppPalette.green
                        : AppPalette.textMuted,
                  ),
                  if (job.lastRun != null) ...<Widget>[
                    const SizedBox(width: 6),
                    FeatureBadge(
                      label: 'last ${job.lastRun!.visibleStatus}',
                      color: _runColor(job.lastRun!.visibleStatus),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '${job.schedule.time} · ${job.schedule.timezone} · ${_daysLabel(job.schedule.days)}',
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${job.model}${job.reasoningEffort == null ? '' : ' · ${job.reasoningEffort}'} · '
                '${job.accountScopeAll ? 'all accounts' : '${job.accountIds.length} accounts'}',
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                job.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          );
          final timing = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'NEXT RUN',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                formatTimestamp(job.nextRunAt),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          );
          final actions = busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Wrap(
                  spacing: 4,
                  children: <Widget>[
                    Switch(
                      value: job.enabled,
                      onChanged: controller.canWrite
                          ? (value) => unawaited(
                              controller.updateAutomation(
                                job.id,
                                <String, Object?>{'enabled': value},
                              ),
                            )
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Run now',
                      onPressed: controller.canWrite
                          ? () => unawaited(controller.runAutomationNow(job.id))
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      tooltip: 'Edit job',
                      onPressed: controller.canWrite ? onEdit : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete job',
                      onPressed: controller.canWrite ? onDelete : null,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppPalette.red,
                      ),
                    ),
                  ],
                );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                details,
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(child: timing),
                    actions,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 5, child: details),
              const SizedBox(width: 24),
              SizedBox(width: 180, child: timing),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _AutomationRunCard extends StatelessWidget {
  const _AutomationRunCard({required this.run, required this.onOpen});

  final AutomationRun run;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppPalette.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                _runIcon(run.visibleStatus),
                color: _runColor(run.visibleStatus),
              ),
              const SizedBox(width: 13),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      run.jobName ?? run.jobId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${run.model ?? 'unknown model'} · ${run.trigger}',
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 115,
                child: FeatureBadge(
                  label: run.visibleStatus,
                  color: _runColor(run.visibleStatus),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: Text(
                  formatTimestamp(run.startedAt),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppPalette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutomationEditorDialog extends StatefulWidget {
  const _AutomationEditorDialog({
    required this.models,
    required this.accounts,
    this.current,
  });

  final AutomationJob? current;
  final List<ModelItem> models;
  final List<AccountSummary> accounts;

  @override
  State<_AutomationEditorDialog> createState() =>
      _AutomationEditorDialogState();
}

class _AutomationEditorDialogState extends State<_AutomationEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _time;
  late final TextEditingController _timezone;
  late final TextEditingController _prompt;
  late final TextEditingController _modelText;
  late final Set<String> _days;
  late final Set<String> _accountIds;
  late String _model;
  late String _reasoning;
  late bool _enabled;
  late bool _includePaused;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    final defaultModel =
        current?.model ??
        widget.models.where((model) => !model.sourceOnly).firstOrNull?.id ??
        '';
    _name = TextEditingController(text: current?.name ?? '');
    _time = TextEditingController(text: current?.schedule.time ?? '09:00');
    _timezone = TextEditingController(
      text: current?.schedule.timezone ?? 'UTC',
    );
    _prompt = TextEditingController(text: current?.prompt ?? '');
    _modelText = TextEditingController(text: defaultModel);
    _days = <String>{...?current?.schedule.days};
    if (_days.isEmpty) {
      _days.addAll(automationWeekdays);
    }
    _accountIds = <String>{...?current?.accountIds};
    _model = defaultModel;
    _reasoning = current?.reasoningEffort ?? '';
    _enabled = current?.enabled ?? true;
    _includePaused = current?.includePausedAccounts ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _time.dispose();
    _timezone.dispose();
    _prompt.dispose();
    _modelText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    return AlertDialog(
      title: Text(current == null ? 'Create automation' : 'Edit automation'),
      content: SizedBox(
        width: 700,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Job name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _time,
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          hintText: '09:00',
                        ),
                        validator: (value) =>
                            RegExp(
                              r'^(?:[01]\d|2[0-3]):[0-5]\d$',
                            ).hasMatch(value ?? '')
                            ? null
                            : 'Use HH:mm.',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _timezone,
                        decoration: const InputDecoration(
                          labelText: 'IANA timezone',
                          hintText: 'UTC or Asia/Tehran',
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Run on'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: automationWeekdays
                      .map(
                        (day) => FilterChip(
                          label: Text(day.toUpperCase()),
                          selected: _days.contains(day),
                          onSelected: (selected) => setState(() {
                            selected ? _days.add(day) : _days.remove(day);
                          }),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
                if (widget.models.isEmpty)
                  TextFormField(
                    controller: _modelText,
                    decoration: const InputDecoration(labelText: 'Model ID'),
                    validator: _required,
                    onChanged: (value) => _model = value.trim(),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue:
                        widget.models.any((model) => model.id == _model)
                        ? _model
                        : null,
                    decoration: const InputDecoration(labelText: 'Model'),
                    items: widget.models
                        .map(
                          (model) => DropdownMenuItem<String>(
                            value: model.id,
                            child: Text(model.name),
                          ),
                        )
                        .toList(growable: false),
                    validator: (value) =>
                        value == null ? 'Choose a model.' : null,
                    onChanged: (value) => setState(() => _model = value ?? ''),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _reasoning,
                  decoration: const InputDecoration(
                    labelText: 'Reasoning effort',
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: '', child: Text('Model default')),
                    DropdownMenuItem(value: 'minimal', child: Text('Minimal')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'xhigh', child: Text('X-high')),
                    DropdownMenuItem(value: 'max', child: Text('Max')),
                    DropdownMenuItem(value: 'ultra', child: Text('Ultra')),
                  ],
                  onChanged: (value) =>
                      setState(() => _reasoning = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _prompt,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Warm-up prompt',
                    helperText: 'Blank uses the backend default when creating.',
                    alignLabelWithHint: true,
                  ),
                  validator: current == null ? null : _required,
                ),
                const SizedBox(height: 14),
                Text(
                  'Account scope',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _accountIds.isEmpty
                      ? 'All eligible accounts.'
                      : '${_accountIds.length} selected accounts.',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: widget.accounts
                          .map(
                            (account) => FilterChip(
                              label: Text(account.displayName),
                              selected: _accountIds.contains(account.accountId),
                              onSelected: (selected) => setState(() {
                                selected
                                    ? _accountIds.add(account.accountId)
                                    : _accountIds.remove(account.accountId);
                              }),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _includePaused,
                  title: const Text('Include paused accounts'),
                  onChanged: (value) => setState(() => _includePaused = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  title: const Text('Automation enabled'),
                  onChanged: (value) => setState(() => _enabled = value),
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
          child: Text(current == null ? 'Create job' : 'Save job'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one weekday.')),
      );
      return;
    }
    final payload = <String, Object?>{
      'name': _name.text.trim(),
      'enabled': _enabled,
      'includePausedAccounts': _includePaused,
      'schedule': <String, Object?>{
        'type': 'daily',
        'time': _time.text,
        'timezone': _timezone.text.trim(),
        'thresholdMinutes': widget.current?.schedule.thresholdMinutes ?? 0,
        'days': automationWeekdays
            .where(_days.contains)
            .toList(growable: false),
      },
      'model': _model,
      'reasoningEffort': _reasoning.isEmpty ? null : _reasoning,
      if (_prompt.text.trim().isNotEmpty) 'prompt': _prompt.text.trim(),
      'accountIds': _accountIds.toList(growable: false),
    };
    Navigator.pop(context, payload);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _AutomationRunDetailsDialog extends StatelessWidget {
  const _AutomationRunDetailsDialog({required this.details});

  final AutomationRunDetails details;

  @override
  Widget build(BuildContext context) {
    final run = details.run;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(child: Text(run.jobName ?? run.jobId)),
          FeatureBadge(
            label: run.visibleStatus,
            color: _runColor(run.visibleStatus),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${run.model ?? 'unknown model'} · ${run.trigger} · started ${formatTimestamp(run.startedAt)}',
              style: const TextStyle(color: AppPalette.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                FeatureBadge(label: '${details.totalAccounts} accounts'),
                FeatureBadge(
                  label: '${details.completedAccounts} complete',
                  color: AppPalette.green,
                ),
                FeatureBadge(
                  label: '${details.pendingAccounts} pending',
                  color: AppPalette.amber,
                ),
              ],
            ),
            if (run.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              FeatureWarning(error: true, message: run.errorMessage!),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1),
            Expanded(
              child: details.accounts.isEmpty
                  ? const Center(child: Text('No per-account rows recorded.'))
                  : ListView.builder(
                      itemExtent: 62,
                      itemCount: details.accounts.length,
                      itemBuilder: (context, index) {
                        final account = details.accounts[index];
                        return ListTile(
                          leading: Icon(
                            _runIcon(account.status),
                            color: _runColor(account.status),
                          ),
                          title: SelectableText(account.accountId),
                          subtitle: account.errorMessage == null
                              ? null
                              : Text(
                                  account.errorMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: FeatureBadge(
                            label: account.status,
                            color: _runColor(account.status),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

Color _runColor(String status) => switch (status) {
  'success' => AppPalette.green,
  'running' => AppPalette.cyan,
  'partial' => AppPalette.amber,
  'pending' => AppPalette.textMuted,
  _ => AppPalette.red,
};

IconData _runIcon(String status) => switch (status) {
  'success' => Icons.check_circle_outline,
  'running' => Icons.sync,
  'partial' => Icons.warning_amber_rounded,
  'pending' => Icons.schedule,
  _ => Icons.error_outline,
};

String _daysLabel(List<String> days) {
  if (days.length == 7) {
    return 'every day';
  }
  return days.map((day) => day.toUpperCase()).join(', ');
}
