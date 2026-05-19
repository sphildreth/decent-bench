import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

import '../../../../app/theme_system/decent_bench_theme.dart';
import '../../../../app/theme_system/decent_bench_theme_extension.dart';
import '../../domain/explain_plan_visualization.dart';
import '../../domain/result_visualization.dart';
import '../../domain/workspace_models.dart';
import '../../domain/workspace_shell_preferences.dart';
import 'shell_pane_frame.dart';

class ResultsGridCellSelection {
  const ResultsGridCellSelection({
    required this.rowIndex,
    required this.columnName,
  });

  final int rowIndex;
  final String columnName;

  ResultsGridCellKey get key =>
      ResultsGridCellKey(rowIndex: rowIndex, columnName: columnName);
}

class ResultsGridCellKey {
  const ResultsGridCellKey({required this.rowIndex, required this.columnName});

  final int rowIndex;
  final String columnName;

  @override
  bool operator ==(Object other) {
    return other is ResultsGridCellKey &&
        other.rowIndex == rowIndex &&
        other.columnName == columnName;
  }

  @override
  int get hashCode => Object.hash(rowIndex, columnName);
}

class ResultsGridInteractionState {
  const ResultsGridInteractionState({
    this.selectedRows = const <int>{},
    this.selectedCell,
    this.pinnedColumns = const <String>{},
    this.cellOverrides = const <ResultsGridCellKey, Object?>{},
    this.cellErrors = const <ResultsGridCellKey, String>{},
    this.executionGeneration = 0,
  });

  final Set<int> selectedRows;
  final ResultsGridCellSelection? selectedCell;
  final Set<String> pinnedColumns;
  final Map<ResultsGridCellKey, Object?> cellOverrides;
  final Map<ResultsGridCellKey, String> cellErrors;
  final int executionGeneration;

  ResultsGridInteractionState copyWith({
    Set<int>? selectedRows,
    Object? selectedCell = _unset,
    Set<String>? pinnedColumns,
    Map<ResultsGridCellKey, Object?>? cellOverrides,
    Map<ResultsGridCellKey, String>? cellErrors,
    int? executionGeneration,
  }) {
    return ResultsGridInteractionState(
      selectedRows: selectedRows ?? this.selectedRows,
      selectedCell: selectedCell == _unset
          ? this.selectedCell
          : selectedCell as ResultsGridCellSelection?,
      pinnedColumns: pinnedColumns ?? this.pinnedColumns,
      cellOverrides: cellOverrides ?? this.cellOverrides,
      cellErrors: cellErrors ?? this.cellErrors,
      executionGeneration: executionGeneration ?? this.executionGeneration,
    );
  }

  static const Object _unset = Object();
}

List<String> resolveResultsColumns(
  QueryTabState tab, {
  bool usePlaceholderContent = true,
}) {
  if (tab.resultColumns.isNotEmpty) {
    return tab.resultColumns;
  }
  if (!usePlaceholderContent) {
    return const <String>[];
  }
  return const <String>['id', 'name', 'region', 'total'];
}

List<Map<String, Object?>> resolveResultsRows(
  QueryTabState tab, {
  bool usePlaceholderContent = true,
}) {
  if (tab.resultRows.isNotEmpty) {
    return tab.resultRows;
  }
  if (!usePlaceholderContent) {
    return const <Map<String, Object?>>[];
  }
  return const <Map<String, Object?>>[
    <String, Object?>{
      'id': 1,
      'name': 'Northwind Trading',
      'region': 'Midwest',
      'total': 1420.50,
    },
    <String, Object?>{
      'id': 2,
      'name': 'Oceanic Logistics',
      'region': 'West',
      'total': 995.00,
    },
    <String, Object?>{
      'id': 3,
      'name': 'Summit Foods',
      'region': 'South',
      'total': 128.75,
    },
  ];
}

Object? resolveResultsCellValue(
  QueryTabState tab,
  ResultsGridInteractionState state,
  int rowIndex,
  String columnName, {
  bool usePlaceholderContent = true,
}) {
  final key = ResultsGridCellKey(rowIndex: rowIndex, columnName: columnName);
  if (state.cellOverrides.containsKey(key)) {
    return state.cellOverrides[key];
  }
  final rows = resolveResultsRows(
    tab,
    usePlaceholderContent: usePlaceholderContent,
  );
  if (rowIndex < 0 || rowIndex >= rows.length) {
    return null;
  }
  return rows[rowIndex][columnName];
}

class ResultsPane extends StatelessWidget {
  const ResultsPane({
    super.key,
    required this.activeTab,
    required this.activeResultsTab,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    required this.interactionState,
    required this.onResultsTabChanged,
    required this.onLoadNextPage,
    required this.onSelectCell,
    required this.onShowCellMenu,
    required this.onSelectRow,
    required this.onTogglePinnedColumn,
    required this.onShowColumnStatistics,
    required this.usePlaceholderContent,
    required this.tableEditabilityLabel,
    this.onLoadHistoryEntry,
    this.onRunHistoryEntry,
    this.onClearHistory,
  });

  final QueryTabState activeTab;
  final ResultsPaneTab activeResultsTab;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final ResultsGridInteractionState interactionState;
  final ValueChanged<ResultsPaneTab> onResultsTabChanged;
  final VoidCallback onLoadNextPage;
  final void Function(int rowIndex, String columnName) onSelectCell;
  final void Function(int rowIndex, String columnName, Offset globalPosition)
  onShowCellMenu;
  final ValueChanged<int> onSelectRow;
  final ValueChanged<String> onTogglePinnedColumn;
  final ValueChanged<String> onShowColumnStatistics;
  final bool usePlaceholderContent;
  final String tableEditabilityLabel;
  final ValueChanged<QueryHistoryEntry>? onLoadHistoryEntry;
  final Future<void> Function(QueryHistoryEntry entry)? onRunHistoryEntry;
  final VoidCallback? onClearHistory;

