import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/account_summary.dart';
import '../../models/reports_data.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';
import '../formatters.dart';
import 'feature_widgets.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.controller, super.key});

  final AppController controller;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _range = 'all';
  String? _accountId;
  String? _model;
  String? _userAgent;

  @override
  Widget build(BuildContext context) {
    final section = widget.controller.reports;
    if (section.value == null && section.isBusy) {
      return const FeatureProgress(label: 'Building native usage report…');
    }
    if (section.value == null) {
      return FeatureFailure(
        title: 'Traffic unavailable',
        error: section.error,
        onRetry: widget.controller.refreshReports,
      );
    }
    final report = section.value!;
    return CustomScrollView(
      key: const PageStorageKey<String>('reports-scroll'),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 14),
          sliver: SliverToBoxAdapter(
            child: FeaturePageHeader(
              eyebrow: 'USAGE LEDGER',
              title: 'Measured traffic, cost, and latency',
              detail:
                  'Analyze the local request ledger by time, model, account, and client family; compare volume, estimated cost, failures, and latency. ${report.daily.length} daily rows · fetched ${formatRelative(section.lastSuccessfulFetch)}',
              trailing: SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: '7d', label: Text('7d')),
                  ButtonSegment<String>(value: '30d', label: Text('30d')),
                  ButtonSegment<String>(value: '90d', label: Text('90d')),
                  ButtonSegment<String>(value: 'all', label: Text('All')),
                ],
                selected: <String>{_range},
                onSelectionChanged: section.isBusy
                    ? null
                    : (selection) {
                        setState(() => _range = selection.single);
                        unawaited(_applyFilters());
                      },
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(child: _buildFilters(report)),
        ),
        if (section.isStale)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
            sliver: SliverToBoxAdapter(
              child: FeatureWarning(
                message:
                    'Showing the last successful report. Refresh failed: ${featureErrorText(section.error)}',
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(child: _SummaryGrid(report: report)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(child: _DailySeriesPanel(report: report)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          sliver: SliverToBoxAdapter(child: _DistributionGrid(report: report)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
          sliver: SliverToBoxAdapter(child: _DailyTable(report: report)),
        ),
      ],
    );
  }

  Widget _buildFilters(ReportsData report) {
    final accounts = widget.controller.orderedAccounts(
      widget.controller.accounts.value ?? const <AccountSummary>[],
    );
    final models = report.byModel.map((entry) => entry.model).toSet().toList()
      ..sort();
    final userAgents =
        report.byUserAgent.map((entry) => entry.userAgent).toSet().toList()
          ..sort();
    final selectedAccount =
        accounts.any((account) => account.accountId == _accountId)
        ? _accountId
        : null;
    final selectedModel = models.contains(_model) ? _model : null;
    final selectedUserAgent = userAgents.contains(_userAgent)
        ? _userAgent
        : null;
    return FeaturePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width >= 980
              ? (width - 24) / 3
              : width >= 620
              ? (width - 12) / 2
              : width;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: itemWidth,
                child: DropdownButtonFormField<String?>(
                  initialValue: selectedAccount,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    prefixIcon: Icon(Icons.account_circle_outlined),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All accounts'),
                    ),
                    ...accounts.map(
                      (account) => DropdownMenuItem<String?>(
                        value: account.accountId,
                        child: Text(
                          account.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _accountId = value);
                    unawaited(_applyFilters());
                  },
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: DropdownButtonFormField<String?>(
                  initialValue: selectedModel,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    prefixIcon: Icon(Icons.memory_outlined),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All models'),
                    ),
                    ...models.map(
                      (model) => DropdownMenuItem<String?>(
                        value: model,
                        child: Text(model, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _model = value);
                    unawaited(_applyFilters());
                  },
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: DropdownButtonFormField<String?>(
                  initialValue: selectedUserAgent,
                  decoration: const InputDecoration(
                    labelText: 'Client family',
                    prefixIcon: Icon(Icons.devices_outlined),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All clients'),
                    ),
                    ...userAgents.map(
                      (agent) => DropdownMenuItem<String?>(
                        value: agent,
                        child: Text(agent, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _userAgent = value);
                    unawaited(_applyFilters());
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyFilters() {
    final now = DateTime.now().toUtc();
    final days = switch (_range) {
      '7d' => 7,
      '30d' => 30,
      '90d' => 90,
      _ => null,
    };
    final start = days == null
        ? null
        : _isoDate(now.subtract(Duration(days: days - 1)));
    return widget.controller.refreshReports(
      query: ReportsQuery(
        startDate: start,
        endDate: days == null ? null : _isoDate(now),
        accountIds: _accountId == null
            ? const <String>[]
            : <String>[_accountId!],
        model: _model,
        userAgentGroup: _userAgent,
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});

  final ReportsData report;

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            SizedBox(
              width: width,
              child: FeatureMetricCard(
                label: 'Recorded cost',
                value: formatMoney(summary.totalCostUsd, 'USD'),
                footnote:
                    '${formatMoney(summary.avgCostPerDay, 'USD')} per day',
                icon: Icons.payments_outlined,
                color: AppPalette.amber,
              ),
            ),
            SizedBox(
              width: width,
              child: FeatureMetricCard(
                label: 'Requests',
                value: formatCompactNumber(summary.totalRequests),
                footnote:
                    '${formatCompactNumber(summary.totalConversations)} conversations',
                icon: Icons.arrow_outward_rounded,
                color: AppPalette.cyan,
              ),
            ),
            SizedBox(
              width: width,
              child: FeatureMetricCard(
                label: 'Tokens',
                value: formatCompactNumber(summary.totalTokens),
                footnote:
                    '${formatCompactNumber(summary.totalCachedTokens)} cached input',
                icon: Icons.data_usage_outlined,
                color: const Color(0xFFB49AF7),
              ),
            ),
            SizedBox(
              width: width,
              child: FeatureMetricCard(
                label: 'Errors',
                value: formatCompactNumber(summary.totalErrors),
                footnote: '${summary.activeAccounts} active accounts',
                icon: Icons.error_outline,
                color: summary.totalErrors == 0
                    ? AppPalette.green
                    : AppPalette.red,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DailySeriesPanel extends StatelessWidget {
  const _DailySeriesPanel({required this.report});

  final ReportsData report;

  @override
  Widget build(BuildContext context) {
    final rows = report.daily.length > 30
        ? report.daily.sublist(report.daily.length - 30)
        : report.daily;
    final maxCost = rows.fold<double>(
      0,
      (current, row) => row.costUsd > current ? row.costUsd : current,
    );
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Daily cost pulse',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          const Text(
            'Latest 30 report buckets; bars are normalized only within this view.',
            style: TextStyle(color: AppPalette.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const SizedBox(
              height: 90,
              child: Center(child: Text('No traffic in this filter.')),
            )
          else
            SizedBox(
              height: 132,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: rows
                    .map((row) {
                      final fraction = maxCost <= 0
                          ? 0.03
                          : row.costUsd / maxCost;
                      return Expanded(
                        child: Tooltip(
                          message:
                              '${row.date}\n${formatMoney(row.costUsd, 'USD')} · ${row.requests} requests',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Container(
                              height: 10 + 112 * fraction.clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                color: AppPalette.cyan.withValues(
                                  alpha: 0.28 + 0.64 * fraction,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _DistributionGrid extends StatelessWidget {
  const _DistributionGrid({required this.report});

  final ReportsData report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 820;
        final panels = <Widget>[
          _DistributionPanel(
            title: 'Cost by model',
            rows: report.byModel
                .map(
                  (entry) => _DistributionRow(
                    label: entry.model,
                    value: entry.costUsd,
                    requests: entry.requests,
                    percentage: entry.percentage,
                  ),
                )
                .toList(growable: false),
          ),
          _DistributionPanel(
            title: 'Cost by client family',
            rows: report.byUserAgent
                .map(
                  (entry) => _DistributionRow(
                    label: entry.userAgent,
                    value: entry.costUsd,
                    requests: entry.requests,
                    percentage: entry.percentage,
                  ),
                )
                .toList(growable: false),
          ),
        ];
        if (stacked) {
          return Column(
            children: <Widget>[
              panels[0],
              const SizedBox(height: 12),
              panels[1],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: panels[0]),
            const SizedBox(width: 12),
            Expanded(child: panels[1]),
          ],
        );
      },
    );
  }
}

class _DistributionRow {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.requests,
    required this.percentage,
  });

  final String label;
  final double value;
  final int requests;
  final double percentage;
}

class _DistributionPanel extends StatelessWidget {
  const _DistributionPanel({required this.title, required this.rows});

  final String title;
  final List<_DistributionRow> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows.take(8).toList(growable: false);
    return FeaturePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No distribution data.')),
            )
          else
            for (final row in visible) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatMoney(row.value, 'USD'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (row.percentage / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AppPalette.outline,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppPalette.cyan,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${row.percentage.toStringAsFixed(1)}% · ${formatCompactNumber(row.requests)} requests',
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 13),
            ],
        ],
      ),
    );
  }
}

class _DailyTable extends StatelessWidget {
  const _DailyTable({required this.report});

  final ReportsData report;

  @override
  Widget build(BuildContext context) {
    final rows = report.daily.reversed.toList(growable: false);
    return FeaturePanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Text(
              'Daily detail',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          const _DailyRowHeader(),
          const Divider(height: 1),
          if (rows.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(child: Text('No daily rows for this filter.')),
            )
          else
            SizedBox(
              height: (rows.length * 48.0).clamp(96, 430),
              child: ListView.builder(
                itemExtent: 48,
                itemCount: rows.length,
                itemBuilder: (context, index) => _DailyRow(row: rows[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyRowHeader extends StatelessWidget {
  const _DailyRowHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(flex: 2, child: Text('DATE')),
          Expanded(child: Text('REQUESTS', textAlign: TextAlign.right)),
          Expanded(child: Text('TOKENS', textAlign: TextAlign.right)),
          Expanded(child: Text('ERRORS', textAlign: TextAlign.right)),
          Expanded(child: Text('TTFT', textAlign: TextAlign.right)),
          Expanded(child: Text('QUEUE', textAlign: TextAlign.right)),
          Expanded(child: Text('COST', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.row});

  final DailyReportRow row;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: AppPalette.textMuted, fontSize: 12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.outline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(flex: 2, child: Text(row.date, style: muted)),
          Expanded(
            child: Text(
              formatCompactNumber(row.requests),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              formatCompactNumber(row.totalTokens),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              formatCompactNumber(row.errorCount),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: row.errorCount == 0
                    ? AppPalette.textMuted
                    : AppPalette.red,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${row.medianTtftMs.toStringAsFixed(0)}ms',
              textAlign: TextAlign.right,
              style: muted,
            ),
          ),
          Expanded(
            child: Text(
              '${row.medianQueueMs.toStringAsFixed(0)}ms',
              textAlign: TextAlign.right,
              style: muted,
            ),
          ),
          Expanded(
            child: Text(
              formatMoney(row.costUsd, 'USD'),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _isoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
