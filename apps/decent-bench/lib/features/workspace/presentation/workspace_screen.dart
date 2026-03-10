import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/panel_card.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_models.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final TextEditingController _dbPathController = TextEditingController();
  late final TextEditingController _sqlController = TextEditingController(
    text: 'SELECT 1 AS ready;',
  );
  late final TextEditingController _paramsController = TextEditingController();
  late final TextEditingController _pageSizeController =
      TextEditingController();
  late final TextEditingController _delimiterController =
      TextEditingController();
  late final TextEditingController _exportPathController =
      TextEditingController();
  late final ScrollController _resultsScrollController = ScrollController()
    ..addListener(_onResultsScroll);
  late final ScrollController _resultsHorizontalController = ScrollController();

  @override
  void dispose() {
    _resultsHorizontalController.dispose();
    _resultsScrollController
      ..removeListener(_onResultsScroll)
      ..dispose();
    _exportPathController.dispose();
    _delimiterController.dispose();
    _pageSizeController.dispose();
    _paramsController.dispose();
    _sqlController.dispose();
    _dbPathController.dispose();
    super.dispose();
  }

  void _onResultsScroll() {
    final controller = widget.controller;
    if (!_resultsScrollController.hasClients || !controller.hasMoreRows) {
      return;
    }
    final threshold = _resultsScrollController.position.maxScrollExtent - 320;
    if (_resultsScrollController.position.pixels >= threshold) {
      controller.fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        _syncFormFields(widget.controller);
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  _Header(controller: widget.controller),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 320,
                          child: Column(
                            children: <Widget>[
                              Expanded(flex: 4, child: _buildConnectionPane()),
                              const SizedBox(height: 16),
                              Expanded(flex: 5, child: _buildSchemaPane()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: <Widget>[
                              Expanded(flex: 4, child: _buildSqlPane()),
                              const SizedBox(height: 16),
                              Expanded(flex: 5, child: _buildResultsPane()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionPane() {
    final controller = widget.controller;
    return PanelCard(
      title: 'Workspace',
      subtitle: controller.databasePath == null
          ? 'Open an existing DecentDB file or create a new one.'
          : controller.databasePath ?? '',
      actions: <Widget>[
        IconButton(
          tooltip: 'Reload schema',
          onPressed: controller.hasOpenDatabase && !controller.isSchemaLoading
              ? controller.refreshSchema
              : null,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _dbPathController,
            decoration: const InputDecoration(
              labelText: 'Database path',
              hintText: '/tmp/workbench.ddb',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: controller.isBusy
                      ? null
                      : () => controller.openDatabase(
                          _dbPathController.text,
                          createIfMissing: false,
                        ),
                  child: const Text('Open Existing'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: controller.isBusy
                      ? null
                      : () => controller.openDatabase(
                          _dbPathController.text,
                          createIfMissing: true,
                        ),
                  child: const Text('Create New'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Recent files', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Expanded(
            child: controller.config.recentFiles.isEmpty
                ? const _EmptyState(
                    title: 'No recent files yet',
                    message: 'The most recent DecentDB paths will appear here.',
                  )
                : ListView.separated(
                    itemCount: controller.config.recentFiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = controller.config.recentFiles[index];
                      return OutlinedButton(
                        onPressed: controller.isBusy
                            ? null
                            : () {
                                _dbPathController.text = item;
                                controller.openDatabase(
                                  item,
                                  createIfMissing: false,
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(14),
                        ),
                        child: Text(
                          item,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemaPane() {
    final controller = widget.controller;
    return PanelCard(
      title: 'Schema',
      subtitle: controller.hasOpenDatabase
          ? '${controller.schema.tables.length} tables, ${controller.schema.views.length} views'
          : 'Tables and columns appear here after opening a database.',
      child: controller.isSchemaLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.schema.objects.isEmpty
          ? const _EmptyState(
              title: 'No schema loaded',
              message:
                  'Create a table or open an existing database to inspect columns.',
            )
          : ListView(
              children: <Widget>[
                for (final object in controller.schema.objects)
                  ExpansionTile(
                    leading: Icon(
                      object.kind == SchemaObjectKind.table
                          ? Icons.table_chart_rounded
                          : Icons.visibility_rounded,
                    ),
                    title: Text(object.name),
                    subtitle: Text(
                      '${object.columns.length} columns'
                      '${object.kind == SchemaObjectKind.view ? ' | view' : ''}',
                    ),
                    children: <Widget>[
                      for (final column in object.columns)
                        ListTile(
                          dense: true,
                          title: Text(column.name),
                          subtitle: Text(column.descriptor),
                        ),
                    ],
                  ),
                if (controller.schema.indexes.isNotEmpty) ...<Widget>[
                  const Divider(height: 28),
                  Text(
                    'Indexes',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final index in controller.schema.indexes)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.account_tree_rounded),
                      title: Text(index.name),
                      subtitle: Text(
                        '${index.table} (${index.columns.join(", ")})'
                        ' | ${index.kind}${index.unique ? " | UNIQUE" : ""}',
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _buildSqlPane() {
    final controller = widget.controller;
    return PanelCard(
      title: 'SQL Editor',
      subtitle:
          'Phase 1 keeps one tab but executes the pinned DecentDB v1.6.0 SQL surface.',
      actions: <Widget>[
        FilledButton.icon(
          onPressed: controller.canRunQuery
              ? () => controller.runSql(
                  sql: _sqlController.text,
                  parameterJson: _paramsController.text,
                )
              : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Run SQL'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: controller.canCancelQuery
              ? controller.cancelActiveQuery
              : null,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop'),
        ),
      ],
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _paramsController,
                  decoration: const InputDecoration(
                    labelText: 'Parameters (JSON array)',
                    hintText: '[1, "alice", true]',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _pageSizeController,
                  decoration: const InputDecoration(labelText: 'Page size'),
                  keyboardType: TextInputType.number,
                  onSubmitted: controller.updateDefaultPageSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _sqlController,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.35,
              ),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'SQL',
                hintText: 'SELECT 1 AS ready;',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('State: ${controller.queryPhase.name}')),
                if (controller.lastQueryElapsed != null)
                  Chip(
                    label: Text(
                      'Elapsed: ${controller.lastQueryElapsed!.inMilliseconds} ms',
                    ),
                  ),
                if (controller.lastRowsAffected != null)
                  Chip(
                    label: Text(
                      'Rows affected: ${controller.lastRowsAffected}',
                    ),
                  ),
                Chip(
                  label: Text(
                    'Default page size: ${controller.config.defaultPageSize}',
                  ),
                ),
              ],
            ),
          ),
          if (controller.lastError != null) ...<Widget>[
            const SizedBox(height: 12),
            _InlineBanner(
              color: Theme.of(context).colorScheme.errorContainer,
              icon: Icons.error_outline_rounded,
              text: controller.lastError!,
            ),
          ] else if (controller.lastStatus != null) ...<Widget>[
            const SizedBox(height: 12),
            _InlineBanner(
              color: Theme.of(context).colorScheme.secondaryContainer,
              icon: Icons.info_outline_rounded,
              text: controller.lastStatus!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsPane() {
    final controller = widget.controller;
    return PanelCard(
      title: 'Paged Results',
      subtitle: controller.resultColumns.isEmpty
          ? 'Result sets and CSV export live here.'
          : '${controller.resultRows.length} rows loaded'
                '${controller.hasMoreRows ? ' | more rows available' : ''}',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _exportPathController,
                  decoration: const InputDecoration(
                    labelText: 'CSV export path',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _delimiterController,
                  decoration: const InputDecoration(labelText: 'Delimiter'),
                  onSubmitted: controller.updateCsvDelimiter,
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Headers'),
                selected: controller.config.csvIncludeHeaders,
                onSelected: controller.updateCsvIncludeHeaders,
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isExporting
                    ? null
                    : () => controller.exportCurrentQuery(
                        _exportPathController.text,
                      ),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  controller.isExporting ? 'Exporting...' : 'Export CSV',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: controller.resultColumns.isEmpty
                ? _buildResultSummary(controller)
                : _buildResultsTable(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummary(WorkspaceController controller) {
    if (controller.lastRowsAffected != null) {
      return Center(
        child: Text(
          'Statement finished with ${controller.lastRowsAffected} affected rows.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    return const _EmptyState(
      title: 'No result set yet',
      message:
          'Run a SELECT, EXPLAIN, CTE, or other row-producing statement to page through results.',
    );
  }

  Widget _buildResultsTable(WorkspaceController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math
            .max(constraints.maxWidth, controller.resultColumns.length * 220)
            .toDouble();

        return Scrollbar(
          controller: _resultsHorizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _resultsHorizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight,
              child: Column(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: <Widget>[
                        for (final column in controller.resultColumns)
                          _ResultCell(
                            width: 220,
                            value: column,
                            isHeader: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Scrollbar(
                      controller: _resultsScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _resultsScrollController,
                        itemCount:
                            controller.resultRows.length +
                            (controller.hasMoreRows ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= controller.resultRows.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: controller.isFetchingNextPage
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton.icon(
                                        onPressed: controller.fetchNextPage,
                                        icon: const Icon(
                                          Icons.expand_more_rounded,
                                        ),
                                        label: const Text('Load next page'),
                                      ),
                              ),
                            );
                          }

                          final row = controller.resultRows[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  for (final column in controller.resultColumns)
                                    _ResultCell(
                                      width: 220,
                                      value: formatCellValue(row[column]),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _syncFormFields(WorkspaceController controller) {
    if (_dbPathController.text.isEmpty && controller.databasePath != null) {
      _dbPathController.text = controller.databasePath!;
    }
    if (_pageSizeController.text.isEmpty) {
      _pageSizeController.text = controller.config.defaultPageSize.toString();
    }
    if (_delimiterController.text.isEmpty) {
      _delimiterController.text = controller.config.csvDelimiter;
    }
    if (_exportPathController.text.isEmpty) {
      _exportPathController.text = controller.suggestExportPath();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF7E2D6), Color(0xFFE6F1EE)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Decent Bench',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Phase 1 scaffold: open/create DecentDB, browse schema, run SQL, page results, cancel, export CSV.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeaderFact(
                    label: 'Native library',
                    value: controller.nativeLibraryPath ?? 'Resolving...',
                  ),
                  const SizedBox(height: 8),
                  _HeaderFact(
                    label: 'Engine',
                    value: controller.engineVersion ?? 'No database open',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(320, constraints.maxWidth),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResultCell extends StatelessWidget {
  const _ResultCell({
    required this.width,
    required this.value,
    this.isHeader = false,
  });

  final double width;
  final String value;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          value,
          maxLines: isHeader ? 1 : 3,
          overflow: TextOverflow.ellipsis,
          style:
              (isHeader
                      ? theme.textTheme.labelLarge
                      : theme.textTheme.bodyMedium)
                  ?.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
