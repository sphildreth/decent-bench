import 'package:flutter/material.dart';

import '../../application/data_quality_controller.dart';
import '../../domain/data_quality_models.dart';
import 'violation_browser.dart';

class TableQualityView extends StatelessWidget {
  const TableQualityView({
    super.key,
    required this.controller,
    required this.tableName,
  });

  final DataQualityController controller;
  final String tableName;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final run = controller.currentRun;
        final table = run?.profileSummaries
            .where((item) => item.tableName == tableName)
            .firstOrNull;
        final issues =
            run?.validationIssues
                .where((issue) => issue.targetTable == tableName)
                .toList() ??
            const <ValidationIssueSummary>[];
        final duplicates =
            run?.duplicateSummaries
                .where((summary) => summary.targetTable == tableName)
                .toList() ??
            const <DuplicateSummary>[];
        final reconciliation = run?.importReconciliation;
        return DefaultTabController(
          length: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Quality: $tableName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const TabBar(
                tabs: <Widget>[
                  Tab(text: 'Profile'),
                  Tab(text: 'Validation'),
                  Tab(text: 'Duplicates'),
                  Tab(text: 'Import'),
                  Tab(text: 'History'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _ProfileTab(table: table),
                    _ValidationTab(controller: controller, issues: issues),
                    _DuplicatesTab(duplicates: duplicates),
                    _ImportTab(
                      reconciliation: reconciliation,
                      tableName: tableName,
                    ),
                    _HistoryTab(
                      runs: controller.recentRuns
                          .where(
                            (run) => run.profileSummaries.any(
                              (table) => table.tableName == tableName,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.table});

  final TableQualitySummary? table;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  ColumnQualitySummary? selectedColumn;

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    if (table == null) {
      return const Center(child: Text('No profile summary for this table.'));
    }
    selectedColumn ??= table.columnSummaries.firstOrNull;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: ListView(
            children: <Widget>[
              DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Column')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Null %')),
                  DataColumn(label: Text('Distinct')),
                  DataColumn(label: Text('Potential key')),
                ],
                rows: <DataRow>[
                  for (final column in table.columnSummaries)
                    DataRow(
                      selected: selectedColumn == column,
                      onSelectChanged: (_) {
                        setState(() => selectedColumn = column);
                      },
                      cells: <DataCell>[
                        DataCell(Text(column.columnName)),
                        DataCell(Text(column.typeName)),
                        DataCell(Text(column.nullPercent.toStringAsFixed(1))),
                        DataCell(Text('${column.distinctCount}')),
                        DataCell(Text(column.potentialKey ? 'yes' : 'no')),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(flex: 2, child: _ColumnDetails(column: selectedColumn)),
      ],
    );
  }
}

class _ColumnDetails extends StatelessWidget {
  const _ColumnDetails({required this.column});

  final ColumnQualitySummary? column;

  @override
  Widget build(BuildContext context) {
    final column = this.column;
    if (column == null) {
      return const Center(child: Text('Select a column.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Text(column.columnName, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _kv('Rows', '${column.rowCount}'),
        _kv(
          'Nulls',
          '${column.nullCount} (${column.nullPercent.toStringAsFixed(1)}%)',
        ),
        _kv('Empty strings', '${column.emptyStringCount}'),
        _kv('Min', column.minValueDisplay ?? ''),
        _kv('Max', column.maxValueDisplay ?? ''),
        _kv('Mean', column.meanValueDisplay ?? ''),
        _kv('Median', column.medianValueDisplay ?? ''),
        _kv('Stddev', column.stddevValueDisplay ?? ''),
        _kv('Malformed temporal', '${column.malformedTemporalCount}'),
        if (column.outlierSummary != null)
          _kv('IQR outliers', '${column.outlierSummary!.outlierCount}'),
        const SizedBox(height: 12),
        Text('Top Values', style: Theme.of(context).textTheme.titleSmall),
        for (final value in column.topValues)
          _kv(
            value.valueDisplay,
            '${value.count} (${value.percent.toStringAsFixed(1)}%)',
          ),
        const SizedBox(height: 12),
        Text('Histogram', style: Theme.of(context).textTheme.titleSmall),
        if (column.histogramBuckets.isEmpty)
          const Text('No histogram for this column.')
        else
          for (final bucket in column.histogramBuckets)
            _kv(bucket.label, '${bucket.count}'),
      ],
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(key)),
          Text(value),
        ],
      ),
    );
  }
}

class _ValidationTab extends StatelessWidget {
  const _ValidationTab({required this.controller, required this.issues});

  final DataQualityController controller;
  final List<ValidationIssueSummary> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const Center(child: Text('No validation issues for this table.'));
    }
    return ListView(
      children: <Widget>[
        for (final issue in issues)
          ListTile(
            dense: true,
            leading: Icon(_severityIcon(issue.severity)),
            title: Text(issue.ruleName),
            subtitle: Text(
              '${issue.issueCode} | ${issue.failureCount} failures',
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              controller.selectIssue(issue);
              showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: SizedBox(
                    width: 900,
                    height: 640,
                    child: ViolationBrowser(
                      controller: controller,
                      issue: issue,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  IconData _severityIcon(QualitySeverity severity) {
    return switch (severity) {
      QualitySeverity.error => Icons.error_outline,
      QualitySeverity.warning => Icons.warning_amber_outlined,
      QualitySeverity.info => Icons.info_outline,
    };
  }
}

class _DuplicatesTab extends StatelessWidget {
  const _DuplicatesTab({required this.duplicates});

  final List<DuplicateSummary> duplicates;

  @override
  Widget build(BuildContext context) {
    if (duplicates.isEmpty) {
      return const Center(child: Text('No duplicate groups for this table.'));
    }
    return ListView(
      children: <Widget>[
        for (final duplicate in duplicates)
          ListTile(
            dense: true,
            title: Text(duplicate.duplicateType),
            subtitle: Text(
              '${duplicate.columns.join(', ')} | ${duplicate.groupCount} groups'
              '${duplicate.candidateLimit == null ? '' : ' | candidate limit ${duplicate.candidateLimit}'}',
            ),
          ),
      ],
    );
  }
}

class _ImportTab extends StatelessWidget {
  const _ImportTab({required this.reconciliation, required this.tableName});

  final ImportReconciliationSummary? reconciliation;
  final String tableName;

  @override
  Widget build(BuildContext context) {
    final reconciliation = this.reconciliation;
    if (reconciliation == null) {
      return const Center(
        child: Text('No import reconciliation for this run.'),
      );
    }
    final mappings = reconciliation.tableMappings
        .where((mapping) => mapping.targetTable == tableName)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Text('Source: ${reconciliation.sourcePathDisplay}'),
        Text('Format: ${reconciliation.sourceFormat}'),
        Text('Warnings: ${reconciliation.warningCount}'),
        const SizedBox(height: 8),
        for (final mapping in mappings)
          ListTile(
            dense: true,
            title: Text('${mapping.sourceName} -> ${mapping.targetTable}'),
            subtitle: Text(
              'Imported ${mapping.importedRowCount}; skipped ${mapping.skippedRowCount}; rejected ${mapping.rejectedRowCount}; warnings ${mapping.warningCount}',
            ),
          ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.runs});

  final List<QualityRunResult> runs;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return const Center(child: Text('No history for this table.'));
    }
    return ListView(
      children: <Widget>[
        for (final run in runs)
          ListTile(
            dense: true,
            title: Text(run.runId.substring(0, 8)),
            subtitle: Text('${run.status.wireName} | ${run.mode.wireName}'),
            trailing: Text('${run.validationIssues.length} issues'),
          ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