  @override
  Widget build(BuildContext context) {
    return ShellPaneFrame(
      title: 'Results Window',
      subtitle: _subtitle(),
      leadingIcon: Icons.table_view_outlined,
      toolbar: _ResultsToolbar(
        activeTab: activeTab,
        pinnedColumnCount: interactionState.pinnedColumns.length,
        selectedRowCount: interactionState.selectedRows.length,
        tableEditabilityLabel: tableEditabilityLabel,
      ),
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _ResultsSubtabs(
            selectedTab: activeResultsTab,
            onSelected: onResultsTabChanged,
          ),
          Expanded(
            child: switch (activeResultsTab) {
              ResultsPaneTab.results => _ResultsGrid(
                tab: activeTab,
                interactionState: interactionState,
                verticalScrollController: verticalScrollController,
                horizontalScrollController: horizontalScrollController,
                onLoadNextPage: onLoadNextPage,
                onSelectCell: onSelectCell,
                onShowCellMenu: onShowCellMenu,
                onSelectRow: onSelectRow,
                onTogglePinnedColumn: onTogglePinnedColumn,
                onShowColumnStatistics: onShowColumnStatistics,
                usePlaceholderContent: usePlaceholderContent,
              ),
              ResultsPaneTab.messages => _MessagesPanel(tab: activeTab),
              ResultsPaneTab.executionPlan => _ExecutionPlanPanel(
                tab: activeTab,
              ),
              ResultsPaneTab.chart => _ChartPanel(
                tab: activeTab,
                usePlaceholderContent: usePlaceholderContent,
              ),
              ResultsPaneTab.history => _HistoryPanel(
                tab: activeTab,
                onLoad: onLoadHistoryEntry,
                onRun: onRunHistoryEntry,
                onClear: onClearHistory,
              ),
            },
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    if (activeTab.resultColumns.isNotEmpty) {
      return '${activeTab.resultRows.length} rows loaded';
    }
    if (activeTab.rowsAffected != null) {
      return '${activeTab.rowsAffected} rows affected';
    }
    return 'Messages, data, and EXPLAIN output';
  }
}

class _ResultsToolbar extends StatelessWidget {
  const _ResultsToolbar({
    required this.activeTab,
    required this.pinnedColumnCount,
    required this.selectedRowCount,
    required this.tableEditabilityLabel,
  });

  final QueryTabState activeTab;
  final int pinnedColumnCount;
  final int selectedRowCount;
  final String tableEditabilityLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        _InfoBadge(
          icon: Icons.push_pin_outlined,
          label: 'Pinned $pinnedColumnCount',
        ),
        _InfoBadge(
          icon: Icons.select_all_outlined,
          label: 'Rows $selectedRowCount',
        ),
        _InfoBadge(
          icon: Icons.chat_bubble_outline,
          label: 'Messages ${activeTab.messageHistory.length}',
        ),
        _InfoBadge(
          icon: Icons.edit_note_outlined,
          label: _shortLabel(tableEditabilityLabel),
        ),
        _InfoBadge(
          icon: activeTab.hasMoreRows
              ? Icons.unfold_more_outlined
              : Icons.check_circle_outline,
          label: activeTab.hasMoreRows ? 'More rows available' : 'Page loaded',
        ),
      ],
    );
  }

  String _shortLabel(String label) {
    if (label.length <= 52) {
      return label;
    }
    return '${label.substring(0, 49)}...';
  }
}

class _ResultsSubtabs extends StatelessWidget {
  const _ResultsSubtabs({required this.selectedTab, required this.onSelected});

  final ResultsPaneTab selectedTab;
  final ValueChanged<ResultsPaneTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: tokens.resultsGrid.headerBackground,
        border: Border(bottom: BorderSide(color: tokens.resultsGrid.gridLine)),
      ),
      child: Row(
        children: <Widget>[
          _ResultTabButton(
            label: 'Results',
            selected: selectedTab == ResultsPaneTab.results,
            onTap: () => onSelected(ResultsPaneTab.results),
          ),
          _ResultTabButton(
            label: 'Messages',
            selected: selectedTab == ResultsPaneTab.messages,
            onTap: () => onSelected(ResultsPaneTab.messages),
          ),
          _ResultTabButton(
            label: 'Execution Plan',
            selected: selectedTab == ResultsPaneTab.executionPlan,
            onTap: () => onSelected(ResultsPaneTab.executionPlan),
          ),
          _ResultTabButton(
            label: 'Chart',
            selected: selectedTab == ResultsPaneTab.chart,
            onTap: () => onSelected(ResultsPaneTab.chart),
          ),
          _ResultTabButton(
            label: 'History',
            selected: selectedTab == ResultsPaneTab.history,
            onTap: () => onSelected(ResultsPaneTab.history),
          ),
        ],
      ),
    );
  }
}

