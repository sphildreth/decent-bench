import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../app/app_metadata.dart';
import '../../../app/startup_launch_options.dart';
import '../../../app/theme_system/theme_manager.dart';
import '../../import/application/import_manager.dart';
import '../../import/domain/import_models.dart';
import '../../import_modules/domain/import_module_manifest.dart';
import '../../import/presentation/generic_import_dialog.dart';
import '../../import/presentation/import_archive_chooser_dialog.dart';
import '../application/branch_controller.dart';
import '../application/menu_command_registry.dart';
import '../application/workspace_controller.dart';
import '../application/workspace_shell_controller.dart';
import '../domain/app_config.dart';
import '../domain/column_statistics.dart';
import '../domain/data_quality_models.dart';
import '../domain/data_quality_reports.dart';
import '../domain/database_statistics.dart';
import '../domain/saved_query_models.dart';
import '../domain/sql_autocomplete.dart';
import '../domain/sql_execution_target.dart';
import '../domain/sql_editor_selection.dart';
import '../domain/sql_formatter.dart';
import '../domain/sql_risk_assessment.dart';
import '../domain/workspace_file_entry.dart';
import '../domain/workspace_models.dart';
import '../infrastructure/app_lifecycle_service.dart';
import '../infrastructure/decentdb_doctor_service.dart';
import '../infrastructure/decentdb_migration_service.dart';
import '../infrastructure/decentdb_web_console_service.dart';
import '../infrastructure/shortcut_config_service.dart';
import 'about_dialog.dart';
import 'decentdb_doctor_dialog.dart';
import 'decentdb_migration_dialog.dart';
import 'excel_import_dialog.dart';
import 'export_results_csv_dialog.dart';
import 'export_results_excel_dialog.dart';
import 'export_results_json_dialog.dart';
import 'help/help_center_dialog.dart';
import 'ms_sql_bak_import_dialog.dart';
import 'log_viewer_dialog.dart';
import 'preferences_dialog.dart';
import 'quality/data_quality_dashboard.dart';
import 'quality/quality_report_export_dialog.dart';
import 'quality/validation_profile_editor.dart';
import 'shell/app_menu_bar.dart';
import 'shell/command_palette.dart';
import 'shell/command_toolbar.dart';
import 'shell/properties_pane.dart';
import 'shell/results_pane.dart';
import 'shell/schema_explorer_pane.dart';
import 'shell/schema_browser_models.dart';
import 'shell/schema_relationship_diagram.dart';
import 'shell/sql_editor_pane.dart';
import 'shell/sql_highlighting_text_controller.dart';
import 'shell/status_bar.dart';
import 'shell/workspace_layout_shell.dart';
import 'sql_dump_import_dialog.dart';
import 'sqlite_import_dialog.dart';

enum _RiskySqlDecision { cancel, currentDatabase, newBranch }

