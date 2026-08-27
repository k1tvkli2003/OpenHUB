import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/account_summary.dart';
import '../../models/advanced_settings.dart';
import '../../models/api_key_analytics.dart';
import '../../models/api_key_info.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';
import '../formatters.dart';
import 'feature_widgets.dart';

class ApiKeysPage extends StatefulWidget {
  const ApiKeysPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends State<ApiKeysPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.controller.apiKeys;
    if (section.value == null && section.isBusy) {
      return const FeatureProgress(label: 'Loading API access policies…');
    }
    if (section.value == null) {
      return FeatureFailure(
        title: 'API keys unavailable',
        error: section.error,
        onRetry: widget.controller.refreshApiKeys,
      );
    }
    final query = _search.text.trim().toLowerCase();
    final rows = section.value!
        .where(
          (key) =>
              query.isEmpty ||
              key.name.toLowerCase().contains(query) ||
              key.keyPrefix.toLowerCase().contains(query) ||
              (key.enforcedModel?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FeaturePageHeader(
                eyebrow: 'LOCAL API POLICY',
                title: '${section.value!.length} scoped access keys',
                detail:
                    'Create keys for local proxy access, restrict models and limits, and inspect each client’s usage. New secrets are shown once; stored rows expose prefixes and policy only · fetched ${formatRelative(section.lastSuccessfulFetch)}',
                trailing: FilledButton.icon(
                  onPressed: widget.controller.canWrite
                      ? () => unawaited(_createKey())
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Create key'),
                ),
              ),
              const SizedBox(height: 18),
              _ApiKeySummary(keys: section.value!),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search key name, prefix, or enforced model',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              if (section.isStale) ...<Widget>[
                const SizedBox(height: 12),
                FeatureWarning(
                  message:
                      'Showing cached API-key policies. Refresh failed: ${featureErrorText(section.error)}',
                ),
              ],
              if (widget.controller.apiKeyActionError != null) ...<Widget>[
                const SizedBox(height: 12),
                FeatureWarning(
                  error: true,
                  message:
                      'API-key action failed: ${featureErrorText(widget.controller.apiKeyActionError)}',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No API keys match this filter.'))
              : ListView.builder(
                  key: const PageStorageKey<String>('api-keys-list'),
                  padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
                  itemCount: rows.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ApiKeyCard(
                      info: rows[index],
                      controller: widget.controller,
                      onInspect: () => unawaited(_showAnalytics(rows[index])),
                      onEdit: () => unawaited(_editKey(rows[index])),
                      onRegenerate: () =>
                          unawaited(_regenerateKey(rows[index])),
                      onDelete: () => unawaited(_deleteKey(rows[index])),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _createKey() async {
    await _ensureModelSources();
    if (!mounted) {
      return;
    }
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ApiKeyEditorDialog(
        models: widget.controller.models.value ?? const <ModelItem>[],
        accounts: widget.controller.orderedAccounts(
          widget.controller.accounts.value ?? const <AccountSummary>[],
        ),
        sources:
            widget.controller.modelSources.value?.sources ??
            const <ModelSource>[],
      ),
    );
    if (payload == null || !mounted) {
      return;
    }
    final result = await widget.controller.createApiKey(payload);
    if (result != null && mounted) {
      await _showSecret(result, regenerated: false);
    }
  }

  Future<void> _showAnalytics(ApiKeyInfo info) async {
    unawaited(widget.controller.refreshApiKeyAnalytics(info.id));
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _ApiKeyAnalyticsDialog(info: info, controller: widget.controller),
    );
  }

  Future<void> _editKey(ApiKeyInfo info) async {
    await _ensureModelSources();
    if (!mounted) {
      return;
    }
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ApiKeyEditorDialog(
        current: info,
        models: widget.controller.models.value ?? const <ModelItem>[],
        accounts: widget.controller.orderedAccounts(
          widget.controller.accounts.value ?? const <AccountSummary>[],
        ),
        sources:
            widget.controller.modelSources.value?.sources ??
            const <ModelSource>[],
      ),
    );
    if (payload != null) {
      await widget.controller.updateApiKey(info.id, payload);
    }
  }

  Future<void> _ensureModelSources() async {
    if (widget.controller.modelSources.value == null) {
      await widget.controller.refreshModelSources();
    }
  }

  Future<void> _regenerateKey(ApiKeyInfo info) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Regenerate ${info.name}?',
      message:
          'The current secret will stop working immediately. The replacement is shown once and is never recoverable from the dashboard.',
      confirmLabel: 'Regenerate key',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final result = await widget.controller.regenerateApiKey(info.id);
    if (result != null && mounted) {
      await _showSecret(result, regenerated: true);
    }
  }

  Future<void> _deleteKey(ApiKeyInfo info) async {
    final confirmed = await showFeatureConfirmation(
      context,
      title: 'Delete ${info.name}?',
      message:
          'This permanently removes the local API-key policy and immediately revokes its secret. Account tokens and usage history are not touched.',
      confirmLabel: 'Delete key',
      destructive: true,
    );
    if (confirmed) {
      await widget.controller.deleteApiKey(info.id);
    }
  }

  Future<void> _showSecret(
    ApiKeyCreateResult result, {
    required bool regenerated,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(regenerated ? 'Replacement key ready' : 'API key created'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const FeatureWarning(
                message:
                    'Copy this secret now. Closing this dialog removes it from the native UI.',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.outline),
                ),
                child: SelectableText(
                  result.secret,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: result.secret));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Secret copied to clipboard.')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy secret'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I saved it'),
          ),
        ],
      ),
    );
  }
}