class _ResultTabButton extends StatelessWidget {
  const _ResultTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? tokens.resultsGrid.background
              : tokens.resultsGrid.headerBackground,
          border: Border(
            right: BorderSide(color: tokens.resultsGrid.gridLine),
            bottom: selected
                ? BorderSide.none
                : BorderSide(color: Colors.transparent),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected
                ? tokens.resultsGrid.cellText
                : tokens.resultsGrid.headerText,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ResultsGrid extends StatefulWidget {
  const _ResultsGrid({
    required this.tab,
    required this.interactionState,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    required this.onLoadNextPage,
    required this.onSelectCell,
    required this.onShowCellMenu,
    required this.onSelectRow,
    required this.onTogglePinnedColumn,
    required this.onShowColumnStatistics,
    required this.usePlaceholderContent,
  });

  final QueryTabState tab;
  final ResultsGridInteractionState interactionState;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final VoidCallback onLoadNextPage;
  final void Function(int rowIndex, String columnName) onSelectCell;
  final void Function(int rowIndex, String columnName, Offset globalPosition)
  onShowCellMenu;
  final ValueChanged<int> onSelectRow;
  final ValueChanged<String> onTogglePinnedColumn;
  final ValueChanged<String> onShowColumnStatistics;
  final bool usePlaceholderContent;

  @override
  State<_ResultsGrid> createState() => _ResultsGridState();
}

class _ResultsGridState extends State<_ResultsGrid> {
  static const double _rowHeight = 36;
  static const double _rowHeaderWidth = 56;
  static const double _columnWidth = 180;
  static const double _minColumnWidth = 96;

  final ScrollController _pinnedVerticalController = ScrollController();
  final Map<String, double> _columnWidths = <String, double>{};
  bool _syncingVertical = false;

  @override
  void initState() {
    super.initState();
    widget.verticalScrollController.addListener(_syncFromScrollable);
    _pinnedVerticalController.addListener(_syncFromPinned);
    _pruneColumnWidths();
  }

  @override
  void didUpdateWidget(covariant _ResultsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verticalScrollController != widget.verticalScrollController) {
      oldWidget.verticalScrollController.removeListener(_syncFromScrollable);
      widget.verticalScrollController.addListener(_syncFromScrollable);
    }
    if (oldWidget.interactionState.executionGeneration !=
        widget.interactionState.executionGeneration) {
      _columnWidths.clear();
    }
    _pruneColumnWidths();
  }

  @override
  void dispose() {
    widget.verticalScrollController.removeListener(_syncFromScrollable);
    _pinnedVerticalController
      ..removeListener(_syncFromPinned)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = resolveResultsColumns(
      widget.tab,
      usePlaceholderContent: widget.usePlaceholderContent,
    );
    final rows = resolveResultsRows(
      widget.tab,
      usePlaceholderContent: widget.usePlaceholderContent,
    );
    final pinnedColumns = <String>[
      for (final column in columns)
        if (widget.interactionState.pinnedColumns.contains(column)) column,
    ];
    final remainingColumns = <String>[
      for (final column in columns)
        if (!widget.interactionState.pinnedColumns.contains(column)) column,
    ];
    final pinnedWidth =
        _rowHeaderWidth +
        pinnedColumns.fold<double>(0, (sum, column) => sum + _widthFor(column));

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollableWidth = math.max(
          constraints.maxWidth - pinnedWidth,
          220,
        );
        final unpinnedContentWidth = math.max(
          scrollableWidth,
          remainingColumns.fold<double>(
            0,
            (sum, column) => sum + _widthFor(column),
          ),
        );

        if (columns.isEmpty && rows.isEmpty) {
          return _ResultsEmptyState(
            tab: widget.tab,
            usePlaceholderContent: widget.usePlaceholderContent,
          );
        }

        return Column(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: pinnedWidth,
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: _rowHeight,
                          child: Row(
                            children: <Widget>[
                              _RowHeaderCell(
                                label: '#',
                                isHeader: true,
                                width: _rowHeaderWidth,
                              ),
                              for (final column in pinnedColumns)
                                _GridCell(
                                  key: ValueKey<String>(
                                    'results.header.$column',
                                  ),
                                  text: column,
                                  tooltip: _headerTooltipFor(column),
                                  isHeader: true,
                                  width: _widthFor(column),
                                  pinned: true,
                                  onPinToggle: () =>
                                      widget.onTogglePinnedColumn(column),
                                  onStatistics: () =>
                                      widget.onShowColumnStatistics(column),
                                  onResize: (delta) =>
                                      _resizeColumn(column, delta),
                                  resizeHandleKey: ValueKey<String>(
                                    'results.resize.$column',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _pinnedVerticalController,
                            itemExtent: _rowHeight,
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final rowSelected = widget
                                  .interactionState
                                  .selectedRows
                                  .contains(index);
                              return Row(
                                children: <Widget>[
                                  _RowHeaderCell(
                                    label: '${index + 1}',
                                    width: _rowHeaderWidth,
                                    selected: rowSelected,
                                    onTap: () => widget.onSelectRow(index),
                                  ),
                                  for (final column in pinnedColumns)
                                    _GridCell(
                                      text: _formatCellValue(
                                        column,
                                        resolveResultsCellValue(
                                          widget.tab,
                                          widget.interactionState,
                                          index,
                                          column,
                                          usePlaceholderContent:
                                              widget.usePlaceholderContent,
                                        ),
                                      ),
                                      width: _widthFor(column),
                                      pinned: true,
                                      selected: _isCellSelected(index, column),
                                      rowSelected: rowSelected,
                                      edited: _isCellEdited(index, column),
                                      errorText: _cellError(index, column),
                                      onTap: () =>
                                          widget.onSelectCell(index, column),
                                      onSecondaryTapDown: (position) =>
                                          widget.onShowCellMenu(
                                            index,
                                            column,
                                            position,
                                          ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: widget.horizontalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: widget.horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: unpinnedContentWidth.toDouble(),
                          child: Column(
                            children: <Widget>[
                              SizedBox(
                                height: _rowHeight,
                                child: Row(
                                  children: <Widget>[
                                    for (final column in remainingColumns)
                                      _GridCell(
                                        key: ValueKey<String>(
                                          'results.header.$column',
                                        ),
                                        text: column,
                                        tooltip: _headerTooltipFor(column),
                                        isHeader: true,
                                        width: _widthFor(column),
                                        pinned: false,
                                        onPinToggle: () =>
                                            widget.onTogglePinnedColumn(column),
                                        onStatistics: () => widget
                                            .onShowColumnStatistics(column),
                                        onResize: (delta) =>
                                            _resizeColumn(column, delta),
                                        resizeHandleKey: ValueKey<String>(
                                          'results.resize.$column',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  controller: widget.verticalScrollController,
                                  itemExtent: _rowHeight,
                                  itemCount: rows.length,
                                  itemBuilder: (context, index) {
                                    final rowSelected = widget
                                        .interactionState
                                        .selectedRows
                                        .contains(index);
                                    return Row(
                                      children: <Widget>[
                                        for (final column in remainingColumns)
                                          _GridCell(
                                            text: _formatCellValue(
                                              column,
                                              resolveResultsCellValue(
                                                widget.tab,
                                                widget.interactionState,
                                                index,
                                                column,
                                                usePlaceholderContent: widget
                                                    .usePlaceholderContent,
                                              ),
                                            ),
                                            width: _widthFor(column),
                                            selected: _isCellSelected(
                                              index,
                                              column,
                                            ),
                                            rowSelected: rowSelected,
                                            edited: _isCellEdited(
                                              index,
                                              column,
                                            ),
                                            errorText: _cellError(
                                              index,
                                              column,
                                            ),
                                            onTap: () => widget.onSelectCell(
                                              index,
                                              column,
                                            ),
                                            onSecondaryTapDown: (position) =>
                                                widget.onShowCellMenu(
                                                  index,
                                                  column,
                                                  position,
                                                ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.tab.hasMoreRows)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onLoadNextPage,
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      widget.tab.phase == QueryPhase.fetching
                          ? 'Loading...'
                          : 'Load next page',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isCellSelected(int rowIndex, String columnName) {
    final cell = widget.interactionState.selectedCell;
    return cell != null &&
        cell.rowIndex == rowIndex &&
        cell.columnName == columnName;
  }

  bool _isCellEdited(int rowIndex, String columnName) {
    return widget.interactionState.cellOverrides.containsKey(
      ResultsGridCellKey(rowIndex: rowIndex, columnName: columnName),
    );
  }

  String? _cellError(int rowIndex, String columnName) {
    return widget.interactionState.cellErrors[ResultsGridCellKey(
      rowIndex: rowIndex,
      columnName: columnName,
    )];
  }

  double _widthFor(String columnName) =>
      _columnWidths[columnName] ?? _columnWidth;

  void _resizeColumn(String columnName, double delta) {
    setState(() {
      _columnWidths[columnName] = math.max(
        _minColumnWidth,
        _widthFor(columnName) + delta,
      );
    });
  }

  String? _headerTooltipFor(String columnName) {
    final contract = widget.tab.resultContractForColumn(columnName);
    if (contract == null) {
      return null;
    }
    final descriptor = contract.nativeTypeDescriptor;
    final parts = <String>[
      '$columnName: ${contract.displayType}',
      'Family: ${descriptor.familyLabel}',
      if (descriptor.isNativeV25Type) descriptor.summaryLabel,
      contract.nullabilityLabel,
      'Source: ${contract.sourceLabel}',
      if (contract.diagnostics.isNotEmpty) contract.diagnostics.first,
    ];
    return parts.join('\n');
  }

  String _formatCellValue(String columnName, Object? value) {
    final contract = widget.tab.resultContractForColumn(columnName);
    return formatTypedCellValue(value, typeName: contract?.typeName);
  }

  void _pruneColumnWidths() {
    final columns = resolveResultsColumns(
      widget.tab,
      usePlaceholderContent: widget.usePlaceholderContent,
    ).toSet();
    _columnWidths.removeWhere((column, _) => !columns.contains(column));
  }

  void _syncFromScrollable() {
    if (_syncingVertical ||
        !widget.verticalScrollController.hasClients ||
        !_pinnedVerticalController.hasClients) {
      return;
    }
    _syncingVertical = true;
    _pinnedVerticalController.jumpTo(
      widget.verticalScrollController.offset.clamp(
        0,
        _pinnedVerticalController.position.maxScrollExtent,
      ),
    );
    _syncingVertical = false;
  }

  void _syncFromPinned() {
    if (_syncingVertical ||
        !_pinnedVerticalController.hasClients ||
        !widget.verticalScrollController.hasClients) {
      return;
    }
    _syncingVertical = true;
    widget.verticalScrollController.jumpTo(
      _pinnedVerticalController.offset.clamp(
        0,
        widget.verticalScrollController.position.maxScrollExtent,
      ),
    );
    _syncingVertical = false;
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    super.key,
    required this.text,
    required this.width,
    this.isHeader = false,
    this.selected = false,
    this.rowSelected = false,
    this.edited = false,
    this.pinned = false,
    this.errorText,
    this.tooltip,
    this.onTap,
    this.onSecondaryTapDown,
    this.onPinToggle,
    this.onStatistics,
    this.onResize,
    this.resizeHandleKey,
  });

  final String text;
  final double width;
  final bool isHeader;
  final bool selected;
  final bool rowSelected;
  final bool edited;
  final bool pinned;
  final String? errorText;
  final String? tooltip;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onSecondaryTapDown;
  final VoidCallback? onPinToggle;
  final VoidCallback? onStatistics;
  final ValueChanged<double>? onResize;
  final Key? resizeHandleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.decentBenchTheme;
    final hasError = errorText != null && errorText!.trim().isNotEmpty;
    final background = isHeader
        ? tokens.resultsGrid.headerBackground
        : selected
        ? tokens.resultsGrid.rowSelectedBackground
        : hasError
        ? tokens.colors.error.withValues(alpha: 0.16)
        : edited
        ? tokens.colors.warning.withValues(alpha: 0.18)
        : rowSelected
        ? tokens.resultsGrid.rowAltBackground
        : tokens.resultsGrid.rowBackground;

    final child = Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: isHeader ? 4 : 10,
        vertical: isHeader ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(color: tokens.resultsGrid.gridLine),
          bottom: BorderSide(
            color: hasError ? tokens.colors.error : tokens.resultsGrid.gridLine,
          ),
        ),
      ),
      child: isHeader
          ? LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 112;
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tokens.resultsGrid.headerText,
                        ),
                      ),
                    ),
                    if (!compact)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 18,
                          height: 24,
                        ),
                        tooltip: 'Column statistics',
                        onPressed: onStatistics,
                        icon: Icon(
                          Icons.query_stats_outlined,
                          size: 14,
                          color: tokens.colors.accent,
                        ),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 18,
                        height: 24,
                      ),
                      tooltip: pinned ? 'Unpin column' : 'Pin column',
                      onPressed: onPinToggle,
                      icon: Icon(
                        pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 14,
                        color: tokens.colors.accent,
                      ),
                    ),
                    if (onResize != null)
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          key: resizeHandleKey,
                          behavior: HitTestBehavior.translucent,
                          dragStartBehavior: DragStartBehavior.down,
                          onHorizontalDragUpdate: (details) =>
                              onResize!(details.delta.dx),
                          child: Container(
                            width: 12,
                            height: 24,
                            alignment: Alignment.center,
                            child: Container(
                              width: 2,
                              height: 18,
                              decoration: BoxDecoration(
                                color: tokens.resultsGrid.gridLine,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          : Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: tokens.fonts.editorFamily,
                color: selected || rowSelected
                    ? tokens.resultsGrid.rowSelectedText
                    : text == 'NULL'
                    ? tokens.resultsGrid.nullText
                    : tokens.resultsGrid.cellText,
              ),
            ),
    );

    final effectiveTooltip = <String>[
      if (hasError) errorText!.trim(),
      if (tooltip != null && tooltip!.trim().isNotEmpty) tooltip!.trim(),
    ].join('\n\n');

    final wrappedChild = effectiveTooltip.isEmpty
        ? child
        : Tooltip(message: effectiveTooltip, child: child);

    if (isHeader || onTap == null) {
      return wrappedChild;
    }
    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown == null
          ? null
          : (details) => onSecondaryTapDown!(details.globalPosition),
      child: wrappedChild,
    );
  }
}

class _RowHeaderCell extends StatelessWidget {
  const _RowHeaderCell({
    required this.label,
    required this.width,
    this.isHeader = false,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final double width;
  final bool isHeader;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.decentBenchTheme;
    final child = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isHeader
            ? tokens.resultsGrid.headerBackground
            : selected
            ? tokens.resultsGrid.rowSelectedBackground
            : tokens.resultsGrid.rowAltBackground,
        border: Border(
          right: BorderSide(color: tokens.resultsGrid.gridLine),
          bottom: BorderSide(color: tokens.resultsGrid.gridLine),
        ),
      ),
      alignment: Alignment.centerRight,
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: tokens.fonts.editorFamily,
          color: isHeader
              ? tokens.resultsGrid.headerText
              : selected
              ? tokens.resultsGrid.rowSelectedText
              : tokens.resultsGrid.cellText,
          fontWeight: isHeader || selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
    if (isHeader || onTap == null) {
      return child;
    }
    return InkWell(onTap: onTap, child: child);
  }
}

class _ResultsEmptyState extends StatelessWidget {
  const _ResultsEmptyState({
    required this.tab,
    required this.usePlaceholderContent,
  });

  final QueryTabState tab;
  final bool usePlaceholderContent;

  @override
  Widget build(BuildContext context) {
    final label = usePlaceholderContent
        ? 'Run a query to replace the demo dataset.'
        : tab.rowsAffected != null
        ? 'Statement completed without a result grid.'
        : tab.lastSql != null
        ? 'Query returned no rows.'
        : 'Run a query to populate the results grid.';
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = math.min(24.0, constraints.maxWidth / 10);
        final verticalPadding = math.min(24.0, constraints.maxHeight / 6);
        final minWidth = math.max(
          0.0,
          constraints.maxWidth - (horizontalPadding * 2),
        );
        final minHeight = math.max(
          0.0,
          constraints.maxHeight - (verticalPadding * 2),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minWidth,
              minHeight: minHeight,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.table_rows_outlined, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (tab.statusMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      tab.statusMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({required this.tab});

  final QueryTabState tab;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    final messages = tab.messageHistory.isNotEmpty
        ? tab.messageHistory.reversed.toList()
        : <QueryMessageEntry>[
            QueryMessageEntry(
              level: QueryMessageLevel.info,
              message:
                  'Ready. Execute a query to capture elapsed time, row counts, and warnings.',
              timestamp: DateTime.now(),
            ),
          ];
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = messages[index];
        return Container(
          padding: const EdgeInsets.all(10),
          color: tokens.colors.panelAltBg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _MessageLevelBadge(level: entry.level),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _formatTimestamp(entry.timestamp),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontFamily: tokens.fonts.editorFamily,
                        color: tokens.colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(entry.message),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute:$second';
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.tab,
    required this.onLoad,
    required this.onRun,
    required this.onClear,
  });

  final QueryTabState tab;
  final ValueChanged<QueryHistoryEntry>? onLoad;
  final Future<void> Function(QueryHistoryEntry entry)? onRun;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    final entries = tab.queryHistory.reversed.toList();
    if (entries.isEmpty) {
      return const _ExecutionPlanEmptyState(
        icon: Icons.history_outlined,
        label: 'Run SQL in this tab to populate history.',
      );
    }
    return Column(
      children: <Widget>[
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: tokens.colors.panelBg,
            border: Border(
              bottom: BorderSide(color: tokens.resultsGrid.gridLine),
            ),
          ),
          child: Row(
            children: <Widget>[
              Text(
                '${entries.length} entries',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.colors.textMuted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.colors.panelAltBg,
                  border: Border.all(color: tokens.resultsGrid.gridLine),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _historyIcon(entry.outcome),
                      size: 18,
                      color: _historyColor(tokens, entry.outcome),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _firstSqlLine(entry.sql),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontFamily: tokens.fonts.editorFamily,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _historySubtitle(entry),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onLoad == null ? null : () => onLoad!(entry),
                      child: const Text('Load'),
                    ),
                    TextButton(
                      onPressed: onRun == null ? null : () => onRun!(entry),
                      child: const Text('Run'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _firstSqlLine(String sql) {
    for (final line in sql.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '(empty SQL)';
  }

  String _historySubtitle(QueryHistoryEntry entry) {
    final parts = <String>[
      _formatTimestamp(entry.ranAt),
      entry.outcome.name,
      '${entry.elapsed.inMilliseconds} ms',
      if (entry.rowsLoaded != null) 'rows ${entry.rowsLoaded}',
      if (entry.rowsAffected != null) 'affected ${entry.rowsAffected}',
      if (entry.errorMessage != null) entry.errorMessage!,
    ];
    return parts.join(' | ');
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute:$second';
  }

  IconData _historyIcon(QueryHistoryOutcome outcome) {
    return switch (outcome) {
      QueryHistoryOutcome.completed => Icons.check_circle_outline,
      QueryHistoryOutcome.failed => Icons.error_outline,
      QueryHistoryOutcome.cancelled => Icons.cancel_outlined,
    };
  }

  Color _historyColor(DecentBenchTheme tokens, QueryHistoryOutcome outcome) {
    return switch (outcome) {
      QueryHistoryOutcome.completed => tokens.colors.success,
      QueryHistoryOutcome.failed => tokens.colors.error,
      QueryHistoryOutcome.cancelled => tokens.colors.warning,
    };
  }
}

class _ExecutionPlanPanel extends StatelessWidget {
  const _ExecutionPlanPanel({required this.tab});

  final QueryTabState tab;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    final plan = tab.executionPlan;
    if (plan.isLoading && !plan.hasData) {
      return const _ExecutionPlanEmptyState(
        icon: Icons.account_tree_outlined,
        label: 'Collecting EXPLAIN output...',
      );
    }
    if (!plan.hasData && plan.errorMessage == null) {
      return const _ExecutionPlanEmptyState(
        icon: Icons.account_tree_outlined,
        label:
            'Run a query to populate the execution plan with EXPLAIN results.',
      );
    }
    final isQueryPlanText =
        plan.columns.length == 1 &&
        plan.columns.first.toLowerCase() == 'query_plan';
    final visualization = isQueryPlanText
        ? buildExplainPlanVisualization(plan.rows, plan.columns.first)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (plan.isLoading) const LinearProgressIndicator(minHeight: 2),
        if (visualization != null && visualization.hasNodes)
          _ExecutionPlanToolbar(visualization: visualization),
        if (plan.errorMessage != null)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            color: tokens.colors.error.withValues(alpha: 0.14),
            child: Text(
              plan.errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.colors.error),
            ),
          ),
        Expanded(
          child: !plan.hasData
              ? const _ExecutionPlanEmptyState(
                  icon: Icons.report_gmailerrorred_outlined,
                  label: 'No EXPLAIN rows were captured for this statement.',
                )
              : visualization != null && visualization.hasNodes
              ? _ExplainPlanTree(visualization: visualization)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 56,
                    columns: <DataColumn>[
                      for (final column in plan.columns)
                        DataColumn(
                          label: Text(
                            column,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontFamily: tokens.fonts.editorFamily,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.resultsGrid.headerText,
                                ),
                          ),
                        ),
                    ],
                    rows: <DataRow>[
                      for (final row in plan.rows)
                        DataRow(
                          cells: <DataCell>[
                            for (final column in plan.columns)
                              DataCell(
                                Text(
                                  formatCellValue(row[column]),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontFamily: tokens.fonts.editorFamily,
                                        color: tokens.resultsGrid.cellText,
                                      ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChartPanel extends StatefulWidget {
  const _ChartPanel({required this.tab, required this.usePlaceholderContent});

  final QueryTabState tab;
  final bool usePlaceholderContent;

  @override
  State<_ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends State<_ChartPanel> {
  static const XTypeGroup _pngTypeGroup = XTypeGroup(
    label: 'PNG',
    extensions: <String>['png'],
  );

  final GlobalKey _chartKey = GlobalKey();
  ResultChartType _chartType = ResultChartType.bar;
  String? _xColumn;
  String? _yColumn;

  @override
  void didUpdateWidget(covariant _ChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab.id != widget.tab.id ||
        oldWidget.tab.executionGeneration != widget.tab.executionGeneration) {
      _xColumn = null;
      _yColumn = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = resolveResultsColumns(
      widget.tab,
      usePlaceholderContent: widget.usePlaceholderContent,
    );
    final rows = resolveResultsRows(
      widget.tab,
      usePlaceholderContent: widget.usePlaceholderContent,
    );
    final inferred = inferVisualizationColumns(
      columns: columns,
      rows: rows,
      tab: widget.tab,
    );
    if (columns.isEmpty || rows.isEmpty || inferred.yColumns.isEmpty) {
      return const _ExecutionPlanEmptyState(
        icon: Icons.bar_chart_outlined,
        label:
            'Run a result query with at least one numeric column to visualize loaded rows.',
      );
    }
    final xColumn = _xColumn != null && inferred.xColumns.contains(_xColumn)
        ? _xColumn!
        : inferred.xColumns.first;
    final yColumn = _yColumn != null && inferred.yColumns.contains(_yColumn)
        ? _yColumn!
        : inferred.yColumns.first;
    final model = buildResultVisualizationModel(
      chartType: _chartType,
      xColumn: xColumn,
      yColumn: yColumn,
      rows: rows,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SegmentedButton<ResultChartType>(
                segments: const <ButtonSegment<ResultChartType>>[
                  ButtonSegment(
                    value: ResultChartType.bar,
                    icon: Icon(Icons.bar_chart_outlined),
                    label: Text('Bar'),
                  ),
                  ButtonSegment(
                    value: ResultChartType.line,
                    icon: Icon(Icons.show_chart_outlined),
                    label: Text('Line'),
                  ),
                  ButtonSegment(
                    value: ResultChartType.scatter,
                    icon: Icon(Icons.scatter_plot_outlined),
                    label: Text('Scatter'),
                  ),
                  ButtonSegment(
                    value: ResultChartType.pie,
                    icon: Icon(Icons.pie_chart_outline),
                    label: Text('Pie'),
                  ),
                ],
                selected: <ResultChartType>{_chartType},
                onSelectionChanged: (value) {
                  setState(() => _chartType = value.single);
                },
              ),
              DropdownButton<String>(
                value: xColumn,
                items: <DropdownMenuItem<String>>[
                  for (final column in inferred.xColumns)
                    DropdownMenuItem(value: column, child: Text('X: $column')),
                ],
                onChanged: (value) => setState(() => _xColumn = value),
              ),
              DropdownButton<String>(
                value: yColumn,
                items: <DropdownMenuItem<String>>[
                  for (final column in inferred.yColumns)
                    DropdownMenuItem(value: column, child: Text('Y: $column')),
                ],
                onChanged: (value) => setState(() => _yColumn = value),
              ),
              Text(
                model.truncated
                    ? 'Showing first ${model.points.length} of ${model.loadedRows} loaded rows'
                    : '${model.points.length} plotted points',
              ),
              TextButton.icon(
                onPressed: model.hasData ? _exportChartPng : null,
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Export PNG'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            key: _chartKey,
            child: _SimpleChart(model: model),
          ),
        ),
      ],
    );
  }

  Future<void> _exportChartPng() async {
    final boundary =
        _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return;
    }
    final location = await getSaveLocation(
      suggestedName: 'decent-bench-chart.png',
      acceptedTypeGroups: const <XTypeGroup>[_pngTypeGroup],
    );
    if (location == null) {
      return;
    }
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      return;
    }
    await File(location.path).writeAsBytes(bytes.buffer.asUint8List());
  }
}

class _SimpleChart extends StatelessWidget {
  const _SimpleChart({required this.model});

  final ResultVisualizationModel model;

  @override
  Widget build(BuildContext context) {
    if (!model.hasData) {
      return const _ExecutionPlanEmptyState(
        icon: Icons.bar_chart_outlined,
        label: 'No plottable numeric values are loaded for this chart.',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: CustomPaint(
        painter: _SimpleChartPainter(
          model: model,
          tokens: context.decentBenchTheme,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SimpleChartPainter extends CustomPainter {
  const _SimpleChartPainter({required this.model, required this.tokens});

  final ResultVisualizationModel model;
  final DecentBenchTheme tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final points = model.points;
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }
    final axisPaint = Paint()
      ..color = tokens.resultsGrid.gridLine
      ..strokeWidth = 1;
    final dataPaint = Paint()
      ..color = tokens.colors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = tokens.colors.accent.withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;
    const left = 42.0;
    const top = 12.0;
    const right = 12.0;
    const bottom = 30.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    canvas
      ..drawLine(chart.bottomLeft, chart.bottomRight, axisPaint)
      ..drawLine(chart.bottomLeft, chart.topLeft, axisPaint);

    final yValues = points.map((point) => point.y).toList();
    final minY = yValues.reduce(math.min);
    final maxY = yValues.reduce(math.max);
    final ySpan = maxY == minY ? 1.0 : maxY - minY;
    Offset pointOffset(int index, ResultChartPoint point) {
      final x = points.length == 1
          ? chart.left + chart.width / 2
          : chart.left + (chart.width * index / (points.length - 1));
      final y = chart.bottom - ((point.y - minY) / ySpan * chart.height);
      return Offset(x, y);
    }

    switch (model.chartType) {
      case ResultChartType.bar:
        final barWidth = math.max(3.0, chart.width / points.length * 0.62);
        for (var i = 0; i < points.length; i++) {
          final offset = pointOffset(i, points[i]);
          canvas.drawRect(
            Rect.fromLTWH(
              offset.dx - barWidth / 2,
              offset.dy,
              barWidth,
              chart.bottom - offset.dy,
            ),
            fillPaint,
          );
        }
        break;
      case ResultChartType.pie:
        final center = chart.center;
        final radius = math.min(chart.width, chart.height) / 2.4;
        final total = yValues.fold<double>(
          0,
          (sum, value) => sum + value.abs(),
        );
        var start = -math.pi / 2;
        for (var i = 0; i < points.length; i++) {
          final sweep = total == 0
              ? 0.0
              : points[i].y.abs() / total * math.pi * 2;
          final slicePaint = Paint()
            ..color = Color.lerp(
              tokens.colors.accent,
              tokens.colors.success,
              points.length == 1 ? 0 : i / (points.length - 1),
            )!
            ..style = PaintingStyle.fill;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            start,
            sweep,
            true,
            slicePaint,
          );
          start += sweep;
        }
        break;
      case ResultChartType.line:
      case ResultChartType.scatter:
        final path = Path();
        for (var i = 0; i < points.length; i++) {
          final offset = pointOffset(i, points[i]);
          if (i == 0) {
            path.moveTo(offset.dx, offset.dy);
          } else if (model.chartType == ResultChartType.line) {
            path.lineTo(offset.dx, offset.dy);
          }
          canvas.drawCircle(offset, 3.5, fillPaint);
        }
        if (model.chartType == ResultChartType.line) {
          canvas.drawPath(path, dataPaint);
        }
        break;
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text:
          '${model.yColumn}: ${minY.toStringAsFixed(2)} - ${maxY.toStringAsFixed(2)}',
      style: TextStyle(color: tokens.colors.textMuted, fontSize: 11),
    );
    textPainter.layout(maxWidth: chart.width);
    textPainter.paint(canvas, Offset(chart.left, chart.bottom + 8));
  }

  @override
  bool shouldRepaint(covariant _SimpleChartPainter oldDelegate) {
    return oldDelegate.model != model || oldDelegate.tokens != tokens;
  }
}

class _ExecutionPlanToolbar extends StatelessWidget {
  const _ExecutionPlanToolbar({required this.visualization});

  final ExplainPlanVisualization visualization;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    final operationCount = <String, int>{};
    for (final node in visualization.nodes) {
      operationCount[node.operation] =
          (operationCount[node.operation] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.resultsGrid.headerBackground,
        border: Border(bottom: BorderSide(color: tokens.resultsGrid.gridLine)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _InfoBadge(
            icon: Icons.account_tree_outlined,
            label: '${visualization.nodes.length} plan steps',
          ),
          for (final entry in operationCount.entries)
            _InfoBadge(
              icon: Icons.bolt_outlined,
              label: '${entry.key} ${entry.value}',
            ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: visualization.rawText));
            },
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Copy Raw Plan'),
          ),
        ],
      ),
    );
  }
}

class _ExplainPlanTree extends StatelessWidget {
  const _ExplainPlanTree({required this.visualization});

  final ExplainPlanVisualization visualization;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visualization.nodes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final node = visualization.nodes[index];
        return Container(
          padding: EdgeInsets.fromLTRB(10 + (node.depth * 18), 10, 10, 10),
          decoration: BoxDecoration(
            color: tokens.colors.panelAltBg,
            border: Border.all(color: tokens.resultsGrid.gridLine),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Text(
                  '${node.lineNumber}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: tokens.fonts.editorFamily,
                    color: tokens.colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _PlanOperationBadge(operation: node.operation),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      node.detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: tokens.fonts.editorFamily,
                        color: tokens.resultsGrid.cellText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        if (node.tableName != null)
                          _PlanMetadataChip(label: 'table ${node.tableName}'),
                        if (node.indexName != null)
                          _PlanMetadataChip(label: 'index ${node.indexName}'),
                        if (node.estimatedRows != null)
                          _PlanMetadataChip(label: 'est ${node.estimatedRows}'),
                        if (node.actualRows != null)
                          _PlanMetadataChip(label: 'actual ${node.actualRows}'),
                      ],
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

class _PlanOperationBadge extends StatelessWidget {
  const _PlanOperationBadge({required this.operation});

  final String operation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.colors.accent.withValues(alpha: 0.12),
        border: Border.all(color: tokens.colors.accent),
      ),
      child: Text(
        operation,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.colors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlanMetadataChip extends StatelessWidget {
  const _PlanMetadataChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.resultsGrid.headerBackground,
        border: Border.all(color: tokens.resultsGrid.gridLine),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontFamily: tokens.fonts.editorFamily,
          color: tokens.colors.textMuted,
        ),
      ),
    );
  }
}

class _ExecutionPlanEmptyState extends StatelessWidget {
  const _ExecutionPlanEmptyState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 24),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.colors.panelAltBg,
        border: Border.all(color: tokens.colors.border),
        borderRadius: BorderRadius.circular(tokens.metrics.borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tokens.colors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MessageLevelBadge extends StatelessWidget {
  const _MessageLevelBadge({required this.level});

  final QueryMessageLevel level;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    final (label, color) = switch (level) {
      QueryMessageLevel.info => ('INFO', tokens.colors.info),
      QueryMessageLevel.warning => ('WARN', tokens.statusBar.warning),
      QueryMessageLevel.error => ('ERROR', tokens.statusBar.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontFamily: tokens.fonts.editorFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
