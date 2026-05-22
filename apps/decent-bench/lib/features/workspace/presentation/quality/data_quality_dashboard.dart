import 'package:flutter/material.dart';

import '../../application/data_quality_controller.dart';
import '../../domain/data_quality_models.dart';
import 'table_quality_view.dart';
import 'validation_profile_editor.dart';

class DataQualityDashboard extends StatelessWidget {
  const DataQualityDashboard({
    super.key,
    required this.controller,
    required this.onExportReport,
  });

  final DataQualityController controller;
  final VoidCallback onExportReport;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final run = controller.currentRun;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _QualityHeader(controller: controller),
            _QualityActions(
              controller: controller,
              onExportReport: onExportReport,
            ),
            if (run == null)
              const Expanded(child: _QualityEmptyState())
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: <Widget>[
                    _SummaryBand(result: run),
                    const SizedBox(height: 8),
                    _SectionTitle('Tables'),
                    for (final table in run.profileSummaries)
                      _TableSummaryRow(
                        table: table,
                        issueCount: run.validationIssues
                            .where(
                              (issue) => issue.targetTable == table.tableName,
                            )
                            .length,
                        onTap: () {
                          controller.selectTable(table.tableName);
                          showDialog<void>(
                            context: context,
                            builder: (_) => Dialog(
                              child: SizedBox(
                                width: 980,
                                height: 720,
                                child: TableQualityView(
                                  controller: controller,
                                  tableName: table.tableName,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    _SectionTitle('Worst Columns'),
                    for (final column in _worstColumns(run).take(8))
                      _WorstColumnRow(column: column),
                    const SizedBox(height: 8),
                    _SectionTitle('Recent Runs'),
                    for (final recent in controller.recentRuns.take(8))
                      _RecentRunRow(result: recent),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QualityHeader extends StatelessWidget {
  const _QualityHeader({required this.controller});

  final DataQualityController controller;

  @override
  Widget build(BuildContext context) {
    final run = controller.currentRun;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.fact_check_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quality',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _FreshnessChip(status: controller.freshness),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            controller.databasePath ?? 'No database open',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (run != null)
            Text(
              'Last run: ${run.startedAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (controller.progress != null)
            Text(
              '${controller.progress!.phase}'
              '${controller.progress!.currentTable == null ? '' : ' - ${controller.progress!.currentTable}'}'
              '${controller.progress!.currentRule == null ? '' : ' - ${controller.progress!.currentRule}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (controller.errorMessage != null)
            Text(
              controller.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

class _QualityActions extends StatelessWidget {
  const _QualityActions({
    required this.controller,
    required this.onExportReport,
  });

  final DataQualityController controller;
  final VoidCallback onExportReport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton.icon(
            onPressed: controller.hasDatabase && !controller.isRunning
                ? () => controller.startRun()
                : null,
            icon: const Icon(Icons.play_arrow_outlined, size: 18),
            label: const Text('Run'),
          ),
          OutlinedButton.icon(
            onPressed: controller.isRunning ? controller.cancelRun : null,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: controller.hasDatabase
                ? () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: SizedBox(
                          width: 920,
                          height: 680,
                          child: ValidationProfileEditor(
                            controller: controller,
                          ),
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.rule_folder_outlined, size: 18),
            label: const Text('Manage Profiles'),
          ),
          OutlinedButton.icon(
            onPressed: controller.currentRun == null ? null : onExportReport,
            icon: const Icon(Icons.ios_share_outlined, size: 18),
            label: const Text('Export Report'),
          ),
          IconButton(
            tooltip: 'Refresh Status',
            onPressed: controller.hasDatabase
                ? controller.loadRecentRuns
                : null,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
    );
  }
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.result});

  final QualityRunResult result;

  @override
  Widget build(BuildContext context) {
    final rows = result.profileSummaries.fold<int>(
      0,
      (sum, table) => sum + table.rowCount,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _MetricBox(label: 'Tables', value: '${result.profileSummaries.length}'),
        _MetricBox(label: 'Rows', value: '$rows'),
        _MetricBox(label: 'Rules', value: '${result.validationIssues.length}'),
        _MetricBox(label: 'Errors', value: '${result.errorIssueCount}'),
        _MetricBox(label: 'Warnings', value: '${result.warningIssueCount}'),
        _MetricBox(label: 'Info', value: '${result.infoIssueCount}'),
        _MetricBox(
          label: 'Duplicates',
          value: '${result.duplicateSummaries.length}',
        ),
        _MetricBox(
          label: 'Import Warnings',
          value: '${result.importReconciliation?.warningCount ?? 0}',
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _TableSummaryRow extends StatelessWidget {
  const _TableSummaryRow({
    required this.table,
    required this.issueCount,
    required this.onTap,
  });

  final TableQualitySummary table;
  final int issueCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nullHeavy = table.columnSummaries
        .where((column) => column.nullPercent >= 50)
        .length;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(table.tableName),
      subtitle: Text(
        '${table.rowCount} rows | $nullHeavy null-heavy columns | $issueCount issues',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _WorstColumnRow extends StatelessWidget {
  const _WorstColumnRow({required this.column});

  final _WorstColumn column;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text('${column.table}.${column.column.columnName}'),
      subtitle: Text(column.metric),
      trailing: Text(column.value),
    );
  }
}

class _RecentRunRow extends StatelessWidget {
  const _RecentRunRow({required this.result});

  final QualityRunResult result;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text('${result.runId.substring(0, 8)} - ${result.targetLabel}'),
      subtitle: Text('${result.mode.wireName} | ${result.status.wireName}'),
      trailing: Text('${result.validationIssues.length} issues'),
    );
  }
}

class _FreshnessChip extends StatelessWidget {
  const _FreshnessChip({required this.status});

  final QualityFreshnessStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(switch (status) {
        QualityFreshnessStatus.fresh => 'Fresh',
        QualityFreshnessStatus.stale => 'Stale',
        QualityFreshnessStatus.running => 'Running',
        QualityFreshnessStatus.failed => 'Failed',
        QualityFreshnessStatus.noRun => 'No run',
      }),
    );
  }
}

class _QualityEmptyState extends StatelessWidget {
  const _QualityEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Run a quality profile to profile tables and validation rules.',
      ),
    );
  }
}

class _WorstColumn {
  const _WorstColumn({
    required this.table,
    required this.column,
    required this.metric,
    required this.value,
  });

  final String table;
  final ColumnQualitySummary column;
  final String metric;
  final String value;
}

List<_WorstColumn> _worstColumns(QualityRunResult result) {
  final columns = <_WorstColumn>[];
  for (final table in result.profileSummaries) {
    for (final column in table.columnSummaries) {
      if (column.nullPercent > 0) {
        columns.add(
          _WorstColumn(
            table: table.tableName,
            column: column,
            metric: 'Null percentage',
            value: '${column.nullPercent.toStringAsFixed(1)}%',
          ),
        );
      }
      if (column.outlierSummary != null &&
          column.outlierSummary!.outlierCount > 0) {
        columns.add(
          _WorstColumn(
            table: table.tableName,
            column: column,
            metric: 'Outliers',
            value: '${column.outlierSummary!.outlierCount}',
          ),
        );
      }
    }
  }
  columns.sort((left, right) => right.value.compareTo(left.value));
  return columns;
}