enum _AboutDialogAction { viewLicenses }

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.controller,
    required this.themeManager,
    this.appLifecycleService = const FlutterAppLifecycleService(),
    this.startupLaunchOptions = const StartupLaunchOptions(),
    this.webConsoleService,
  });

  final WorkspaceController controller;
  final ThemeManager themeManager;
  final AppLifecycleService appLifecycleService;
  final StartupLaunchOptions startupLaunchOptions;
  final DecentDbWebConsoleService? webConsoleService;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  static const _decentDbTypeGroup = XTypeGroup(
    label: 'DecentDB',
    extensions: <String>['ddb'],
  );
  static const _csvTypeGroup = XTypeGroup(
    label: 'CSV',
    extensions: <String>['csv'],
  );
  static const _jsonTypeGroup = XTypeGroup(
    label: 'JSON',
    extensions: <String>['json', 'jsonl', 'ndjson'],
  );
  static const _excelExportTypeGroup = XTypeGroup(
    label: 'Excel',
    extensions: <String>['xlsx'],
  );
  static const _schemaExportTypeGroup = XTypeGroup(
    label: 'Schema SQL',
    extensions: <String>['sql'],
  );
  static const _projectTypeGroup = XTypeGroup(
    label: 'Decent Bench Project',
    extensions: <String>['toml'],
  );

  late final SqlHighlightingTextEditingController _sqlController =
      SqlHighlightingTextEditingController()
        ..addListener(_handleSqlEditorStateChanged);
  late final TextEditingController _paramsController = TextEditingController();
  late final TextEditingController _findController = TextEditingController();
  late final FocusNode _sqlFocusNode = FocusNode(debugLabel: 'sql-editor')
    ..addListener(_handleFocusChanged);
  late final FocusNode _paramsFocusNode = FocusNode(debugLabel: 'sql-params')
    ..addListener(_handleFocusChanged);
  late final FocusNode _resultsFocusNode = FocusNode(debugLabel: 'results')
    ..addListener(_handleFocusChanged);
  late final FocusNode _findFocusNode = FocusNode(debugLabel: 'editor-find')
    ..addListener(_handleFocusChanged);
  late final UndoHistoryController _sqlUndoController = UndoHistoryController();
  late final UndoHistoryController _paramsUndoController =
      UndoHistoryController();
  late final ScrollController _resultsVerticalController = ScrollController()
    ..addListener(_onResultsScroll);
  late final ScrollController _resultsHorizontalController = ScrollController();
  late final ScrollController _editorScrollController = ScrollController();
  late final WorkspaceShellController _shellController =
      WorkspaceShellController(
        initialPreferences: widget.controller.config.shellPreferences,
        onPersist: (preferences, {statusMessage}) {
          return widget.controller.updateShellPreferences(
            preferences,
            statusMessage: statusMessage,
          );
        },
      );
  final GlobalKey<SchemaRelationshipDiagramState> _erdDiagramKey =
      GlobalKey<SchemaRelationshipDiagramState>();
  final ShortcutConfigService _shortcutConfigService =
      const ShortcutConfigService();
  final SqlAutocompleteEngine _autocompleteEngine =
      const SqlAutocompleteEngine();
  final SqlFormatter _sqlFormatter = const SqlFormatter();
  final ImportManager _importManager = ImportManager();
  final DecentDbMigrationService _migrationService = DecentDbMigrationService();
  late final DecentDbWebConsoleService _webConsoleService =
      widget.webConsoleService ?? DecentDbWebConsoleService();

  bool _didHydrateShellPreferences = false;
  bool _isDropTargetActive = false;
  bool _genericImportOpen = false;
  bool _showFindBar = false;
  int _findMatchCount = 0;
  int _activeFindMatch = 0;
  String? _selectedSchemaNodeId;
  bool _showCommandPalette = false;
  bool _nativeMenuAvailable = false;
  bool _didCheckNativeMenuAvailability = false;
  bool _didProcessStartupLaunchOptions = false;
  bool _pendingSqlEditorStateRebuild = false;
  bool _pendingControllerSync = false;
  _NavigationPaneMode _navigationPaneMode = _NavigationPaneMode.schema;
  int _autocompleteSelectionIndex = 0;
  TextEditingValue? _dismissedAutocompleteValue;
  String? _pendingSqlText;
  String? _pendingParamsText;
  SqlExecutionTarget _lastSqlExecutionTarget = const SqlExecutionTarget(
    kind: SqlExecutionTargetKind.buffer,
    sql: '',
    startOffset: 0,
    endOffset: 0,
    startLine: 1,
    startColumn: 1,
    lineCount: 0,
  );
  final Map<String, ResultsGridInteractionState> _resultsStateByTabId =
      <String, ResultsGridInteractionState>{};

  @override
  void initState() {
    super.initState();
    unawaited(_checkNativeMenuAvailability());
  }

  @override
  void dispose() {
    unawaited(_shellController.persistNow());
    _shellController.dispose();
    _paramsUndoController.dispose();
    _sqlUndoController.dispose();
    _editorScrollController.dispose();
    _resultsHorizontalController.dispose();
    _resultsVerticalController
      ..removeListener(_onResultsScroll)
      ..dispose();
    _findFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _paramsFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _sqlFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _resultsFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _findController.dispose();
    _paramsController.dispose();
    _sqlController.removeListener(_handleSqlEditorStateChanged);
    _sqlController.dispose();
    unawaited(_webConsoleService.shutdown());
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSqlEditorStateChanged() {
    final currentTarget = _sqlExecutionTarget();
    final shouldRebuild =
        currentTarget.kind != _lastSqlExecutionTarget.kind ||
        currentTarget.startOffset != _lastSqlExecutionTarget.startOffset ||
        currentTarget.endOffset != _lastSqlExecutionTarget.endOffset ||
        currentTarget.lineCount != _lastSqlExecutionTarget.lineCount;
    _lastSqlExecutionTarget = currentTarget;
    if (!mounted || !shouldRebuild) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    if (_pendingSqlEditorStateRebuild) {
      return;
    }
    _pendingSqlEditorStateRebuild = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingSqlEditorStateRebuild = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onResultsScroll() {
    if (!_resultsVerticalController.hasClients) {
      return;
    }
    final tab = widget.controller.activeTab;
    if (!tab.hasMoreRows || tab.phase == QueryPhase.fetching) {
      return;
    }
    final threshold = _resultsVerticalController.position.maxScrollExtent - 240;
    if (_resultsVerticalController.position.pixels >= threshold) {
      widget.controller.fetchNextPage(tabId: tab.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller,
        _shellController,
      ]),
      builder: (context, _) {
        final controller = widget.controller;
        _hydrateShellPreferencesIfReady(controller);
        _scheduleStartupLaunchIfReady(controller);
        final activeTab = controller.activeTab;
        _syncControllers(controller, activeTab);

        final selectedSelection = _selectedSchemaSelection(controller);
        final shortcuts = _shortcutConfigService.load(controller.config);
        final registry = _buildMenuCommandRegistry(controller, shortcuts);
        final autocompleteResult = _autocompleteFor(controller);
        final selectedAutocompleteIndex = _selectedAutocompleteIndexFor(
          autocompleteResult,
        );
        final sqlExecutionTarget = _sqlExecutionTarget();
        final sqlSelection = _sqlSelectionInfo();
        final shellPreferences = _shellController.preferences;
        final resultsState = _resultsStateFor(activeTab.id);
        final usePlaceholderContent = _usePlaceholderContent(controller);
        final databaseLabel = controller.databasePath == null
            ? 'sample.decentdb'
            : p.basename(controller.databasePath!);
        final schemaPaneIsLoading =
            controller.isInitializing ||
            controller.isSchemaLoading ||
            controller.isOpeningDatabase;

        return DropTarget(
          enable: !controller.hasImportSession && !_genericImportOpen,
          onDragEntered: (_) => setState(() => _isDropTargetActive = true),
          onDragExited: (_) => setState(() => _isDropTargetActive = false),
          onDragDone: (details) async {
            setState(() => _isDropTargetActive = false);
            await _handleIncomingFiles(details.files.map((file) => file.path));
          },
          child: Shortcuts(
            shortcuts: registry.buildShortcutMap(),
            child: Actions(
              actions: <Type, Action<Intent>>{
                MenuCommandIntent: CallbackAction<MenuCommandIntent>(
                  onInvoke: (intent) => registry.invoke(intent.commandId),
                ),
              },
              child: _wrapInMenuHost(
                registry,
                controller.config.recentFiles,
                Scaffold(
                  body: SafeArea(
                    child: Stack(
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (!_nativeMenuAvailable ||
                                !_didCheckNativeMenuAvailability)
                              AppMenuBar(
                                registry: registry,
                                recentFiles: controller.config.recentFiles,
                                onOpenRecent: _openRecentWorkspace,
                              ),
                            CommandToolbar(registry: registry),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: WorkspaceLayoutShell(
                                  controller: _shellController,
                                  schemaExplorer: _WorkspaceNavigationPane(
                                    mode: _navigationPaneMode,
                                    onModeChanged: _setNavigationPaneMode,
                                    schemaExplorer: SchemaExplorerPane(
                                      schema: controller.schema,
                                      databasePath: controller.databasePath,
                                      toolingMetadata:
                                          controller.toolingMetadata,
                                      branchLabel:
                                          controller.branchState.branchLabel,
                                      selectedNodeId: selectedSelection?.nodeId,
                                      onSelectNode: (nodeId) {
                                        setState(() {
                                          _selectedSchemaNodeId = nodeId;
                                        });
                                      },
                                      onShowNodeMenu:
                                          _showSchemaNodeContextMenu,
                                      onRefresh: () {
                                        controller.refreshSchema();
                                      },
                                      isLoading: schemaPaneIsLoading,
                                    ),
                                    qualityDashboard: DataQualityDashboard(
                                      controller: controller.dataQuality,
                                      onExportReport:
                                          _showQualityReportExportDialog,
                                    ),
                                    erdViewer: SchemaRelationshipDiagram(
                                      key: _erdDiagramKey,
                                      schema: controller.schema,
                                      databaseLabel: databaseLabel,
                                      databasePath: controller.databasePath,
                                      logger: controller.logger,
                                      selectedTableName:
                                          _selectedTableNameForErd(controller),
                                      onSelectTable: (tableName) {
                                        setState(() {
                                          _selectedSchemaNodeId =
                                              'table:$tableName';
                                        });
                                      },
                                      onOpenTable: _openTableFromErd,
                                      isLoading: schemaPaneIsLoading,
                                    ),
                                  ),
                                  propertiesPane: PropertiesPane(
                                    selection: selectedSelection,
                                  ),
                                  sqlEditor: SqlEditorPane(
                                    tabs: controller.tabs,
                                    activeTab: activeTab,
                                    sqlController: _sqlController,
                                    paramsController: _paramsController,
                                    editorScrollController:
                                        _editorScrollController,
                                    focusNode: _sqlFocusNode,
                                    paramsFocusNode: _paramsFocusNode,
                                    undoController: _sqlUndoController,
                                    paramsUndoController: _paramsUndoController,
                                    autocompleteResult: autocompleteResult,
                                    snippets: controller.config.snippets,
                                    zoomFactor: shellPreferences.editorZoom,
                                    indentSpaces: controller
                                        .config
                                        .editorSettings
                                        .indentSpaces,
                                    showLineNumbers: controller
                                        .config
                                        .editorSettings
                                        .showLineNumbers,
                                    showFindBar: _showFindBar,
                                    findController: _findController,
                                    findFocusNode: _findFocusNode,
                                    findStatusLabel: _findStatusLabel(),
                                    runLabel: sqlExecutionTarget.runLabel,
                                    formatLabel:
                                        sqlSelection.hasRunnableSelection
                                        ? 'Format Selection'
                                        : 'Format',
                                    editorContextLabel:
                                        sqlExecutionTarget.contextLabel,
                                    errorLocationLabel:
                                        activeTab.error?.location?.shortLabel,
                                    errorMessage: activeTab.error?.message,
                                    showRunBufferButton:
                                        !sqlExecutionTarget.isBufferTarget &&
                                        resolveSqlBufferTarget(
                                          _sqlController.value,
                                        ).hasRunnableSql,
                                    onSqlChanged: _handleSqlChanged,
                                    onParamsChanged:
                                        controller.updateActiveParameterJson,
                                    onSelectTab: controller.selectTab,
                                    onCloseTab: controller.closeTab,
                                    onNewTab: () => controller.createTab(),
                                    onRunQuery: _runPrimarySqlTarget,
                                    onRunBuffer: _runEntireSqlBuffer,
                                    onStopQuery: () {
                                      controller.cancelActiveQuery();
                                    },
                                    onFormatSql: _formatActiveSql,
                                    onInsertSnippet: _insertSnippet,
                                    onApplyAutocomplete: (suggestion) =>
                                        _applyAutocompleteSuggestion(
                                          autocompleteResult,
                                          suggestion,
                                        ),
                                    selectedAutocompleteIndex:
                                        selectedAutocompleteIndex,
                                    onAutocompleteNext: () =>
                                        _moveAutocompleteSelection(
                                          autocompleteResult,
                                          1,
                                        ),
                                    onAutocompletePrevious: () =>
                                        _moveAutocompleteSelection(
                                          autocompleteResult,
                                          -1,
                                        ),
                                    onAcceptAutocomplete: () =>
                                        _acceptAutocompleteSuggestion(
                                          autocompleteResult,
                                        ),
                                    onDismissAutocomplete: _dismissAutocomplete,
                                    canRun: controller.canRunActiveTab,
                                    canStop: controller.canCancelActiveTab,
                                    onFindChanged: _handleFindChanged,
                                    onFindNext: _findNext,
                                    onFindPrevious: _findPrevious,
                                    onCloseFind: _hideFindBar,
                                  ),
                                  resultsPane: Focus(
                                    focusNode: _resultsFocusNode,
                                    child: ResultsPane(
                                      activeTab: activeTab,
                                      activeResultsTab:
                                          shellPreferences.activeResultsTab,
                                      verticalScrollController:
                                          _resultsVerticalController,
                                      horizontalScrollController:
                                          _resultsHorizontalController,
                                      interactionState: resultsState,
                                      onResultsTabChanged:
                                          _shellController.setActiveResultsTab,
                                      onLoadNextPage: () {
                                        controller.fetchNextPage();
                                      },
                                      onSelectCell: _selectResultsCell,
                                      onShowCellMenu: _showResultsCellMenu,
                                      onSelectRow: _selectResultsRow,
                                      onTogglePinnedColumn: _togglePinnedColumn,
                                      onShowColumnStatistics:
                                          _showResultColumnStatistics,
                                      onLoadHistoryEntry: (entry) {
                                        controller
                                            .loadHistoryEntryIntoActiveTab(
                                              entry,
                                            );
                                      },
                                      onRunHistoryEntry: (entry) {
                                        return controller.rerunHistoryEntry(
                                          entry,
                                        );
                                      },
                                      onClearHistory:
                                          controller.clearActiveTabHistory,
                                      usePlaceholderContent:
                                          usePlaceholderContent,
                                      tableEditabilityLabel: controller
                                          .tableEditabilityForTab(activeTab.id)
                                          .statusLabel,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (shellPreferences.showStatusBar)
                              StatusBar(
                                statusMessage:
                                    controller.workspaceError ??
                                    controller.workspaceMessage ??
                                    'Ready',
                                workspaceLabel: 'Workspace: $databaseLabel',
                                lastExecutionLabel:
                                    'Last execution: ${activeTab.elapsed?.inMilliseconds ?? 142} ms',
                                rowsLabel:
                                    'Rows: ${activeTab.resultRows.isNotEmpty ? activeTab.resultRows.length : activeTab.rowsAffected ?? (controller.hasOpenDatabase ? 0 : 250)}',
                                editorModeLabel: _editorModeLabel(),
                                branchLabel: controller.branchState.branchLabel,
                              ),
                          ],
                        ),
                        if (_isDropTargetActive) const _DropOverlay(),
                        if (_showCommandPalette)
                          CommandPalette(
                            registry: registry,
                            logger: widget.controller.logger,
                            onDismiss: () =>
                                setState(() => _showCommandPalette = false),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hydrateShellPreferencesIfReady(WorkspaceController controller) {
    if (_didHydrateShellPreferences || controller.isInitializing) {
      return;
    }
    _shellController.replacePreferences(controller.config.shellPreferences);
    _didHydrateShellPreferences = true;
  }

  void _scheduleStartupLaunchIfReady(WorkspaceController controller) {
    if (_didProcessStartupLaunchOptions || controller.isInitializing) {
      return;
    }
    _didProcessStartupLaunchOptions = true;
    if (!widget.startupLaunchOptions.hasPendingAction) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _handleStartupLaunchOptions(widget.startupLaunchOptions);
    });
  }

  void _syncControllers(
    WorkspaceController controller,
    QueryTabState activeTab,
  ) {
    _pendingSqlText = activeTab.sql;
    _pendingParamsText = activeTab.parameterJson;
    if (_pendingControllerSync) {
      return;
    }
    if (_sqlController.text == activeTab.sql &&
        _paramsController.text == activeTab.parameterJson) {
      return;
    }
    _dismissedAutocompleteValue = null;
    _autocompleteSelectionIndex = 0;
    _pendingControllerSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingControllerSync = false;
      if (!mounted) {
        return;
      }
      _syncTextController(_sqlController, _pendingSqlText ?? '');
      _syncTextController(_paramsController, _pendingParamsText ?? '');
    });
  }

  void _syncTextController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    final offset = math.min(value.length, controller.selection.baseOffset);
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: math.max(offset, 0)),
    );
  }

  void _handleSqlChanged(String value) {
    _dismissedAutocompleteValue = null;
    _autocompleteSelectionIndex = 0;
    widget.controller.updateActiveSql(value);
  }

  void _setNavigationPaneMode(_NavigationPaneMode mode) {
    if (mode == _NavigationPaneMode.erd) {
      _logErdNavigationSelected();
    }
    setState(() {
      _navigationPaneMode = mode;
    });
  }

  void _logErdNavigationSelected() {
    final controller = widget.controller;
    final schema = controller.schema;
    final isLoading =
        controller.isInitializing ||
        controller.isSchemaLoading ||
        controller.isOpeningDatabase;
    final details = <String, Object?>{
      'database_label': controller.databasePath == null
          ? 'sample.decentdb'
          : p.basename(controller.databasePath!),
      'has_open_database': controller.hasOpenDatabase,
      'is_initializing': controller.isInitializing,
      'is_schema_loading': controller.isSchemaLoading,
      'is_opening_database': controller.isOpeningDatabase,
      'schema_loaded_at_utc': schema.loadedAt.toIso8601String(),
      'object_count': schema.objects.length,
      'table_count': schema.tables.length,
      'view_count': schema.views.length,
      'index_count': schema.indexes.length,
      'trigger_count': schema.triggers.length,
      'selected_schema_node_id': _selectedSchemaNodeId,
      'selected_table_for_erd': _selectedTableNameForErd(controller),
      'table_names_sample': _sampleSchemaNames(schema.tables),
      'view_names_sample': _sampleSchemaNames(schema.views),
    };
    assert(() {
      developer.log(
        'ERD navigation selected ${jsonEncode(details)}',
        name: 'erd.navigation',
      );
      return true;
    }());
    controller.logger.info(
      category: 'erd',
      operation: 'navigation_selected',
      message: 'ERD navigation selected.',
      databasePath: controller.databasePath,
      details: details,
    );
    if (controller.hasOpenDatabase && !isLoading && schema.tables.isEmpty) {
      controller.logger.warning(
        category: 'erd',
        operation: 'navigation_empty_schema',
        message:
            'ERD selected for ${details['database_label']} while the open '
            'workspace schema has ${schema.tables.length} tables, '
            '${schema.views.length} views, and ${schema.objects.length} '
            'schema objects.',
        databasePath: controller.databasePath,
        details: details,
      );
    }
  }

  List<String> _sampleSchemaNames(List<SchemaObjectSummary> objects) {
    const sampleLimit = 25;
    return objects
        .map((object) => object.name)
        .take(sampleLimit)
        .toList(growable: false);
  }

  SchemaSelectionDetails? _selectedSchemaSelection(
    WorkspaceController controller,
  ) {
    final candidate =
        _selectedSchemaNodeId ?? _fallbackSchemaNodeId(controller);
    final resolved = _selectionDetailsForNode(controller, candidate);
    if (resolved != null) {
      _selectedSchemaNodeId = resolved.nodeId;
      return resolved;
    }
    _selectedSchemaNodeId = 'database';
    return _selectionDetailsForNode(controller, 'database');
  }

  String _fallbackSchemaNodeId(WorkspaceController controller) {
    if (controller.schema.tables.isNotEmpty) {
      return 'table:${controller.schema.tables.first.name}';
    }
    if (controller.schema.views.isNotEmpty) {
      return 'view:${controller.schema.views.first.name}';
    }
    if (controller.schema.indexes.isNotEmpty) {
      return 'index:${controller.schema.indexes.first.name}';
    }
    return 'database';
  }

  String? _selectedTableNameForErd(WorkspaceController controller) {
    final nodeId = _selectedSchemaNodeId ?? _fallbackSchemaNodeId(controller);
    if (!nodeId.startsWith('table:')) {
      return null;
    }
    final tableName = nodeId.substring('table:'.length);
    return controller.schema.objectNamed(tableName)?.kind ==
            SchemaObjectKind.table
        ? tableName
        : null;
  }

  SchemaSelectionDetails? _selectionDetailsForNode(
    WorkspaceController controller,
    String nodeId,
  ) {
    final allowSampleSchema = controller.databasePath == null;
    if (nodeId == 'database') {
      return SchemaSelectionDetails(
        nodeId: nodeId,
        kind: SchemaSelectionKind.database,
        label: controller.databasePath == null
            ? 'sample.decentdb'
            : p.basename(controller.databasePath!),
        subtitle: 'Database summary',
        summaryRows: <MapEntry<String, String>>[
          MapEntry('Tables', '${controller.schema.tables.length}'),
          MapEntry('Views', '${controller.schema.views.length}'),
          MapEntry('Indexes', '${controller.schema.indexes.length}'),
          MapEntry('Triggers', '${controller.schema.triggers.length}'),
          MapEntry('Engine', controller.engineVersion ?? 'DecentDB mock shell'),
        ],
        notes: controller.databasePath == null
            ? const <String>[
                'No database is open yet. The shell is showing realistic placeholders so layout and density can be evaluated.',
              ]
            : const <String>[
                'Select a table, view, index, column, or constraint in Schema Explorer to inspect it here.',
              ],
      );
    }

    if (nodeId.startsWith('section:')) {
      final section = nodeId.substring('section:'.length);
      final (label, count) = switch (section) {
        'tables' => ('Tables', controller.schema.tables.length),
        'views' => ('Views', controller.schema.views.length),
        'indexes' => ('Indexes', controller.schema.indexes.length),
        _ => (section, 0),
      };
      return SchemaSelectionDetails(
        nodeId: nodeId,
        kind: SchemaSelectionKind.section,
        label: label,
        subtitle: '$label folder',
        summaryRows: <MapEntry<String, String>>[
          MapEntry('Visible items', '$count'),
          MapEntry('Selection', 'Explorer section'),
        ],
        notes: <String>[
          'Sections are lazily expanded and keep their expansion state while the workspace is open.',
        ],
      );
    }

    if (nodeId.startsWith('table:') || nodeId.startsWith('view:')) {
      final isTable = nodeId.startsWith('table:');
      final objectName = nodeId.substring(isTable ? 6 : 5);
      final object = controller.schema.objectNamed(objectName);
      if (object == null) {
        return allowSampleSchema ? _sampleSelectionDetails(nodeId) : null;
      }
      final indexes = controller.schema.indexesForObject(object.name);
      final triggers = controller.schema.triggersForObject(object.name);
      return SchemaSelectionDetails(
        nodeId: nodeId,
        kind: isTable ? SchemaSelectionKind.table : SchemaSelectionKind.view,
        label: object.name,
        subtitle: '${object.kind.name} metadata',
        objectName: object.name,
        definition: object.ddl,
        summaryRows: <MapEntry<String, String>>[
          MapEntry('Columns', '${object.columns.length}'),
          MapEntry('Indexes', '${indexes.length}'),
          MapEntry('Triggers', '${triggers.length}'),
          MapEntry('Temporary', object.temporary ? 'Yes' : 'No'),
          if (object.isTable && object.rowCount != null)
            MapEntry('Rows', '${object.rowCount}'),
          if (object.isTable &&
              object.primaryKeyColumns.isNotEmpty)
            MapEntry('Primary key', object.primaryKeyColumns.join(', ')),
          if (object.isTable && object.foreignKeys.isNotEmpty)
            MapEntry('Foreign keys', '${object.foreignKeys.length}'),
          if (object.isView && object.viewDependencies.isNotEmpty)
            MapEntry('Depends on', object.viewDependencies.join(', ')),
          MapEntry(
            'Definition',
            object.ddl == null || object.ddl!.trim().isEmpty
                ? 'Unavailable'
                : 'Available',
          ),
        ],
        notes: <String>[
          ...object.exposedConstraintSummaries,
          for (final trigger in triggers)
            'Trigger ${trigger.name}: ${trigger.timing.toUpperCase()} ${trigger.events.join(", ")}',
          if (object.isView &&
              object.sqlText != null &&
              object.sqlText!.trim().isNotEmpty)
            'SQL text: ${object.sqlText}',
          ...controller.schemaNotesForObject(object),
        ],
      );
    }

    if (nodeId.startsWith('index:')) {
      final indexName = nodeId.substring('index:'.length);
      for (final index in controller.schema.indexes) {
        if (index.name == indexName) {
          return SchemaSelectionDetails(
            nodeId: nodeId,
            kind: SchemaSelectionKind.schemaIndex,
            label: index.name,
            subtitle: 'Index metadata',
            objectName: index.table,
            definition: index.ddl,
            summaryRows: <MapEntry<String, String>>[
              MapEntry('Table', index.table),
              MapEntry('Kind', index.kind),
              MapEntry('Unique', index.unique ? 'Yes' : 'No'),
              MapEntry('Temporary', index.temporary ? 'Yes' : 'No'),
              MapEntry('Columns', index.columns.join(', ')),
              if (index.includeColumns.isNotEmpty)
                MapEntry(
                  'Includes',
                  index.includeColumns.join(', '),
                ),
              MapEntry('Fresh', index.fresh ? 'Yes' : 'No'),
              if (index.predicateSql != null && index.predicateSql!.isNotEmpty)
                MapEntry('Predicate', index.predicateSql!),
            ],
            notes: <String>[
              if (!index.fresh)
                'Index needs rebuild — call ALTER INDEX ... REBUILD.',
              if (index.ddl == null || index.ddl!.trim().isEmpty)
                'Canonical index DDL is unavailable for this index.',
            ],
          );
        }
      }
      return allowSampleSchema ? _sampleSelectionDetails(nodeId) : null;
    }

    if (nodeId.startsWith('column:')) {
      final parts = nodeId.split(':');
      if (parts.length >= 3) {
        final object = controller.schema.objectNamed(parts[1]);
        if (object == null) {
          return allowSampleSchema ? _sampleSelectionDetails(nodeId) : null;
        }
        for (final column in object.columns) {
          if (column.name == parts[2]) {
            final typeMetadata = controller.toolingMetadata?.columnTypeFor(
              tableName: object.name,
              columnName: column.name,
            );
            final nativeType =
                typeMetadata?.nativeTypeDescriptor ??
                describeNativeType(typeName: column.type);
            final spatialInfo = nativeType.spatial;
            return SchemaSelectionDetails(
              nodeId: nodeId,
              kind: SchemaSelectionKind.column,
              label: column.name,
              subtitle: 'Column metadata',
              objectName: object.name,
              summaryRows: <MapEntry<String, String>>[
                MapEntry('Object', object.name),
                MapEntry('Type', column.type),
                MapEntry('Type family', nativeType.familyLabel),
                if (typeMetadata?.typeInfo.valueKind.trim().isNotEmpty == true)
                  MapEntry('Value kind', typeMetadata!.typeInfo.valueKind),
                if (spatialInfo != null)
                  MapEntry('Spatial', spatialInfo.summaryLabel),
                if (nativeType.enumLabels.isNotEmpty)
                  MapEntry('Enum labels', nativeType.enumLabels.join(', ')),
                MapEntry('Primary key', column.primaryKey ? 'Yes' : 'No'),
                MapEntry('Nullable', column.notNull ? 'No' : 'Yes'),
                MapEntry('Unique', column.unique ? 'Yes' : 'No'),
                if (column.hasDefault) MapEntry('Default', column.defaultExpr!),
                if (column.isGenerated)
                  MapEntry(
                    'Generated',
                    column.generatedStored
                        ? 'STORED AS (${column.generatedExpr})'
                        : 'AS (${column.generatedExpr})',
                  ),
                if (column.hasForeignKey)
                  MapEntry(
                    'References',
                    '${column.refTable}(${column.refColumn})',
                  ),
              ],
              notes: <String>[
                if (nativeType.isNativeV25Type)
                  'Native DecentDB type: ${nativeType.summaryLabel}.',
                if (column.constraintSummaries.isEmpty)
                  'No explicit constraints exposed.'
                else
                  ...column.constraintSummaries,
              ],
            );
          }
        }
      }
      return allowSampleSchema ? _sampleSelectionDetails(nodeId) : null;
    }

    if (nodeId.startsWith('constraint:')) {
      final parts = nodeId.split(':');
      if (parts.length >= 4) {
        final object = controller.schema.objectNamed(parts[1]);
        if (object == null) {
          return allowSampleSchema ? _sampleSelectionDetails(nodeId) : null;
        }
        if (parts[2] == 'check') {
          final checkIndex = int.tryParse(parts[3]);
          if (checkIndex != null &&
              checkIndex >= 0 &&
              checkIndex < object.checks.length) {
            final check = object.checks[checkIndex];
            return SchemaSelectionDetails(
              nodeId: nodeId,
              kind: SchemaSelectionKind.constraint,
              label: check.summary,
              subtitle: 'Constraint metadata',
              objectName: object.name,
              summaryRows: <MapEntry<String, String>>[
                MapEntry('Object', object.name),
                MapEntry(
                  'Constraint',
                  check.name.isEmpty ? 'CHECK' : check.name,
                ),
                MapEntry('Expression', check.exprSql),
              ],
              notes: const <String>[
                'Table-level CHECK constraints are surfaced directly from DecentDB schema metadata.',
              ],
            );
          }
        }
        for (final column in object.columns) {
          if (column.name != parts[2]) {
            continue;
          }
          final constraintIndex = int.tryParse(parts[3]);
          if (constraintIndex != null &&
              constraintIndex >= 0 &&
              constraintIndex < column.constraintSummaries.length) {
            final constraint = column.constraintSummaries[constraintIndex];
            return SchemaSelectionDetails(
              nodeId: nodeId,
              kind: SchemaSelectionKind.constraint,
              label: constraint,
              subtitle: 'Constraint metadata',
              objectName: object.name,
              summaryRows: <MapEntry<String, String>>[
                MapEntry('Object', object.name),
                MapEntry('Column', column.name),
                MapEntry('Constraint', constraint),
              ],
              notes: const <String>[],
            );
          }
        }
      }
      return SchemaSelectionDetails(
        nodeId: nodeId,
        kind: SchemaSelectionKind.constraint,
        label: 'No explicit constraints',
        subtitle: 'Constraint folder',
        summaryRows: const <MapEntry<String, String>>[
          MapEntry('Constraint count', '0'),
        ],
        notes: const <String>[
          'The current object does not define any explicit constraints.',
        ],
      );
    }

    if (nodeId.startsWith('trigger:')) {
      final parts = nodeId.split(':');
      if (parts.length >= 3) {
        final targetName = parts[1];
        final triggerName = parts.sublist(2).join(':');
        final trigger = controller.schema.triggerNamed(targetName, triggerName);
        if (trigger != null) {
          return SchemaSelectionDetails(
            nodeId: nodeId,
            kind: SchemaSelectionKind.trigger,
            label: trigger.name,
            subtitle: 'Trigger metadata',
            objectName: trigger.targetName,
            definition: trigger.ddl,
            summaryRows: <MapEntry<String, String>>[
              MapEntry('Target', trigger.targetName),
              MapEntry('Target kind', trigger.targetKind),
              MapEntry('Timing', trigger.timing.toUpperCase()),
              MapEntry('Events', trigger.events.join(', ')),
              MapEntry('For each row', trigger.forEachRow ? 'Yes' : 'No'),
              MapEntry('Temporary', trigger.temporary ? 'Yes' : 'No'),
            ],
            notes: <String>['Action SQL: ${trigger.actionSql}'],
          );
        }
        if (triggerName == 'none') {
          return SchemaSelectionDetails(
            nodeId: nodeId,
            kind: SchemaSelectionKind.trigger,
            label: 'No triggers',
            subtitle: 'Trigger folder',
            objectName: targetName,
            summaryRows: const <MapEntry<String, String>>[
              MapEntry('Trigger count', '0'),
            ],
            notes: const <String>['No triggers are defined for this object.'],
          );
        }
      }
      return allowSampleSchema ? _sampleSelectionDetails(nodeId) : null;
    }

    return allowSampleSchema ? _sampleSelectionDetails(nodeId) : null;
  }

  SchemaSelectionDetails? _sampleSelectionDetails(String nodeId) {
    if (nodeId.startsWith('table:sample.')) {
      final label = nodeId.substring('table:sample.'.length);
      return SchemaSelectionDetails(
        nodeId: nodeId,
        kind: SchemaSelectionKind.table,
        label: label,
        subtitle: 'Sample table metadata',
        objectName: label,
        summaryRows: const <MapEntry<String, String>>[
          MapEntry('Columns', '3'),
          MapEntry('Indexes', '1'),
          MapEntry('Definition', 'Placeholder'),
        ],
        notes: const <String>[
          'Sample metadata is shown until a real DecentDB file is opened.',
        ],
      );
    }
    if (nodeId.startsWith('view:sample.')) {
      final label = nodeId.substring('view:sample.'.length);
      return SchemaSelectionDetails(
        nodeId: nodeId,
        kind: SchemaSelectionKind.view,
        label: label,
        subtitle: 'Sample view metadata',
        objectName: label,
        summaryRows: const <MapEntry<String, String>>[
          MapEntry('Columns', '2'),
          MapEntry('Definition', 'Placeholder'),
        ],
        notes: const <String>[
          'Sample metadata is shown until a real DecentDB file is opened.',
        ],
      );
    }
    if (nodeId.startsWith('index:sample:')) {
      final label = nodeId.substring('index:sample:'.length);
      return SchemaSelectionDetails(
        nodeId: nodeId,
        kind: SchemaSelectionKind.schemaIndex,
        label: label,
        subtitle: 'Sample index metadata',
        summaryRows: const <MapEntry<String, String>>[
          MapEntry('Kind', 'btree'),
          MapEntry('Unique', 'No'),
        ],
        notes: const <String>[
          'Sample metadata is shown until a real DecentDB file is opened.',
        ],
      );
    }
    return null;
  }

  String _editorModeLabel() {
    if (_findFocusNode.hasFocus) {
      return 'Find mode';
    }
    if (_resultsFocusNode.hasFocus) {
      return 'Grid mode';
    }
    if (_paramsFocusNode.hasFocus) {
      return 'Parameter mode';
    }
    if (_sqlFocusNode.hasFocus) {
      return 'Editor mode';
    }
    return 'Ready mode';
  }

  AutocompleteResult _autocompleteFor(WorkspaceController controller) {
    final value = _sqlController.value;
    if (_dismissedAutocompleteValue == value) {
      return const AutocompleteResult(
        replaceStart: 0,
        replaceEnd: 0,
        suggestions: <AutocompleteSuggestion>[],
      );
    }
    final selection = _sqlController.selection;
    final offset = selection.isValid && selection.baseOffset >= 0
        ? selection.baseOffset
        : _sqlController.text.length;
    return _autocompleteEngine.suggest(
      sql: _sqlController.text,
      cursorOffset: offset,
      schema: controller.schema,
      config: controller.config,
    );
  }

  SqlEditorSelectionInfo _sqlSelectionInfo() {
    return resolveSqlEditorSelectionInfo(_sqlController.value);
  }

  SqlExecutionTarget _sqlExecutionTarget() {
    return resolveSqlExecutionTarget(_sqlController.value);
  }

  int _selectedAutocompleteIndexFor(AutocompleteResult result) {
    if (result.isEmpty) {
      return 0;
    }
    return _autocompleteSelectionIndex
        .clamp(0, result.suggestions.length - 1)
        .toInt();
  }

  void _moveAutocompleteSelection(AutocompleteResult result, int delta) {
    if (result.isEmpty) {
      return;
    }
    final nextIndex =
        (_selectedAutocompleteIndexFor(result) + delta) %
        result.suggestions.length;
    setState(() {
      _autocompleteSelectionIndex = nextIndex < 0
          ? result.suggestions.length - 1
          : nextIndex;
    });
  }

  void _acceptAutocompleteSuggestion(AutocompleteResult result) {
    if (result.isEmpty) {
      return;
    }
    _applyAutocompleteSuggestion(
      result,
      result.suggestions[_selectedAutocompleteIndexFor(result)],
    );
  }

  void _dismissAutocomplete() {
    setState(() {
      _dismissedAutocompleteValue = _sqlController.value;
      _autocompleteSelectionIndex = 0;
    });
  }

  Future<void> _checkNativeMenuAvailability() async {
    if (kIsWeb ||
        !(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      if (!mounted) {
        return;
      }
      setState(() {
        _didCheckNativeMenuAvailability = true;
        _nativeMenuAvailable = false;
      });
      return;
    }

    try {
      final supported = await SystemChannels.menu.invokeMethod<bool>(
        'Menu.isPluginAvailable',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _didCheckNativeMenuAvailability = true;
        _nativeMenuAvailable = supported ?? Platform.isMacOS;
      });
    } on MissingPluginException {
      widget.controller.logger.debug(
        category: 'platform',
        operation: 'native_menu_detect',
        message: 'Native menu plugin not available on this platform.',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _didCheckNativeMenuAvailability = true;
        _nativeMenuAvailable = false;
      });
    } catch (error) {
      widget.controller.logger.debug(
        category: 'platform',
        operation: 'native_menu_detect',
        message: 'Could not detect native menu availability.',
        details: <String, Object?>{'error': error.toString()},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _didCheckNativeMenuAvailability = true;
        _nativeMenuAvailable = false;
      });
    }
  }

  ResultsGridInteractionState _resultsStateFor(String tabId) {
    final current = _resultsStateByTabId.putIfAbsent(
      tabId,
      () => const ResultsGridInteractionState(),
    );
    final tab = widget.controller.tabById(tabId) ?? widget.controller.activeTab;
    final usePlaceholderContent = _usePlaceholderContent(widget.controller);
    final rows = resolveResultsRows(
      tab,
      usePlaceholderContent: usePlaceholderContent,
    );
    final columns = resolveResultsColumns(
      tab,
      usePlaceholderContent: usePlaceholderContent,
    );
    final shouldResetForExecution =
        current.executionGeneration != tab.executionGeneration;
    final normalized = current.copyWith(
      selectedRows: shouldResetForExecution
          ? const <int>{}
          : current.selectedRows
                .where((rowIndex) => rowIndex >= 0 && rowIndex < rows.length)
                .toSet(),
      selectedCell: shouldResetForExecution
          ? null
          : current.selectedCell != null &&
                current.selectedCell!.rowIndex >= 0 &&
                current.selectedCell!.rowIndex < rows.length &&
                columns.contains(current.selectedCell!.columnName)
          ? current.selectedCell
          : null,
      pinnedColumns: current.pinnedColumns.where(columns.contains).toSet(),
      cellOverrides: shouldResetForExecution
          ? const <ResultsGridCellKey, Object?>{}
          : Map<ResultsGridCellKey, Object?>.fromEntries(
              current.cellOverrides.entries.where(
                (entry) =>
                    entry.key.rowIndex >= 0 &&
                    entry.key.rowIndex < rows.length &&
                    columns.contains(entry.key.columnName),
              ),
            ),
      executionGeneration: tab.executionGeneration,
    );
    _resultsStateByTabId[tabId] = normalized;
    return normalized;
  }

  void _selectResultsCell(int rowIndex, String columnName) {
    final tabId = widget.controller.activeTabId;
    final current = _resultsStateFor(tabId);
    setState(() {
      _resultsStateByTabId[tabId] = current.copyWith(
        selectedRows: <int>{rowIndex},
        selectedCell: ResultsGridCellSelection(
          rowIndex: rowIndex,
          columnName: columnName,
        ),
      );
    });
    _resultsFocusNode.requestFocus();
  }

  void _selectResultsRow(int rowIndex) {
    final tabId = widget.controller.activeTabId;
    final current = _resultsStateFor(tabId);
    setState(() {
      _resultsStateByTabId[tabId] = current.copyWith(
        selectedRows: <int>{rowIndex},
        selectedCell: null,
      );
    });
    _resultsFocusNode.requestFocus();
  }

  Future<void> _showResultsCellMenu(
    int rowIndex,
    String columnName,
    Offset globalPosition,
  ) async {
    _selectResultsCell(rowIndex, columnName);
    final clipboardText = (await Clipboard.getData(
      Clipboard.kTextPlain,
    ))?.text?.trim();
    final canPaste = clipboardText != null && clipboardText.isNotEmpty;
    final canSetNull = _isSelectedResultsCellNullable(
      rowIndex: rowIndex,
      columnName: columnName,
    );
    final editability = widget.controller.tableEditabilityForTab(
      widget.controller.activeTabId,
    );
    final canEditCell = editability.canEditColumn(columnName);
    final spatialCopyProfile = _selectedResultsCellSpatialCopyProfile(
      rowIndex: rowIndex,
      columnName: columnName,
    );
    if (!mounted) {
      return;
    }

    final action = await showMenu<_ResultsCellMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: <PopupMenuEntry<_ResultsCellMenuAction>>[
        _popupMenuItem(
          value: _ResultsCellMenuAction.copy,
          icon: Icons.copy_outlined,
          label: 'Copy',
        ),
        _popupMenuItem(
          value: _ResultsCellMenuAction.copySpatialWkb,
          icon: Icons.public_outlined,
          label: 'Copy EWKB Base64',
          enabled: spatialCopyProfile.canCopyWkb,
        ),
        _popupMenuItem(
          value: _ResultsCellMenuAction.copySpatialWkt,
          icon: Icons.location_on_outlined,
          label: 'Copy WKT',
          enabled: spatialCopyProfile.canCopyWkt,
        ),
        _popupMenuItem(
          value: _ResultsCellMenuAction.copySpatialGeoJson,
          icon: Icons.data_object_outlined,
          label: 'Copy GeoJSON',
          enabled: spatialCopyProfile.canCopyGeoJson,
        ),
        _popupMenuItem(
          value: _ResultsCellMenuAction.edit,
          icon: Icons.edit_outlined,
          label: 'Edit Cell',
          enabled: canEditCell,
        ),
        _popupMenuItem(
          value: _ResultsCellMenuAction.insertRow,
          icon: Icons.add_circle_outline,
          label: 'Insert Row',
          enabled: editability.canInsertRows,
        ),
        _popupMenuItem(
          value: _ResultsCellMenuAction.paste,
          icon: Icons.content_paste_outlined,
          label: 'Paste',
          enabled: canEditCell && canPaste,
        ),
        _popupMenuItem(
          value: _ResultsCellMenuAction.setNull,
          icon: Icons.exposure_zero_outlined,
          label: 'Set To Null',
          enabled: canEditCell && canSetNull,
        ),
        _popupMenuItem(
          value: _ResultsCellMenuAction.deleteRow,
          icon: Icons.delete_outline,
          label: 'Delete Row',
          enabled: editability.canDeleteRows,
        ),
      ],
    );
    if (action == null) {
      return;
    }

    switch (action) {
      case _ResultsCellMenuAction.copy:
        await _copyResultsSelection();
        break;
      case _ResultsCellMenuAction.copySpatialWkb:
        await _copySelectedSpatialWkb(
          rowIndex: rowIndex,
          columnName: columnName,
        );
        break;
      case _ResultsCellMenuAction.copySpatialWkt:
        await _copySelectedSpatialWkt(
          rowIndex: rowIndex,
          columnName: columnName,
        );
        break;
      case _ResultsCellMenuAction.copySpatialGeoJson:
        await _copySelectedSpatialGeoJson(
          rowIndex: rowIndex,
          columnName: columnName,
        );
        break;
      case _ResultsCellMenuAction.edit:
        await _editSelectedResultsCell(
          rowIndex: rowIndex,
          columnName: columnName,
        );
        break;
      case _ResultsCellMenuAction.insertRow:
        await _insertResultRow(
          anchorRowIndex: rowIndex,
          columnName: columnName,
        );
        break;
      case _ResultsCellMenuAction.paste:
        if (clipboardText != null && clipboardText.isNotEmpty) {
          await _commitSelectedResultsCellValue(
            rowIndex: rowIndex,
            columnName: columnName,
            value: clipboardText,
          );
        }
        break;
      case _ResultsCellMenuAction.setNull:
        await _commitSelectedResultsCellValue(
          rowIndex: rowIndex,
          columnName: columnName,
          value: null,
        );
        break;
      case _ResultsCellMenuAction.deleteRow:
        await _deleteSelectedResultsRow(rowIndex: rowIndex);
        break;
    }
  }

  void _togglePinnedColumn(String columnName) {
    final tabId = widget.controller.activeTabId;
    final current = _resultsStateFor(tabId);
    final nextPinned = <String>{...current.pinnedColumns};
    if (!nextPinned.add(columnName)) {
      nextPinned.remove(columnName);
    }
    setState(() {
      _resultsStateByTabId[tabId] = current.copyWith(pinnedColumns: nextPinned);
    });
  }

  Future<void> _showResultColumnStatistics(String columnName) async {
    final tab = widget.controller.activeTab;
    final usePlaceholderContent = _usePlaceholderContent(widget.controller);
    final rows = resolveResultsRows(
      tab,
      usePlaceholderContent: usePlaceholderContent,
    );
    final contract = tab.resultContractForColumn(columnName);
    final statistics = buildColumnStatistics(
      columnName: columnName,
      rows: rows,
      nativeType: contract?.nativeTypeDescriptor,
    );
    await _showColumnStatisticsDialog(statistics);
  }

  Future<void> _showSchemaColumnStatistics(String nodeId) async {
    final parts = nodeId.split(':');
    if (parts.length < 3) {
      return;
    }
    final objectName = parts[1];
    final columnName = parts[2];
    final object = widget.controller.schema.objectNamed(objectName);
    final column = object == null
        ? null
        : _firstOrNull(object.columns.where((item) => item.name == columnName));
    final typeMetadata = widget.controller.toolingMetadata?.columnTypeFor(
      tableName: objectName,
      columnName: columnName,
    );
    final nativeType =
        typeMetadata?.nativeTypeDescriptor ??
        (column == null ? null : describeNativeType(typeName: column.type));
    final activeTab = widget.controller.activeTab;
    final canUseLoadedRows =
        activeTab.resultRows.isNotEmpty &&
        activeTab.resultColumns.contains(columnName);
    final statistics = buildColumnStatistics(
      columnName: columnName,
      rows: canUseLoadedRows
          ? activeTab.resultRows
          : const <Map<String, Object?>>[],
      nativeType: nativeType,
    );
    await _showColumnStatisticsDialog(
      statistics,
      note: canUseLoadedRows
          ? null
          : 'Open or run a result set containing this column to profile loaded values.',
    );
  }

  Future<void> _showColumnStatisticsDialog(
    ColumnStatistics statistics, {
    String? note,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Column Statistics: ${statistics.columnName}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _KeyValueList(rows: statistics.summaryRows),
              if (note != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(note),
              ],
              if (statistics.topValues.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Top values',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final value in statistics.topValues)
                  Text('${value.label}: ${value.count}'),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: statistics.toClipboardText()),
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Copy Summary'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatabaseStatisticsDashboard() async {
    final statistics = await _buildDatabaseStatistics();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Statistics'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _KeyValueList(rows: statistics.summaryRows),
                if (statistics.operationalMetricRows.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Operational metrics',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _KeyValueList(rows: statistics.operationalMetricRows),
                ],
                if (statistics.maintenanceHints.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Maintenance hints',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final hint in statistics.maintenanceHints)
                    Text('- $hint'),
                ],
                if (statistics.rowCountQueries.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Lazy row counts',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${statistics.rowCountQueries.length} COUNT query template'
                    '${statistics.rowCountQueries.length == 1 ? '' : 's'} available.',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: statistics.rowCountQueries.isEmpty
                ? null
                : () {
                    Navigator.of(context).pop();
                    _openSqlTemplate(_rowCountQuery(statistics));
                  },
            child: const Text('Open Row Count Query'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: statistics.toClipboardText()),
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Copy Summary'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatabaseDoctorDashboard() async {
    final databasePath = widget.controller.databasePath;
    if (databasePath == null || databasePath.trim().isEmpty) {
      return;
    }
    final service = DecentDbDoctorService(
      sysViewRunner: (sql) => widget.controller.querySysView(sql),
    );
    final future = widget.controller.runDatabaseDoctor(service: service);
    if (!mounted) {
      return;
    }
    await DecentDbDoctorDialog.show(context: context, future: future);
  }

  Future<void> _openWebConsole() async {
    final databasePath = widget.controller.databasePath;
    if (databasePath == null || databasePath.trim().isEmpty) {
      await _showPlaceholderNotice(
        'Open Web Console',
        'Open a DecentDB database first.',
      );
      return;
    }
    try {
      final session = await _webConsoleService.launch(
        databasePath: databasePath,
      );
      if (!mounted) {
        return;
      }
      await _showWebConsoleSessionDialog(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showPlaceholderNotice('Open Web Console', error.toString());
    }
  }

  Future<void> _showWebConsoleSessionDialog(DecentDbWebConsoleSession session) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final endpoint = session.consoleUri?.toString() ?? 'Starting';
        return AlertDialog(
          title: const Text('Web Console'),
          content: SizedBox(
            width: 520,
            child: _KeyValueList(
              rows: <MapEntry<String, String>>[
                MapEntry('Database', session.databasePath),
                MapEntry('Endpoint', endpoint),
                MapEntry('Process', p.basename(session.cliPath)),
                if (session.consolePort != null)
                  MapEntry('Port', '${session.consolePort}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await _webConsoleService.shutdown();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Stop'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<DatabaseStatistics> _buildDatabaseStatistics() async {
    final databasePath = widget.controller.databasePath;
    final databaseFileBytes = await _fileSize(databasePath);
    final walFileBytes = await _fileSize(
      databasePath == null ? null : '$databasePath-wal',
    );
    final shmFileBytes = await _fileSize(
      databasePath == null ? null : '$databasePath-shm',
    );
    final operationalMetrics = await widget.controller.loadOperationalMetrics();
    return buildDatabaseStatistics(
      schema: widget.controller.schema,
      branchState: widget.controller.branchState,
      databasePath: databasePath,
      databaseFileBytes: databaseFileBytes,
      walFileBytes: walFileBytes,
      shmFileBytes: shmFileBytes,
      operationalMetrics: operationalMetrics,
    );
  }

  Future<int?> _fileSize(String? path) async {
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return 0;
    }
    return file.length();
  }

  String _rowCountQuery(DatabaseStatistics statistics) {
    final entries = statistics.rowCountQueries.entries.toList();
    if (entries.isEmpty) {
      return '-- No tables are available for row counting.';
    }
    return entries
        .map(
          (entry) =>
              'SELECT ${_quoteStringLiteral(entry.key)} AS table_name, '
              'COUNT(*) AS row_count\nFROM ${quoteSqlIdentifier(entry.key)}',
        )
        .join('\nUNION ALL\n');
  }

  void _selectAllResultsRows() {
    final tab = widget.controller.activeTab;
    final current = _resultsStateFor(tab.id);
    final rows = resolveResultsRows(tab);
    setState(() {
      _resultsStateByTabId[tab.id] = current.copyWith(
        selectedRows: <int>{for (var i = 0; i < rows.length; i++) i},
        selectedCell: null,
      );
    });
    _resultsFocusNode.requestFocus();
  }

  String _findStatusLabel() {
    if (_findController.text.isEmpty) {
      return 'Type to search';
    }
    if (_findMatchCount == 0) {
      return 'No matches';
    }
    return '$_activeFindMatch of $_findMatchCount';
  }

  void _openFindBar() {
    final selection = _sqlController.selection;
    final selectedText = selection.isValid && !selection.isCollapsed
        ? selection.textInside(_sqlController.text)
        : '';
    setState(() {
      _showFindBar = true;
      if (_findController.text.isEmpty && selectedText.isNotEmpty) {
        _findController.text = selectedText;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _findFocusNode.requestFocus();
      _findController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _findController.text.length,
      );
    });
    if (_findController.text.isNotEmpty) {
      _findNext();
    }
  }

  void _hideFindBar() {
    setState(() {
      _showFindBar = false;
      _findMatchCount = 0;
      _activeFindMatch = 0;
    });
    _sqlFocusNode.requestFocus();
  }

  void _handleFindChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _findMatchCount = 0;
        _activeFindMatch = 0;
      });
      return;
    }
    _findNext(resetFromStart: true);
  }

  void _findNext({bool resetFromStart = false}) {
    final matches = _findMatches(_findController.text);
    if (matches.isEmpty) {
      setState(() {
        _findMatchCount = 0;
        _activeFindMatch = 0;
      });
      return;
    }

    final currentStart = resetFromStart || !_sqlController.selection.isValid
        ? -1
        : _sqlController.selection.start;
    var targetIndex = matches.indexWhere((match) => match.start > currentStart);
    if (targetIndex < 0) {
      targetIndex = 0;
    }
    _applyFindMatch(matches, targetIndex);
  }

  void _findPrevious() {
    final matches = _findMatches(_findController.text);
    if (matches.isEmpty) {
      setState(() {
        _findMatchCount = 0;
        _activeFindMatch = 0;
      });
      return;
    }

    final currentStart = _sqlController.selection.isValid
        ? _sqlController.selection.start
        : _sqlController.text.length + 1;
    var targetIndex = -1;
    for (var i = matches.length - 1; i >= 0; i--) {
      if (matches[i].start < currentStart) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex < 0) {
      targetIndex = matches.length - 1;
    }
    _applyFindMatch(matches, targetIndex);
  }

  List<_TextMatch> _findMatches(String pattern) {
    final query = pattern.trim().toLowerCase();
    if (query.isEmpty) {
      return const <_TextMatch>[];
    }
    final source = _sqlController.text.toLowerCase();
    final matches = <_TextMatch>[];
    var start = 0;
    while (true) {
      final index = source.indexOf(query, start);
      if (index < 0) {
        break;
      }
      matches.add(_TextMatch(index, index + query.length));
      start = index + math.max(query.length, 1);
    }
    return matches;
  }

  void _applyFindMatch(List<_TextMatch> matches, int index) {
    final match = matches[index];
    _sqlController.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    _sqlFocusNode.requestFocus();
    setState(() {
      _findMatchCount = matches.length;
      _activeFindMatch = index + 1;
    });
  }

  Future<void> _undoFocusedEdit() async {
    _focusedEditableField()?.undoController?.undo();
  }

  Future<void> _redoFocusedEdit() async {
    _focusedEditableField()?.undoController?.redo();
  }

  Future<void> _cutFocusedSelection() async {
    final field = _focusedEditableField();
    if (field == null) {
      return;
    }
    final selection = field.controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: selection.textInside(field.controller.text)),
    );
    final updated =
        selection.textBefore(field.controller.text) +
        selection.textAfter(field.controller.text);
    field.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: selection.start),
    );
    field.onChanged(updated);
  }

  Future<void> _copyFocusedSelection() async {
    if (_resultsFocusNode.hasFocus) {
      await _copyResultsSelection();
      return;
    }
    final field = _focusedEditableField();
    if (field == null) {
      return;
    }
    final selection = field.controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: selection.textInside(field.controller.text)),
    );
  }

  Future<void> _pasteIntoFocusedField() async {
    if (_resultsFocusNode.hasFocus) {
      final pasteText = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      final selectedCell = _resultsStateFor(
        widget.controller.activeTabId,
      ).selectedCell;
      if (pasteText == null || pasteText.isEmpty || selectedCell == null) {
        return;
      }
      await _commitSelectedResultsCellValue(
        rowIndex: selectedCell.rowIndex,
        columnName: selectedCell.columnName,
        value: pasteText,
      );
      return;
    }
    final field = _focusedEditableField();
    if (field == null) {
      return;
    }
    final pasteData = await Clipboard.getData(Clipboard.kTextPlain);
    final pasteText = pasteData?.text;
    if (pasteText == null || pasteText.isEmpty) {
      return;
    }
    final selection = field.controller.selection;
    final start = selection.isValid
        ? selection.start
        : field.controller.text.length;
    final end = selection.isValid
        ? selection.end
        : field.controller.text.length;
    final updated =
        field.controller.text.substring(0, start) +
        pasteText +
        field.controller.text.substring(end);
    final offset = start + pasteText.length;
    field.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: offset),
    );
    field.onChanged(updated);
  }

  Future<void> _selectAllFocusedSurface() async {
    if (_resultsFocusNode.hasFocus) {
      _selectAllResultsRows();
      return;
    }
    final field = _focusedEditableField();
    if (field == null) {
      return;
    }
    field.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: field.controller.text.length,
    );
  }

  Future<void> _copyResultsSelection() async {
    final tab = widget.controller.activeTab;
    final usePlaceholderContent = _usePlaceholderContent(widget.controller);
    final columns = resolveResultsColumns(
      tab,
      usePlaceholderContent: usePlaceholderContent,
    );
    final state = _resultsStateFor(tab.id);
    if (state.selectedCell != null && state.selectedCell!.rowIndex >= 0) {
      final cell = state.selectedCell!;
      await Clipboard.setData(
        ClipboardData(
          text: _formatResultCellValueForCopy(
            tab,
            cell.columnName,
            resolveResultsCellValue(
              tab,
              state,
              cell.rowIndex,
              cell.columnName,
              usePlaceholderContent: usePlaceholderContent,
            ),
          ),
        ),
      );
      return;
    }
    if (state.selectedRows.isEmpty) {
      return;
    }
    final buffer = StringBuffer()..writeln(columns.join('\t'));
    final sortedRows = state.selectedRows.toList()..sort();
    for (final rowIndex in sortedRows) {
      buffer.writeln(
        columns
            .map(
              (column) => _formatResultCellValueForCopy(
                tab,
                column,
                resolveResultsCellValue(
                  tab,
                  state,
                  rowIndex,
                  column,
                  usePlaceholderContent: usePlaceholderContent,
                ),
              ),
            )
            .join('\t'),
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
  }

  String _formatResultCellValueForCopy(
    QueryTabState tab,
    String columnName,
    Object? value,
  ) {
    final contract = tab.resultContractForColumn(columnName);
    return formatTypedCellValue(value, typeName: contract?.typeName);
  }

  Future<void> _copySelectedSpatialWkb({
    required int rowIndex,
    required String columnName,
  }) async {
    final tab = widget.controller.activeTab;
    final value = _resolveSelectedResultsCellValue(
      tab: tab,
      state: _resultsStateFor(tab.id),
      rowIndex: rowIndex,
      columnName: columnName,
    );
    await Clipboard.setData(ClipboardData(text: formatSpatialWkbBase64(value)));
  }

  Future<void> _copySelectedSpatialWkt({
    required int rowIndex,
    required String columnName,
  }) async {
    final tab = widget.controller.activeTab;
    final value = _resolveSelectedResultsCellValue(
      tab: tab,
      state: _resultsStateFor(tab.id),
      rowIndex: rowIndex,
      columnName: columnName,
    );
    final text = _formatSelectedSpatialTextValue(
      value: value,
      contractTypeName: tab.resultContractForColumn(columnName)?.typeName,
    );
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _copySelectedSpatialGeoJson({
    required int rowIndex,
    required String columnName,
  }) async {
    final tab = widget.controller.activeTab;
    final value = _resolveSelectedResultsCellValue(
      tab: tab,
      state: _resultsStateFor(tab.id),
      rowIndex: rowIndex,
      columnName: columnName,
    );
    final text = _formatSelectedSpatialTextValue(
      value: value,
      contractTypeName: tab.resultContractForColumn(columnName)?.typeName,
    );
    await Clipboard.setData(ClipboardData(text: text));
  }

  String _formatSelectedSpatialTextValue({
    required Object? value,
    required String? contractTypeName,
  }) {
    return value == null
        ? ''
        : formatTypedCellValue(value, typeName: contractTypeName);
  }

  Object? _resolveSelectedResultsCellValue({
    required QueryTabState tab,
    required ResultsGridInteractionState state,
    required int rowIndex,
    required String columnName,
  }) {
    return resolveResultsCellValue(
      tab,
      state,
      rowIndex,
      columnName,
      usePlaceholderContent: _usePlaceholderContent(widget.controller),
    );
  }

  _ResultsCellSpatialCopyProfile _selectedResultsCellSpatialCopyProfile({
    required int rowIndex,
    required String columnName,
  }) {
    final tab = widget.controller.activeTab;
    final state = _resultsStateFor(tab.id);
    final contract = tab.resultContractForColumn(columnName);
    if (contract?.nativeTypeDescriptor.isSpatial != true) {
      return const _ResultsCellSpatialCopyProfile();
    }
    final value = _resolveSelectedResultsCellValue(
      tab: tab,
      state: state,
      rowIndex: rowIndex,
      columnName: columnName,
    );
    if (value is! Uint8List && value is! String) {
      return const _ResultsCellSpatialCopyProfile(canCopyWkb: false);
    }
    if (value is String) {
      return _ResultsCellSpatialCopyProfile(
        canCopyWkt: _looksLikeSpatialWkt(value),
        canCopyGeoJson: _looksLikeSpatialGeoJson(value),
      );
    }

    return const _ResultsCellSpatialCopyProfile(canCopyWkb: true);
  }

  bool _looksLikeSpatialWkt(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('{')
        ? false
        : RegExp(r'^[A-Z][A-Z0-9_]*\s*\(').hasMatch(trimmed.toUpperCase());
  }

  bool _looksLikeSpatialGeoJson(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return false;
    }
    return trimmed.contains('"type"') && trimmed.contains('"coordinates"');
  }

  Future<void> _editSelectedResultsCell({
    required int rowIndex,
    required String columnName,
  }) async {
    final tab = widget.controller.activeTab;
    final currentValue = _resolveSelectedResultsCellValue(
      tab: tab,
      state: _resultsStateFor(tab.id),
      rowIndex: rowIndex,
      columnName: columnName,
    );
    final editorController = TextEditingController(
      text: currentValue?.toString() ?? '',
    );
    final nextValue = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $columnName'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: editorController,
              autofocus: true,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'Value'),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(editorController.text),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    editorController.dispose();
    if (nextValue == null) {
      return;
    }
    await _commitSelectedResultsCellValue(
      rowIndex: rowIndex,
      columnName: columnName,
      value: nextValue,
    );
  }

  Future<void> _commitSelectedResultsCellValue({
    required int rowIndex,
    required String columnName,
    required Object? value,
  }) async {
    final editability = widget.controller.tableEditabilityForTab(
      widget.controller.activeTabId,
    );
    if (!editability.canEditColumn(columnName)) {
      _setResultsCellError(
        rowIndex: rowIndex,
        columnName: columnName,
        message: editability.reason,
      );
      return;
    }
    if (!await _confirmDirectTableEdit(actionLabel: 'Apply edit')) {
      return;
    }
    _updateSelectedResultsCellValue(
      rowIndex: rowIndex,
      columnName: columnName,
      value: value,
    );
    final result = await widget.controller.updateResultCell(
      rowIndex: rowIndex,
      columnName: columnName,
      value: value,
      tabId: widget.controller.activeTabId,
    );
    if (!mounted) {
      return;
    }
    if (result.success) {
      _clearResultsCellOverride(rowIndex: rowIndex, columnName: columnName);
      return;
    }
    _setResultsCellError(
      rowIndex: rowIndex,
      columnName: columnName,
      message: result.message,
    );
  }

  Future<void> _deleteSelectedResultsRow({required int rowIndex}) async {
    if (!await _confirmDirectTableEdit(actionLabel: 'Delete row')) {
      return;
    }
    final tabId = widget.controller.activeTabId;
    final selectedCell = _resultsStateFor(tabId).selectedCell;
    final result = await widget.controller.deleteResultRow(
      rowIndex: rowIndex,
      tabId: tabId,
    );
    if (!mounted) {
      return;
    }
    if (result.success) {
      final current = _resultsStateFor(tabId);
      setState(() {
        _resultsStateByTabId[tabId] = current.copyWith(
          selectedRows: const <int>{},
          selectedCell: null,
          cellOverrides: <ResultsGridCellKey, Object?>{
            for (final entry in current.cellOverrides.entries)
              if (entry.key.rowIndex != rowIndex) entry.key: entry.value,
          },
          cellErrors: <ResultsGridCellKey, String>{
            for (final entry in current.cellErrors.entries)
              if (entry.key.rowIndex != rowIndex) entry.key: entry.value,
          },
        );
      });
      return;
    }
    final resultColumns = widget.controller.activeTab.resultColumns;
    final columnName =
        selectedCell?.columnName ??
        (resultColumns.isEmpty ? '' : resultColumns.first);
    if (columnName.isEmpty) {
      return;
    }
    _setResultsCellError(
      rowIndex: rowIndex,
      columnName: columnName,
      message: result.message,
    );
  }

  Future<void> _insertResultRow({
    required int anchorRowIndex,
    required String columnName,
  }) async {
    final editability = widget.controller.tableEditabilityForTab(
      widget.controller.activeTabId,
    );
    if (!editability.canInsertRows) {
      _setResultsCellError(
        rowIndex: anchorRowIndex,
        columnName: columnName,
        message: editability.reason,
      );
      return;
    }
    final values = await _showInsertRowDialog(editability);
    if (values == null) {
      return;
    }
    if (!await _confirmDirectTableEdit(actionLabel: 'Insert row')) {
      return;
    }
    final result = await widget.controller.insertResultRow(
      values: values,
      tabId: widget.controller.activeTabId,
    );
    if (!mounted) {
      return;
    }
    if (result.success) {
      return;
    }
    _setResultsCellError(
      rowIndex: anchorRowIndex,
      columnName: columnName,
      message: result.message,
    );
  }

  Future<Map<String, Object?>?> _showInsertRowDialog(
    TableEditabilityState editability,
  ) async {
    final controllers = <String, TextEditingController>{
      for (final sourceColumn in editability.insertableColumns.keys)
        sourceColumn: TextEditingController(),
    };
    final result = await showDialog<Map<String, Object?>?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Insert Row${editability.tableName == null ? '' : ' Into ${editability.tableName}'}',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final entry in controllers.entries) ...<Widget>[
                    TextField(
                      controller: entry.value,
                      decoration: InputDecoration(labelText: entry.key),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(<String, Object?>{
                  for (final entry in controllers.entries)
                    if (entry.value.text.trim().isNotEmpty)
                      entry.key: entry.value.text,
                });
              },
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<bool> _confirmDirectTableEdit({required String actionLabel}) async {
    if (widget.controller.canUseNativeBranchWorkflow) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apply table edit?'),
          content: Text(
            'This will run generated SQL directly against the current '
            'database because branch-safe editing is unavailable.\n\n'
            '${BranchController.nativeBranchApiUnavailableReason}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  void _updateSelectedResultsCellValue({
    required int rowIndex,
    required String columnName,
    required Object? value,
  }) {
    final tabId = widget.controller.activeTabId;
    final current = _resultsStateFor(tabId);
    final nextOverrides = Map<ResultsGridCellKey, Object?>.from(
      current.cellOverrides,
    )..[ResultsGridCellKey(rowIndex: rowIndex, columnName: columnName)] = value;
    final nextErrors = Map<ResultsGridCellKey, String>.from(current.cellErrors)
      ..remove(ResultsGridCellKey(rowIndex: rowIndex, columnName: columnName));
    setState(() {
      _resultsStateByTabId[tabId] = current.copyWith(
        selectedRows: <int>{rowIndex},
        selectedCell: ResultsGridCellSelection(
          rowIndex: rowIndex,
          columnName: columnName,
        ),
        cellOverrides: nextOverrides,
        cellErrors: nextErrors,
      );
    });
    _resultsFocusNode.requestFocus();
  }

  void _clearResultsCellOverride({
    required int rowIndex,
    required String columnName,
  }) {
    final tabId = widget.controller.activeTabId;
    final current = _resultsStateFor(tabId);
    final key = ResultsGridCellKey(rowIndex: rowIndex, columnName: columnName);
    final nextOverrides = Map<ResultsGridCellKey, Object?>.from(
      current.cellOverrides,
    )..remove(key);
    final nextErrors = Map<ResultsGridCellKey, String>.from(current.cellErrors)
      ..remove(key);
    setState(() {
      _resultsStateByTabId[tabId] = current.copyWith(
        selectedRows: <int>{rowIndex},
        selectedCell: ResultsGridCellSelection(
          rowIndex: rowIndex,
          columnName: columnName,
        ),
        cellOverrides: nextOverrides,
        cellErrors: nextErrors,
      );
    });
    _resultsFocusNode.requestFocus();
  }

  void _setResultsCellError({
    required int rowIndex,
    required String columnName,
    required String message,
  }) {
    final tabId = widget.controller.activeTabId;
    final current = _resultsStateFor(tabId);
    final key = ResultsGridCellKey(rowIndex: rowIndex, columnName: columnName);
    final nextErrors = Map<ResultsGridCellKey, String>.from(current.cellErrors)
      ..[key] = message;
    setState(() {
      _resultsStateByTabId[tabId] = current.copyWith(
        selectedRows: <int>{rowIndex},
        selectedCell: ResultsGridCellSelection(
          rowIndex: rowIndex,
          columnName: columnName,
        ),
        cellErrors: nextErrors,
      );
    });
    _resultsFocusNode.requestFocus();
  }

  bool _isSelectedResultsCellNullable({
    required int rowIndex,
    required String columnName,
  }) {
    final tab = widget.controller.activeTab;
    final sql = (tab.lastSql ?? tab.sql).trim();
    final objectName = _firstObjectNameInFromClause(sql);
    if (objectName == null) {
      return false;
    }
    final object = widget.controller.schema.objectNamed(objectName);
    if (object == null || rowIndex < 0) {
      return false;
    }
    for (final column in object.columns) {
      if (column.name == columnName) {
        return !column.notNull;
      }
    }
    return false;
  }

  String? _firstObjectNameInFromClause(String sql) {
    final quotedMatch = RegExp(
      r'\bFROM\s+"((?:[^"]|"")+)"',
      caseSensitive: false,
    ).firstMatch(sql);
    if (quotedMatch != null) {
      return quotedMatch.group(1)?.replaceAll('""', '"');
    }
    final bareMatch = RegExp(
      r'\bFROM\s+([A-Za-z_][A-Za-z0-9_]*)',
      caseSensitive: false,
    ).firstMatch(sql);
    return bareMatch?.group(1);
  }

  _EditableFieldBinding? _focusedEditableField() {
    final controller = widget.controller;
    final bindings = <_EditableFieldBinding>[
      _EditableFieldBinding(
        controller: _findController,
        focusNode: _findFocusNode,
        undoController: null,
        onChanged: _handleFindChanged,
      ),
      _EditableFieldBinding(
        controller: _sqlController,
        focusNode: _sqlFocusNode,
        undoController: _sqlUndoController,
        onChanged: controller.updateActiveSql,
      ),
      _EditableFieldBinding(
        controller: _paramsController,
        focusNode: _paramsFocusNode,
        undoController: _paramsUndoController,
        onChanged: controller.updateActiveParameterJson,
      ),
    ];
    for (final binding in bindings) {
      if (binding.focusNode.hasFocus) {
        return binding;
      }
    }
    return null;
  }

  Widget _wrapInMenuHost(
    MenuCommandRegistry registry,
    List<String> recentFiles,
    Widget child,
  ) {
    if (!_nativeMenuAvailable) {
      return child;
    }
    return NativeAppMenuHost(
      registry: registry,
      recentFiles: recentFiles,
      onOpenRecent: _openRecentWorkspace,
      child: child,
    );
  }

  MenuCommandRegistry _buildMenuCommandRegistry(
    WorkspaceController controller,
    Map<String, ShortcutBinding> shortcuts,
  ) {
    MenuCommand command({
      required String id,
      required String label,
      required IconData icon,
      required Future<void> Function() onInvoke,
      bool enabled = true,
      bool checked = false,
    }) {
      return MenuCommand(
        id: id,
        label: label,
        icon: icon,
        enabled: enabled,
        checked: checked,
        shortcut: shortcuts[id],
        onInvoke: onInvoke,
      );
    }

    final prefs = _shellController.preferences;
    return MenuCommandRegistry(
      commands: <MenuCommand>[
        command(
          id: 'file_new',
          label: 'New',
          icon: Icons.note_add_outlined,
          onInvoke: _createNewWorkspace,
        ),
        command(
          id: 'file_open',
          label: 'Open...',
          icon: Icons.folder_open_outlined,
          onInvoke: _openWorkspace,
        ),
        command(
          id: 'file_open_project',
          label: 'Open Project...',
          icon: Icons.folder_special_outlined,
          onInvoke: _openWorkspaceProject,
        ),
        command(
          id: 'file_save',
          label: 'Save',
          icon: Icons.save_outlined,
          onInvoke: widget.controller.saveWorkspace,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'file_save_as',
          label: 'Save As...',
          icon: Icons.save_as_outlined,
          onInvoke: _saveWorkspaceAs,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'file_export_project',
          label: 'Export Project...',
          icon: Icons.drive_folder_upload_outlined,
          onInvoke: _exportWorkspaceProject,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'file_close',
          label: 'Close',
          icon: Icons.close_outlined,
          onInvoke: widget.controller.closeWorkspace,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'file_exit',
          label: 'Exit',
          icon: Icons.power_settings_new_outlined,
          onInvoke: widget.appLifecycleService.requestExit,
        ),
        command(
          id: 'edit_undo',
          label: 'Undo',
          icon: Icons.undo_outlined,
          onInvoke: _undoFocusedEdit,
        ),
        command(
          id: 'edit_redo',
          label: 'Redo',
          icon: Icons.redo_outlined,
          onInvoke: _redoFocusedEdit,
        ),
        command(
          id: 'edit_cut',
          label: 'Cut',
          icon: Icons.content_cut_outlined,
          onInvoke: _cutFocusedSelection,
        ),
        command(
          id: 'edit_copy',
          label: 'Copy',
          icon: Icons.copy_outlined,
          onInvoke: _copyFocusedSelection,
        ),
        command(
          id: 'edit_paste',
          label: 'Paste',
          icon: Icons.content_paste_outlined,
          onInvoke: _pasteIntoFocusedField,
        ),
        command(
          id: 'edit_find',
          label: 'Find',
          icon: Icons.search_outlined,
          onInvoke: () async {
            _openFindBar();
          },
        ),
        command(
          id: 'edit_find_next',
          label: 'Find Next',
          icon: Icons.find_replace_outlined,
          onInvoke: () async {
            if (!_showFindBar) {
              _openFindBar();
            } else {
              _findNext();
            }
          },
        ),
        command(
          id: 'edit_select_all',
          label: 'Select All',
          icon: Icons.select_all_outlined,
          onInvoke: _selectAllFocusedSurface,
        ),
        command(
          id: 'import_excel',
          label: 'Import Excel...',
          icon: Icons.table_chart_outlined,
          onInvoke: _showExcelImportDialog,
        ),
        command(
          id: 'import_sqlite',
          label: 'Import SQLite...',
          icon: Icons.storage_outlined,
          onInvoke: _showSqliteImportDialog,
        ),
        command(
          id: 'import_sql_dump',
          label: 'Import SQL Dump...',
          icon: Icons.description_outlined,
          onInvoke: _showSqlDumpImportDialog,
        ),
        command(
          id: 'import_clipboard_table',
          label: 'Import Clipboard Table...',
          icon: Icons.content_paste_outlined,
          onInvoke: _startClipboardTableImport,
        ),
        command(
          id: 'import_from_database',
          label: 'Import From Database...',
          icon: Icons.cloud_sync_outlined,
          onInvoke: () async {},
          enabled: false,
        ),
        command(
          id: 'import_rerun_last',
          label: 'Re-run Last Import',
          icon: Icons.restart_alt_outlined,
          onInvoke: () async {},
          enabled: false,
        ),
        command(
          id: 'import_open_wizard',
          label: 'Open Import Wizard...',
          icon: Icons.file_open_outlined,
          onInvoke: _showImportChooser,
        ),
        command(
          id: 'export_results_csv',
          label: 'Export Results as CSV...',
          icon: Icons.file_download_outlined,
          onInvoke: _showCsvExportDialog,
          enabled: controller.activeTab.canExport,
        ),
        command(
          id: 'export_results_json',
          label: 'Export Results as JSON...',
          icon: Icons.data_object_outlined,
          onInvoke: _showJsonExportDialog,
          enabled: controller.activeTab.canExport,
        ),
        command(
          id: 'export_results_parquet',
          label: 'Export Results as Parquet...',
          icon: Icons.view_column_outlined,
          onInvoke: _showParquetExportUnavailableDialog,
          enabled: false,
        ),
        command(
          id: 'export_results_excel',
          label: 'Export Results as Excel...',
          icon: Icons.table_view_outlined,
          onInvoke: _showExcelExportDialog,
          enabled: controller.activeTab.canExport,
        ),
        command(
          id: 'export_table',
          label: 'Export Table...',
          icon: Icons.table_rows_outlined,
          onInvoke: _showExportTableDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'export_schema',
          label: 'Export Schema...',
          icon: Icons.schema_outlined,
          onInvoke: _showExportSchemaDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'export_rerun_last',
          label: 'Re-run Last Export',
          icon: Icons.replay_outlined,
          onInvoke: () async {},
          enabled: false,
        ),
        command(
          id: 'view_reset_layout',
          label: 'Reset Layout',
          icon: Icons.space_dashboard_outlined,
          onInvoke: () async => _shellController.resetLayout(),
        ),
        command(
          id: 'view_toggle_schema',
          label: 'Show/Hide Schema Explorer',
          icon: Icons.account_tree_outlined,
          checked: prefs.showSchemaExplorer,
          onInvoke: () async => _shellController.setSchemaExplorerVisible(
            !prefs.showSchemaExplorer,
          ),
        ),
        command(
          id: 'view_toggle_properties',
          label: 'Show/Hide Properties',
          icon: Icons.info_outline,
          checked: prefs.showPropertiesPane,
          onInvoke: () async => _shellController.setPropertiesPaneVisible(
            !prefs.showPropertiesPane,
          ),
        ),
        command(
          id: 'view_toggle_results',
          label: 'Show/Hide Results',
          icon: Icons.table_view_outlined,
          checked: prefs.showResultsPane,
          onInvoke: () async =>
              _shellController.setResultsPaneVisible(!prefs.showResultsPane),
        ),
        command(
          id: 'view_toggle_status_bar',
          label: 'Show/Hide Status Bar',
          icon: Icons.horizontal_rule_outlined,
          checked: prefs.showStatusBar,
          onInvoke: () async =>
              _shellController.setStatusBarVisible(!prefs.showStatusBar),
        ),
        command(
          id: 'view_command_palette',
          label: 'Command Palette...',
          icon: Icons.search_outlined,
          onInvoke: () async {
            setState(() => _showCommandPalette = !_showCommandPalette);
          },
        ),
        command(
          id: 'view_zoom_in',
          label: 'Zoom In',
          icon: Icons.zoom_in_outlined,
          onInvoke: () async => _shellController.zoomIn(),
        ),
        command(
          id: 'view_zoom_out',
          label: 'Zoom Out',
          icon: Icons.zoom_out_outlined,
          onInvoke: () async => _shellController.zoomOut(),
        ),
        command(
          id: 'view_zoom_reset',
          label: 'Reset Zoom',
          icon: Icons.center_focus_strong_outlined,
          onInvoke: () async => _shellController.resetZoom(),
        ),
        command(
          id: 'tools_run_query',
          label: _sqlExecutionTarget().runLabel,
          icon: Icons.play_arrow_outlined,
          onInvoke: _runPrimarySqlTarget,
          enabled: controller.canRunActiveTab,
        ),
        command(
          id: 'tools_run_buffer',
          label: 'Run Buffer',
          icon: Icons.subject_outlined,
          onInvoke: _runEntireSqlBuffer,
          enabled: controller.canRunActiveTab,
        ),
        command(
          id: 'tools_stop_query',
          label: 'Stop Query',
          icon: Icons.stop_circle_outlined,
          onInvoke: controller.cancelActiveQuery,
          enabled: controller.canCancelActiveTab,
        ),
        command(
          id: 'tools_format_sql',
          label: _sqlSelectionInfo().hasRunnableSelection
              ? 'Format Selection'
              : 'Format SQL',
          icon: Icons.auto_fix_high_outlined,
          onInvoke: () async => _formatActiveSql(),
        ),
        command(
          id: 'tools_new_query_tab',
          label: 'New Query Tab',
          icon: Icons.add_box_outlined,
          onInvoke: () async => controller.createTab(),
        ),
        command(
          id: 'tools_entity_relationship_diagram',
          label: 'Entity Relationship Diagram',
          icon: Icons.account_tree_outlined,
          onInvoke: _showEntityRelationshipDiagram,
        ),
        command(
          id: 'tools_export_erd_image',
          label: 'Export ERD Image...',
          icon: Icons.image_outlined,
          onInvoke: _exportErdImageFromCommand,
          enabled: _navigationPaneMode == _NavigationPaneMode.erd,
        ),
        command(
          id: 'tools_saved_queries',
          label: 'Saved Queries',
          icon: Icons.bookmarks_outlined,
          onInvoke: _showSavedQueriesDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_data_quality_dashboard',
          label: 'Data Quality Dashboard',
          icon: Icons.fact_check_outlined,
          onInvoke: _showQualityDashboard,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_run_quality_profile',
          label: 'Run Quality Profile',
          icon: Icons.play_circle_outline,
          onInvoke: () async => controller.dataQuality.startRun(),
          enabled:
              controller.hasOpenDatabase && !controller.dataQuality.isRunning,
        ),
        command(
          id: 'tools_manage_quality_profiles',
          label: 'Manage Quality Profiles',
          icon: Icons.rule_folder_outlined,
          onInvoke: _showQualityProfileManagerDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_export_quality_report',
          label: 'Export Quality Report...',
          icon: Icons.ios_share_outlined,
          onInvoke: _showQualityReportExportDialog,
          enabled:
              controller.hasOpenDatabase &&
              controller.dataQuality.currentRun != null,
        ),
        command(
          id: 'tools_query_history',
          label: 'Query History',
          icon: Icons.history_outlined,
          onInvoke: _showQueryHistoryDialog,
        ),
        command(
          id: 'tools_database_statistics',
          label: 'Database Statistics',
          icon: Icons.monitor_heart_outlined,
          onInvoke: _showDatabaseStatisticsDashboard,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_database_doctor',
          label: 'Database Doctor',
          icon: Icons.medical_services_outlined,
          onInvoke: _showDatabaseDoctorDashboard,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_open_web_console',
          label: 'Open Web Console',
          icon: Icons.open_in_browser_outlined,
          onInvoke: _openWebConsole,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_branch_workbench',
          label: 'Branch & Snapshots',
          icon: Icons.account_tree_outlined,
          onInvoke: _showBranchSnapshotWorkbench,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_create_snapshot',
          label: 'Create Snapshot...',
          icon: Icons.camera_alt_outlined,
          onInvoke: _showCreateSnapshotDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_create_branch',
          label: 'Create Branch...',
          icon: Icons.call_split_outlined,
          onInvoke: _showCreateBranchDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_branch_diff',
          label: 'Branch Diff...',
          icon: Icons.compare_arrows_outlined,
          onInvoke: _showBranchDiffDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_restore_branch',
          label: 'Restore Branch...',
          icon: Icons.restore_outlined,
          onInvoke: _showRestoreBranchDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_merge_branch',
          label: 'Merge Branch...',
          icon: Icons.merge_type,
          onInvoke: _showMergeBranchDialog,
          enabled: controller.hasOpenDatabase,
        ),
        command(
          id: 'tools_view_log',
          label: 'View Logs',
          icon: Icons.receipt_long_outlined,
          onInvoke: () => LogViewerDialog.show(
            context,
            logDirectoryPath: controller.logDirectoryPath,
          ),
        ),
        command(
          id: 'tools_snippets',
          label: 'Manage Snippets',
          icon: Icons.library_books_outlined,
          onInvoke: () => _showPreferencesDialog(
            initialSection: PreferencesDialogSection.snippets,
          ),
        ),
        command(
          id: 'tools_manage_connections',
          label: 'Manage Connections',
          icon: Icons.settings_ethernet_outlined,
          onInvoke: () async {},
          enabled: false,
        ),
        command(
          id: 'tools_options',
          label: 'Options / Preferences',
          icon: Icons.tune_outlined,
          onInvoke: _showPreferencesDialog,
        ),
        command(
          id: 'help_docs',
          label: 'Documentation',
          icon: Icons.menu_book_outlined,
          onInvoke: _showDocumentationDialog,
        ),
        command(
          id: 'help_keyboard_shortcuts',
          label: 'Keyboard Shortcuts',
          icon: Icons.keyboard_outlined,
          onInvoke: () => _showShortcutDialog(shortcuts),
        ),
        command(
          id: 'help_about',
          label: 'About Decent Bench',
          icon: Icons.info_outline,
          onInvoke: _showAboutDialog,
        ),
      ],
    );
  }

  Future<void> _createNewWorkspace() async {
    final result = await getSaveLocation(
      suggestedName: 'workspace.ddb',
      acceptedTypeGroups: const <XTypeGroup>[_decentDbTypeGroup],
    );
    if (result == null) {
      return;
    }
    await widget.controller.openDatabase(result.path, createIfMissing: true);
  }

  Future<void> _openWorkspace() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_decentDbTypeGroup],
    );
    if (file == null) {
      return;
    }
    await _openDatabaseWithMigrationOffer(file.path);
  }

  Future<void> _saveWorkspaceAs() async {
    final currentPath = widget.controller.databasePath;
    if (currentPath == null) {
      return;
    }

    final defaultDirectory = p.dirname(currentPath);
    final result = await getSaveLocation(
      suggestedName: p.basename(currentPath),
      initialDirectory: defaultDirectory,
      acceptedTypeGroups: const <XTypeGroup>[_decentDbTypeGroup],
    );
    if (result == null) {
      return;
    }
    await widget.controller.saveWorkspaceAs(result.path);
  }

  Future<void> _openDatabaseWithMigrationOffer(
    String path, {
    bool allowMigrationOffer = true,
  }) async {
    await widget.controller.openDatabase(path, createIfMissing: false);
    if (!mounted || !allowMigrationOffer) {
      return;
    }
    final openError = widget.controller.workspaceError;
    if (!DecentDbMigrationService.isUnsupportedFormatVersionMessage(
      openError,
    )) {
      return;
    }
    await _showLegacyDatabaseMigrationOffer(
      sourcePath: path,
      openError: openError ?? 'Unsupported database format version.',
    );
  }

  Future<void> _showLegacyDatabaseMigrationOffer({
    required String sourcePath,
    required String openError,
  }) async {
    if (!mounted) {
      return;
    }
    final backupPath = DecentDbMigrationService.backupPathFor(sourcePath);
    final proceed = await DecentDbInPlaceMigrationDialog.show(
      context: context,
      sourcePath: sourcePath,
      backupPath: backupPath,
      openError: openError,
    );
    if (!proceed || !mounted) {
      return;
    }
    final inPlaceResult = await _showInPlaceMigrationProgressDialog(
      sourcePath: sourcePath,
    );
    if (inPlaceResult == null || !mounted) {
      return;
    }
    await _openDatabaseWithMigrationOffer(
      inPlaceResult.finalPath,
      allowMigrationOffer: false,
    );
  }

  Future<DecentDbInPlaceMigrationResult?>
      _showInPlaceMigrationProgressDialog({
    required String sourcePath,
  }) {
    final migrationFuture = _migrationService.migrateInPlace(
      sourcePath: sourcePath,
    );
    return showDialog<DecentDbInPlaceMigrationResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<DecentDbInPlaceMigrationResult>(
          future: migrationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return AlertDialog(
                title: const Text('Upgrading DecentDB file'),
                content: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Database: ${p.basename(sourcePath)}'),
                      const Text(
                        'Migrating to the current format in place…',
                      ),
                    ],
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Upgrade failed'),
                content: SizedBox(
                  width: 560,
                  child: SelectableText(snapshot.error.toString()),
                ),
                actions: <Widget>[
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }
            final result = snapshot.data;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop(result);
              }
            });
            return AlertDialog(
              title: const Text('Upgrading DecentDB file'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Database: ${p.basename(sourcePath)}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openWorkspaceProject() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_projectTypeGroup],
    );
    if (file == null) {
      return;
    }
    await widget.controller.openWorkspaceProject(file.path);
  }

  Future<void> _exportWorkspaceProject() async {
    final result = await getSaveLocation(
      suggestedName: '.dbench-project.toml',
      acceptedTypeGroups: const <XTypeGroup>[_projectTypeGroup],
    );
    if (result == null) {
      return;
    }
    await widget.controller.exportWorkspaceProject(result.path);
  }

  Future<void> _openRecentWorkspace(String path) async {
    await _openDatabaseWithMigrationOffer(path);
  }

  Future<void> _showSqliteImportDialog({String sourcePath = ''}) async {
    final controller = widget.controller;
    if (!controller.hasSqliteImportSession || sourcePath.trim().isNotEmpty) {
      controller.beginSqliteImport(sourcePath: sourcePath);
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SqliteImportDialog(controller: controller),
    );
    if (!mounted) {
      return;
    }
    controller.closeSqliteImportSession();
  }

  Future<void> _showExcelImportDialog({String sourcePath = ''}) async {
    final controller = widget.controller;
    if (!controller.hasExcelImportSession || sourcePath.trim().isNotEmpty) {
      controller.beginExcelImport(sourcePath: sourcePath);
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExcelImportDialog(controller: controller),
    );
    if (!mounted) {
      return;
    }
    controller.closeExcelImportSession();
  }

  Future<void> _showSqlDumpImportDialog({String sourcePath = ''}) async {
    final controller = widget.controller;
    if (!controller.hasSqlDumpImportSession || sourcePath.trim().isNotEmpty) {
      controller.beginSqlDumpImport(sourcePath: sourcePath);
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SqlDumpImportDialog(controller: controller),
    );
    if (!mounted) {
      return;
    }
    controller.closeSqlDumpImportSession();
  }

  Future<void> _showMsSqlBakImportDialog({String sourcePath = ''}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MsSqlBakImportDialog(
        controller: widget.controller,
        sourcePath: sourcePath,
      ),
    );
  }

  Future<void> _showGenericImportDialog({
    required String sourcePath,
    required ImportFormatDefinition format,
  }) async {
    setState(() {
      _genericImportOpen = true;
    });
    final result = await showDialog<GenericImportDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GenericImportDialog(
        initialSourcePath: sourcePath,
        initialFormat: format,
        logger: widget.controller.logger,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _genericImportOpen = false;
    });
    if (result != null) {
      if (!result.summary.rolledBack) {
        await widget.controller.dataQuality.recordImportReconciliation(
          _genericImportReconciliation(result.summary),
          targetDatabasePath: result.targetPath,
        );
      }
      await widget.controller.openDatabase(
        result.targetPath,
        createIfMissing: false,
      );
      if (result.runQualityAfterImport) {
        widget.controller.dataQuality.selectTable(null);
        await widget.controller.dataQuality.startRun();
        if (mounted) {
          setState(() {
            _navigationPaneMode = _NavigationPaneMode.quality;
          });
        }
      }
    }
  }

  Future<void> _showImportChooser() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_importSourceTypeGroup()],
    );
    if (file == null) {
      return;
    }
    await _startImportFromPath(file.path);
  }

  Future<void> _startClipboardTableImport() async {
    final clipboardText = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final text = clipboardText ?? '';
    if (text.trim().isEmpty) {
      await _showPlaceholderNotice(
        'Clipboard is empty',
        'Copy a TSV, CSV, Markdown pipe table, or HTML table before starting clipboard import.',
      );
      return;
    }
    const maxClipboardCharacters = 5 * 1024 * 1024;
    if (text.length > maxClipboardCharacters) {
      await _showPlaceholderNotice(
        'Clipboard table is too large',
        'Clipboard import is limited to 5 MiB of text in this build. Save the source as a file and import it from disk.',
      );
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp(
      'decent-bench-clipboard-',
    );
    final detected = _clipboardImportPayload(text);
    final file = File(p.join(tempDir.path, detected.fileName))
      ..writeAsStringSync(detected.text, flush: true);
    await _startImportFromPath(file.path);
  }

  ImportReconciliationSummary _genericImportReconciliation(
    GenericImportSummary summary,
  ) {
    final warningsByCode = <String, int>{};
    for (final warning in summary.warnings) {
      final code = normalizeImportWarningCode(warning);
      warningsByCode[code] = (warningsByCode[code] ?? 0) + 1;
    }
    return ImportReconciliationSummary(
      importJobId: summary.jobId,
      sourcePathDisplay: summary.sourcePath,
      sourceFormat: summary.formatLabel,
      sourceFingerprint: null,
      startedAt: null,
      completedAt: DateTime.now().toUtc(),
      tableMappings: <ImportTableReconciliation>[
        for (final entry in summary.rowsCopiedByTable.entries)
          ImportTableReconciliation(
            sourceName: entry.key,
            targetTable: entry.key,
            sourceRowCount: null,
            importedRowCount: entry.value,
            skippedRowCount: 0,
            rejectedRowCount: 0,
            transformedRowCount: 0,
            typeCoercionFailureCount:
                warningsByCode['type_coercion_failed'] ?? 0,
            warningCount: summary.warnings.length,
          ),
      ],
      warningCount: summary.warnings.length,
      warningsByTable: <String, int>{
        for (final table in summary.importedTables)
          table: summary.warnings.length,
      },
      warningsByCode: warningsByCode,
    );
  }

  Future<void> _handleStartupLaunchOptions(
    StartupLaunchOptions launchOptions,
  ) async {
    await applyStartupLaunchOptions(
      launchOptions,
      showNotice: _showPlaceholderNotice,
      openDatabase: (path) {
        return _openDatabaseWithMigrationOffer(path);
      },
      startImport: _startImportFromPath,
    );
  }

  Future<void> _startImportFromPath(String path) async {
    final detection = await _importManager.detectSource(path);
    switch (detection.format.implementationKind) {
      case ImportImplementationKind.directOpen:
        await _openDatabaseWithMigrationOffer(path);
        break;
      case ImportImplementationKind.legacyWizard:
        switch (detection.format.key) {
          case ImportFormatKey.sqlite:
            await _showSqliteImportDialog(sourcePath: path);
            break;
          case ImportFormatKey.xlsx:
          case ImportFormatKey.xls:
            await _showExcelImportDialog(sourcePath: path);
            break;
          case ImportFormatKey.sqlDump:
            await _showSqlDumpImportDialog(sourcePath: path);
            break;
          case ImportFormatKey.msSqlBak:
            await _showMsSqlBakImportDialog(sourcePath: path);
            break;
          default:
            await _showPlaceholderNotice(
              'Import unavailable',
              '${detection.format.label} is detected but still uses a wizard path that is not wired here yet.',
            );
            break;
        }
        break;
      case ImportImplementationKind.genericWizard:
        await _showGenericImportDialog(
          sourcePath: path,
          format: detection.format,
        );
        break;
      case ImportImplementationKind.wrapper:
        await _handleArchiveImport(detection);
        break;
      case ImportImplementationKind.recognizedUnsupported:
        final module = _importManager.moduleForDetection(detection);
        final note = _moduleLimitationsText(module.limitations);
        await _showPlaceholderNotice(
          '${detection.format.label} not available yet',
          'Decent Bench recognizes this format as `${detection.format.supportState.name}`, but it is not implemented in this build yet.$note',
        );
        break;
      case ImportImplementationKind.unknown:
        await _showPlaceholderNotice(
          'Unknown file type',
          'Supported import sources currently include ${_supportedImportExtensionSummary()}.',
        );
        break;
    }
  }

  XTypeGroup _importSourceTypeGroup() {
    return XTypeGroup(
      label: 'Import sources',
      extensions: _importManager.registry
          .implementedExtensions()
          .map(_fileSelectorExtension)
          .where((extension) => extension.isNotEmpty)
          .toList(growable: false),
    );
  }

  String _supportedImportExtensionSummary() {
    final extensions = _importManager.registry.implementedExtensions();
    final display = <String>[
      for (final extension in extensions)
        if (!extension.contains('.tar.')) '`$extension`',
    ];
    final compound = <String>[
      for (final extension in extensions)
        if (extension.contains('.tar.')) '`$extension`',
    ];
    if (compound.isNotEmpty) {
      display.add('including ${compound.join(' and ')} archives');
    }
    if (display.length <= 1) {
      return display.join();
    }
    return '${display.take(display.length - 1).join(', ')}, and ${display.last}';
  }

  String _moduleLimitationsText(List<ImportModuleLimitation> limitations) {
    if (limitations.isEmpty) {
      return '';
    }
    return '\n\n${limitations.map((limitation) => limitation.message).join('\n')}';
  }

  String _fileSelectorExtension(String extension) {
    return extension.startsWith('.') ? extension.substring(1) : extension;
  }

  _ClipboardImportPayload _clipboardImportPayload(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('<table')) {
      return _ClipboardImportPayload(
        fileName: 'clipboard_table.html',
        text: _sanitizeClipboardHtml(text),
      );
    }
    if (_looksLikeMarkdownClipboardTable(text)) {
      return _ClipboardImportPayload(
        fileName: 'clipboard_table.md',
        text: text,
      );
    }
    if (text.contains('\t')) {
      return _ClipboardImportPayload(
        fileName: 'clipboard_table.tsv',
        text: text,
      );
    }
    return _ClipboardImportPayload(fileName: 'clipboard_table.csv', text: text);
  }

  bool _looksLikeMarkdownClipboardTable(String text) {
    final lines = const LineSplitter()
        .convert(text)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    for (var index = 0; index + 1 < lines.length; index++) {
      if (!lines[index].contains('|')) {
        continue;
      }
      final separatorCells = lines[index + 1]
          .split('|')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList(growable: false);
      if (separatorCells.isNotEmpty &&
          separatorCells.every(
            (cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell),
          )) {
        return true;
      }
    }
    return false;
  }

  String _sanitizeClipboardHtml(String text) {
    return text
        .replaceAll(
          RegExp(
            r'<script\b[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'<style\b[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'''\son[a-z]+\s*=\s*("[^"]*"|'[^']*')''',
            caseSensitive: false,
          ),
          '',
        );
  }

  Future<void> _showCsvExportDialog() async {
    final controller = widget.controller;
    final activeTab = controller.activeTab;
    final result = await showDialog<CsvExportDialogResult>(
      context: context,
      builder: (context) {
        return CsvExportDialog(
          queryTitle: activeTab.title,
          initialPath: activeTab.exportPath.trim().isEmpty
              ? controller.suggestExportPath()
              : activeTab.exportPath.trim(),
          initialDelimiter: controller.config.csvDelimiter,
          initialIncludeHeaders: controller.config.csvIncludeHeaders,
          onBrowse: (currentPath) async {
            final initialName = currentPath.trim().isEmpty
                ? p.basename(controller.suggestExportPath())
                : p.basename(currentPath.trim());
            final location = await getSaveLocation(
              suggestedName: initialName,
              acceptedTypeGroups: const <XTypeGroup>[_csvTypeGroup],
            );
            return location?.path;
          },
        );
      },
    );
    if (result == null) {
      return;
    }

    controller.updateActiveExportPath(result.path);
    await controller.updateCsvDelimiter(result.delimiter);
    await controller.updateCsvIncludeHeaders(result.includeHeaders);
    await controller.exportCurrentQuery();
  }

  Future<void> _showJsonExportDialog() async {
    final controller = widget.controller;
    final activeTab = controller.activeTab;
    final result = await showDialog<JsonExportDialogResult>(
      context: context,
      builder: (context) {
        final currentPath = activeTab.exportPath.trim();
        final suggestedPath = currentPath.isEmpty
            ? controller.suggestExportPath().replaceAll(
                RegExp(r'\.csv$', caseSensitive: false),
                '.json',
              )
            : currentPath.replaceAll(
                RegExp(r'\.(csv|jsonl|ndjson)$', caseSensitive: false),
                '.json',
              );
        return JsonExportDialog(
          queryTitle: activeTab.title,
          initialPath: suggestedPath,
          onBrowse: (currentPath) async {
            final initialName = currentPath.trim().isEmpty
                ? p.basename(suggestedPath)
                : p.basename(currentPath.trim());
            final location = await getSaveLocation(
              suggestedName: initialName,
              acceptedTypeGroups: const <XTypeGroup>[_jsonTypeGroup],
            );
            return location?.path;
          },
        );
      },
    );
    if (result == null) {
      return;
    }

    controller.updateActiveExportPath(result.path);
    await controller.exportCurrentQueryAsJson(
      path: result.path,
      format: result.format,
      pretty: result.pretty,
      includeMetadata: result.includeMetadata,
    );
  }

  Future<void> _showExcelExportDialog() async {
    final controller = widget.controller;
    final activeTab = controller.activeTab;
    final result = await showDialog<ExcelExportDialogResult>(
      context: context,
      builder: (context) {
        final currentPath = activeTab.exportPath.trim();
        final suggestedPath = currentPath.isEmpty
            ? controller.suggestExportPath().replaceAll(
                RegExp(r'\.csv$', caseSensitive: false),
                '.xlsx',
              )
            : currentPath.replaceAll(
                RegExp(
                  r'\.(csv|json|jsonl|ndjson|xlsx)$',
                  caseSensitive: false,
                ),
                '.xlsx',
              );
        return ExcelExportDialog(
          queryTitle: activeTab.title,
          initialPath: suggestedPath,
          initialIncludeHeaders: controller.config.csvIncludeHeaders,
          onBrowse: (currentPath) async {
            final initialName = currentPath.trim().isEmpty
                ? p.basename(suggestedPath)
                : p.basename(currentPath.trim());
            final location = await getSaveLocation(
              suggestedName: initialName,
              acceptedTypeGroups: const <XTypeGroup>[_excelExportTypeGroup],
            );
            return location?.path;
          },
        );
      },
    );
    if (result == null) {
      return;
    }

    controller.updateActiveExportPath(result.path);
    await controller.exportCurrentQueryAsExcel(
      path: result.path,
      includeHeaders: result.includeHeaders,
    );
  }

  Future<void> _showExportTableDialog() async {
    final controller = widget.controller;
    final tableName = _selectedTableNameForExport(controller);
    if (tableName == null) {
      await _showInfoDialog(
        'Export Table',
        'Select a table in the schema explorer before exporting table data.',
      );
      return;
    }
    final previousTabId = controller.activeTabId;
    final query = 'SELECT *\nFROM ${_quoteIdentifier(tableName)}';
    controller.createTab(sql: query);
    final exportTabId = controller.activeTabId;
    try {
      await controller.runActiveTab();
      if (controller.tabById(exportTabId)?.canExport != true) {
        await _showInfoDialog(
          'Export Table',
          'No exportable result rows were returned from "$tableName".',
        );
        return;
      }
      await _showCsvExportDialog();
    } finally {
      if (controller.tabById(previousTabId) != null) {
        controller.selectTab(previousTabId);
      }
      if (controller.tabById(exportTabId) != null &&
          exportTabId != previousTabId) {
        await controller.closeTab(exportTabId);
      }
    }
  }

  Future<void> _showExportSchemaDialog() async {
    final controller = widget.controller;
    final result = await getSaveLocation(
      suggestedName:
          'schema_export_${p.basenameWithoutExtension(controller.databasePath ?? 'sample.decentdb')}.sql',
      acceptedTypeGroups: const <XTypeGroup>[_schemaExportTypeGroup],
    );
    if (result == null) {
      return;
    }
    final contents = _schemaExportContents(controller);
    try {
      await File(result.path).writeAsString(contents);
    } catch (error) {
      await _showInfoDialog(
        'Export Schema',
        'Unable to write schema export file to ${result.path}.\n\n$error',
      );
      return;
    }
    await _showInfoDialog(
      'Export Schema',
      'Schema export written to:\n${result.path}',
    );
  }

  Future<void> _showParquetExportUnavailableDialog() {
    return _showPlaceholderNotice(
      'Export Parquet',
      'Parquet export remains blocked until a maintained Apache-compatible Dart or FFI writer is selected and validated for desktop builds. Excel export is available now.',
    );
  }

  Future<void> _showQualityDashboard() async {
    _shellController.setSchemaExplorerVisible(true);
    setState(() {
      _navigationPaneMode = _NavigationPaneMode.quality;
    });
  }

  Future<void> _showQualityProfileManagerDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 960,
          height: 700,
          child: ValidationProfileEditor(
            controller: widget.controller.dataQuality,
          ),
        ),
      ),
    );
  }

  Future<void> _showQualityReportExportDialog() async {
    final qualityController = widget.controller.dataQuality;
    if (qualityController.currentRun == null) {
      await _showInfoDialog(
        'Export Quality Report',
        'Run a quality profile before exporting a quality report.',
      );
      return;
    }
    final result = await showDialog<QualityReportExportDialogResult>(
      context: context,
      builder: (context) => QualityReportExportDialog(
        initialPath: _defaultQualityReportPath(
          QualityReportFormat.markdown.extension,
        ),
        onBrowse: (format, currentPath) async {
          final initialName = currentPath.trim().isEmpty
              ? p.basename(_defaultQualityReportPath(format.extension))
              : p.basename(currentPath.trim());
          final location = await getSaveLocation(
            suggestedName: initialName,
            acceptedTypeGroups: <XTypeGroup>[
              XTypeGroup(
                label: 'Quality report',
                extensions: <String>[format.extension.substring(1)],
              ),
            ],
          );
          return location?.path;
        },
      ),
    );
    if (result == null) {
      return;
    }
    try {
      await qualityController.exportReport(
        QualityReportOptions(
          format: result.format,
          destinationPath: result.path,
          includeSampleValues: result.includeSampleValues,
          includeViolationDetailRows: result.includeViolationSamples,
          includeImportReconciliation: result.includeImportReconciliation,
          includeRuleDefinitions: result.includeRuleDefinitions,
          freshnessStatus: qualityController.freshness,
        ),
      );
      if (!mounted) {
        return;
      }
      await _showInfoDialog(
        'Export Quality Report',
        'Quality report written to:\n${result.path}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showInfoDialog(
        'Export Quality Report',
        'Unable to write quality report to ${result.path}.\n\n$error',
      );
    }
  }

  String _defaultQualityReportPath(String extension) {
    final databasePath = widget.controller.databasePath;
    final baseName = p.basenameWithoutExtension(
      databasePath ?? 'workspace.ddb',
    );
    final directory = databasePath == null
        ? Directory.current.path
        : p.dirname(databasePath);
    return p.join(directory, '${baseName}_quality_report$extension');
  }

  String _schemaExportContents(WorkspaceController controller) {
    final snapshot = controller.schema;
    final objects = snapshot.objects.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    final buffer = StringBuffer()
      ..writeln('-- Decent Bench schema export')
      ..writeln('-- Database: ${controller.databasePath ?? 'sample.decentdb'}')
      ..writeln('-- Exported: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('--')
      ..writeln(
        '-- Objects: ${snapshot.objects.length} | '
        'Tables: ${snapshot.tables.length} | '
        'Views: ${snapshot.views.length}',
      )
      ..writeln();

    for (final object in objects) {
      final indexes = snapshot.indexesForObject(object.name).toList()
        ..sort((left, right) => left.name.compareTo(right.name));
      final triggers = snapshot.triggersForObject(object.name).toList()
        ..sort((left, right) => left.name.compareTo(right.name));
      buffer
        ..writeln(
          '-- === ${object.kind.name.toUpperCase()}: ${object.name} ===',
        )
        ..writeln('-- Temporary: ${object.temporary}');
      if (object.ddl == null || object.ddl!.trim().isEmpty) {
        buffer.writeln(
          '-- DDL unavailable for ${object.kind.name} ${object.name}.',
        );
      } else {
        final ddl = object.ddl!.trim();
        buffer.writeln(ddl.endsWith(';') ? ddl : '$ddl;');
      }
      if (object.columns.isNotEmpty) {
        buffer.writeln(
          '-- Columns (${object.columns.length}): ${object.columns.map((column) => column.name).join(', ')}',
        );
      }
      if (indexes.isNotEmpty) {
        buffer.writeln('-- Indexes');
        for (final index in indexes) {
          if (index.ddl == null || index.ddl!.trim().isEmpty) {
            buffer.writeln('-- Index ${index.name} has no DDL.');
          } else {
            final ddl = index.ddl!.trim();
            buffer.writeln(ddl.endsWith(';') ? ddl : '$ddl;');
          }
        }
      }
      if (triggers.isNotEmpty) {
        buffer.writeln('-- Triggers');
        for (final trigger in triggers) {
          final ddl = trigger.ddl.trim();
          buffer.writeln(ddl.endsWith(';') ? ddl : '$ddl;');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  String? _selectedTableNameForExport(WorkspaceController controller) {
    final nodeId = _selectedSchemaNodeId ?? _fallbackSchemaNodeId(controller);
    if (!nodeId.startsWith('table:')) {
      return null;
    }
    final tableName = nodeId.substring('table:'.length);
    final object = controller.schema.objectNamed(tableName);
    if (object == null || object.kind != SchemaObjectKind.table) {
      return null;
    }
    return tableName;
  }

  Future<void> _handleIncomingFiles(Iterable<String> rawPaths) async {
    final decision = decideWorkspaceIncomingFiles(rawPaths);
    final path = decision.primaryPath;
    if (path == null) {
      await _showPlaceholderNotice(
        'No file detected',
        'Drop a DecentDB or supported import source to continue.',
      );
      return;
    }
    if (decision.hadMultipleFiles) {
      await _showPlaceholderNotice(
        'One file at a time',
        'MVP import currently continues with ${p.basename(path)}.',
      );
    }

    await _startImportFromPath(path);
  }

  Future<void> _handleArchiveImport(ImportDetectionResult detection) async {
    if (!detection.hasArchiveCandidates) {
      await _showPlaceholderNotice(
        detection.format.label,
        'No recognized importable files were found inside `${p.basename(detection.sourcePath)}`.',
      );
      return;
    }
    final candidate = await showDialog<ImportArchiveCandidate>(
      context: context,
      builder: (context) => ImportArchiveChooserDialog(
        archivePath: detection.sourcePath,
        wrapperLabel: detection.format.label,
        candidates: detection.archiveCandidates,
      ),
    );
    if (candidate == null) {
      return;
    }
    final extractedPath = await _importManager.extractArchiveCandidate(
      archivePath: detection.sourcePath,
      wrapperKey: detection.format.key,
      candidate: candidate,
    );
    try {
      await _startImportFromPath(extractedPath);
    } catch (error) {
      widget.controller.logger.error(
        category: 'import',
        operation: 'archive_extract_start',
        message: 'Failed to start import from extracted archive candidate.',
        error: error,
        details: <String, Object?>{'archive_path': detection.sourcePath},
      );
    } finally {
      final extractedDir = Directory(p.dirname(extractedPath));
      if (await extractedDir.exists()) {
        await extractedDir.delete(recursive: true);
      }
    }
  }

  Future<void> _showSchemaNodeContextMenu(
    String nodeId,
    Offset globalPosition,
  ) async {
    final items = _schemaMenuItemsForNode(nodeId);
    if (items.isEmpty) {
      return;
    }
    setState(() {
      _selectedSchemaNodeId = nodeId;
    });
    final action = await showMenu<_SchemaNodeMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: items,
    );
    if (action == null) {
      return;
    }

    final objectName = _objectNameForSchemaNode(nodeId);
    switch (action) {
      case _SchemaNodeMenuAction.scriptDdl:
        if (objectName != null) {
          _openObjectDefinitionQuery(objectName);
        }
        break;
      case _SchemaNodeMenuAction.viewData:
        if (objectName != null) {
          await _openObjectDataQuery(objectName);
        }
        break;
      case _SchemaNodeMenuAction.showInErd:
        if (objectName != null) {
          await _showEntityRelationshipDiagram(tableName: objectName);
        }
        break;
      case _SchemaNodeMenuAction.scriptInsert:
        if (objectName != null) {
          _openSqlTemplate(_insertTemplateForTable(objectName));
        }
        break;
      case _SchemaNodeMenuAction.scriptUpdate:
        if (objectName != null) {
          _openSqlTemplate(_updateTemplateForTable(objectName));
        }
        break;
      case _SchemaNodeMenuAction.scriptDelete:
        if (objectName != null) {
          _openSqlTemplate(_deleteTemplateForTable(objectName));
        }
        break;
      case _SchemaNodeMenuAction.renameObject:
        if (objectName != null) {
          _openSqlTemplate(
            'ALTER TABLE ${_quoteIdentifier(objectName)}\n'
            'RENAME TO ${_quoteIdentifier('new_$objectName')};',
          );
        }
        break;
      case _SchemaNodeMenuAction.deleteObject:
        if (objectName != null) {
          _openSqlTemplate('DROP TABLE ${_quoteIdentifier(objectName)};');
        }
        break;
      case _SchemaNodeMenuAction.refresh:
        await widget.controller.refreshSchema();
        break;
      case _SchemaNodeMenuAction.newIndex:
        _openSqlTemplate(_newIndexTemplate());
        break;
      case _SchemaNodeMenuAction.rebuildAllIndexes:
        _openSqlTemplate('REINDEX;');
        break;
      case _SchemaNodeMenuAction.newView:
        _openSqlTemplate(_newViewTemplate());
        break;
      case _SchemaNodeMenuAction.columnStatistics:
        await _showSchemaColumnStatistics(nodeId);
        break;
    }
  }

  List<PopupMenuEntry<_SchemaNodeMenuAction>> _schemaMenuItemsForNode(
    String nodeId,
  ) {
    if (nodeId.startsWith('column:')) {
      return <PopupMenuEntry<_SchemaNodeMenuAction>>[
        _popupMenuItem(
          value: _SchemaNodeMenuAction.columnStatistics,
          icon: Icons.query_stats_outlined,
          label: 'Column Statistics',
        ),
      ];
    }
    if (nodeId.startsWith('table:')) {
      return <PopupMenuEntry<_SchemaNodeMenuAction>>[
        _popupMenuItem(
          value: _SchemaNodeMenuAction.scriptInsert,
          icon: Icons.note_add_outlined,
          label: 'Script Table as INSERT',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.scriptUpdate,
          icon: Icons.edit_note_outlined,
          label: 'Script Table as UPDATE',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.scriptDelete,
          icon: Icons.delete_sweep_outlined,
          label: 'Script Table as DELETE',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.scriptDdl,
          icon: Icons.description_outlined,
          label: 'Script Table DDL',
        ),
        const PopupMenuDivider(),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.viewData,
          icon: Icons.table_view_outlined,
          label: 'View Data',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.showInErd,
          icon: Icons.account_tree_outlined,
          label: 'Show in ER Diagram',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.renameObject,
          icon: Icons.drive_file_rename_outline_outlined,
          label: 'Rename',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.deleteObject,
          icon: Icons.delete_outline,
          label: 'Delete',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.refresh,
          icon: Icons.refresh_outlined,
          label: 'Refresh',
        ),
      ];
    }
    if (nodeId == 'section:indexes') {
      return <PopupMenuEntry<_SchemaNodeMenuAction>>[
        _popupMenuItem(
          value: _SchemaNodeMenuAction.newIndex,
          icon: Icons.add_circle_outline,
          label: 'New Index',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.rebuildAllIndexes,
          icon: Icons.build_circle_outlined,
          label: 'Rebuild All',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.refresh,
          icon: Icons.refresh_outlined,
          label: 'Refresh',
        ),
      ];
    }
    if (nodeId == 'section:views') {
      return <PopupMenuEntry<_SchemaNodeMenuAction>>[
        _popupMenuItem(
          value: _SchemaNodeMenuAction.newView,
          icon: Icons.add_circle_outline,
          label: 'New View',
        ),
        _popupMenuItem(
          value: _SchemaNodeMenuAction.refresh,
          icon: Icons.refresh_outlined,
          label: 'Refresh',
        ),
      ];
    }
    return const <PopupMenuEntry<_SchemaNodeMenuAction>>[];
  }

  String? _objectNameForSchemaNode(String nodeId) {
    if (nodeId.startsWith('table:')) {
      return nodeId.substring('table:'.length);
    }
    if (nodeId.startsWith('view:')) {
      return nodeId.substring('view:'.length);
    }
    return null;
  }

  Future<void> _openObjectDataQuery(String objectName) async {
    _openSqlTemplate(
      'SELECT *\n'
      'FROM ${_quoteIdentifier(objectName)}\n'
      'LIMIT ${widget.controller.config.defaultPageSize};',
    );
    if (widget.controller.hasOpenDatabase) {
      await widget.controller.runActiveTab();
    }
  }

  Future<void> _openTableFromErd(String tableName) async {
    setState(() {
      _navigationPaneMode = _NavigationPaneMode.erd;
      _selectedSchemaNodeId = 'table:$tableName';
    });
    await _openObjectDataQuery(tableName);
  }

  Future<void> _showEntityRelationshipDiagram({String? tableName}) async {
    _shellController.setSchemaExplorerVisible(true);
    _logErdNavigationSelected();
    setState(() {
      _navigationPaneMode = _NavigationPaneMode.erd;
      if (tableName != null) {
        _selectedSchemaNodeId = 'table:$tableName';
      }
    });
  }

  Future<void> _exportErdImageFromCommand() async {
    if (_navigationPaneMode != _NavigationPaneMode.erd) {
      await _showEntityRelationshipDiagram();
    }
    await _erdDiagramKey.currentState?.exportImageFromCommand();
  }

  void _openObjectDefinitionQuery(String objectName) {
    final object = widget.controller.schema.objectNamed(objectName);
    final ddl = object?.ddl?.trim();
    if (ddl == null || ddl.isEmpty) {
      _openSqlTemplate(
        '-- Canonical DDL is unavailable for ${_quoteIdentifier(objectName)}.',
      );
      return;
    }
    _openSqlTemplate(ddl.endsWith(';') ? ddl : '$ddl;');
  }

  void _openSqlTemplate(String sql) {
    _dismissedAutocompleteValue = null;
    _autocompleteSelectionIndex = 0;
    widget.controller.createTab(sql: sql);
  }

  String _insertTemplateForTable(String tableName) {
    final object = widget.controller.schema.objectNamed(tableName);
    final columns = object?.columns ?? const <SchemaColumn>[];
    if (columns.isEmpty) {
      return 'INSERT INTO ${_quoteIdentifier(tableName)} ()\nVALUES ();';
    }
    final quotedColumns = columns
        .map((column) => _quoteIdentifier(column.name))
        .join(', ');
    final values = <String>[
      for (var index = 0; index < columns.length; index++) '\$${index + 1}',
    ].join(', ');
    return 'INSERT INTO ${_quoteIdentifier(tableName)} (\n'
        '  $quotedColumns\n'
        ')\n'
        'VALUES (\n'
        '  $values\n'
        ');';
  }

  String _updateTemplateForTable(String tableName) {
    final object = widget.controller.schema.objectNamed(tableName);
    final columns = object?.columns ?? const <SchemaColumn>[];
    final keyColumn =
        _firstOrNull(columns.where((column) => column.primaryKey)) ??
        (columns.isEmpty ? null : columns.first);
    final valueColumns = columns
        .where((column) => column != keyColumn)
        .toList();
    final setters = valueColumns.isEmpty
        ? '  ${_quoteIdentifier('column_name')} = \$1'
        : <String>[
            for (var index = 0; index < valueColumns.length; index++)
              '  ${_quoteIdentifier(valueColumns[index].name)} = \$${index + 1}',
          ].join(',\n');
    final whereValue = valueColumns.length + 1;
    final whereClause = keyColumn == null
        ? 'WHERE ${_quoteIdentifier('key_column')} = \$$whereValue;'
        : 'WHERE ${_quoteIdentifier(keyColumn.name)} = \$$whereValue;';
    return 'UPDATE ${_quoteIdentifier(tableName)}\n'
        'SET\n'
        '$setters\n'
        '$whereClause';
  }

  String _deleteTemplateForTable(String tableName) {
    final object = widget.controller.schema.objectNamed(tableName);
    final keyColumn = object == null
        ? null
        : _firstOrNull(object.columns.where((column) => column.primaryKey)) ??
              (object.columns.isEmpty ? null : object.columns.first);
    final whereClause = keyColumn == null
        ? 'WHERE ${_quoteIdentifier('key_column')} = \$1;'
        : 'WHERE ${_quoteIdentifier(keyColumn.name)} = \$1;';
    return 'DELETE FROM ${_quoteIdentifier(tableName)}\n$whereClause';
  }

  String _newIndexTemplate() {
    final firstTable = _firstOrNull(widget.controller.schema.tables);
    final table = firstTable?.name ?? 'table_name';
    final column = firstTable == null || firstTable.columns.isEmpty
        ? 'column_name'
        : firstTable.columns.first.name;
    return 'CREATE INDEX ${_quoteIdentifier('idx_${table}_$column')}\n'
        'ON ${_quoteIdentifier(table)} (${_quoteIdentifier(column)});';
  }

  String _newViewTemplate() {
    final table =
        _firstOrNull(widget.controller.schema.tables)?.name ?? 'table_name';
    return 'CREATE VIEW ${_quoteIdentifier('new_view')}\n'
        'AS\n'
        'SELECT *\n'
        'FROM ${_quoteIdentifier(table)}\n'
        'LIMIT ${widget.controller.config.defaultPageSize};';
  }

  String _quoteIdentifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _quoteStringLiteral(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  bool _usePlaceholderContent(WorkspaceController controller) {
    return !controller.hasOpenDatabase;
  }

  void _formatActiveSql() {
    final selection = _sqlSelectionInfo();
    final formatted = _sqlFormatter.format(
      selection.hasRunnableSelection
          ? selection.selectedText
          : _sqlController.text,
      settings: widget.controller.config.editorSettings,
    );
    _sqlController.value = replaceSelectedTextOrAll(
      _sqlController.value,
      replacement: formatted,
      useSelection: selection.hasRunnableSelection,
    );
    widget.controller.updateActiveSql(_sqlController.text);
  }

  Future<void> _runPrimarySqlTarget() async {
    final executionTarget = _sqlExecutionTarget();
    if (!executionTarget.isBufferTarget) {
      final decision = await _confirmRiskySqlIfNeeded(executionTarget.sql);
      if (decision == _RiskySqlDecision.cancel) {
        return;
      }
      if (decision == _RiskySqlDecision.newBranch) {
        await widget.controller.runSqlOnNewBranch(
          executionTarget.sql,
          bufferStartOffset: executionTarget.startOffset,
          description: switch (executionTarget.kind) {
            SqlExecutionTargetKind.selection => 'selected SQL',
            SqlExecutionTargetKind.statement => 'statement',
            SqlExecutionTargetKind.buffer => 'SQL',
          },
        );
        return;
      }
      await widget.controller.runActiveSql(
        executionTarget.sql,
        bufferStartOffset: executionTarget.startOffset,
        description: switch (executionTarget.kind) {
          SqlExecutionTargetKind.selection => 'selected SQL',
          SqlExecutionTargetKind.statement => 'statement',
          SqlExecutionTargetKind.buffer => 'SQL',
        },
      );
      return;
    }
    final decision = await _confirmRiskySqlIfNeeded(
      widget.controller.activeTab.sql,
    );
    if (decision == _RiskySqlDecision.cancel) {
      return;
    }
    if (decision == _RiskySqlDecision.newBranch) {
      await widget.controller.runSqlOnNewBranch(
        widget.controller.activeTab.sql,
        description: 'SQL buffer',
      );
      return;
    }
    await widget.controller.runActiveTab();
  }

  Future<void> _runEntireSqlBuffer() async {
    final decision = await _confirmRiskySqlIfNeeded(
      widget.controller.activeTab.sql,
    );
    if (decision == _RiskySqlDecision.cancel) {
      return;
    }
    if (decision == _RiskySqlDecision.newBranch) {
      await widget.controller.runSqlOnNewBranch(
        widget.controller.activeTab.sql,
        description: 'SQL buffer',
      );
      return;
    }
    await widget.controller.runActiveTab();
  }

  Future<_RiskySqlDecision> _confirmRiskySqlIfNeeded(String sql) async {
    final assessment = assessSqlRisk(sql);
    if (!assessment.requiresConfirmation) {
      return _RiskySqlDecision.currentDatabase;
    }
    final branchState = widget.controller.branchState;
    final canUseNativeBranch = widget.controller.canUseNativeBranchWorkflow;
    final result = await showDialog<_RiskySqlDecision>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            assessment.isDestructive
                ? 'Confirm Destructive SQL'
                : 'Confirm Mutating SQL',
          ),
          content: Text(
            '${assessment.reason}\n\n'
            '${canUseNativeBranch ? 'Run on New Branch creates a temporary DecentDB branch and executes this SQL there first.' : branchState.nativeBranchApiUnavailableReason}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_RiskySqlDecision.cancel),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: canUseNativeBranch
                  ? () => Navigator.of(context).pop(_RiskySqlDecision.newBranch)
                  : null,
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Run on New Branch'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_RiskySqlDecision.currentDatabase),
              child: const Text('Run on Current Database'),
            ),
          ],
        );
      },
    );
    return result ?? _RiskySqlDecision.cancel;
  }

  void _insertSnippet(SqlSnippet snippet) {
    _dismissedAutocompleteValue = null;
    _autocompleteSelectionIndex = 0;
    final text = _sqlController.text;
    final selection = _sqlController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final replacement = snippet.body;
    final updated =
        text.substring(0, start) + replacement + text.substring(end);
    final offset = start + replacement.length;
    _sqlController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: offset),
    );
    widget.controller.updateActiveSql(updated);
  }

  void _applyAutocompleteSuggestion(
    AutocompleteResult result,
    AutocompleteSuggestion suggestion,
  ) {
    _dismissedAutocompleteValue = null;
    _autocompleteSelectionIndex = 0;
    final current = _sqlController.text;
    final updated =
        current.substring(0, result.replaceStart) +
        suggestion.insertText +
        current.substring(result.replaceEnd);
    final offset = result.replaceStart + suggestion.insertText.length;
    _sqlController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: offset),
    );
    widget.controller.updateActiveSql(updated);
  }

  Future<void> _showSavedQueriesDialog() async {
    final filterController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final queries = _filterSavedQueries(
                  widget.controller.savedQueries,
                  filterController.text,
                );
                return AlertDialog(
                  title: const Text('Saved Queries'),
                  content: SizedBox(
                    width: 780,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: filterController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_outlined),
                            labelText: 'Filter by name, folder, tag, or SQL',
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: queries.isEmpty
                              ? const Text(
                                  'No saved queries match this workspace filter.',
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: queries.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final query = queries[index];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        query.hasSchemaDrift(
                                              widget.controller.toolingMetadata,
                                            )
                                            ? Icons.warning_amber_outlined
                                            : Icons.bookmark_outline,
                                      ),
                                      title: Text(query.name),
                                      subtitle: Text(
                                        _savedQuerySubtitle(query),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Wrap(
                                        spacing: 6,
                                        children: <Widget>[
                                          TextButton(
                                            onPressed: () {
                                              widget.controller.loadSavedQuery(
                                                query.id,
                                              );
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Open'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              widget.controller.loadSavedQuery(
                                                query.id,
                                                openInNewTab: true,
                                              );
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('New Tab'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              await widget.controller
                                                  .deleteSavedQuery(query.id);
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    FilledButton.icon(
                      onPressed: () async =>
                          _showSaveActiveQueryDialog(context),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save Active Query'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    filterController.dispose();
  }

  List<SavedQuery> _filterSavedQueries(
    List<SavedQuery> queries,
    String filter,
  ) {
    final normalized = filter.trim().toLowerCase();
    if (normalized.isEmpty) {
      return queries;
    }
    return queries.where((query) {
      return query.name.toLowerCase().contains(normalized) ||
          query.folder.toLowerCase().contains(normalized) ||
          query.tags.any((tag) => tag.toLowerCase().contains(normalized)) ||
          query.sql.toLowerCase().contains(normalized);
    }).toList();
  }

  Future<void> _showSaveActiveQueryDialog(BuildContext dialogContext) async {
    final nameController = TextEditingController(
      text: widget.controller.activeTab.title,
    );
    final folderController = TextEditingController();
    final tagsController = TextEditingController();
    final descriptionController = TextEditingController();
    final saved = await showDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Active Query'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: folderController,
                  decoration: const InputDecoration(labelText: 'Folder'),
                ),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'comma,separated',
                  ),
                ),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (saved == true) {
      await widget.controller.saveActiveQuery(
        name: nameController.text,
        folder: folderController.text,
        description: descriptionController.text,
        tags: tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
      );
    }
    nameController.dispose();
    folderController.dispose();
    tagsController.dispose();
    descriptionController.dispose();
  }

  String _savedQuerySubtitle(SavedQuery query) {
    final parts = <String>[
      if (query.folder.trim().isNotEmpty) query.folder,
      if (query.tags.isNotEmpty) query.tags.join(', '),
      if (query.hasSchemaDrift(widget.controller.toolingMetadata))
        'schema drift',
      query.sql.replaceAll('\n', ' '),
    ];
    return parts.join(' - ');
  }

  Future<void> _showQueryHistoryDialog() {
    final entries = widget.controller.queryHistory;
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Query History'),
          content: SizedBox(
            width: 760,
            child: entries.isEmpty
                ? const Text(
                    'No query executions have been recorded in this workspace yet.',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          entry.sql.replaceAll('\n', ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                        subtitle: Text(
                          '${entry.ranAt.toLocal()} • ${entry.outcome.name} • ${entry.elapsed.inMilliseconds} ms'
                          '${entry.rowsLoaded != null ? ' • rows ${entry.rowsLoaded}' : ''}'
                          '${entry.rowsAffected != null ? ' • affected ${entry.rowsAffected}' : ''}'
                          '${entry.errorMessage != null ? ' • ${entry.errorMessage}' : ''}',
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: <Widget>[
                            TextButton(
                              onPressed: () {
                                widget.controller.loadHistoryEntryIntoActiveTab(
                                  entry,
                                );
                                Navigator.of(context).pop();
                              },
                              child: const Text('Load'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await widget.controller.rerunHistoryEntry(
                                  entry,
                                );
                              },
                              child: const Text('Run'),
                            ),
                            TextButton(
                              onPressed: () {
                                widget.controller.loadHistoryEntryIntoActiveTab(
                                  entry,
                                  openInNewTab: true,
                                );
                                Navigator.of(context).pop();
                              },
                              child: const Text('New Tab'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBranchSnapshotWorkbench() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            final state = controller.branchState;
            final diff = controller.lastBranchDiff;
            final canUseNative = controller.canUseNativeBranchWorkflow;
            return AlertDialog(
              title: const Text('Branch & Snapshot Workbench'),
              content: SizedBox(
                width: 680,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            canUseNative
                                ? Icons.account_tree_outlined
                                : Icons.info_outline,
                          ),
                          title: Text(state.branchLabel),
                          subtitle: Text(
                            canUseNative
                                ? 'Native DecentDB branch operations are available through the workspace gateway.'
                                : state.nativeBranchApiUnavailableReason,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Branches',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        if (state.branches.isEmpty)
                          const Text('No native branch list is available.')
                        else
                          ...state.branches.map(
                            (branch) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.call_split_outlined),
                              title: Text(branch.name),
                              subtitle: Text(
                                branch.isCurrent
                                    ? 'Current branch'
                                    : 'Parent ${branch.parentRef ?? 'unknown'}',
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Snapshots',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        if (state.snapshots.isEmpty)
                          const Text('No native snapshots are available.')
                        else
                          ...state.snapshots.map(
                            (snapshot) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.camera_alt_outlined),
                              title: Text(snapshot.name),
                              subtitle: Text(
                                '${snapshot.ref}'
                                '${snapshot.branch == null ? '' : ' on ${snapshot.branch}'}',
                              ),
                            ),
                          ),
                        if (diff != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            'Last Diff',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${diff.leftRef} -> ${diff.rightRef}: '
                            '${diff.addedRows} added, '
                            '${diff.modifiedRows} modified, '
                            '${diff.removedRows} removed.',
                          ),
                          const SizedBox(height: 4),
                          for (final row in diff.rows.take(5))
                            Text(
                              '${row.tableName} ${row.operation}'
                              '${row.primaryKey == null ? '' : ' ${row.primaryKey}'}',
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => controller.refreshBranchState(),
                  child: const Text('Refresh'),
                ),
                TextButton(
                  onPressed: canUseNative
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _showCreateSnapshotDialog();
                        }
                      : null,
                  child: const Text('Create Snapshot'),
                ),
                TextButton(
                  onPressed: canUseNative
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _showCreateBranchDialog();
                        }
                      : null,
                  child: const Text('Create Branch'),
                ),
                TextButton(
                  onPressed: canUseNative
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _showBranchDiffDialog();
                        }
                      : null,
                  child: const Text('Diff'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateSnapshotDialog() async {
    if (!widget.controller.canUseNativeBranchWorkflow) {
      await _showBranchSnapshotWorkbench();
      return;
    }
    final name = await _promptBranchWorkflowValue(
      title: 'Create Snapshot',
      label: 'Snapshot name',
      initialValue: 'snapshot_${_branchWorkflowTimestamp()}',
    );
    if (name == null) {
      return;
    }
    await widget.controller.createSnapshot(name);
  }

  Future<void> _showCreateBranchDialog() async {
    if (!widget.controller.canUseNativeBranchWorkflow) {
      await _showBranchSnapshotWorkbench();
      return;
    }
    final branchName = await _promptBranchWorkflowValue(
      title: 'Create Branch',
      label: 'Branch name',
      initialValue: 'safe_run_${_branchWorkflowTimestamp()}',
    );
    if (branchName == null) {
      return;
    }
    final fromRef = await _promptBranchWorkflowValue(
      title: 'Create Branch',
      label: 'Source branch or snapshot ref',
      initialValue: widget.controller.branchState.currentBranch,
    );
    if (fromRef == null) {
      return;
    }
    await widget.controller.createBranch(
      branchName: branchName,
      fromRef: fromRef,
    );
  }

  Future<void> _showBranchDiffDialog() async {
    if (!widget.controller.canUseNativeBranchWorkflow) {
      await _showBranchSnapshotWorkbench();
      return;
    }
    final leftRef = await _promptBranchWorkflowValue(
      title: 'Branch Diff',
      label: 'Left ref',
      initialValue: 'main',
    );
    if (leftRef == null) {
      return;
    }
    final rightRef = await _promptBranchWorkflowValue(
      title: 'Branch Diff',
      label: 'Right ref',
      initialValue: widget.controller.branchState.currentBranch,
    );
    if (rightRef == null) {
      return;
    }
    await widget.controller.previewBranchDiff(
      leftRef: leftRef,
      rightRef: rightRef,
    );
    if (mounted) {
      await _showBranchSnapshotWorkbench();
    }
  }

  Future<void> _showRestoreBranchDialog() async {
    if (!widget.controller.canUseNativeBranchWorkflow) {
      await _showBranchSnapshotWorkbench();
      return;
    }
    final branchName = await _promptBranchWorkflowValue(
      title: 'Restore Branch',
      label: 'Branch name',
      initialValue: widget.controller.branchState.currentBranch,
    );
    if (branchName == null) {
      return;
    }
    final targetRef = await _promptBranchWorkflowValue(
      title: 'Restore Branch',
      label: 'Target branch or snapshot ref',
      initialValue: 'main',
    );
    if (targetRef == null) {
      return;
    }
    final diff = await widget.controller.previewRestoreBranch(
      branchName: branchName,
      targetRef: targetRef,
    );
    if (!mounted || diff == null) {
      return;
    }
    final apply = await _confirmBranchApply(
      title: 'Apply Restore',
      message:
          'Dry run found ${diff.totalChanges} row changes. A pre-restore '
          'snapshot will be created before applying the restore.',
    );
    if (apply == true) {
      await widget.controller.applyRestoreBranch(
        branchName: branchName,
        targetRef: targetRef,
      );
    }
  }

  Future<void> _showMergeBranchDialog() async {
    if (!widget.controller.canUseNativeBranchWorkflow) {
      await _showBranchSnapshotWorkbench();
      return;
    }
    final sourceBranch = await _promptBranchWorkflowValue(
      title: 'Merge Branch',
      label: 'Source branch',
      initialValue: widget.controller.branchState.currentBranch,
    );
    if (sourceBranch == null) {
      return;
    }
    final targetBranch = await _promptBranchWorkflowValue(
      title: 'Merge Branch',
      label: 'Target branch',
      initialValue: 'main',
    );
    if (targetBranch == null) {
      return;
    }
    final diff = await widget.controller.previewMergeBranch(
      sourceBranch: sourceBranch,
      targetBranch: targetBranch,
    );
    if (!mounted || diff == null) {
      return;
    }
    final apply = await _confirmBranchApply(
      title: 'Apply Merge',
      message:
          'Dry run found ${diff.totalChanges} row changes. Apply the '
          'constrained DecentDB merge now?',
    );
    if (apply == true) {
      await widget.controller.applyMergeBranch(
        sourceBranch: sourceBranch,
        targetBranch: targetBranch,
      );
    }
  }

  Future<String?> _promptBranchWorkflowValue({
    required String title,
    required String label,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    try {
      return showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool?> _confirmBranchApply({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  String _branchWorkflowTimestamp() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_')
        .replaceAll(RegExp(r'_+$'), '');
  }

  Future<void> _showShortcutDialog(Map<String, ShortcutBinding> shortcuts) {
    final sorted = shortcuts.values.toList()
      ..sort((left, right) => left.commandId.compareTo(right.commandId));
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Keyboard Shortcuts'),
          content: SizedBox(
            width: 520,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final shortcut = sorted[index];
                return ListTile(
                  dense: true,
                  title: Text(shortcut.commandId.replaceAll('_', ' ')),
                  trailing: Text(
                    shortcut.displayLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(fontFamily: 'monospace'),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDocumentationDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          const HelpCenterDialog(initialArticleId: 'getting-started'),
    );
  }

  Future<void> _showPreferencesDialog({
    PreferencesDialogSection initialSection = PreferencesDialogSection.general,
  }) {
    return _showPreferencesDialogInternal(initialSection: initialSection);
  }

  Future<void> _showPreferencesDialogInternal({
    PreferencesDialogSection initialSection = PreferencesDialogSection.general,
  }) async {
    await _shellController.persistNow();
    await widget.controller.reloadConfig();
    _shellController.replacePreferences(
      widget.controller.config.shellPreferences,
    );
    if (!mounted) {
      return;
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return PreferencesDialog(
            initialConfig: widget.controller.config,
            configFilePath: widget.controller.configFilePath,
            shortcutConfigService: _shortcutConfigService,
            createSnippetId: widget.controller.createSnippetId,
            availableThemesById: <String, String>{
              for (final theme in widget.themeManager.availableThemes)
                theme.id: theme.name,
            },
            resolvedThemesDirectory:
                widget.themeManager.resolvedThemesDirectory,
            initialSection: initialSection,
            onPreviewTheme: widget.themeManager.switchTheme,
            onSave: (config) async {
              final saved = await widget.controller.applyAppConfig(
                config,
                statusMessage:
                    'Saved preferences to ${widget.controller.configFilePath}.',
              );
              if (saved) {
                _shellController.replacePreferences(
                  widget.controller.config.shellPreferences,
                );
                return null;
              }
              return widget.controller.workspaceError ??
                  'Unable to save application preferences.';
            },
          );
        },
      );
    } finally {
      unawaited(
        widget.themeManager.loadFromConfig(widget.controller.config.appearance),
      );
    }
  }

  Future<void> _showAboutDialog() async {
    final action = await showDialog<_AboutDialogAction>(
      context: context,
      builder: (dialogContext) {
        return DecentBenchAboutDialog(
          onViewLicenses: () {
            Navigator.of(dialogContext).pop(_AboutDialogAction.viewLicenses);
          },
          onClose: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );

    if (!mounted || action != _AboutDialogAction.viewLicenses) {
      return;
    }

    showLicensePage(
      context: context,
      applicationName: kDecentBenchDisplayName,
      applicationVersion: kDecentBenchVersion,
      applicationIcon: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Image.asset(
          kDecentBenchLogoAsset,
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          semanticLabel: 'Decent Bench logo',
        ),
      ),
    );
  }

  Future<void> _showInfoDialog(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(child: SelectableText(message)),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPlaceholderNotice(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<T> _popupMenuItem<T>({
    required T value,
    required IconData icon,
    required String label,
    bool enabled = true,
  }) {
    return PopupMenuItem<T>(
      value: value,
      enabled: enabled,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

enum _NavigationPaneMode { schema, quality, erd }

class _WorkspaceNavigationPane extends StatelessWidget {
  const _WorkspaceNavigationPane({
    required this.mode,
    required this.onModeChanged,
    required this.schemaExplorer,
    required this.qualityDashboard,
    required this.erdViewer,
  });

  final _NavigationPaneMode mode;
  final ValueChanged<_NavigationPaneMode> onModeChanged;
  final Widget schemaExplorer;
  final Widget qualityDashboard;
  final Widget erdViewer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: SegmentedButton<_NavigationPaneMode>(
            segments: const <ButtonSegment<_NavigationPaneMode>>[
              ButtonSegment<_NavigationPaneMode>(
                value: _NavigationPaneMode.schema,
                icon: Icon(Icons.schema_outlined, size: 16),
                label: Text('Schema'),
              ),
              ButtonSegment<_NavigationPaneMode>(
                value: _NavigationPaneMode.quality,
                icon: Icon(Icons.fact_check_outlined, size: 16),
                label: Text('Quality'),
              ),
              ButtonSegment<_NavigationPaneMode>(
                value: _NavigationPaneMode.erd,
                icon: Icon(Icons.account_tree_outlined, size: 16),
                label: Text('ERD'),
              ),
            ],
            selected: <_NavigationPaneMode>{mode},
            onSelectionChanged: (value) => onModeChanged(value.single),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: switch (mode) {
              _NavigationPaneMode.schema => 0,
              _NavigationPaneMode.quality => 1,
              _NavigationPaneMode.erd => 2,
            },
            children: <Widget>[schemaExplorer, qualityDashboard, erdViewer],
          ),
        ),
      ],
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.18),
      child: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).colorScheme.primary),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.file_download_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Drop file to open or import',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'DecentDB files open directly. SQLite, Excel, and SQL dumps launch the matching import wizard.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyValueList extends StatelessWidget {
  const _KeyValueList({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 130,
                  child: Text(
                    row.key,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(child: Text(row.value)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TextMatch {
  const _TextMatch(this.start, this.end);

  final int start;
  final int end;
}

class _ClipboardImportPayload {
  const _ClipboardImportPayload({required this.fileName, required this.text});

  final String fileName;
  final String text;
}

class _EditableFieldBinding {
  const _EditableFieldBinding({
    required this.controller,
    required this.focusNode,
    required this.undoController,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final UndoHistoryController? undoController;
  final ValueChanged<String> onChanged;
}

enum _ResultsCellMenuAction {
  copy,
  copySpatialWkb,
  copySpatialWkt,
  copySpatialGeoJson,
  edit,
  insertRow,
  paste,
  setNull,
  deleteRow,
}

class _ResultsCellSpatialCopyProfile {
  const _ResultsCellSpatialCopyProfile({
    this.canCopyWkb = false,
    this.canCopyWkt = false,
    this.canCopyGeoJson = false,
  });

  final bool canCopyWkb;
  final bool canCopyWkt;
  final bool canCopyGeoJson;
}

enum _SchemaNodeMenuAction {
  scriptDdl,
  scriptInsert,
  scriptUpdate,
  scriptDelete,
  viewData,
  showInErd,
  renameObject,
  deleteObject,
  refresh,
  newIndex,
  rebuildAllIndexes,
  newView,
  columnStatistics,
}