class _ApiKeySummary extends StatelessWidget {
  const _ApiKeySummary({required this.keys});

  final List<ApiKeyInfo> keys;

  @override
  Widget build(BuildContext context) {
    final active = keys.where((key) => key.isActive && !key.isExpired).length;
    final requests = keys.fold<int>(
      0,
      (sum, key) => sum + (key.usageSummary?.requestCount ?? 0),
    );
    final tokens = keys.fold<int>(
      0,
      (sum, key) => sum + (key.usageSummary?.totalTokens ?? 0),
    );
    final cost = keys.fold<double>(
      0,
      (sum, key) => sum + (key.usageSummary?.totalCostUsd ?? 0),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final cards = <Widget>[
          FeatureMetricCard(
            label: 'Usable keys',
            value: '$active',
            footnote: '${keys.length} total policies',
            icon: Icons.key_outlined,
            color: AppPalette.green,
          ),
          FeatureMetricCard(
            label: 'Requests',
            value: formatCompactNumber(requests),
            footnote: 'Recorded by key',
            icon: Icons.arrow_outward_rounded,
            color: AppPalette.cyan,
          ),
          FeatureMetricCard(
            label: 'Tokens',
            value: formatCompactNumber(tokens),
            footnote: 'Input and output',
            icon: Icons.data_usage_outlined,
            color: const Color(0xFFB49AF7),
          ),
          FeatureMetricCard(
            label: 'Cost',
            value: formatMoney(cost, 'USD'),
            footnote: 'Attributed traffic',
            icon: Icons.payments_outlined,
            color: AppPalette.amber,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _ApiKeyCard extends StatelessWidget {
  const _ApiKeyCard({
    required this.info,
    required this.controller,
    required this.onInspect,
    required this.onEdit,
    required this.onRegenerate,
    required this.onDelete,
  });

  final ApiKeyInfo info;
  final AppController controller;
  final VoidCallback onInspect;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final busy = controller.mutatingApiKeyIds.contains(info.id);
    final statusColor = info.isExpired
        ? AppPalette.red
        : info.isActive
        ? AppPalette.green
        : AppPalette.textMuted;
    return FeaturePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      info.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FeatureBadge(
                    label: info.isExpired
                        ? 'expired'
                        : info.isActive
                        ? 'active'
                        : 'disabled',
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                info.keyPrefix,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontFamily: 'Consolas',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  FeatureBadge(label: info.trafficClass),
                  if (info.enforcedModel != null)
                    FeatureBadge(
                      label: 'model ${info.enforcedModel}',
                      color: AppPalette.cyan,
                    ),
                  if (info.enforcedReasoningEffort != null)
                    FeatureBadge(label: info.enforcedReasoningEffort!),
                  if (info.accountAssignmentScopeEnabled)
                    FeatureBadge(
                      label: '${info.assignedAccountIds.length} accounts',
                    ),
                ],
              ),
            ],
          );
          final usage = _ApiKeyUsage(info: info);
          final actions = busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Wrap(
                  spacing: 5,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Usage and trends',
                      onPressed: onInspect,
                      icon: const Icon(Icons.insights_outlined),
                    ),
                    Switch(
                      value: info.isActive,
                      onChanged: controller.canWrite
                          ? (value) => unawaited(
                              controller.updateApiKey(
                                info.id,
                                <String, Object?>{'isActive': value},
                              ),
                            )
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Edit policy',
                      onPressed: controller.canWrite ? onEdit : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Regenerate secret',
                      onPressed: controller.canWrite ? onRegenerate : null,
                      icon: const Icon(Icons.autorenew),
                    ),
                    IconButton(
                      tooltip: 'Delete key',
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
                identity,
                const SizedBox(height: 14),
                usage,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 4, child: identity),
              const SizedBox(width: 18),
              Expanded(flex: 3, child: usage),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ApiKeyAnalyticsDialog extends StatelessWidget {
  const _ApiKeyAnalyticsDialog({required this.info, required this.controller});

  final ApiKeyInfo info;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${info.name} · 7-day usage'),
      content: SizedBox(
        width: 900,
        height: 620,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final section = controller.apiKeyAnalytics[info.id];
            if (section == null || (section.value == null && section.isBusy)) {
              return const FeatureProgress(
                label: 'Loading API-key usage and trends…',
              );
            }
            if (section.value == null) {
              return FeatureFailure(
                title: 'API-key analytics unavailable',
                error: section.error,
                onRetry: () =>
                    controller.refreshApiKeyAnalytics(info.id, force: true),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (section.isStale) ...<Widget>[
                  FeatureWarning(
                    message:
                        'Showing cached analytics. Refresh failed: ${featureErrorText(section.error)}',
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'API cache fetched ${formatRelative(section.lastSuccessfulFetch)} · latest source sample ${formatRelative(section.sourceSampleAt)}',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _ApiKeyAnalyticsBody(
                    analytics: section.value!,
                    accountLabels: <String, String>{
                      for (final account
                          in controller.accounts.value ??
                              const <AccountSummary>[])
                        account.accountId: account.displayName,
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => unawaited(
            controller.refreshApiKeyAnalytics(info.id, force: true),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh analytics'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ApiKeyAnalyticsBody extends StatelessWidget {
  const _ApiKeyAnalyticsBody({
    required this.analytics,
    required this.accountLabels,
  });

  final ApiKeyAnalytics analytics;
  final Map<String, String> accountLabels;

  @override
  Widget build(BuildContext context) {
    final usage = analytics.usage7Day;
    final accountCosts = usage.accountCosts.toList(growable: false)
      ..sort((left, right) => right.costUsd.compareTo(left.costUsd));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _AnalyticsMetric(
                label: 'Requests',
                value: formatCompactNumber(usage.totalRequests),
              ),
              _AnalyticsMetric(
                label: 'Tokens',
                value: formatCompactNumber(usage.totalTokens),
              ),
              _AnalyticsMetric(
                label: 'Cached input',
                value: formatCompactNumber(usage.cachedInputTokens),
              ),
              _AnalyticsMetric(
                label: 'Cost',
                value: formatMoney(usage.totalCostUsd, 'USD'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final charts = <Widget>[
                _TrendCard(
                  title: 'Cost trend',
                  value: formatMoney(usage.totalCostUsd, 'USD'),
                  points: analytics.trends.cost,
                  color: AppPalette.green,
                ),
                _TrendCard(
                  title: 'Token trend',
                  value: formatCompactNumber(usage.totalTokens),
                  points: analytics.trends.tokens,
                  color: AppPalette.cyan,
                ),
              ];
              if (constraints.maxWidth < 700) {
                return Column(
                  children: <Widget>[
                    charts.first,
                    const SizedBox(height: 10),
                    charts.last,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: charts.first),
                  const SizedBox(width: 10),
                  Expanded(child: charts.last),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Cost by account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (accountCosts.isEmpty)
            const Text(
              'No account-attributed cost in this window.',
              style: TextStyle(color: AppPalette.textMuted),
            )
          else
            for (final row in accountCosts.take(50))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _accountCostLabel(row),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: row.isDeleted
                              ? AppPalette.textMuted
                              : AppPalette.text,
                        ),
                      ),
                    ),
                    if (row.isDeleted) ...<Widget>[
                      const FeatureBadge(label: 'deleted'),
                      const SizedBox(width: 9),
                    ],
                    Text(
                      formatMoney(row.costUsd, 'USD'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _accountCostLabel(ApiKeyAccountCost row) {
    final accountId = row.accountId;
    if (accountId != null) {
      final currentLabel = accountLabels[accountId];
      if (currentLabel != null && currentLabel.trim().isNotEmpty) {
        return currentLabel;
      }
    }
    final email = row.email;
    if (email != null && email.trim().isNotEmpty) {
      return accountDisplayNameFromEmail(email);
    }
    return 'Unknown account';
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.value,
    required this.points,
    required this.color,
  });

  final String title;
  final String value;
  final List<ApiKeyTrendPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(color: AppPalette.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 105,
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'No samples',
                      style: TextStyle(color: AppPalette.textMuted),
                    ),
                  )
                : Semantics(
                    label: '$title with ${points.length} time samples',
                    child: CustomPaint(
                      painter: _TrendPainter(points: points, color: color),
                      size: Size.infinite,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points, required this.color});

  final List<ApiKeyTrendPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) {
      return;
    }
    final ordered = points.toList(growable: false)
      ..sort((left, right) => left.time.compareTo(right.time));
    final minTime = ordered.first.time.millisecondsSinceEpoch.toDouble();
    final maxTime = ordered.last.time.millisecondsSinceEpoch.toDouble();
    final maxValue = ordered
        .map((point) => point.value)
        .fold<double>(0, (current, value) => value > current ? value : current);
    final gridPaint = Paint()
      ..color = AppPalette.outline.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var index = 1; index < 4; index += 1) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path();
    for (var index = 0; index < ordered.length; index += 1) {
      final point = ordered[index];
      final x = maxTime == minTime
          ? (ordered.length == 1
                ? size.width / 2
                : size.width * index / (ordered.length - 1))
          : size.width *
                (point.time.millisecondsSinceEpoch - minTime) /
                (maxTime - minTime);
      final y = maxValue <= 0
          ? size.height
          : size.height * (1 - point.value / maxValue);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _ApiKeyUsage extends StatelessWidget {
  const _ApiKeyUsage({required this.info});

  final ApiKeyInfo info;

  @override
  Widget build(BuildContext context) {
    final usage = info.usageSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${formatCompactNumber(usage?.requestCount)} requests · ${formatCompactNumber(usage?.totalTokens)} tokens',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          '${formatMoney(usage?.totalCostUsd ?? 0, 'USD')} · last used ${formatRelative(info.lastUsedAt)}',
          style: const TextStyle(color: AppPalette.textMuted, fontSize: 12),
        ),
        if (info.limits.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          for (final limit in info.limits.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: LinearProgressIndicator(
                      value: limit.fraction,
                      minHeight: 5,
                      backgroundColor: AppPalette.outline,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        limit.fraction >= 1 ? AppPalette.red : AppPalette.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${limit.currentValue}/${limit.maxValue} ${limit.limitWindow}',
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ApiKeyEditorDialog extends StatefulWidget {
  const _ApiKeyEditorDialog({
    required this.models,
    required this.accounts,
    required this.sources,
    this.current,
  });

  final ApiKeyInfo? current;
  final List<ModelItem> models;
  final List<AccountSummary> accounts;
  final List<ModelSource> sources;

  @override
  State<_ApiKeyEditorDialog> createState() => _ApiKeyEditorDialogState();
}

class _ApiKeyEditorDialogState extends State<_ApiKeyEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _weeklyLimit;
  late final Set<String> _allowedModels;
  late final Set<String> _accountIds;
  late final Set<String> _sourceIds;
  late String _enforcedModel;
  late String _reasoning;
  late String _serviceTier;
  late String _trafficClass;
  late bool _active;
  late bool _showUpstreamLimits;
  late bool _showAccountPoolUsage;
  bool _resetUsage = false;
  bool _clearMissingSourceRestriction = false;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _name = TextEditingController(text: current?.name ?? '');
    final weekly = current?.limits
        .where(
          (limit) =>
              limit.limitType == 'total_tokens' &&
              limit.limitWindow == 'weekly' &&
              limit.modelFilter == null,
        )
        .firstOrNull;
    _weeklyLimit = TextEditingController(
      text: weekly?.maxValue.toString() ?? '',
    );
    _allowedModels = <String>{...?(current?.allowedModels)};
    _accountIds = <String>{...?current?.assignedAccountIds};
    _sourceIds = <String>{...?current?.assignedSourceIds};
    _enforcedModel = current?.enforcedModel ?? '';
    _reasoning = current?.enforcedReasoningEffort ?? '';
    _serviceTier = current?.enforcedServiceTier ?? '';
    _trafficClass = current?.trafficClass ?? 'foreground';
    _active = current?.isActive ?? true;
    final sections =
        (current?.usageSections ?? 'upstream_limits,account_pool_usage')
            .split(',')
            .toSet();
    _showUpstreamLimits = sections.contains('upstream_limits');
    _showAccountPoolUsage = sections.contains('account_pool_usage');
  }

  @override
  void dispose() {
    _name.dispose();
    _weeklyLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.current != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit API policy' : 'Create API key'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 128,
                  decoration: const InputDecoration(
                    labelText: 'Key name',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name is required.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _enforcedModel,
                  decoration: const InputDecoration(
                    labelText: 'Enforced model',
                    helperText: 'Optional; blank lets the request choose.',
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('No enforced model'),
                    ),
                    ...widget.models.map(
                      (model) => DropdownMenuItem<String>(
                        value: model.id,
                        child: Text(model.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _enforcedModel = value ?? ''),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _reasoning,
                        decoration: const InputDecoration(
                          labelText: 'Reasoning effort',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: '',
                            child: Text('Request choice'),
                          ),
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(
                            value: 'minimal',
                            child: Text('Minimal'),
                          ),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(
                            value: 'xhigh',
                            child: Text('X-high'),
                          ),
                          DropdownMenuItem(value: 'max', child: Text('Max')),
                          DropdownMenuItem(
                            value: 'ultra',
                            child: Text('Ultra'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _reasoning = value ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _serviceTier,
                        decoration: const InputDecoration(
                          labelText: 'Service tier',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: '',
                            child: Text('Request choice'),
                          ),
                          DropdownMenuItem(value: 'auto', child: Text('Auto')),
                          DropdownMenuItem(
                            value: 'default',
                            child: Text('Default'),
                          ),
                          DropdownMenuItem(
                            value: 'priority',
                            child: Text('Priority'),
                          ),
                          DropdownMenuItem(value: 'flex', child: Text('Flex')),
                          DropdownMenuItem(value: 'fast', child: Text('Fast')),
                        ],
                        onChanged: (value) =>
                            setState(() => _serviceTier = value ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _trafficClass,
                  decoration: const InputDecoration(labelText: 'Traffic class'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'foreground',
                      child: Text('Foreground'),
                    ),
                    DropdownMenuItem(
                      value: 'opportunistic',
                      child: Text('Opportunistic'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _trafficClass = value ?? 'foreground'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weeklyLimit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weekly total-token limit',
                    helperText:
                        'Optional. Leave blank for no weekly key limit.',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final parsed = int.tryParse(value.trim());
                    return parsed == null || parsed <= 0
                        ? 'Enter a positive whole number.'
                        : null;
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'Allowed models',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _allowedModels.isEmpty
                      ? 'All models are allowed.'
                      : '${_allowedModels.length} explicitly allowed.',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: widget.models
                      .map(
                        (model) => FilterChip(
                          label: Text(
                            model.sourceOnly
                                ? '${model.name} · external source'
                                : model.name,
                          ),
                          selected: _allowedModels.contains(model.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _allowedModels.add(model.id)
                                : _allowedModels.remove(model.id);
                          }),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
                Text(
                  'Model-source scope',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _sourceIds.isEmpty
                      ? (widget.current?.sourceAssignmentScopeEnabled ?? false)
                            ? 'Restricted to no source. Requests are denied until a source is selected or the restriction is explicitly removed.'
                            : 'All enabled model sources are allowed.'
                      : '${_sourceIds.length} assigned model sources.',
                  style: TextStyle(
                    color:
                        _sourceIds.isEmpty &&
                            (widget.current?.sourceAssignmentScopeEnabled ??
                                false)
                        ? AppPalette.amber
                        : AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.sources.isEmpty)
                  const Text(
                    'No model-source catalog is currently available. Existing assignments are preserved.',
                    style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: widget.sources
                        .map(
                          (source) => FilterChip(
                            label: Text(
                              source.isEnabled
                                  ? source.name
                                  : '${source.name} · disabled',
                            ),
                            selected: _sourceIds.contains(source.id),
                            onSelected: (selected) => setState(() {
                              selected
                                  ? _sourceIds.add(source.id)
                                  : _sourceIds.remove(source.id);
                              _clearMissingSourceRestriction = false;
                            }),
                          ),
                        )
                        .toList(growable: false),
                  ),
                for (final missingId in _sourceIds.where(
                  (id) => widget.sources.every((source) => source.id != id),
                ))
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: FilterChip(
                      label: Text('Missing source · $missingId'),
                      selected: true,
                      onSelected: (selected) {
                        if (!selected) {
                          setState(() => _sourceIds.remove(missingId));
                        }
                      },
                    ),
                  ),
                if ((widget.current?.sourceAssignmentScopeEnabled ?? false) &&
                    (widget.current?.assignedSourceIds.isEmpty ?? false) &&
                    _sourceIds.isEmpty)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _clearMissingSourceRestriction,
                    title: const Text(
                      'Remove the deny-all restriction and allow all sources',
                    ),
                    subtitle: const Text(
                      'Unchecked keeps the existing safe deny-all state.',
                    ),
                    onChanged: (value) => setState(
                      () => _clearMissingSourceRestriction = value ?? false,
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Account scope',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _accountIds.isEmpty
                      ? 'All accounts in the routing pool.'
                      : '${_accountIds.length} assigned accounts.',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 170),
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
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _showUpstreamLimits,
                  title: const Text('Expose upstream limits'),
                  onChanged: (value) =>
                      setState(() => _showUpstreamLimits = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _showAccountPoolUsage,
                  title: const Text('Expose account-pool usage'),
                  onChanged: (value) =>
                      setState(() => _showAccountPoolUsage = value),
                ),
                if (isEditing) ...<Widget>[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _active,
                    title: const Text('Key enabled'),
                    onChanged: (value) => setState(() => _active = value),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _resetUsage,
                    title: const Text('Reset usage counters on save'),
                    onChanged: (value) =>
                        setState(() => _resetUsage = value ?? false),
                  ),
                ],
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
          child: Text(isEditing ? 'Save policy' : 'Create key'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_showUpstreamLimits && !_showAccountPoolUsage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one usage section visible.'),
        ),
      );
      return;
    }
    final usageSections = <String>[
      if (_showUpstreamLimits) 'upstream_limits',
      if (_showAccountPoolUsage) 'account_pool_usage',
    ];
    final weeklyLimit = int.tryParse(_weeklyLimit.text.trim());
    final payload = <String, Object?>{
      'name': _name.text.trim(),
      'allowedModels': _allowedModels.isEmpty
          ? null
          : _allowedModels.toList(growable: false),
      'applyToCodexModel': _enforcedModel.isNotEmpty,
      'enforcedModel': _enforcedModel.isEmpty ? null : _enforcedModel,
      'enforcedReasoningEffort': _reasoning.isEmpty ? null : _reasoning,
      'enforcedServiceTier': _serviceTier.isEmpty ? null : _serviceTier,
      'trafficClass': _trafficClass,
      'usageSections': usageSections.join(','),
      'assignedAccountIds': _accountIds.toList(growable: false),
      'limits': weeklyLimit == null
          ? const <Object?>[]
          : <Object?>[
              <String, Object?>{
                'limitType': 'total_tokens',
                'limitWindow': 'weekly',
                'maxValue': weeklyLimit,
              },
            ],
      if (widget.current != null) 'isActive': _active,
      if (widget.current != null && _resetUsage) 'resetUsage': true,
    };
    final sourceMutation = buildSourceAssignmentMutation(
      creating: widget.current == null,
      initialSourceIds: widget.current?.assignedSourceIds ?? const <String>[],
      sourceScopeEnabled: widget.current?.sourceAssignmentScopeEnabled ?? false,
      selectedSourceIds: _sourceIds,
      clearMissingRestriction: _clearMissingSourceRestriction,
    );
    if (sourceMutation.include) {
      payload['assignedSourceIds'] = sourceMutation.ids;
    }
    Navigator.pop(context, payload);
  }
}

/// Encodes the backend's safe source-scope semantics.
///
/// A key can legitimately have `scopeEnabled=true` and no surviving source
/// IDs. That state is deny-all. Omitting the field preserves it; sending an
/// empty list disables the scope and broadens access, so that only happens
/// after the operator explicitly requests it.
({bool include, List<String> ids}) buildSourceAssignmentMutation({
  required bool creating,
  required List<String> initialSourceIds,
  required bool sourceScopeEnabled,
  required Set<String> selectedSourceIds,
  required bool clearMissingRestriction,
}) {
  final selected = selectedSourceIds.toList(growable: false)..sort();
  if (creating) {
    return (include: selected.isNotEmpty, ids: selected);
  }
  final initial = initialSourceIds.toSet();
  final changed =
      initial.length != selectedSourceIds.length ||
      initial.any((id) => !selectedSourceIds.contains(id));
  final explicitDenyAllRemoval =
      sourceScopeEnabled &&
      selectedSourceIds.isEmpty &&
      clearMissingRestriction;
  return (include: changed || explicitDenyAllRemoval, ids: selected);
}
