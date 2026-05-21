import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../app/logging/app_logger.dart';
import '../../../app/logging/import_log_details.dart';
import '../domain/app_config.dart';
import '../domain/excel_import_models.dart';
import '../domain/saved_query_models.dart';
import '../domain/sql_dump_import_models.dart';
import '../domain/sqlite_import_models.dart';
import '../domain/workspace_file_entry.dart';
import '../domain/workspace_models.dart';
import '../domain/workspace_shell_preferences.dart';
import '../domain/workspace_state.dart';
import '../infrastructure/app_config_store.dart';
import '../infrastructure/decentdb_bridge.dart';
import '../infrastructure/layout_persistence_service.dart';
import '../infrastructure/saved_query_library_store.dart';
import '../infrastructure/workspace_state_store.dart';

class WorkspaceController extends ChangeNotifier {
  static const int _maxMessageHistoryEntries = 80;
  static const String nativeBranchApiUnavailableReason =
      'Native DecentDB branch and snapshot operations require a public Dart '
      'binding API. Decent Bench does not call private binding internals or '
      'C ABI surfaces that are not exported by the public Dart package.';

  WorkspaceController({
    WorkspaceDatabaseGateway? gateway,
    WorkspaceConfigStore? configStore,
    WorkspaceStateStore? workspaceStateStore,
    SavedQueryLibraryStore? savedQueryLibraryStore,
    LayoutPersistenceService? layoutPersistenceService,
    AppLogger? logger,
  }) : _logger = logger ?? const NoOpAppLogger(),
       _gateway = gateway ?? DecentDbBridge(),
       _configStore = configStore ?? AppConfigStore(logger: logger),
       _workspaceStateStore = workspaceStateStore ?? FileWorkspaceStateStore(),
       _savedQueryLibraryStore =
           savedQueryLibraryStore ?? FileSavedQueryLibraryStore(),
       _layoutPersistenceService =
           layoutPersistenceService ?? const LayoutPersistenceService() {
    _resetTabs(notify: false, resetCounters: true);
  }

  final AppLogger _logger;
  final WorkspaceDatabaseGateway _gateway;
  final WorkspaceConfigStore _configStore;
  final WorkspaceStateStore _workspaceStateStore;
  final SavedQueryLibraryStore _savedQueryLibraryStore;
  final LayoutPersistenceService _layoutPersistenceService;

  AppConfig config = AppConfig.defaults();
  SchemaSnapshot schema = SchemaSnapshot.empty();
  ToolingMetadata? toolingMetadata;
  WorkspaceBranchState branchState = WorkspaceBranchState.unavailable(
    nativeBranchApiUnavailableReason,
  );
  WorkspaceBranchDiff? lastBranchDiff;
  SavedQueryLibrary savedQueryLibrary = SavedQueryLibrary.empty;
  List<QueryTabState> tabs = const <QueryTabState>[];
  ExcelImportSession? excelImportSession;
  SqlDumpImportSession? sqlDumpImportSession;
  SqliteImportSession? sqliteImportSession;

  String? databasePath;
  String? engineVersion;
  String? nativeLibraryPath;
  String? workspaceError;
  String? workspaceMessage;
  bool isInitializing = true;
  bool isSchemaLoading = false;
  bool isOpeningDatabase = false;
  bool isBranchStateLoading = false;

  int _nextTabIdCounter = 1;
  int _nextTabTitleCounter = 1;
  String? _activeTabId;
  Timer? _workspaceSaveDebounce;
  StreamSubscription<ExcelImportUpdate>? _excelImportSubscription;
  StreamSubscription<SqlDumpImportUpdate>? _sqlDumpImportSubscription;
  StreamSubscription<SqliteImportUpdate>? _sqliteImportSubscription;
  bool _disposed = false;

  bool get hasOpenDatabase => databasePath != null;
  bool get hasExcelImportSession => excelImportSession != null;
  bool get hasSqlDumpImportSession => sqlDumpImportSession != null;
  bool get hasSqliteImportSession => sqliteImportSession != null;
  bool get hasImportSession =>
      hasExcelImportSession ||
      hasSqlDumpImportSession ||
      hasSqliteImportSession;

  String get activeTabId => _activeTabId ?? tabs.first.id;

  QueryTabState get activeTab =>
      tabs.firstWhere((tab) => tab.id == activeTabId);

  List<QueryHistoryEntry> get queryHistory {
    final entries = <QueryHistoryEntry>[
      for (final tab in tabs) ...tab.queryHistory,
    ];
    entries.sort((left, right) => right.ranAt.compareTo(left.ranAt));
    return entries;
  }

  List<SavedQuery> get savedQueries => savedQueryLibrary.queries;

  bool get hasRunningTabs => tabs.any(
    (tab) =>
        tab.canCancel ||
        tab.isExporting ||
        tab.phase == QueryPhase.running ||
        tab.phase == QueryPhase.fetching,
  );

  String get configFilePath => _configStore.describeLocation();

  String get savedQueryLibraryLocation {
    final path = databasePath;
    return path == null ? '' : _savedQueryLibraryStore.describeLocation(path);
  }

  bool get canRunActiveTab => canRunTab(activeTabId);

  bool get canCancelActiveTab => tabById(activeTabId)?.canCancel ?? false;

  bool get canUseNativeBranchWorkflow =>
      hasOpenDatabase && branchState.isNativeBranchApiAvailable;

  AppLogger get logger => _logger;

  void _logDebug(
    String operation,
    String message, {
    String category = 'workspace',
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
  }) {
    _logger.debug(
      category: category,
      operation: operation,
      message: message,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
    );
  }

  void _logInfo(
    String operation,
    String message, {
    String category = 'workspace',
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
  }) {
    _logger.info(
      category: category,
      operation: operation,
      message: message,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
    );
  }

  void _logWarning(
    String operation,
    String message, {
    String category = 'workspace',
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.warning(
      category: category,
      operation: operation,
      message: message,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logError(
    String operation,
    String message, {
    String category = 'workspace',
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.error(
      category: category,
      operation: operation,
      message: message,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
      error: error,
      stackTrace: stackTrace,
    );
  }

  int _durationToNanos(Duration duration) => duration.inMicroseconds * 1000;

  Map<String, Object?> _queryContractLogDetails(QueryContract? contract) {
    if (contract == null) {
      return const <String, Object?>{};
    }
    return <String, Object?>{
      'schema_fingerprint': contract.schemaFingerprint,
      'statement_kind': contract.statementKind,
      'read_only': contract.readOnly,
      'parameter_count': contract.parameters.length,
      'result_column_contracts': <Map<String, Object?>>[
        for (final column in contract.resultColumns)
          <String, Object?>{
            'name': column.name,
            'type_name': column.typeName,
            'nullable': column.nullable,
            'source': column.sourceLabel,
          },
      ],
    };
  }

  QueryTabState? tabById(String tabId) {
    for (final tab in tabs) {
      if (tab.id == tabId) {
        return tab;
      }
    }
    return null;
  }

  bool canRunTab(String tabId) {
    final tab = tabById(tabId);
    if (tab == null || !hasOpenDatabase || tab.isExporting) {
      return false;
    }
    return switch (tab.phase) {
      QueryPhase.idle ||
      QueryPhase.completed ||
      QueryPhase.cancelled ||
      QueryPhase.failed => true,
      QueryPhase.opening ||
      QueryPhase.running ||
      QueryPhase.fetching ||
      QueryPhase.cancelling => false,
    };
  }

  Future<void> initialize() async {
    if (!isInitializing) {
      return;
    }

    final stopwatch = Stopwatch()..start();
    await _logger.initialize(minimumLevel: config.logging.verbosity);
    _logInfo('initialize', 'Starting workspace controller initialization.');
    try {
      config = await _configStore.load();
      _logger.updateMinimumLevel(config.logging.verbosity);
      nativeLibraryPath = await _gateway.initialize();
      workspaceMessage = 'Ready.';
      workspaceError = null;
      await _reopenMostRecentWorkspaceIfAvailable();
      _logInfo(
        'initialize',
        'Workspace controller initialized.',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        details: <String, Object?>{
          'native_library_path': nativeLibraryPath,
          'recent_file_count': config.recentFiles.length,
          'theme_id': config.appearance.activeTheme,
          'verbosity': config.logging.verbosity.name,
        },
      );
    } catch (error) {
      workspaceError = error.toString();
      workspaceMessage = null;
      _logError(
        'initialize',
        'Workspace controller initialization failed.',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
      );
    } finally {
      isInitializing = false;
      _safeNotify();
    }
  }

  Future<void> openDatabase(
    String rawPath, {
    required bool createIfMissing,
    bool restoreStartupQuery = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final normalized = rawPath.trim();
    if (normalized.isEmpty) {
      _setWorkspaceError('Enter a DecentDB file path first.');
      return;
    }

    final file = File(normalized);
    try {
      if (createIfMissing) {
        if (await file.exists()) {
          _setWorkspaceError(
            'Refusing to create over an existing file: $normalized',
          );
          return;
        }
        await file.parent.create(recursive: true);
      } else if (!await file.exists()) {
        _setWorkspaceError('Database file does not exist: $normalized');
        return;
      }
    } on FileSystemException catch (error) {
      _setWorkspaceError(error.message);
      return;
    }

    _workspaceSaveDebounce?.cancel();
    await _cancelAllOpenCursors();

    isOpeningDatabase = true;
    isSchemaLoading = true;
    schema = SchemaSnapshot.empty();
    toolingMetadata = null;
    branchState = WorkspaceBranchState.unavailable(
      nativeBranchApiUnavailableReason,
    );
    lastBranchDiff = null;
    workspaceError = null;
    workspaceMessage = createIfMissing
        ? 'Creating database...'
        : 'Opening database...';
    _safeNotify();
    _logInfo(
      'open_database',
      createIfMissing ? 'Creating database.' : 'Opening database.',
      databasePath: normalized,
      details: <String, Object?>{
        'create_if_missing': createIfMissing,
        'restore_startup_query': restoreStartupQuery,
        'write_queue_enabled': config.writeQueue.enabled,
      },
    );

    try {
      final session = await _gateway.openDatabase(
        normalized,
        writeQueue: config.writeQueue,
      );
      databasePath = session.path;
      engineVersion = session.engineVersion;
      config = config.pushRecentFile(session.path);
      await _configStore.save(config);
      final restoredState = await _workspaceStateStore.load(session.path);
      await _loadSavedQueryLibrary(session.path);
      _restoreTabs(restoredState, notify: false);
      await refreshSchema(showLoadingState: false);
      await refreshBranchState(showLoadingState: false);
      if (restoreStartupQuery) {
        await _restoreStartupQueryState();
      }
      await _persistWorkspaceStateNow();
      workspaceMessage =
          'Opened ${p.basename(session.path)}'
          ' on DecentDB ${session.engineVersion}'
          ' with ${tabs.length} query tab${tabs.length == 1 ? '' : 's'}.';
      _logInfo(
        'open_database',
        'Opened database successfully.',
        databasePath: session.path,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        details: <String, Object?>{
          'engine_version': session.engineVersion,
          'tab_count': tabs.length,
          'schema_tables': schema.tables.length,
          'schema_views': schema.views.length,
          if (toolingMetadata?.schemaFingerprint.isNotEmpty == true)
            'schema_fingerprint': toolingMetadata!.schemaFingerprint,
        },
      );
    } catch (error) {
      databasePath = null;
      engineVersion = null;
      schema = SchemaSnapshot.empty();
      toolingMetadata = null;
      branchState = WorkspaceBranchState.unavailable(
        nativeBranchApiUnavailableReason,
      );
      lastBranchDiff = null;
      savedQueryLibrary = SavedQueryLibrary.empty;
      _setWorkspaceError(error.toString());
      _resetTabs(notify: false, resetCounters: true);
      _logError(
        'open_database',
        'Opening database failed.',
        databasePath: normalized,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
      );
    } finally {
      isOpeningDatabase = false;
      isSchemaLoading = false;
      _safeNotify();
    }
  }

  Future<void> openLogDatabase() async {
    await _logger.initialize(minimumLevel: config.logging.verbosity);
    await openDatabase(_logger.logDatabasePath, createIfMissing: false);
  }

  Future<void> openWorkspaceProject(String projectPath) async {
    final normalized = p.normalize(projectPath);
    final project = WorkspaceProjectFile.fromToml(
      await File(normalized).readAsString(),
    );
    if (project.openOnLoad) {
      await openDatabase(
        project.resolveDatabasePath(normalized),
        createIfMissing: false,
      );
    }
    final queryLibraryPath = project.resolveQueryLibraryPath(normalized);
    if (queryLibraryPath != null) {
      savedQueryLibrary = await _savedQueryLibraryStore.loadFromPath(
        queryLibraryPath,
      );
      for (final queryId in project.autoOpenQueryIds) {
        final query = savedQueryLibrary.queryById(queryId);
        if (query != null) {
          createTab(sql: query.sql);
          _mutateTab(
            activeTabId,
            (tab) => tab.copyWith(
              parameterJson: query.parameterJson,
              queryContract: query.queryContract,
            ),
            persist: true,
            notify: false,
          );
        }
      }
    }
    workspaceError = null;
    workspaceMessage =
        'Opened project ${p.basename(normalized)}'
        '${project.runRiskyQueriesOnBranch && !canUseNativeBranchWorkflow ? ' (branch-safe risky queries unavailable).' : '.'}';
    _safeNotify();
  }

  Future<void> exportWorkspaceProject(String projectPath) async {
    final currentDatabasePath = databasePath;
    if (currentDatabasePath == null) {
      workspaceError = 'Open a DecentDB file before exporting a project.';
      workspaceMessage = null;
      _safeNotify();
      return;
    }
    final normalized = p.normalize(projectPath);
    final queryLibraryPath = p.join(p.dirname(normalized), 'queries.toml');
    await _savedQueryLibraryStore.saveToPath(
      queryLibraryPath,
      savedQueryLibrary,
    );
    final project = WorkspaceProjectFile(
      databasePath: p.relative(
        currentDatabasePath,
        from: p.dirname(normalized),
      ),
      queryLibraryPath: p.basename(queryLibraryPath),
    );
    final file = File(normalized);
    await file.parent.create(recursive: true);
    await file.writeAsString(project.toToml());
    workspaceError = null;
    workspaceMessage = 'Exported project ${p.basename(normalized)}.';
    _safeNotify();
  }

  Future<void> refreshSchema({bool showLoadingState = true}) async {
    if (!hasOpenDatabase) {
      return;
    }

    final stopwatch = Stopwatch()..start();

    if (showLoadingState) {
      isSchemaLoading = true;
      workspaceError = null;
      workspaceMessage = 'Refreshing schema...';
      _safeNotify();
    }

    try {
      final loadedSchema = await _gateway.loadSchema();
      schema = loadedSchema;
      _safeNotify();

      ToolingMetadata? metadata;
      try {
        metadata = await _gateway.getToolingMetadata();
        toolingMetadata = metadata;
      } catch (error, stackTrace) {
        toolingMetadata = null;
        _logWarning(
          'refresh_schema_metadata',
          'Loaded schema snapshot, but tooling metadata was unavailable.',
          databasePath: databasePath,
          elapsedNanos: _durationToNanos(stopwatch.elapsed),
          error: error,
          stackTrace: stackTrace,
        );
      }

      workspaceMessage =
          'Loaded ${schema.tables.length} tables and ${schema.views.length} views.';
      workspaceError = null;
      _scheduleWorkspaceStateSave();
      _logInfo(
        'refresh_schema',
        'Loaded schema snapshot.',
        databasePath: databasePath,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        details: <String, Object?>{
          'table_count': schema.tables.length,
          'view_count': schema.views.length,
          'index_count': schema.indexes.length,
          'tooling_metadata_loaded': metadata != null,
          if (metadata != null) ...<String, Object?>{
            'schema_fingerprint': metadata.schemaFingerprint,
            'metadata_version': metadata.metadataVersion,
            'query_contract_version':
                metadata.capabilities.queryContractVersion,
          },
        },
      );
    } catch (error) {
      toolingMetadata = null;
      _setWorkspaceError(error.toString());
      _logError(
        'refresh_schema',
        'Schema refresh failed.',
        databasePath: databasePath,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
      );
    } finally {
      isSchemaLoading = false;
      _safeNotify();
    }
  }

  Future<void> refreshBranchState({bool showLoadingState = true}) async {
    if (!hasOpenDatabase) {
      branchState = WorkspaceBranchState.unavailable('Open a database first.');
      lastBranchDiff = null;
      if (showLoadingState) {
        _safeNotify();
      }
      return;
    }

    if (showLoadingState) {
      isBranchStateLoading = true;
      workspaceError = null;
      workspaceMessage = 'Refreshing branch and snapshot state...';
      _safeNotify();
    }

    try {
      final branches = await _gateway.listBranches();
      final snapshots = await _gateway.listSnapshots();
      final currentBranch = _currentBranchName(branches);
      branchState = WorkspaceBranchState(
        currentBranch: currentBranch,
        isNativeBranchApiAvailable: true,
        nativeBranchApiUnavailableReason: '',
        branches: branches,
        snapshots: snapshots,
      );
      workspaceError = null;
      if (showLoadingState) {
        workspaceMessage =
            'Loaded ${branches.length} branches and '
            '${snapshots.length} snapshots.';
      }
      _logInfo(
        'refresh_branch_state',
        'Loaded branch and snapshot state.',
        databasePath: databasePath,
        details: <String, Object?>{
          'current_branch': currentBranch,
          'branch_count': branches.length,
          'snapshot_count': snapshots.length,
        },
      );
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
        setMessage: showLoadingState,
        notify: false,
      );
    } catch (error, stackTrace) {
      _setBranchWorkflowUnavailable(
        'Could not load native branch and snapshot state: $error',
        setMessage: showLoadingState,
        notify: false,
      );
      _logWarning(
        'refresh_branch_state',
        'Branch and snapshot state refresh failed.',
        databasePath: databasePath,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isBranchStateLoading = false;
      _safeNotify();
    }
  }

  Future<WorkspaceSnapshotInfo?> createSnapshot(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      workspaceMessage = 'Snapshot name cannot be empty.';
      _safeNotify();
      return null;
    }
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      workspaceMessage = 'Creating snapshot "$trimmed"...';
      _safeNotify();
      final snapshot = await _gateway.createSnapshot(name: trimmed);
      workspaceMessage = 'Created snapshot ${snapshot.name}.';
      await refreshBranchState(showLoadingState: false);
      _safeNotify();
      return snapshot;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _setWorkspaceError(error.toString());
      return null;
    }
  }

  Future<WorkspaceBranchInfo?> createBranch({
    required String branchName,
    String fromRef = 'main',
  }) async {
    final trimmed = branchName.trim();
    final sourceRef = fromRef.trim().isEmpty ? 'main' : fromRef.trim();
    if (trimmed.isEmpty) {
      workspaceMessage = 'Branch name cannot be empty.';
      _safeNotify();
      return null;
    }
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      workspaceMessage = 'Creating branch "$trimmed"...';
      _safeNotify();
      final branch = await _gateway.createBranch(
        branchName: trimmed,
        fromRef: sourceRef,
      );
      workspaceMessage = 'Created branch ${branch.name}.';
      await refreshBranchState(showLoadingState: false);
      _safeNotify();
      return branch;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _setWorkspaceError(error.toString());
      return null;
    }
  }

  Future<WorkspaceBranchDiff?> previewBranchDiff({
    required String leftRef,
    required String rightRef,
  }) async {
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      final diff = await _gateway.branchDiff(
        leftRef: leftRef.trim(),
        rightRef: rightRef.trim(),
      );
      lastBranchDiff = diff;
      workspaceMessage =
          'Diff loaded: ${diff.totalChanges} row changes across '
          '${diff.rows.map((row) => row.tableName).toSet().length} tables.';
      _safeNotify();
      return diff;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _setWorkspaceError(error.toString());
      return null;
    }
  }

  Future<WorkspaceBranchDiff?> previewRestoreBranch({
    required String branchName,
    required String targetRef,
  }) async {
    return _restoreBranch(
      branchName: branchName,
      targetRef: targetRef,
      dryRun: true,
    );
  }

  Future<WorkspaceBranchDiff?> applyRestoreBranch({
    required String branchName,
    required String targetRef,
  }) async {
    return _restoreBranch(
      branchName: branchName,
      targetRef: targetRef,
      dryRun: false,
    );
  }

  Future<WorkspaceBranchDiff?> previewMergeBranch({
    required String sourceBranch,
    required String targetBranch,
  }) async {
    return _mergeBranch(
      sourceBranch: sourceBranch,
      targetBranch: targetBranch,
      dryRun: true,
    );
  }

  Future<WorkspaceBranchDiff?> applyMergeBranch({
    required String sourceBranch,
    required String targetBranch,
  }) async {
    return _mergeBranch(
      sourceBranch: sourceBranch,
      targetBranch: targetBranch,
      dryRun: false,
    );
  }

  Future<WorkspaceBranchDiff?> _restoreBranch({
    required String branchName,
    required String targetRef,
    required bool dryRun,
  }) async {
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      if (!dryRun) {
        await _gateway.createSnapshot(name: _preRestoreSnapshotName());
      }
      final diff = await _gateway.restoreBranch(
        branchName: branchName.trim(),
        targetRef: targetRef.trim(),
        dryRun: dryRun,
      );
      lastBranchDiff = diff;
      workspaceMessage = dryRun
          ? 'Restore dry run loaded ${diff.totalChanges} row changes.'
          : 'Restored ${branchName.trim()} to ${targetRef.trim()}.';
      if (!dryRun) {
        await refreshSchema(showLoadingState: false);
        await refreshBranchState(showLoadingState: false);
      }
      _safeNotify();
      return diff;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _setWorkspaceError(error.toString());
      return null;
    }
  }

  Future<WorkspaceBranchDiff?> _mergeBranch({
    required String sourceBranch,
    required String targetBranch,
    required bool dryRun,
  }) async {
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      final diff = await _gateway.mergeBranch(
        sourceBranch: sourceBranch.trim(),
        targetBranch: targetBranch.trim(),
        dryRun: dryRun,
      );
      lastBranchDiff = diff;
      workspaceMessage = dryRun
          ? 'Merge dry run loaded ${diff.totalChanges} row changes.'
          : 'Merged ${sourceBranch.trim()} into ${targetBranch.trim()}.';
      if (!dryRun) {
        await refreshSchema(showLoadingState: false);
        await refreshBranchState(showLoadingState: false);
      }
      _safeNotify();
      return diff;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _setWorkspaceError(error.toString());
      return null;
    }
  }

  String _currentBranchName(List<WorkspaceBranchInfo> branches) {
    for (final branch in branches) {
      if (branch.isCurrent) {
        return branch.name;
      }
    }
    return branches.isEmpty ? 'main' : branches.first.name;
  }

  String _preRestoreSnapshotName() {
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_')
        .replaceAll(RegExp(r'_+$'), '');
    return 'pre_restore_$stamp';
  }

  void _setBranchWorkflowUnavailable(
    String reason, {
    bool setMessage = true,
    bool notify = true,
  }) {
    branchState = WorkspaceBranchState.unavailable(
      reason.trim().isEmpty ? nativeBranchApiUnavailableReason : reason,
    );
    lastBranchDiff = null;
    if (setMessage) {
      workspaceMessage =
          'Native branch workflow unavailable: '
          '${branchState.nativeBranchApiUnavailableReason}';
      workspaceError = null;
    }
    _logInfo(
      'branch_workflow_unavailable',
      'Native branch workflow unavailable.',
      databasePath: databasePath,
      details: <String, Object?>{
        'reason': branchState.nativeBranchApiUnavailableReason,
      },
    );
    if (notify) {
      _safeNotify();
    }
  }

  void updateActiveSql(String value) {
    _mutateActiveTab((tab) => tab.copyWith(sql: value), persist: true);
  }

  void updateActiveParameterJson(String value) {
    _mutateActiveTab(
      (tab) => tab.copyWith(parameterJson: value),
      persist: true,
    );
  }

  Future<void> _reopenMostRecentWorkspaceIfAvailable() async {
    final lastOpenedPath = config.recentFiles.isEmpty
        ? null
        : config.recentFiles.first.trim();
    if (lastOpenedPath == null || lastOpenedPath.isEmpty) {
      return;
    }

    final file = File(lastOpenedPath);
    try {
      if (!await file.exists()) {
        return;
      }
    } on FileSystemException {
      return;
    }

    await openDatabase(
      lastOpenedPath,
      createIfMissing: false,
      restoreStartupQuery: true,
    );

    if (hasOpenDatabase) {
      return;
    }

    final startupRestoreError = workspaceError;
    await _removeRecentFileFromStartupRestore(lastOpenedPath);
    workspaceError = null;
    workspaceMessage =
        'Ready. Could not reopen ${p.basename(lastOpenedPath)} automatically.';
    final details = <String, Object?>{'removed_recent_file': true};
    if (startupRestoreError != null) {
      details['startup_restore_error'] = startupRestoreError;
    }
    _logWarning(
      'startup_restore',
      'Skipped automatic reopen after the most recent workspace failed to open.',
      databasePath: lastOpenedPath,
      details: details,
    );
  }

  Future<void> _removeRecentFileFromStartupRestore(String path) async {
    if (!config.recentFiles.contains(path)) {
      return;
    }

    final updatedRecentFiles = config.recentFiles
        .where((item) => item != path)
        .toList();
    config = config.copyWith(recentFiles: updatedRecentFiles);

    try {
      await _configStore.save(config);
    } catch (error, stackTrace) {
      _logWarning(
        'startup_restore',
        'Failed to prune a startup workspace that could not be reopened.',
        category: 'config',
        databasePath: path,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void updateActiveExportPath(String value) {
    _mutateActiveTab((tab) => tab.copyWith(exportPath: value), persist: true);
  }

  void selectTab(String tabId) {
    if (tabById(tabId) == null || activeTabId == tabId) {
      return;
    }
    _activeTabId = tabId;
    _scheduleWorkspaceStateSave();
    _safeNotify();
  }

  void nextTab() {
    if (tabs.length < 2) {
      return;
    }
    final currentIndex = tabs.indexWhere((tab) => tab.id == activeTabId);
    final nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % tabs.length;
    selectTab(tabs[nextIndex].id);
  }

  void previousTab() {
    if (tabs.length < 2) {
      return;
    }
    final currentIndex = tabs.indexWhere((tab) => tab.id == activeTabId);
    final nextIndex = currentIndex <= 0 ? tabs.length - 1 : currentIndex - 1;
    selectTab(tabs[nextIndex].id);
  }

  void loadHistoryEntryIntoActiveTab(
    QueryHistoryEntry entry, {
    bool openInNewTab = false,
  }) {
    loadHistoryEntryIntoTab(activeTabId, entry, openInNewTab: openInNewTab);
  }

  void loadHistoryEntryIntoTab(
    String tabId,
    QueryHistoryEntry entry, {
    bool openInNewTab = false,
  }) {
    if (openInNewTab) {
      createTab(sql: entry.sql);
      tabId = activeTabId;
    }
    _mutateTab(
      tabId,
      (tab) => tab.copyWith(sql: entry.sql, parameterJson: entry.parameterJson),
      persist: true,
    );
  }

  Future<void> rerunHistoryEntry(
    QueryHistoryEntry entry, {
    bool openInNewTab = false,
  }) async {
    loadHistoryEntryIntoActiveTab(entry, openInNewTab: openInNewTab);
    await runActiveTab();
  }

  void clearActiveTabHistory() {
    clearTabHistory(activeTabId);
  }

  void clearTabHistory(String tabId) {
    _mutateTab(
      tabId,
      (tab) => tab.copyWith(queryHistory: const <QueryHistoryEntry>[]),
      persist: true,
    );
  }

  Future<SavedQuery?> saveActiveQuery({
    required String name,
    String description = '',
    String folder = '',
    List<String> tags = const <String>[],
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      workspaceError = 'Saved query name is required.';
      workspaceMessage = null;
      _safeNotify();
      return null;
    }
    if (!hasOpenDatabase) {
      workspaceError = 'Open a DecentDB file before saving queries.';
      workspaceMessage = null;
      _safeNotify();
      return null;
    }
    final sql = activeTab.sql.trim();
    if (sql.isEmpty) {
      workspaceError = 'Enter SQL before saving a query.';
      workspaceMessage = null;
      _safeNotify();
      return null;
    }

    final now = DateTime.now().toUtc();
    final query = SavedQuery(
      id: _createSavedQueryId(),
      name: trimmedName,
      description: description.trim(),
      folder: folder.trim(),
      tags: <String>[
        for (final tag in tags)
          if (tag.trim().isNotEmpty) tag.trim(),
      ],
      sql: activeTab.sql,
      parameterJson: activeTab.parameterJson,
      createdAt: now,
      updatedAt: now,
      schemaFingerprint: toolingMetadata?.schemaFingerprint,
      schemaFingerprintAlgorithm: toolingMetadata?.schemaFingerprintAlgorithm,
      queryContract: activeTab.queryContract,
    );
    savedQueryLibrary = savedQueryLibrary.upsert(query);
    await _persistSavedQueryLibrary();
    workspaceError = null;
    workspaceMessage = 'Saved query "${query.name}".';
    _safeNotify();
    return query;
  }

  void loadSavedQueryIntoActiveTab(
    SavedQuery query, {
    bool openInNewTab = false,
  }) {
    loadSavedQuery(query.id, openInNewTab: openInNewTab);
  }

  void loadSavedQuery(String queryId, {bool openInNewTab = false}) {
    final query = savedQueryLibrary.queryById(queryId);
    if (query == null) {
      workspaceError = 'Saved query not found.';
      workspaceMessage = null;
      _safeNotify();
      return;
    }
    if (openInNewTab) {
      createTab(sql: query.sql);
    }
    _mutateActiveTab(
      (tab) => tab.copyWith(
        sql: query.sql,
        parameterJson: query.parameterJson,
        queryContract: query.queryContract,
      ),
      persist: true,
    );
    workspaceError = null;
    workspaceMessage = query.hasSchemaDrift(toolingMetadata)
        ? 'Loaded "${query.name}" with a schema drift warning.'
        : 'Loaded saved query "${query.name}".';
    _safeNotify();
  }

  Future<void> deleteSavedQuery(String queryId) async {
    final query = savedQueryLibrary.queryById(queryId);
    savedQueryLibrary = savedQueryLibrary.remove(queryId);
    await _persistSavedQueryLibrary();
    workspaceError = null;
    workspaceMessage = query == null
        ? 'Saved query library updated.'
        : 'Deleted saved query "${query.name}".';
    _safeNotify();
  }

  void createTab({String? sql}) {
    final title = _newTabTitle();
    final tab = QueryTabState.initial(
      id: _newTabId(),
      title: title,
      sql: sql ?? 'SELECT 1 AS ready;',
      exportPath: _suggestExportPathForTitle(title),
    );
    tabs = <QueryTabState>[...tabs, tab];
    _activeTabId = tab.id;
    _scheduleWorkspaceStateSave();
    _safeNotify();
  }

  Future<void> closeTab(String tabId) async {
    final closing = tabById(tabId);
    if (closing == null) {
      return;
    }

    final closingIndex = tabs.indexWhere((tab) => tab.id == tabId);

    if (closing.cursorId != null) {
      try {
        await _gateway.cancelQuery(closing.cursorId!);
      } catch (_) {
        // Best-effort cleanup.
      }
    }

    final remaining = tabs.where((tab) => tab.id != tabId).toList();
    if (remaining.isEmpty) {
      _resetTabs(notify: false);
    } else {
      tabs = remaining;
      if (_activeTabId == tabId) {
        final nextIndex = closingIndex.clamp(0, remaining.length - 1);
        _activeTabId = remaining[nextIndex].id;
      }
    }

    _scheduleWorkspaceStateSave();
    _safeNotify();
  }

  Future<void> runActiveTab() => runTab(activeTabId);

  Future<void> runActiveSql(
    String sql, {
    int bufferStartOffset = 0,
    String description = 'selected SQL',
  }) => runTab(
    activeTabId,
    sqlOverride: sql,
    sqlBufferStartOffset: bufferStartOffset,
    sqlOverrideDescription: description,
  );

  Future<void> runTab(
    String tabId, {
    String? sqlOverride,
    int sqlBufferStartOffset = 0,
    String sqlOverrideDescription = 'selected SQL',
  }) async {
    final stopwatch = Stopwatch()..start();
    final tab = tabById(tabId);
    if (tab == null || !canRunTab(tabId)) {
      return;
    }
    if (!hasOpenDatabase) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.validation,
          message: 'Open or create a DecentDB file before running SQL.',
        ),
      );
      return;
    }

    final effectiveSourceSql = sqlOverride ?? tab.sql;
    final trimmedSql = effectiveSourceSql.trim();
    final isAlternateSql = sqlOverride != null;
    final effectiveBufferStartOffset = isAlternateSql
        ? sqlBufferStartOffset
        : effectiveSourceSql.length - effectiveSourceSql.trimLeft().length;
    if (trimmedSql.isEmpty) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.validation,
          message: 'Enter SQL before pressing Run.',
        ),
      );
      return;
    }

    final params = _parseParameters(tabId, tab.parameterJson);
    if (params == null) {
      return;
    }

    final startedAt = DateTime.now();
    final generation = tab.executionGeneration + 1;
    final previousCursor = tab.cursorId;
    _mutateTab(
      tabId,
      (current) => current.copyWith(
        phase: QueryPhase.opening,
        resultColumns: const <String>[],
        resultRows: const <Map<String, Object?>>[],
        cursorId: null,
        error: null,
        statusMessage: isAlternateSql
            ? 'Executing $sqlOverrideDescription...'
            : 'Executing SQL...',
        lastSql: trimmedSql,
        lastParameterJson: tab.parameterJson,
        lastParams: params,
        lastRunStartedAt: startedAt,
        rowsAffected: null,
        elapsed: null,
        hasMoreRows: false,
        isResultPartial: false,
        executionGeneration: generation,
        executionPlan: const QueryExecutionPlanState.loading(),
        queryContract: null,
        messageHistory: _appendMessage(
          current.messageHistory,
          QueryMessageLevel.info,
          isAlternateSql
              ? 'Executing $sqlOverrideDescription...'
              : 'Executing SQL...',
          timestamp: startedAt,
        ),
      ),
      notify: false,
    );
    _safeNotify();
    _logInfo(
      'run_query',
      isAlternateSql
          ? 'Executing $sqlOverrideDescription.'
          : 'Executing SQL buffer.',
      category: 'query',
      databasePath: databasePath,
      sql: trimmedSql,
      details: <String, Object?>{
        'tab_id': tabId,
        'execution_target': isAlternateSql ? sqlOverrideDescription : 'buffer',
        'parameter_count': params.length,
      },
    );

    if (previousCursor != null) {
      unawaited(_gateway.cancelQuery(previousCursor));
    }

    try {
      final queryContract = await _gateway.describeQueryContract(trimmedSql);
      if (!_isCurrentGeneration(tabId, generation)) {
        return;
      }
      _mutateTab(
        tabId,
        (current) => current.copyWith(queryContract: queryContract),
        notify: false,
      );
      if (_validateQueryContractParameters(
        tabId: tabId,
        contract: queryContract,
        parameterValues: params,
      )) {
        final page = await _gateway.runQuery(
          sql: trimmedSql,
          params: params,
          pageSize: config.defaultPageSize,
        );
        if (!_isCurrentGeneration(tabId, generation)) {
          if (page.cursorId != null) {
            unawaited(_gateway.cancelQuery(page.cursorId!));
          }
          return;
        }

        _mutateTab(tabId, (current) {
          final statusMessage = page.rowsAffected != null
              ? 'Statement completed with ${page.rowsAffected} affected rows.'
              : 'Loaded ${page.rows.length} rows from the first page.';
          final explainsCurrentSql = _isExplainSql(trimmedSql);
          final shouldLoadExecutionPlan = _shouldLoadExecutionPlan(
            sql: trimmedSql,
            page: page,
          );
          final updated = _applyFirstPage(
            current,
            page,
            queryContract: queryContract,
            statusMessage: statusMessage,
          );
          final withPlan = explainsCurrentSql
              ? updated.copyWith(
                  executionPlan: QueryExecutionPlanState(
                    columns: page.columns,
                    rows: page.rows,
                    isLoading: !page.done,
                  ),
                )
              : shouldLoadExecutionPlan
              ? updated
              : updated.copyWith(
                  executionPlan: const QueryExecutionPlanState.idle().copyWith(
                    errorMessage:
                        'Execution plan is only available for statements that return rows.',
                  ),
                );
          final withMessage = withPlan.copyWith(
            messageHistory: _appendMessage(
              withPlan.messageHistory,
              QueryMessageLevel.info,
              statusMessage,
            ),
          );
          if (!page.done) {
            _logger.logQueryTiming(
              databasePath: databasePath ?? '',
              sql: trimmedSql,
              rowCount: page.rows.length,
              rowsAffected: page.rowsAffected,
              elapsedNanos: _durationToNanos(page.elapsed),
              operation: 'query.first_page',
              details: <String, Object?>{
                'tab_id': tabId,
                'has_more_rows': true,
              },
            );
            return withMessage;
          }
          _logger.logQueryTiming(
            databasePath: databasePath ?? '',
            sql: trimmedSql,
            rowCount: withMessage.resultRows.length,
            rowsAffected: withMessage.rowsAffected,
            elapsedNanos: _durationToNanos(withMessage.elapsed ?? page.elapsed),
            details: <String, Object?>{'tab_id': tabId, 'has_more_rows': false},
          );
          return withMessage.copyWith(
            queryHistory: _appendQueryHistory(
              withMessage.queryHistory,
              _buildQueryHistoryEntry(
                withMessage,
                outcome: QueryHistoryOutcome.completed,
                rowsLoaded: withMessage.resultRows.length,
                rowsAffected: withMessage.rowsAffected,
                elapsed: withMessage.elapsed,
              ),
            ),
          );
        }, notify: false);
        if (_shouldLoadExecutionPlan(sql: trimmedSql, page: page)) {
          unawaited(
            _loadExecutionPlanForTab(
              tabId,
              generation: generation,
              sql: trimmedSql,
              params: params,
            ),
          );
        }
        return;
      }
    } catch (error) {
      if (_isCurrentGeneration(tabId, generation)) {
        _mutateTab(tabId, (current) {
          final failure = QueryErrorDetails.fromError(
            error,
            stage: QueryErrorStage.opening,
            executedSql: trimmedSql,
            bufferText: tab.sql,
            bufferStartOffset: effectiveBufferStartOffset,
          );
          final updated = current.copyWith(
            phase: QueryPhase.failed,
            error: failure,
            statusMessage: null,
            cursorId: null,
            hasMoreRows: false,
            executionPlan: current.executionPlan.copyWith(
              isLoading: false,
              errorMessage:
                  'Execution plan unavailable because the query did not complete.',
            ),
            messageHistory: _appendMessage(
              current.messageHistory,
              QueryMessageLevel.error,
              '${failure.stageLabel}: ${failure.message}',
            ),
          );
          return updated.copyWith(
            queryHistory: _appendQueryHistory(
              updated.queryHistory,
              _buildQueryHistoryEntry(
                updated,
                outcome: QueryHistoryOutcome.failed,
                errorMessage: failure.message,
                rowsLoaded: updated.resultRows.length,
                rowsAffected: updated.rowsAffected,
                elapsed: updated.elapsed,
              ),
            ),
          );
        }, notify: false);
        _logError(
          'run_query',
          'Query execution failed.',
          category: 'query',
          databasePath: databasePath,
          sql: trimmedSql,
          elapsedNanos: _durationToNanos(stopwatch.elapsed),
          error: error,
          details: <String, Object?>{
            'tab_id': tabId,
            'execution_target': isAlternateSql
                ? sqlOverrideDescription
                : 'buffer',
          },
        );
      }
    } finally {
      _safeNotify();
    }
  }

  Future<void> fetchNextPage({String? tabId}) async {
    final resolvedTabId = tabId ?? activeTabId;
    final tab = tabById(resolvedTabId);
    if (tab == null ||
        tab.cursorId == null ||
        tab.phase == QueryPhase.fetching ||
        !tab.hasMoreRows) {
      return;
    }

    final generation = tab.executionGeneration;
    _mutateTab(
      resolvedTabId,
      (current) => current.copyWith(
        phase: QueryPhase.fetching,
        error: null,
        statusMessage: 'Loading the next page...',
      ),
      notify: false,
    );
    _safeNotify();
    final stopwatch = Stopwatch()..start();
    _logDebug(
      'fetch_page',
      'Fetching next result page.',
      category: 'query',
      databasePath: databasePath,
      sql: tab.lastSql ?? tab.sql,
      details: <String, Object?>{
        'tab_id': resolvedTabId,
        'cursor_id': tab.cursorId,
      },
    );

    try {
      final page = await _gateway.fetchNextPage(
        cursorId: tab.cursorId!,
        pageSize: config.defaultPageSize,
      );
      if (!_isCurrentGeneration(resolvedTabId, generation)) {
        if (page.cursorId != null) {
          unawaited(_gateway.cancelQuery(page.cursorId!));
        }
        return;
      }

      _mutateTab(resolvedTabId, (current) {
        final rowCount = current.resultRows.length + page.rows.length;
        final statusMessage = page.done
            ? 'Loaded $rowCount total rows.'
            : 'Loaded $rowCount rows so far.';
        final updated = current.copyWith(
          phase: QueryPhase.completed,
          resultRows: <Map<String, Object?>>[
            ...current.resultRows,
            ...page.rows,
          ],
          cursorId: page.cursorId,
          hasMoreRows: !page.done,
          elapsed: (current.elapsed ?? Duration.zero) + page.elapsed,
          statusMessage: statusMessage,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.info,
            statusMessage,
          ),
        );
        final withPlan = _isExplainSql(current.lastSql ?? current.sql)
            ? updated.copyWith(
                executionPlan: updated.executionPlan.copyWith(
                  columns: updated.resultColumns,
                  rows: updated.resultRows,
                  isLoading: !page.done,
                  errorMessage: null,
                ),
              )
            : updated;
        if (!page.done) {
          return withPlan;
        }
        _logger.logQueryTiming(
          databasePath: databasePath ?? '',
          sql: withPlan.lastSql ?? withPlan.sql,
          rowCount: withPlan.resultRows.length,
          rowsAffected: withPlan.rowsAffected,
          elapsedNanos: _durationToNanos(withPlan.elapsed ?? page.elapsed),
          details: <String, Object?>{
            'tab_id': resolvedTabId,
            'completed_via_fetch': true,
          },
        );
        return withPlan.copyWith(
          queryHistory: _appendQueryHistory(
            withPlan.queryHistory,
            _buildQueryHistoryEntry(
              withPlan,
              outcome: QueryHistoryOutcome.completed,
              rowsLoaded: withPlan.resultRows.length,
              rowsAffected: withPlan.rowsAffected,
              elapsed: withPlan.elapsed,
            ),
          ),
        );
      }, notify: false);
    } catch (error) {
      if (_isCurrentGeneration(resolvedTabId, generation)) {
        _mutateTab(resolvedTabId, (current) {
          final failure = QueryErrorDetails.fromError(
            error,
            stage: QueryErrorStage.paging,
          );
          final updated = current.copyWith(
            phase: QueryPhase.failed,
            error: failure,
            statusMessage: null,
            cursorId: null,
            hasMoreRows: false,
            executionPlan: _isExplainSql(current.lastSql ?? current.sql)
                ? current.executionPlan.copyWith(
                    isLoading: false,
                    errorMessage: failure.message,
                  )
                : current.executionPlan,
            messageHistory: _appendMessage(
              current.messageHistory,
              QueryMessageLevel.error,
              '${failure.stageLabel}: ${failure.message}',
            ),
          );
          return updated.copyWith(
            queryHistory: _appendQueryHistory(
              updated.queryHistory,
              _buildQueryHistoryEntry(
                updated,
                outcome: QueryHistoryOutcome.failed,
                errorMessage: failure.message,
                rowsLoaded: updated.resultRows.length,
                rowsAffected: updated.rowsAffected,
                elapsed: updated.elapsed,
              ),
            ),
          );
        }, notify: false);
        _logError(
          'fetch_page',
          'Fetching the next query page failed.',
          category: 'query',
          databasePath: databasePath,
          sql: tab.lastSql ?? tab.sql,
          elapsedNanos: _durationToNanos(stopwatch.elapsed),
          error: error,
          details: <String, Object?>{'tab_id': resolvedTabId},
        );
      }
    } finally {
      _safeNotify();
    }
  }

  Future<void> cancelActiveQuery() => cancelTabQuery(activeTabId);

  Future<void> cancelTabQuery(String tabId) async {
    final tab = tabById(tabId);
    if (tab == null || !tab.canCancel) {
      return;
    }

    final stopwatch = Stopwatch()..start();

    final generation = tab.executionGeneration + 1;
    final hasPartialRows = tab.resultRows.isNotEmpty;
    final cursorId = tab.cursorId;
    _mutateTab(
      tabId,
      (current) => current.copyWith(
        phase: QueryPhase.cancelling,
        error: null,
        statusMessage: 'Cancelling query...',
        cursorId: null,
        hasMoreRows: false,
        executionGeneration: generation,
        executionPlan: current.executionPlan.copyWith(isLoading: false),
      ),
      notify: false,
    );
    _safeNotify();
    _logWarning(
      'cancel_query',
      'Cancelling active query.',
      category: 'query',
      databasePath: databasePath,
      sql: tab.lastSql ?? tab.sql,
      details: <String, Object?>{'tab_id': tabId},
    );

    if (cursorId != null) {
      try {
        await _gateway.cancelQuery(cursorId);
      } catch (error) {
        if (_isCurrentGeneration(tabId, generation)) {
          _mutateTab(tabId, (current) {
            final failure = QueryErrorDetails.fromError(
              error,
              stage: QueryErrorStage.cancellation,
            );
            final updated = current.copyWith(
              phase: QueryPhase.failed,
              error: failure,
              statusMessage: null,
              messageHistory: _appendMessage(
                current.messageHistory,
                QueryMessageLevel.error,
                '${failure.stageLabel}: ${failure.message}',
              ),
            );
            return updated.copyWith(
              queryHistory: _appendQueryHistory(
                updated.queryHistory,
                _buildQueryHistoryEntry(
                  updated,
                  outcome: QueryHistoryOutcome.failed,
                  errorMessage: failure.message,
                  rowsLoaded: updated.resultRows.length,
                  rowsAffected: updated.rowsAffected,
                  elapsed: updated.elapsed,
                ),
              ),
            );
          }, notify: false);
          _safeNotify();
          _logError(
            'cancel_query',
            'Query cancellation failed.',
            category: 'query',
            databasePath: databasePath,
            sql: tab.lastSql ?? tab.sql,
            elapsedNanos: _durationToNanos(stopwatch.elapsed),
            error: error,
            details: <String, Object?>{'tab_id': tabId},
          );
        }
        return;
      }
    }

    if (_isCurrentGeneration(tabId, generation)) {
      _mutateTab(tabId, (current) {
        final statusMessage = hasPartialRows
            ? 'Query cancelled. Partial results remain visible.'
            : 'Query cancelled before a complete page was loaded.';
        final updated = current.copyWith(
          phase: QueryPhase.cancelled,
          error: null,
          statusMessage: statusMessage,
          isResultPartial: hasPartialRows,
          hasMoreRows: false,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.warning,
            statusMessage,
          ),
        );
        return updated.copyWith(
          queryHistory: _appendQueryHistory(
            updated.queryHistory,
            _buildQueryHistoryEntry(
              updated,
              outcome: QueryHistoryOutcome.cancelled,
              rowsLoaded: updated.resultRows.length,
              rowsAffected: updated.rowsAffected,
              elapsed: updated.elapsed,
            ),
          ),
        );
      }, notify: false);
      _safeNotify();
      _logWarning(
        'cancel_query',
        'Query cancellation completed.',
        category: 'query',
        databasePath: databasePath,
        sql: tab.lastSql ?? tab.sql,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        details: <String, Object?>{
          'tab_id': tabId,
          'partial_results': hasPartialRows,
        },
      );
    }
  }

  Future<void> exportCurrentQuery() => exportTabQuery(activeTabId);

  Future<void> exportCurrentQueryAsJson({
    required String path,
    required String format,
    required bool pretty,
    required bool includeMetadata,
  }) => exportTabQueryAsJson(
    activeTabId,
    path: path,
    format: format,
    pretty: pretty,
    includeMetadata: includeMetadata,
  );

  Future<void> exportCurrentQueryAsExcel({
    required String path,
    required bool includeHeaders,
  }) => exportTabQueryAsExcel(
    activeTabId,
    path: path,
    includeHeaders: includeHeaders,
  );

  Future<void> exportTabQuery(String tabId) async {
    final tab = tabById(tabId);
    if (tab == null) {
      return;
    }

    final stopwatch = Stopwatch()..start();

    final exportPath = tab.exportPath.trim().isEmpty
        ? suggestExportPath(tabId)
        : tab.exportPath.trim();
    if (!tab.canExport) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.export,
          message: 'Run a row-producing query before exporting CSV.',
        ),
      );
      return;
    }
    if (exportPath.isEmpty) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.export,
          message: 'Enter a CSV destination path first.',
        ),
      );
      return;
    }

    _mutateTab(
      tabId,
      (current) => current.copyWith(
        isExporting: true,
        error: null,
        statusMessage: 'Exporting CSV...',
        messageHistory: _appendMessage(
          current.messageHistory,
          QueryMessageLevel.info,
          'Exporting CSV...',
        ),
      ),
      notify: false,
    );
    _safeNotify();
    _logInfo(
      'export_csv',
      'Exporting query results to CSV.',
      category: 'export',
      databasePath: databasePath,
      sql: tab.lastSql,
      details: <String, Object?>{
        'tab_id': tabId,
        'path': exportPath,
        ..._queryContractLogDetails(tab.queryContract),
      },
    );

    try {
      final result = await _gateway.exportCsv(
        sql: tab.lastSql!,
        params: tab.lastParams,
        pageSize: config.defaultPageSize,
        path: exportPath,
        delimiter: config.csvDelimiter,
        includeHeaders: config.csvIncludeHeaders,
      );
      _mutateTab(tabId, (current) {
        final statusMessage =
            'Exported ${result.rowCount} rows to ${result.path}.';
        return current.copyWith(
          isExporting: false,
          statusMessage: statusMessage,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.info,
            statusMessage,
          ),
        );
      }, notify: false);
      _logInfo(
        'export_csv',
        'CSV export completed.',
        category: 'export',
        databasePath: databasePath,
        sql: tab.lastSql,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        rowCount: result.rowCount,
        details: <String, Object?>{
          'tab_id': tabId,
          'path': result.path,
          ..._queryContractLogDetails(tab.queryContract),
        },
      );
    } catch (error) {
      _mutateTab(tabId, (current) {
        final failure = QueryErrorDetails.fromError(
          error,
          stage: QueryErrorStage.export,
        );
        return current.copyWith(
          isExporting: false,
          error: failure,
          statusMessage: null,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.error,
            '${failure.stageLabel}: ${failure.message}',
          ),
        );
      }, notify: false);
      _logError(
        'export_csv',
        'CSV export failed.',
        category: 'export',
        databasePath: databasePath,
        sql: tab.lastSql,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{'tab_id': tabId, 'path': exportPath},
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> exportTabQueryAsJson(
    String tabId, {
    required String path,
    required String format,
    required bool pretty,
    required bool includeMetadata,
  }) async {
    final tab = tabById(tabId);
    if (tab == null) {
      return;
    }
    final exportPath = path.trim();
    final stopwatch = Stopwatch()..start();
    if (!tab.canExport) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.export,
          message: 'Run a row-producing query before exporting JSON.',
        ),
      );
      return;
    }
    if (exportPath.isEmpty) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.export,
          message: 'Enter a JSON destination path first.',
        ),
      );
      return;
    }

    _mutateTab(
      tabId,
      (current) => current.copyWith(
        isExporting: true,
        error: null,
        statusMessage: 'Exporting ${format.toUpperCase()}...',
        messageHistory: _appendMessage(
          current.messageHistory,
          QueryMessageLevel.info,
          'Exporting ${format.toUpperCase()}...',
        ),
      ),
      notify: false,
    );
    _safeNotify();
    _logInfo(
      'export_json',
      'Exporting query results to JSON.',
      category: 'export',
      databasePath: databasePath,
      sql: tab.lastSql,
      details: <String, Object?>{
        'tab_id': tabId,
        'path': exportPath,
        'format': format,
        'pretty': pretty,
        'include_metadata': includeMetadata,
        ..._queryContractLogDetails(tab.queryContract),
      },
    );

    try {
      final result = await _gateway.exportJson(
        sql: tab.lastSql!,
        params: tab.lastParams,
        pageSize: config.defaultPageSize,
        path: exportPath,
        format: format,
        pretty: pretty,
        includeMetadata: includeMetadata,
      );
      _mutateTab(tabId, (current) {
        final statusMessage =
            'Exported ${result.rowCount} rows to ${result.path}.';
        return current.copyWith(
          isExporting: false,
          statusMessage: statusMessage,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.info,
            statusMessage,
          ),
        );
      }, notify: false);
      _logInfo(
        'export_json',
        'JSON export completed.',
        category: 'export',
        databasePath: databasePath,
        sql: tab.lastSql,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        rowCount: result.rowCount,
        details: <String, Object?>{
          'tab_id': tabId,
          'path': result.path,
          'format': format,
          'include_metadata': includeMetadata,
          ..._queryContractLogDetails(tab.queryContract),
        },
      );
    } catch (error) {
      _mutateTab(tabId, (current) {
        final failure = QueryErrorDetails.fromError(
          error,
          stage: QueryErrorStage.export,
        );
        return current.copyWith(
          isExporting: false,
          error: failure,
          statusMessage: null,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.error,
            '${failure.stageLabel}: ${failure.message}',
          ),
        );
      }, notify: false);
      _logError(
        'export_json',
        'JSON export failed.',
        category: 'export',
        databasePath: databasePath,
        sql: tab.lastSql,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{
          'tab_id': tabId,
          'path': exportPath,
          'format': format,
        },
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> exportTabQueryAsExcel(
    String tabId, {
    required String path,
    required bool includeHeaders,
  }) async {
    final tab = tabById(tabId);
    if (tab == null) {
      return;
    }
    final exportPath = path.trim();
    final stopwatch = Stopwatch()..start();
    if (!tab.canExport) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.export,
          message: 'Run a row-producing query before exporting Excel.',
        ),
      );
      return;
    }
    if (exportPath.isEmpty) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.export,
          message: 'Enter an Excel destination path first.',
        ),
      );
      return;
    }

    _mutateTab(
      tabId,
      (current) => current.copyWith(
        isExporting: true,
        error: null,
        statusMessage: 'Exporting Excel...',
        messageHistory: _appendMessage(
          current.messageHistory,
          QueryMessageLevel.info,
          'Exporting Excel...',
        ),
      ),
      notify: false,
    );
    _safeNotify();
    _logInfo(
      'export_excel',
      'Exporting query results to Excel.',
      category: 'export',
      databasePath: databasePath,
      sql: tab.lastSql,
      details: <String, Object?>{
        'tab_id': tabId,
        'path': exportPath,
        'include_headers': includeHeaders,
        ..._queryContractLogDetails(tab.queryContract),
      },
    );

    try {
      final result = await _gateway.exportExcel(
        sql: tab.lastSql!,
        params: tab.lastParams,
        pageSize: config.defaultPageSize,
        path: exportPath,
        includeHeaders: includeHeaders,
      );
      _mutateTab(tabId, (current) {
        final statusMessage =
            'Exported ${result.rowCount} rows to ${result.path}.';
        return current.copyWith(
          isExporting: false,
          statusMessage: statusMessage,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.info,
            statusMessage,
          ),
        );
      }, notify: false);
      _logInfo(
        'export_excel',
        'Excel export completed.',
        category: 'export',
        databasePath: databasePath,
        sql: tab.lastSql,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        rowCount: result.rowCount,
        details: <String, Object?>{
          'tab_id': tabId,
          'path': result.path,
          'include_headers': includeHeaders,
          ..._queryContractLogDetails(tab.queryContract),
        },
      );
    } catch (error) {
      _mutateTab(tabId, (current) {
        final failure = QueryErrorDetails.fromError(
          error,
          stage: QueryErrorStage.export,
        );
        return current.copyWith(
          isExporting: false,
          error: failure,
          statusMessage: null,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.error,
            '${failure.stageLabel}: ${failure.message}',
          ),
        );
      }, notify: false);
      _logError(
        'export_excel',
        'Excel export failed.',
        category: 'export',
        databasePath: databasePath,
        sql: tab.lastSql,
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{'tab_id': tabId, 'path': exportPath},
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> updateDefaultPageSize(String rawValue) async {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed <= 0) {
      _setWorkspaceError('Page size must be a positive integer.');
      return;
    }

    config = config.copyWith(defaultPageSize: parsed);
    await _persistConfig('Updated default page size to $parsed rows.');
  }

  Future<void> updateCsvDelimiter(String rawValue) async {
    if (rawValue.isEmpty) {
      _setWorkspaceError('CSV delimiter cannot be empty.');
      return;
    }
    config = config.copyWith(csvDelimiter: rawValue);
    await _persistConfig('Updated CSV delimiter.');
  }

  Future<void> updateCsvIncludeHeaders(bool value) async {
    config = config.copyWith(csvIncludeHeaders: value);
    await _persistConfig(
      value
          ? 'CSV exports will include headers.'
          : 'CSV exports will omit headers.',
    );
  }

  Future<void> updateAutocompleteEnabled(bool value) async {
    config = config.copyWith(
      editorSettings: config.editorSettings.copyWith(
        autocompleteEnabled: value,
      ),
    );
    await _persistConfig(
      value ? 'SQL autocomplete enabled.' : 'SQL autocomplete disabled.',
    );
  }

  Future<void> updateAutocompleteMaxSuggestions(String rawValue) async {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed <= 0) {
      _setWorkspaceError(
        'Autocomplete suggestions must be a positive integer.',
      );
      return;
    }
    config = config.copyWith(
      editorSettings: config.editorSettings.copyWith(
        autocompleteMaxSuggestions: parsed,
      ),
    );
    await _persistConfig('Updated autocomplete suggestion limit.');
  }

  Future<void> updateFormatterUppercaseKeywords(bool value) async {
    config = config.copyWith(
      editorSettings: config.editorSettings.copyWith(
        formatUppercaseKeywords: value,
      ),
    );
    await _persistConfig(
      value
          ? 'Formatter will uppercase SQL keywords.'
          : 'Formatter will preserve keyword casing.',
    );
  }

  Future<void> updateEditorIndentSpaces(String rawValue) async {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed <= 0) {
      _setWorkspaceError('Indent spaces must be a positive integer.');
      return;
    }
    config = config.copyWith(
      editorSettings: config.editorSettings.copyWith(indentSpaces: parsed),
    );
    await _persistConfig('Updated SQL formatter indentation.');
  }

  Future<void> saveSnippet(SqlSnippet snippet) async {
    config = config.upsertSnippet(snippet);
    await _persistConfig('Saved snippet "${snippet.name}".');
  }

  Future<void> deleteSnippet(String snippetId) async {
    final existing = config.snippets.where((item) => item.id == snippetId);
    if (existing.isEmpty) {
      return;
    }
    config = config.removeSnippet(snippetId);
    await _persistConfig('Deleted snippet "${existing.first.name}".');
  }

  Future<void> updateShellPreferences(
    WorkspaceShellPreferences preferences, {
    String? statusMessage,
  }) async {
    config = _layoutPersistenceService.save(config, preferences);
    await _persistConfig(statusMessage);
  }

  Future<void> reloadConfig() async {
    try {
      config = await _configStore.load();
      _logger.updateMinimumLevel(config.logging.verbosity);
      workspaceError = null;
      _logInfo(
        'reload_config',
        'Reloaded application configuration.',
        category: 'config',
        details: <String, Object?>{
          'theme_id': config.appearance.activeTheme,
          'verbosity': config.logging.verbosity.name,
        },
      );
      _safeNotify();
    } catch (error) {
      _setWorkspaceError(error.toString());
      _logError(
        'reload_config',
        'Reloading application configuration failed.',
        category: 'config',
        error: error,
      );
    }
  }

  Future<bool> applyAppConfig(AppConfig next, {String? statusMessage}) async {
    final validationError = _validateAppConfig(next);
    if (validationError != null) {
      _setWorkspaceError(validationError);
      return false;
    }

    config = next.copyWith(
      configVersion: AppConfig.currentConfigVersion,
      shellPreferences: next.shellPreferences.normalized(),
    );
    _trimQueryHistoriesToLimit();
    await _persistConfig(statusMessage ?? 'Updated application preferences.');
    _logger.updateMinimumLevel(config.logging.verbosity);
    if (workspaceError == null) {
      _logInfo(
        'apply_config',
        'Applied application configuration changes.',
        category: 'config',
        details: <String, Object?>{
          'theme_id': config.appearance.activeTheme,
          'verbosity': config.logging.verbosity.name,
          'show_line_numbers': config.editorSettings.showLineNumbers,
        },
      );
    }
    return workspaceError == null;
  }

  Future<OperationalMetricsSnapshot> loadOperationalMetrics({
    int maxRows = 20,
  }) async {
    if (!hasOpenDatabase) {
      return OperationalMetricsSnapshot.empty();
    }
    try {
      return await _gateway.loadOperationalMetrics(maxRows: maxRows);
    } catch (error, stackTrace) {
      _logWarning(
        'load_operational_metrics',
        'Loading DecentDB operational metrics failed.',
        category: 'diagnostics',
        databasePath: databasePath,
        error: error,
        stackTrace: stackTrace,
      );
      return OperationalMetricsSnapshot.empty();
    }
  }

  void beginExcelImport({String sourcePath = ''}) {
    final trimmedSource = sourcePath.trim();
    excelImportSession = ExcelImportSession.initial(sourcePath: trimmedSource)
        .copyWith(
          targetPath: trimmedSource.isEmpty
              ? ''
              : _suggestImportTargetPath(trimmedSource),
        );
    _safeNotify();
    _logInfo(
      'begin_excel_import',
      'Opened Excel import workflow.',
      category: 'import.excel',
      details: <String, Object?>{'source_path': trimmedSource},
    );
    if (trimmedSource.isNotEmpty) {
      unawaited(loadExcelImportSource(trimmedSource));
    }
  }

  void closeExcelImportSession() {
    if (excelImportSession?.phase == ExcelImportJobPhase.running ||
        excelImportSession?.phase == ExcelImportJobPhase.cancelling) {
      return;
    }
    excelImportSession = null;
    _safeNotify();
  }

  Future<void> loadExcelImportSource(String rawPath) async {
    final stopwatch = Stopwatch()..start();
    final normalized = rawPath.trim();
    if (normalized.isEmpty) {
      _setExcelImportError('Choose an Excel workbook first.');
      return;
    }

    final session =
        excelImportSession ??
        ExcelImportSession.initial(sourcePath: normalized);
    excelImportSession = session.copyWith(
      phase: ExcelImportJobPhase.inspecting,
      sourcePath: normalized,
      targetPath: session.targetPath.trim().isEmpty
          ? _suggestImportTargetPath(normalized)
          : session.targetPath,
      sheets: const <ExcelImportSheetDraft>[],
      warnings: const <String>[],
      focusedSheet: null,
      progress: null,
      summary: null,
      error: null,
      jobId: null,
    );
    _safeNotify();

    try {
      final inspection = await _gateway.inspectExcelSource(
        sourcePath: normalized,
        headerRow: session.headerRow,
      );
      final focused = inspection.sheets.where((sheet) => sheet.selected).isEmpty
          ? (inspection.sheets.isEmpty
                ? null
                : inspection.sheets.first.sourceName)
          : inspection.sheets.firstWhere((sheet) => sheet.selected).sourceName;
      excelImportSession = excelImportSession?.copyWith(
        phase: ExcelImportJobPhase.ready,
        sourcePath: inspection.sourcePath,
        headerRow: inspection.headerRow,
        sheets: inspection.sheets,
        warnings: inspection.warnings,
        focusedSheet: focused,
        error: inspection.sheets.isEmpty
            ? 'No worksheets were found in the selected workbook.'
            : null,
      );
      _logInfo(
        'inspect_excel_source',
        'Loaded Excel import inspection.',
        category: 'import.excel',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        details: buildImportInspectionLogDetails(
          sourcePath: inspection.sourcePath,
          tableCount: inspection.sheets.length,
          warnings: inspection.warnings,
          extra: <String, Object?>{'header_row': inspection.headerRow},
        ),
      );
      if (inspection.warnings.isNotEmpty) {
        _logWarning(
          'inspect_excel_source_warnings',
          'Excel inspection produced warnings.',
          category: 'import.excel',
          elapsedNanos: _durationToNanos(stopwatch.elapsed),
          details: buildImportInspectionLogDetails(
            sourcePath: inspection.sourcePath,
            tableCount: inspection.sheets.length,
            warnings: inspection.warnings,
            extra: <String, Object?>{'header_row': inspection.headerRow},
          ),
        );
      }
      _safeNotify();
    } catch (error) {
      _setExcelImportError(error.toString(), phase: ExcelImportJobPhase.failed);
      _logError(
        'inspect_excel_source',
        'Excel source inspection failed.',
        category: 'import.excel',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{'source_path': normalized},
      );
    }
  }

  Future<void> updateExcelImportHeaderRow(bool value) async {
    final session = excelImportSession;
    if (session == null) {
      return;
    }
    excelImportSession = session.copyWith(headerRow: value, error: null);
    _safeNotify();
    if (session.sourcePath.trim().isNotEmpty) {
      await loadExcelImportSource(session.sourcePath);
    }
  }

  void setExcelImportStep(ExcelImportWizardStep step) {
    final session = excelImportSession;
    if (session == null) {
      return;
    }
    excelImportSession = session.copyWith(step: step, error: null);
    _safeNotify();
  }

  void updateExcelImportTargetPath(String value) {
    final session = excelImportSession;
    if (session == null) {
      return;
    }
    excelImportSession = session.copyWith(targetPath: value, error: null);
    _safeNotify();
  }

  void updateExcelImportIntoExistingTarget(bool value) {
    final session = excelImportSession;
    if (session == null) {
      return;
    }
    excelImportSession = session.copyWith(
      importIntoExistingTarget: value,
      replaceExistingTarget: value ? false : session.replaceExistingTarget,
      error: null,
    );
    _safeNotify();
  }

  void updateExcelImportReplaceExistingTarget(bool value) {
    final session = excelImportSession;
    if (session == null || session.importIntoExistingTarget) {
      return;
    }
    excelImportSession = session.copyWith(
      replaceExistingTarget: value,
      error: null,
    );
    _safeNotify();
  }

  void toggleExcelImportSheetSelection(String sourceName, bool selected) {
    final session = excelImportSession;
    if (session == null) {
      return;
    }

    final updatedSheets = <ExcelImportSheetDraft>[
      for (final sheet in session.sheets)
        if (sheet.sourceName == sourceName)
          sheet.copyWith(selected: selected)
        else
          sheet,
    ];
    String? focused;
    if (updatedSheets.any(
      (sheet) => sheet.sourceName == session.focusedSheet && sheet.selected,
    )) {
      focused = session.focusedSheet;
    } else {
      for (final sheet in updatedSheets) {
        if (sheet.selected) {
          focused = sheet.sourceName;
          break;
        }
      }
    }
    excelImportSession = session.copyWith(
      sheets: updatedSheets,
      focusedSheet: focused,
      error: null,
    );
    _safeNotify();
  }

  void focusExcelImportSheet(String sourceName) {
    final session = excelImportSession;
    if (session == null) {
      return;
    }
    excelImportSession = session.copyWith(focusedSheet: sourceName);
    _safeNotify();
  }

  void renameExcelImportSheet(String sourceName, String targetName) {
    _mutateExcelImportSheet(
      sourceName,
      (sheet) => sheet.copyWith(targetName: targetName),
    );
  }

  void renameExcelImportColumn(
    String sourceSheetName,
    int sourceColumnIndex,
    String targetName,
  ) {
    _mutateExcelImportSheet(
      sourceSheetName,
      (sheet) => sheet.copyWith(
        columns: <ExcelImportColumnDraft>[
          for (final column in sheet.columns)
            if (column.sourceIndex == sourceColumnIndex)
              column.copyWith(targetName: targetName)
            else
              column,
        ],
      ),
    );
  }

  void overrideExcelImportColumnType(
    String sourceSheetName,
    int sourceColumnIndex,
    String targetType,
  ) {
    _mutateExcelImportSheet(
      sourceSheetName,
      (sheet) => sheet.copyWith(
        columns: <ExcelImportColumnDraft>[
          for (final column in sheet.columns)
            if (column.sourceIndex == sourceColumnIndex)
              column.copyWith(targetType: targetType)
            else
              column,
        ],
      ),
    );
  }

  Future<void> runExcelImport() async {
    final stopwatch = Stopwatch()..start();
    final session = excelImportSession;
    if (session == null) {
      return;
    }
    if (session.selectedSheets.isEmpty) {
      _setExcelImportError('Select at least one worksheet to import.');
      return;
    }
    if (!session.canAdvanceFromTransforms) {
      _setExcelImportError(
        'Resolve duplicate or empty target names before starting the import.',
      );
      return;
    }
    if (session.targetPath.trim().isEmpty) {
      _setExcelImportError('Choose a target DecentDB file first.');
      return;
    }

    await _excelImportSubscription?.cancel();
    final jobId = createExcelImportJobId();
    final request = ExcelImportRequest(
      jobId: jobId,
      sourcePath: session.sourcePath,
      targetPath: session.targetPath.trim(),
      importIntoExistingTarget: session.importIntoExistingTarget,
      replaceExistingTarget: session.replaceExistingTarget,
      headerRow: session.headerRow,
      sheets: session.sheets,
    );

    excelImportSession = session.copyWith(
      step: ExcelImportWizardStep.execute,
      phase: ExcelImportJobPhase.running,
      error: null,
      summary: null,
      jobId: jobId,
      progress: ExcelImportProgress(
        jobId: jobId,
        currentSheet: request.selectedSheets.first.targetName,
        completedSheets: 0,
        totalSheets: request.selectedSheets.length,
        currentSheetRowsCopied: 0,
        currentSheetRowCount: request.selectedSheets.first.rowCount,
        totalRowsCopied: 0,
        message: 'Preparing Excel import...',
      ),
    );
    _safeNotify();
    _logInfo(
      'run_excel_import',
      'Starting Excel import.',
      category: 'import.excel',
      details: buildExcelImportRequestLogDetails(request),
    );

    _excelImportSubscription = _gateway.importExcel(request: request).listen((
      update,
    ) {
      final current = excelImportSession;
      if (current == null || current.jobId != update.jobId) {
        return;
      }

      switch (update.kind) {
        case ExcelImportUpdateKind.progress:
          excelImportSession = current.copyWith(
            phase: current.phase == ExcelImportJobPhase.cancelling
                ? ExcelImportJobPhase.cancelling
                : ExcelImportJobPhase.running,
            progress: update.progress,
            error: null,
          );
          break;
        case ExcelImportUpdateKind.completed:
          final summary = update.summary;
          excelImportSession = current.copyWith(
            step: ExcelImportWizardStep.summary,
            phase: ExcelImportJobPhase.completed,
            summary: summary,
            error: null,
          );
          workspaceMessage = summary?.statusMessage;
          workspaceError = null;
          _logInfo(
            'run_excel_import',
            'Excel import completed.',
            category: 'import.excel',
            databasePath: summary?.targetPath,
            rowCount: summary?.totalRowsCopied,
            elapsedNanos: _durationToNanos(stopwatch.elapsed),
            details: summary == null
                ? <String, Object?>{'job_id': update.jobId}
                : buildExcelImportSummaryLogDetails(summary),
          );
          if (summary != null && summary.warnings.isNotEmpty) {
            _logWarning(
              'run_excel_import_warnings',
              'Excel import completed with warnings.',
              category: 'import.excel',
              databasePath: summary.targetPath,
              rowCount: summary.totalRowsCopied,
              elapsedNanos: _durationToNanos(stopwatch.elapsed),
              details: buildExcelImportSummaryLogDetails(summary),
            );
          }
          break;
        case ExcelImportUpdateKind.cancelled:
          final summary = update.summary;
          excelImportSession = current.copyWith(
            step: ExcelImportWizardStep.summary,
            phase: ExcelImportJobPhase.cancelled,
            summary: summary,
            error: null,
          );
          workspaceMessage = summary?.statusMessage;
          workspaceError = null;
          _logWarning(
            'run_excel_import',
            'Excel import was cancelled.',
            category: 'import.excel',
            databasePath: summary?.targetPath,
            rowCount: summary?.totalRowsCopied,
            elapsedNanos: _durationToNanos(stopwatch.elapsed),
            details: summary == null
                ? <String, Object?>{'job_id': update.jobId}
                : buildExcelImportSummaryLogDetails(summary),
          );
          break;
        case ExcelImportUpdateKind.failed:
          final message = update.message ?? 'Excel import failed.';
          excelImportSession = current.copyWith(
            step: ExcelImportWizardStep.summary,
            phase: ExcelImportJobPhase.failed,
            error: message,
          );
          workspaceError = message;
          workspaceMessage = null;
          _logError(
            'run_excel_import',
            'Excel import failed.',
            category: 'import.excel',
            elapsedNanos: _durationToNanos(stopwatch.elapsed),
            details: <String, Object?>{
              'job_id': update.jobId,
              'source_path': current.sourcePath,
              'target_path': current.targetPath,
              'selected_sheet_count': current.selectedSheets.length,
              'message': message,
            },
          );
          break;
      }
      _safeNotify();
    });
  }

  Future<void> cancelExcelImport() async {
    final stopwatch = Stopwatch()..start();
    final session = excelImportSession;
    if (session == null || session.jobId == null) {
      return;
    }
    excelImportSession = session.copyWith(
      phase: ExcelImportJobPhase.cancelling,
      error: null,
    );
    _safeNotify();
    _logWarning(
      'cancel_excel_import',
      'Cancelling Excel import.',
      category: 'import.excel',
      details: <String, Object?>{'job_id': session.jobId},
    );
    try {
      await _gateway.cancelImport(session.jobId!);
    } catch (error) {
      _setExcelImportError(error.toString(), phase: ExcelImportJobPhase.failed);
      _logError(
        'cancel_excel_import',
        'Excel import cancellation failed.',
        category: 'import.excel',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{'job_id': session.jobId},
      );
    }
  }

  Future<void> openExcelImportedDatabaseFromSummary() async {
    final summary = excelImportSession?.summary;
    if (summary == null) {
      return;
    }
    await openDatabase(summary.targetPath, createIfMissing: false);
    excelImportSession = null;
    _safeNotify();
  }

  Future<void> runQueryForExcelImportedTable() async {
    final summary = excelImportSession?.summary;
    if (summary == null) {
      return;
    }
    await openDatabase(summary.targetPath, createIfMissing: false);
    if (summary.firstImportedObject != null) {
      createTab(
        sql:
            'SELECT *\nFROM ${_quoteIdentifier(summary.firstImportedObject!)}\nLIMIT ${config.defaultPageSize};',
      );
    }
    excelImportSession = null;
    _safeNotify();
  }

  void beginSqlDumpImport({String sourcePath = ''}) {
    final trimmedSource = sourcePath.trim();
    sqlDumpImportSession =
        SqlDumpImportSession.initial(sourcePath: trimmedSource).copyWith(
          targetPath: trimmedSource.isEmpty
              ? ''
              : _suggestImportTargetPath(trimmedSource),
        );
    _safeNotify();
    _logInfo(
      'begin_sql_dump_import',
      'Opened SQL dump import workflow.',
      category: 'import.sql_dump',
      details: <String, Object?>{'source_path': trimmedSource},
    );
    if (trimmedSource.isNotEmpty) {
      unawaited(loadSqlDumpImportSource(trimmedSource));
    }
  }

  void closeSqlDumpImportSession() {
    if (sqlDumpImportSession?.phase == SqlDumpImportJobPhase.running ||
        sqlDumpImportSession?.phase == SqlDumpImportJobPhase.cancelling) {
      return;
    }
    sqlDumpImportSession = null;
    _safeNotify();
  }

  Future<void> loadSqlDumpImportSource(String rawPath) async {
    final stopwatch = Stopwatch()..start();
    final normalized = rawPath.trim();
    if (normalized.isEmpty) {
      _setSqlDumpImportError('Choose a SQL dump file first.');
      return;
    }

    final session =
        sqlDumpImportSession ??
        SqlDumpImportSession.initial(sourcePath: normalized);
    sqlDumpImportSession = session.copyWith(
      phase: SqlDumpImportJobPhase.inspecting,
      sourcePath: normalized,
      targetPath: session.targetPath.trim().isEmpty
          ? _suggestImportTargetPath(normalized)
          : session.targetPath,
      tables: const <SqlDumpImportTableDraft>[],
      warnings: const <String>[],
      skippedStatements: const <SqlDumpImportSkippedStatement>[],
      totalStatements: 0,
      focusedTable: null,
      progress: null,
      summary: null,
      error: null,
      jobId: null,
    );
    _safeNotify();

    try {
      final inspection = await _gateway.inspectSqlDumpSource(
        sourcePath: normalized,
        encoding: session.encoding,
      );
      final focused = inspection.tables.isEmpty
          ? null
          : inspection.tables.first.sourceName;
      sqlDumpImportSession = sqlDumpImportSession?.copyWith(
        phase: SqlDumpImportJobPhase.ready,
        sourcePath: inspection.sourcePath,
        encoding: inspection.requestedEncoding,
        resolvedEncoding: inspection.resolvedEncoding,
        tables: inspection.tables,
        warnings: inspection.warnings,
        skippedStatements: inspection.skippedStatements,
        totalStatements: inspection.totalStatements,
        focusedTable: focused,
        error: inspection.tables.isEmpty
            ? 'No supported CREATE TABLE statements were parsed from the selected dump.'
            : null,
      );
      _logInfo(
        'inspect_sql_dump_source',
        'Loaded SQL dump inspection.',
        category: 'import.sql_dump',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        details: buildImportInspectionLogDetails(
          sourcePath: inspection.sourcePath,
          tableCount: inspection.tables.length,
          warnings: inspection.warnings,
          extra: <String, Object?>{
            'skipped_statement_count': inspection.skippedStatements.length,
            'encoding': inspection.resolvedEncoding,
          },
        ),
      );
      if (inspection.warnings.isNotEmpty) {
        _logWarning(
          'inspect_sql_dump_source_warnings',
          'SQL dump inspection produced warnings.',
          category: 'import.sql_dump',
          elapsedNanos: _durationToNanos(stopwatch.elapsed),
          details: buildImportInspectionLogDetails(
            sourcePath: inspection.sourcePath,
            tableCount: inspection.tables.length,
            warnings: inspection.warnings,
            extra: <String, Object?>{
              'skipped_statement_count': inspection.skippedStatements.length,
              'encoding': inspection.resolvedEncoding,
            },
          ),
        );
      }
      _safeNotify();
    } catch (error) {
      _setSqlDumpImportError(
        error.toString(),
        phase: SqlDumpImportJobPhase.failed,
      );
      _logError(
        'inspect_sql_dump_source',
        'SQL dump inspection failed.',
        category: 'import.sql_dump',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{'source_path': normalized},
      );
    }
  }

  Future<void> updateSqlDumpImportEncoding(String value) async {
    final session = sqlDumpImportSession;
    if (session == null) {
      return;
    }
    sqlDumpImportSession = session.copyWith(encoding: value, error: null);
    _safeNotify();
    if (session.sourcePath.trim().isNotEmpty) {
      await loadSqlDumpImportSource(session.sourcePath);
    }
  }

  void setSqlDumpImportStep(SqlDumpImportWizardStep step) {
    final session = sqlDumpImportSession;
    if (session == null) {
      return;
    }
    sqlDumpImportSession = session.copyWith(step: step, error: null);
    _safeNotify();
  }

  void updateSqlDumpImportTargetPath(String value) {
    final session = sqlDumpImportSession;
    if (session == null) {
      return;
    }
    sqlDumpImportSession = session.copyWith(targetPath: value, error: null);
    _safeNotify();
  }

  void updateSqlDumpImportIntoExistingTarget(bool value) {
    final session = sqlDumpImportSession;
    if (session == null) {
      return;
    }
    sqlDumpImportSession = session.copyWith(
      importIntoExistingTarget: value,
      replaceExistingTarget: value ? false : session.replaceExistingTarget,
      error: null,
    );
    _safeNotify();
  }

  void updateSqlDumpImportReplaceExistingTarget(bool value) {
    final session = sqlDumpImportSession;
    if (session == null || session.importIntoExistingTarget) {
      return;
    }
    sqlDumpImportSession = session.copyWith(
      replaceExistingTarget: value,
      error: null,
    );
    _safeNotify();
  }

  void toggleSqlDumpImportTableSelection(String sourceName, bool selected) {
    final session = sqlDumpImportSession;
    if (session == null) {
      return;
    }

    final updatedTables = <SqlDumpImportTableDraft>[
      for (final table in session.tables)
        if (table.sourceName == sourceName)
          table.copyWith(selected: selected)
        else
          table,
    ];
    String? focused;
    if (updatedTables.any(
      (table) => table.sourceName == session.focusedTable && table.selected,
    )) {
      focused = session.focusedTable;
    } else {
      for (final table in updatedTables) {
        if (table.selected) {
          focused = table.sourceName;
          break;
        }
      }
    }
    sqlDumpImportSession = session.copyWith(
      tables: updatedTables,
      focusedTable: focused,
      error: null,
    );
    _safeNotify();
  }

  void focusSqlDumpImportTable(String sourceName) {
    final session = sqlDumpImportSession;
    if (session == null) {
      return;
    }
    sqlDumpImportSession = session.copyWith(focusedTable: sourceName);
    _safeNotify();
  }

  void renameSqlDumpImportTable(String sourceName, String targetName) {
    _mutateSqlDumpImportTable(
      sourceName,
      (table) => table.copyWith(targetName: targetName),
    );
  }

  void renameSqlDumpImportColumn(
    String sourceTableName,
    int sourceColumnIndex,
    String targetName,
  ) {
    _mutateSqlDumpImportTable(
      sourceTableName,
      (table) => table.copyWith(
        columns: <SqlDumpImportColumnDraft>[
          for (final column in table.columns)
            if (column.sourceIndex == sourceColumnIndex)
              column.copyWith(targetName: targetName)
            else
              column,
        ],
      ),
    );
  }

  void overrideSqlDumpImportColumnType(
    String sourceTableName,
    int sourceColumnIndex,
    String targetType,
  ) {
    _mutateSqlDumpImportTable(
      sourceTableName,
      (table) => table.copyWith(
        columns: <SqlDumpImportColumnDraft>[
          for (final column in table.columns)
            if (column.sourceIndex == sourceColumnIndex)
              column.copyWith(targetType: targetType)
            else
              column,
        ],
      ),
    );
  }

  Future<void> runSqlDumpImport() async {
    final stopwatch = Stopwatch()..start();
    final session = sqlDumpImportSession;
    if (session == null) {
      return;
    }
    if (session.selectedTables.isEmpty) {
      _setSqlDumpImportError('Select at least one parsed table to import.');
      return;
    }
    if (!session.canAdvanceFromTransforms) {
      _setSqlDumpImportError(
        'Resolve duplicate or empty target names before starting the import.',
      );
      return;
    }
    if (session.targetPath.trim().isEmpty) {
      _setSqlDumpImportError('Choose a target DecentDB file first.');
      return;
    }

    await _sqlDumpImportSubscription?.cancel();
    final jobId = createSqlDumpImportJobId();
    final request = SqlDumpImportRequest(
      jobId: jobId,
      sourcePath: session.sourcePath,
      targetPath: session.targetPath.trim(),
      importIntoExistingTarget: session.importIntoExistingTarget,
      replaceExistingTarget: session.replaceExistingTarget,
      encoding: session.encoding,
      tables: session.tables,
    );

    sqlDumpImportSession = session.copyWith(
      step: SqlDumpImportWizardStep.execute,
      phase: SqlDumpImportJobPhase.running,
      error: null,
      summary: null,
      jobId: jobId,
      progress: SqlDumpImportProgress(
        jobId: jobId,
        currentTable: request.selectedTables.first.targetName,
        completedTables: 0,
        totalTables: request.selectedTables.length,
        currentTableRowsCopied: 0,
        currentTableRowCount: request.selectedTables.first.rowCount,
        totalRowsCopied: 0,
        message: 'Preparing SQL dump import...',
      ),
    );
    _safeNotify();
    _logInfo(
      'run_sql_dump_import',
      'Starting SQL dump import.',
      category: 'import.sql_dump',
      details: buildSqlDumpImportRequestLogDetails(request),
    );

    _sqlDumpImportSubscription = _gateway
        .importSqlDump(request: request)
        .listen((update) {
          final current = sqlDumpImportSession;
          if (current == null || current.jobId != update.jobId) {
            return;
          }

          switch (update.kind) {
            case SqlDumpImportUpdateKind.progress:
              sqlDumpImportSession = current.copyWith(
                phase: current.phase == SqlDumpImportJobPhase.cancelling
                    ? SqlDumpImportJobPhase.cancelling
                    : SqlDumpImportJobPhase.running,
                progress: update.progress,
                error: null,
              );
              break;
            case SqlDumpImportUpdateKind.completed:
              final summary = update.summary;
              sqlDumpImportSession = current.copyWith(
                step: SqlDumpImportWizardStep.summary,
                phase: SqlDumpImportJobPhase.completed,
                summary: summary,
                error: null,
              );
              workspaceMessage = summary?.statusMessage;
              workspaceError = null;
              _logInfo(
                'run_sql_dump_import',
                'SQL dump import completed.',
                category: 'import.sql_dump',
                databasePath: summary?.targetPath,
                rowCount: summary?.totalRowsCopied,
                elapsedNanos: _durationToNanos(stopwatch.elapsed),
                details: summary == null
                    ? <String, Object?>{'job_id': update.jobId}
                    : buildSqlDumpImportSummaryLogDetails(summary),
              );
              if (summary != null && summary.warnings.isNotEmpty) {
                _logWarning(
                  'run_sql_dump_import_warnings',
                  'SQL dump import completed with warnings.',
                  category: 'import.sql_dump',
                  databasePath: summary.targetPath,
                  rowCount: summary.totalRowsCopied,
                  elapsedNanos: _durationToNanos(stopwatch.elapsed),
                  details: buildSqlDumpImportSummaryLogDetails(summary),
                );
              }
              break;
            case SqlDumpImportUpdateKind.cancelled:
              final summary = update.summary;
              sqlDumpImportSession = current.copyWith(
                step: SqlDumpImportWizardStep.summary,
                phase: SqlDumpImportJobPhase.cancelled,
                summary: summary,
                error: null,
              );
              workspaceMessage = summary?.statusMessage;
              workspaceError = null;
              _logWarning(
                'run_sql_dump_import',
                'SQL dump import was cancelled.',
                category: 'import.sql_dump',
                databasePath: summary?.targetPath,
                rowCount: summary?.totalRowsCopied,
                elapsedNanos: _durationToNanos(stopwatch.elapsed),
                details: summary == null
                    ? <String, Object?>{'job_id': update.jobId}
                    : buildSqlDumpImportSummaryLogDetails(summary),
              );
              break;
            case SqlDumpImportUpdateKind.failed:
              final message = update.message ?? 'SQL dump import failed.';
              sqlDumpImportSession = current.copyWith(
                step: SqlDumpImportWizardStep.summary,
                phase: SqlDumpImportJobPhase.failed,
                error: message,
              );
              workspaceError = message;
              workspaceMessage = null;
              _logError(
                'run_sql_dump_import',
                'SQL dump import failed.',
                category: 'import.sql_dump',
                elapsedNanos: _durationToNanos(stopwatch.elapsed),
                details: <String, Object?>{
                  'job_id': update.jobId,
                  'source_path': current.sourcePath,
                  'target_path': current.targetPath,
                  'selected_table_count': current.selectedTables.length,
                  'message': message,
                },
              );
              break;
          }
          _safeNotify();
        });
  }

  Future<void> cancelSqlDumpImport() async {
    final stopwatch = Stopwatch()..start();
    final session = sqlDumpImportSession;
    if (session == null || session.jobId == null) {
      return;
    }
    sqlDumpImportSession = session.copyWith(
      phase: SqlDumpImportJobPhase.cancelling,
      error: null,
    );
    _safeNotify();
    _logWarning(
      'cancel_sql_dump_import',
      'Cancelling SQL dump import.',
      category: 'import.sql_dump',
      details: <String, Object?>{'job_id': session.jobId},
    );
    try {
      await _gateway.cancelImport(session.jobId!);
    } catch (error) {
      _setSqlDumpImportError(
        error.toString(),
        phase: SqlDumpImportJobPhase.failed,
      );
      _logError(
        'cancel_sql_dump_import',
        'SQL dump import cancellation failed.',
        category: 'import.sql_dump',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{'job_id': session.jobId},
      );
    }
  }

  Future<void> openSqlDumpImportedDatabaseFromSummary() async {
    final summary = sqlDumpImportSession?.summary;
    if (summary == null) {
      return;
    }
    await openDatabase(summary.targetPath, createIfMissing: false);
    sqlDumpImportSession = null;
    _safeNotify();
  }

  Future<void> runQueryForSqlDumpImportedTable() async {
    final summary = sqlDumpImportSession?.summary;
    if (summary == null) {
      return;
    }
    await openDatabase(summary.targetPath, createIfMissing: false);
    if (summary.firstImportedTable != null) {
      createTab(
        sql:
            'SELECT *\nFROM ${_quoteIdentifier(summary.firstImportedTable!)}\nLIMIT ${config.defaultPageSize};',
      );
    }
    sqlDumpImportSession = null;
    _safeNotify();
  }

  void beginSqliteImport({String sourcePath = ''}) {
    final trimmedSource = sourcePath.trim();
    sqliteImportSession = SqliteImportSession.initial(sourcePath: trimmedSource)
        .copyWith(
          targetPath: trimmedSource.isEmpty
              ? ''
              : _suggestImportTargetPath(trimmedSource),
        );
    _safeNotify();
    _logInfo(
      'begin_sqlite_import',
      'Opened SQLite import workflow.',
      category: 'import.sqlite',
      details: <String, Object?>{'source_path': trimmedSource},
    );
    if (trimmedSource.isNotEmpty) {
      unawaited(loadSqliteImportSource(trimmedSource));
    }
  }

  void closeSqliteImportSession() {
    if (sqliteImportSession?.phase == SqliteImportJobPhase.running ||
        sqliteImportSession?.phase == SqliteImportJobPhase.cancelling) {
      return;
    }
    sqliteImportSession = null;
    _safeNotify();
  }

  Future<void> loadSqliteImportSource(String rawPath) async {
    final stopwatch = Stopwatch()..start();
    final normalized = rawPath.trim();
    if (normalized.isEmpty) {
      _setSqliteImportError('Choose a SQLite source file first.');
      return;
    }

    final session =
        sqliteImportSession ??
        SqliteImportSession.initial(sourcePath: normalized);
    sqliteImportSession = session.copyWith(
      phase: SqliteImportJobPhase.inspecting,
      sourcePath: normalized,
      targetPath: session.targetPath.trim().isEmpty
          ? _suggestImportTargetPath(normalized)
          : session.targetPath,
      tables: const <SqliteImportTableDraft>[],
      warnings: const <String>[],
      focusedTable: null,
      progress: null,
      summary: null,
      error: null,
      jobId: null,
      loadingPreviewTable: null,
    );
    _safeNotify();

    try {
      final inspection = await _gateway.inspectSqliteSource(
        sourcePath: normalized,
      );
      final focused = inspection.tables.isEmpty
          ? null
          : inspection.tables.first.sourceName;
      sqliteImportSession = sqliteImportSession?.copyWith(
        phase: SqliteImportJobPhase.ready,
        sourcePath: inspection.sourcePath,
        tables: inspection.tables,
        warnings: inspection.warnings,
        focusedTable: focused,
        error: inspection.tables.isEmpty
            ? 'No user tables were found in the selected SQLite file.'
            : null,
      );
      _logInfo(
        'inspect_sqlite_source',
        'Loaded SQLite source inspection.',
        category: 'import.sqlite',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        details: buildImportInspectionLogDetails(
          sourcePath: inspection.sourcePath,
          tableCount: inspection.tables.length,
          warnings: inspection.warnings,
        ),
      );
      if (inspection.warnings.isNotEmpty) {
        _logWarning(
          'inspect_sqlite_source_warnings',
          'SQLite inspection produced warnings.',
          category: 'import.sqlite',
          elapsedNanos: _durationToNanos(stopwatch.elapsed),
          details: buildImportInspectionLogDetails(
            sourcePath: inspection.sourcePath,
            tableCount: inspection.tables.length,
            warnings: inspection.warnings,
          ),
        );
      }
      _safeNotify();
      if (focused != null) {
        await loadSqliteImportPreview(focused);
      }
    } catch (error) {
      _setSqliteImportError(
        error.toString(),
        phase: SqliteImportJobPhase.failed,
      );
      _logError(
        'inspect_sqlite_source',
        'SQLite source inspection failed.',
        category: 'import.sqlite',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{'source_path': normalized},
      );
    }
  }

  void setSqliteImportStep(SqliteImportWizardStep step) {
    final session = sqliteImportSession;
    if (session == null) {
      return;
    }
    sqliteImportSession = session.copyWith(step: step, error: null);
    _safeNotify();
  }

  void updateSqliteImportTargetPath(String value) {
    final session = sqliteImportSession;
    if (session == null) {
      return;
    }
    sqliteImportSession = session.copyWith(targetPath: value, error: null);
    _safeNotify();
  }

  void updateSqliteImportIntoExistingTarget(bool value) {
    final session = sqliteImportSession;
    if (session == null) {
      return;
    }
    sqliteImportSession = session.copyWith(
      importIntoExistingTarget: value,
      replaceExistingTarget: value ? false : session.replaceExistingTarget,
      error: null,
    );
    _safeNotify();
  }

  void updateSqliteImportReplaceExistingTarget(bool value) {
    final session = sqliteImportSession;
    if (session == null || session.importIntoExistingTarget) {
      return;
    }
    sqliteImportSession = session.copyWith(
      replaceExistingTarget: value,
      error: null,
    );
    _safeNotify();
  }

  void toggleSqliteImportTableSelection(String sourceName, bool selected) {
    final session = sqliteImportSession;
    if (session == null) {
      return;
    }

    final updatedTables = <SqliteImportTableDraft>[
      for (final table in session.tables)
        if (table.sourceName == sourceName)
          table.copyWith(selected: selected)
        else
          table,
    ];
    String? focused;
    if (updatedTables.any(
      (table) => table.sourceName == session.focusedTable && table.selected,
    )) {
      focused = session.focusedTable;
    } else {
      for (final table in updatedTables) {
        if (table.selected) {
          focused = table.sourceName;
          break;
        }
      }
    }
    sqliteImportSession = session.copyWith(
      tables: updatedTables,
      focusedTable: focused,
      error: null,
    );
    _safeNotify();
    if (selected && focused != null) {
      unawaited(loadSqliteImportPreview(focused));
    }
  }

  Future<void> focusSqliteImportTable(String sourceName) async {
    final session = sqliteImportSession;
    if (session == null) {
      return;
    }
    sqliteImportSession = session.copyWith(focusedTable: sourceName);
    _safeNotify();
    await loadSqliteImportPreview(sourceName);
  }

  Future<void> loadSqliteImportPreview(String sourceName) async {
    final session = sqliteImportSession;
    if (session == null || session.sourcePath.trim().isEmpty) {
      return;
    }
    final table = session.tables.where((item) => item.sourceName == sourceName);
    if (table.isEmpty ||
        table.first.previewLoaded ||
        session.loadingPreviewTable == sourceName) {
      return;
    }

    sqliteImportSession = session.copyWith(
      loadingPreviewTable: sourceName,
      error: null,
    );
    _safeNotify();

    try {
      final preview = await _gateway.loadSqlitePreview(
        sourcePath: session.sourcePath,
        tableName: sourceName,
      );
      _mutateSqliteImportTable(
        sourceName,
        (table) => table.copyWith(
          previewRows: preview.rows,
          previewLoaded: true,
          previewError: null,
        ),
      );
    } catch (error) {
      _mutateSqliteImportTable(
        sourceName,
        (table) => table.copyWith(
          previewLoaded: false,
          previewError: error.toString(),
        ),
      );
    } finally {
      sqliteImportSession = sqliteImportSession?.copyWith(
        loadingPreviewTable: null,
      );
      _safeNotify();
    }
  }

  void renameSqliteImportTable(String sourceName, String targetName) {
    _mutateSqliteImportTable(
      sourceName,
      (table) => table.copyWith(targetName: targetName),
    );
  }

  void renameSqliteImportColumn(
    String sourceTableName,
    String sourceColumnName,
    String targetName,
  ) {
    _mutateSqliteImportTable(
      sourceTableName,
      (table) => table.copyWith(
        columns: <SqliteImportColumnDraft>[
          for (final column in table.columns)
            if (column.sourceName == sourceColumnName)
              column.copyWith(targetName: targetName)
            else
              column,
        ],
      ),
    );
  }

  void overrideSqliteImportColumnType(
    String sourceTableName,
    String sourceColumnName,
    String targetType,
  ) {
    _mutateSqliteImportTable(
      sourceTableName,
      (table) => table.copyWith(
        columns: <SqliteImportColumnDraft>[
          for (final column in table.columns)
            if (column.sourceName == sourceColumnName)
              column.copyWith(targetType: targetType)
            else
              column,
        ],
      ),
    );
  }

  Future<void> runSqliteImport() async {
    final stopwatch = Stopwatch()..start();
    final session = sqliteImportSession;
    if (session == null) {
      return;
    }
    if (session.selectedTables.isEmpty) {
      _setSqliteImportError('Select at least one SQLite table to import.');
      return;
    }
    if (!session.canAdvanceFromTransforms) {
      _setSqliteImportError(
        'Resolve duplicate or empty target names before starting the import.',
      );
      return;
    }
    if (session.targetPath.trim().isEmpty) {
      _setSqliteImportError('Choose a target DecentDB file first.');
      return;
    }

    await _sqliteImportSubscription?.cancel();
    final jobId = createSqliteImportJobId();
    final request = SqliteImportRequest(
      jobId: jobId,
      sourcePath: session.sourcePath,
      targetPath: session.targetPath.trim(),
      importIntoExistingTarget: session.importIntoExistingTarget,
      replaceExistingTarget: session.replaceExistingTarget,
      tables: session.tables,
    );

    sqliteImportSession = session.copyWith(
      step: SqliteImportWizardStep.execute,
      phase: SqliteImportJobPhase.running,
      error: null,
      summary: null,
      jobId: jobId,
      progress: SqliteImportProgress(
        jobId: jobId,
        currentTable: request.selectedTables.first.targetName,
        completedTables: 0,
        totalTables: request.selectedTables.length,
        currentTableRowsCopied: 0,
        currentTableRowCount: request.selectedTables.first.rowCount,
        totalRowsCopied: 0,
        message: 'Preparing SQLite import...',
      ),
    );
    _safeNotify();
    _logInfo(
      'run_sqlite_import',
      'Starting SQLite import.',
      category: 'import.sqlite',
      details: buildSqliteImportRequestLogDetails(request),
    );

    _sqliteImportSubscription = _gateway.importSqlite(request: request).listen((
      update,
    ) {
      final current = sqliteImportSession;
      if (current == null || current.jobId != update.jobId) {
        return;
      }

      switch (update.kind) {
        case SqliteImportUpdateKind.progress:
          sqliteImportSession = current.copyWith(
            phase: current.phase == SqliteImportJobPhase.cancelling
                ? SqliteImportJobPhase.cancelling
                : SqliteImportJobPhase.running,
            progress: update.progress,
            error: null,
          );
          break;
        case SqliteImportUpdateKind.completed:
          final summary = update.summary;
          sqliteImportSession = current.copyWith(
            step: SqliteImportWizardStep.summary,
            phase: SqliteImportJobPhase.completed,
            summary: summary,
            error: null,
          );
          workspaceMessage = summary?.statusMessage;
          workspaceError = null;
          _logInfo(
            'run_sqlite_import',
            'SQLite import completed.',
            category: 'import.sqlite',
            databasePath: summary?.targetPath,
            rowCount: summary?.totalRowsCopied,
            elapsedNanos: _durationToNanos(stopwatch.elapsed),
            details: summary == null
                ? <String, Object?>{'job_id': update.jobId}
                : buildSqliteImportSummaryLogDetails(summary),
          );
          if (summary != null && summary.warnings.isNotEmpty) {
            _logWarning(
              'run_sqlite_import_warnings',
              'SQLite import completed with warnings.',
              category: 'import.sqlite',
              databasePath: summary.targetPath,
              rowCount: summary.totalRowsCopied,
              elapsedNanos: _durationToNanos(stopwatch.elapsed),
              details: buildSqliteImportSummaryLogDetails(summary),
            );
          }
          break;
        case SqliteImportUpdateKind.cancelled:
          final summary = update.summary;
          sqliteImportSession = current.copyWith(
            step: SqliteImportWizardStep.summary,
            phase: SqliteImportJobPhase.cancelled,
            summary: summary,
            error: null,
          );
          workspaceMessage = summary?.statusMessage;
          workspaceError = null;
          _logWarning(
            'run_sqlite_import',
            'SQLite import was cancelled.',
            category: 'import.sqlite',
            databasePath: summary?.targetPath,
            rowCount: summary?.totalRowsCopied,
            elapsedNanos: _durationToNanos(stopwatch.elapsed),
            details: summary == null
                ? <String, Object?>{'job_id': update.jobId}
                : buildSqliteImportSummaryLogDetails(summary),
          );
          break;
        case SqliteImportUpdateKind.failed:
          final message = update.message ?? 'SQLite import failed.';
          sqliteImportSession = current.copyWith(
            step: SqliteImportWizardStep.summary,
            phase: SqliteImportJobPhase.failed,
            error: message,
          );
          workspaceError = message;
          workspaceMessage = null;
          _logError(
            'run_sqlite_import',
            'SQLite import failed.',
            category: 'import.sqlite',
            elapsedNanos: _durationToNanos(stopwatch.elapsed),
            details: <String, Object?>{
              'job_id': update.jobId,
              'source_path': current.sourcePath,
              'target_path': current.targetPath,
              'selected_table_count': current.selectedTables.length,
              'message': message,
            },
          );
          break;
      }
      _safeNotify();
    });
  }

  Future<void> cancelSqliteImport() async {
    final stopwatch = Stopwatch()..start();
    final session = sqliteImportSession;
    if (session == null || session.jobId == null) {
      return;
    }
    sqliteImportSession = session.copyWith(
      phase: SqliteImportJobPhase.cancelling,
      error: null,
    );
    _safeNotify();
    _logWarning(
      'cancel_sqlite_import',
      'Cancelling SQLite import.',
      category: 'import.sqlite',
      details: <String, Object?>{'job_id': session.jobId},
    );
    try {
      await _gateway.cancelImport(session.jobId!);
    } catch (error) {
      _setSqliteImportError(
        error.toString(),
        phase: SqliteImportJobPhase.failed,
      );
      _logError(
        'cancel_sqlite_import',
        'SQLite import cancellation failed.',
        category: 'import.sqlite',
        elapsedNanos: _durationToNanos(stopwatch.elapsed),
        error: error,
        details: <String, Object?>{'job_id': session.jobId},
      );
    }
  }

  Future<void> openImportedDatabaseFromSummary() async {
    final summary = sqliteImportSession?.summary;
    if (summary == null) {
      return;
    }
    await openDatabase(summary.targetPath, createIfMissing: false);
    sqliteImportSession = null;
    _safeNotify();
  }

  Future<void> runQueryForImportedTable() async {
    final summary = sqliteImportSession?.summary;
    if (summary == null) {
      return;
    }
    await openDatabase(summary.targetPath, createIfMissing: false);
    if (summary.firstImportedTable != null) {
      createTab(
        sql:
            'SELECT *\nFROM ${_quoteIdentifier(summary.firstImportedTable!)}\nLIMIT ${config.defaultPageSize};',
      );
    }
    sqliteImportSession = null;
    _safeNotify();
  }

  String createSnippetId() =>
      'snippet-${DateTime.now().microsecondsSinceEpoch.toString()}';

  String createExcelImportJobId() =>
      'excel-import-${DateTime.now().microsecondsSinceEpoch}';

  String createSqlDumpImportJobId() =>
      'sql-dump-import-${DateTime.now().microsecondsSinceEpoch}';

  String createSqliteImportJobId() =>
      'sqlite-import-${DateTime.now().microsecondsSinceEpoch}';

  String suggestExportPath([String? tabId]) {
    final tab = tabId == null ? activeTab : tabById(tabId) ?? activeTab;
    return _suggestExportPathForTitle(tab.title);
  }

  String? errorDetailsForTab(String tabId) {
    final tab = tabById(tabId);
    if (tab?.error == null) {
      return null;
    }
    return tab!.error!.toClipboardText(sql: tab.lastSql ?? tab.sql);
  }

  TableEditabilityState tableEditabilityForTab([String? tabId]) {
    final tab = tabId == null ? activeTab : tabById(tabId);
    if (tab == null) {
      return TableEditabilityState.noResults;
    }
    return _tableEditabilityFor(tab);
  }

  Future<TableEditCommitResult> updateResultCell({
    required int rowIndex,
    required String columnName,
    required Object? value,
    String? tabId,
  }) async {
    final resolvedTabId = tabId ?? activeTabId;
    final tab = tabById(resolvedTabId);
    if (tab == null) {
      return const TableEditCommitResult(
        success: false,
        message: 'The selected query tab is no longer available.',
      );
    }

    final editability = _tableEditabilityFor(tab);
    final tableName = editability.tableName;
    final primaryKeyColumn = editability.primaryKeyColumn;
    final primaryKeyResultColumn = editability.primaryKeyResultColumn;
    final sourceColumn = editability.editableColumns[columnName];
    if (!editability.isEditable ||
        tableName == null ||
        primaryKeyColumn == null ||
        primaryKeyResultColumn == null ||
        sourceColumn == null) {
      return TableEditCommitResult(
        success: false,
        message: editability.canEditColumn(columnName)
            ? 'The selected cell cannot be edited.'
            : editability.reason,
      );
    }
    if (rowIndex < 0 || rowIndex >= tab.resultRows.length) {
      return const TableEditCommitResult(
        success: false,
        message: 'The selected row is no longer loaded.',
      );
    }

    final contract = tab.resultContractForColumn(columnName);
    final schemaColumn = _schemaColumn(tableName, sourceColumn);
    if (contract == null || schemaColumn == null) {
      return const TableEditCommitResult(
        success: false,
        message: 'Column metadata is unavailable for this edit.',
      );
    }

    final coerced = _coerceTableEditValue(
      value: value,
      tableName: tableName,
      contract: contract,
      schemaColumn: schemaColumn,
    );
    if (coerced.error != null) {
      return TableEditCommitResult(success: false, message: coerced.error!);
    }

    final row = tab.resultRows[rowIndex];
    final primaryKeyValue = row[primaryKeyResultColumn];
    if (primaryKeyValue == null) {
      return const TableEditCommitResult(
        success: false,
        message: 'The selected row does not expose a primary key value.',
      );
    }

    final sql =
        'UPDATE ${_quoteIdentifier(tableName)} '
        'SET ${_quoteIdentifier(sourceColumn)} = \$1 '
        'WHERE ${_quoteIdentifier(primaryKeyColumn)} = \$2';
    try {
      final rowsAffected = await _executeAppGeneratedTableDml(
        sql: sql,
        params: <Object?>[coerced.value, primaryKeyValue],
      );
      if (rowsAffected == 0) {
        return const TableEditCommitResult(
          success: false,
          message: 'No rows were updated. Refresh the query and try again.',
          rowsAffected: 0,
        );
      }

      _mutateTab(resolvedTabId, (current) {
        if (rowIndex < 0 || rowIndex >= current.resultRows.length) {
          return current;
        }
        final rows = <Map<String, Object?>>[
          for (final resultRow in current.resultRows)
            Map<String, Object?>.from(resultRow),
        ];
        rows[rowIndex][columnName] = coerced.value;
        final message = rowsAffected == null
            ? 'Updated $tableName.$sourceColumn.'
            : 'Updated $tableName.$sourceColumn with $rowsAffected affected rows.';
        return current.copyWith(
          resultRows: rows,
          statusMessage: message,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.info,
            message,
          ),
        );
      }, notify: false);
      _safeNotify();
      return TableEditCommitResult(
        success: true,
        message: 'Updated $tableName.$sourceColumn.',
        rowsAffected: rowsAffected,
      );
    } catch (error, stackTrace) {
      _logWarning(
        'update_result_cell',
        'Table cell update failed.',
        category: 'query',
        databasePath: databasePath,
        sql: sql,
        error: error,
        stackTrace: stackTrace,
        details: <String, Object?>{
          'tab_id': resolvedTabId,
          'table': tableName,
          'column': sourceColumn,
        },
      );
      final failure = QueryErrorDetails.fromError(
        error,
        stage: QueryErrorStage.validation,
      );
      return TableEditCommitResult(success: false, message: failure.message);
    }
  }

  Future<TableEditCommitResult> insertResultRow({
    required Map<String, Object?> values,
    String? tabId,
  }) async {
    final resolvedTabId = tabId ?? activeTabId;
    final tab = tabById(resolvedTabId);
    if (tab == null) {
      return const TableEditCommitResult(
        success: false,
        message: 'The selected query tab is no longer available.',
      );
    }

    final editability = _tableEditabilityFor(tab);
    final tableName = editability.tableName;
    if (!editability.canInsertRows || tableName == null) {
      return TableEditCommitResult(success: false, message: editability.reason);
    }

    final insertedValues = <String, Object?>{};
    for (final entry in editability.insertableColumns.entries) {
      final sourceColumnName = entry.value;
      final schemaColumn = _schemaColumn(tableName, sourceColumnName);
      if (schemaColumn == null) {
        continue;
      }
      final hasValue = values.containsKey(sourceColumnName);
      final rawValue = values[sourceColumnName];
      final emptyText = rawValue is String && rawValue.trim().isEmpty;
      final requiredValue =
          schemaColumn.notNull &&
          schemaColumn.defaultExpr == null &&
          !schemaColumn.primaryKey;
      if (!hasValue || emptyText) {
        if (requiredValue) {
          return TableEditCommitResult(
            success: false,
            message: '${schemaColumn.name} is required.',
          );
        }
        continue;
      }

      final contract = _resultContractForSourceColumn(tab, sourceColumnName);
      final coerced = _coerceTableEditValue(
        value: rawValue,
        tableName: tableName,
        contract: contract,
        schemaColumn: schemaColumn,
      );
      if (coerced.error != null) {
        return TableEditCommitResult(success: false, message: coerced.error!);
      }
      insertedValues[sourceColumnName] = coerced.value;
    }

    final sql = insertedValues.isEmpty
        ? 'INSERT INTO ${_quoteIdentifier(tableName)} DEFAULT VALUES'
        : 'INSERT INTO ${_quoteIdentifier(tableName)} '
              '(${insertedValues.keys.map(_quoteIdentifier).join(', ')}) '
              'VALUES (${List<String>.generate(insertedValues.length, (index) => '\$${index + 1}').join(', ')})';
    try {
      final rowsAffected = await _executeAppGeneratedTableDml(
        sql: sql,
        params: <Object?>[...insertedValues.values],
      );
      if (rowsAffected == 0) {
        return const TableEditCommitResult(
          success: false,
          message: 'No rows were inserted. Refresh the query and try again.',
          rowsAffected: 0,
        );
      }

      _mutateTab(resolvedTabId, (current) {
        final row = <String, Object?>{};
        var canAppendVisibleRow = current.resultColumns.isNotEmpty;
        for (final resultColumn in current.resultColumns) {
          final sourceColumn = _resultSourceColumn(current, resultColumn);
          if (sourceColumn == null ||
              !insertedValues.containsKey(sourceColumn)) {
            canAppendVisibleRow = false;
            break;
          }
          row[resultColumn] = insertedValues[sourceColumn];
        }
        final rows = canAppendVisibleRow
            ? <Map<String, Object?>>[...current.resultRows, row]
            : current.resultRows;
        final message = rowsAffected == null
            ? 'Inserted row into $tableName.'
            : 'Inserted row into $tableName with $rowsAffected affected rows.';
        return current.copyWith(
          resultRows: rows,
          statusMessage: canAppendVisibleRow
              ? message
              : '$message Refresh results to load generated values.',
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.info,
            canAppendVisibleRow
                ? message
                : '$message Refresh results to load generated values.',
          ),
        );
      }, notify: false);
      _safeNotify();
      return TableEditCommitResult(
        success: true,
        message: 'Inserted row into $tableName.',
        rowsAffected: rowsAffected,
      );
    } catch (error, stackTrace) {
      _logWarning(
        'insert_result_row',
        'Table row insert failed.',
        category: 'query',
        databasePath: databasePath,
        sql: sql,
        error: error,
        stackTrace: stackTrace,
        details: <String, Object?>{'tab_id': resolvedTabId, 'table': tableName},
      );
      final failure = QueryErrorDetails.fromError(
        error,
        stage: QueryErrorStage.validation,
      );
      return TableEditCommitResult(success: false, message: failure.message);
    }
  }

  Future<TableEditCommitResult> deleteResultRow({
    required int rowIndex,
    String? tabId,
  }) async {
    final resolvedTabId = tabId ?? activeTabId;
    final tab = tabById(resolvedTabId);
    if (tab == null) {
      return const TableEditCommitResult(
        success: false,
        message: 'The selected query tab is no longer available.',
      );
    }

    final editability = _tableEditabilityFor(tab);
    final tableName = editability.tableName;
    final primaryKeyColumn = editability.primaryKeyColumn;
    final primaryKeyResultColumn = editability.primaryKeyResultColumn;
    if (!editability.canDeleteRows ||
        tableName == null ||
        primaryKeyColumn == null ||
        primaryKeyResultColumn == null) {
      return TableEditCommitResult(success: false, message: editability.reason);
    }
    if (rowIndex < 0 || rowIndex >= tab.resultRows.length) {
      return const TableEditCommitResult(
        success: false,
        message: 'The selected row is no longer loaded.',
      );
    }

    final primaryKeyValue = tab.resultRows[rowIndex][primaryKeyResultColumn];
    if (primaryKeyValue == null) {
      return const TableEditCommitResult(
        success: false,
        message: 'The selected row does not expose a primary key value.',
      );
    }

    final sql =
        'DELETE FROM ${_quoteIdentifier(tableName)} '
        'WHERE ${_quoteIdentifier(primaryKeyColumn)} = \$1';
    try {
      final rowsAffected = await _executeAppGeneratedTableDml(
        sql: sql,
        params: <Object?>[primaryKeyValue],
      );
      if (rowsAffected == 0) {
        return const TableEditCommitResult(
          success: false,
          message: 'No rows were deleted. Refresh the query and try again.',
          rowsAffected: 0,
        );
      }

      _mutateTab(resolvedTabId, (current) {
        if (rowIndex < 0 || rowIndex >= current.resultRows.length) {
          return current;
        }
        final rows = <Map<String, Object?>>[
          for (var index = 0; index < current.resultRows.length; index++)
            if (index != rowIndex)
              Map<String, Object?>.from(current.resultRows[index]),
        ];
        final message = rowsAffected == null
            ? 'Deleted row from $tableName.'
            : 'Deleted row from $tableName with $rowsAffected affected rows.';
        return current.copyWith(
          resultRows: rows,
          statusMessage: message,
          messageHistory: _appendMessage(
            current.messageHistory,
            QueryMessageLevel.info,
            message,
          ),
        );
      }, notify: false);
      _safeNotify();
      return TableEditCommitResult(
        success: true,
        message: 'Deleted row from $tableName.',
        rowsAffected: rowsAffected,
      );
    } catch (error, stackTrace) {
      _logWarning(
        'delete_result_row',
        'Table row delete failed.',
        category: 'query',
        databasePath: databasePath,
        sql: sql,
        error: error,
        stackTrace: stackTrace,
        details: <String, Object?>{'tab_id': resolvedTabId, 'table': tableName},
      );
      final failure = QueryErrorDetails.fromError(
        error,
        stage: QueryErrorStage.validation,
      );
      return TableEditCommitResult(success: false, message: failure.message);
    }
  }

  Future<int?> _executeAppGeneratedTableDml({
    required String sql,
    required List<Object?> params,
  }) async {
    if (config.writeQueue.enabled) {
      final result = await _gateway.executeQueuedWrite(
        sql: sql,
        params: params,
      );
      return result.rowsAffected;
    }
    final page = await _gateway.runQuery(
      sql: sql,
      params: params,
      pageSize: config.defaultPageSize,
    );
    return page.rowsAffected;
  }

  List<SchemaObjectSummary> filterSchemaObjects(String rawFilter) {
    final filter = rawFilter.trim().toLowerCase();
    if (filter.isEmpty) {
      return schema.objects;
    }
    return schema.objects.where((object) {
      if (object.name.toLowerCase().contains(filter)) {
        return true;
      }
      if (object.checks.any((check) {
        return check.name.toLowerCase().contains(filter) ||
            check.exprSql.toLowerCase().contains(filter);
      })) {
        return true;
      }
      if (object.columns.any(
        (column) =>
            column.name.toLowerCase().contains(filter) ||
            column.type.toLowerCase().contains(filter) ||
            column.constraintSummaries.any(
              (summary) => summary.toLowerCase().contains(filter),
            ),
      )) {
        return true;
      }
      if (schema
          .indexesForObject(object.name)
          .any(
            (index) =>
                index.name.toLowerCase().contains(filter) ||
                index.kind.toLowerCase().contains(filter) ||
                index.columns.any(
                  (column) => column.toLowerCase().contains(filter),
                ),
          )) {
        return true;
      }
      return schema
          .triggersForObject(object.name)
          .any(
            (trigger) =>
                trigger.name.toLowerCase().contains(filter) ||
                trigger.timing.toLowerCase().contains(filter) ||
                trigger.events.any(
                  (event) => event.toLowerCase().contains(filter),
                ),
          );
    }).toList();
  }

  List<String> schemaNotesForObject(SchemaObjectSummary object) {
    return <String>[
      if (object.temporary)
        'Temporary ${object.kind.name}s exist only for the current database connection.',
      if (object.ddl == null || object.ddl!.trim().isEmpty)
        '${object.kind == SchemaObjectKind.table ? 'Table DDL' : 'View definition'} is unavailable for this object.',
    ];
  }

  TableEditabilityState _tableEditabilityFor(QueryTabState tab) {
    if (!hasOpenDatabase) {
      return const TableEditabilityState(
        isEditable: false,
        reason: 'Open a DecentDB file before editing rows.',
      );
    }
    if (tab.resultColumns.isEmpty) {
      return TableEditabilityState.noResults;
    }

    final contract = tab.queryContract;
    if (contract == null) {
      return const TableEditabilityState(
        isEditable: false,
        reason: 'Query contract metadata is unavailable for this result set.',
      );
    }
    if (contract.diagnostics.isNotEmpty) {
      return TableEditabilityState(
        isEditable: false,
        reason:
            'Query contract diagnostics prevent safe editing: '
            '${contract.diagnostics.first}',
      );
    }
    final statementKind = contract.statementKind.trim().toLowerCase();
    if (statementKind != 'query' && statementKind != 'select') {
      return const TableEditabilityState(
        isEditable: false,
        reason: 'Only single-table SELECT results can be edited.',
      );
    }
    if (!contract.readOnly) {
      return const TableEditabilityState(
        isEditable: false,
        reason: 'Only read-only SELECT results can be edited.',
      );
    }

    String? tableName;
    final resultToSourceColumn = <String, String>{};
    final readOnlyColumns = <String>{};
    for (final resultColumn in tab.resultColumns) {
      final columnContract = tab.resultContractForColumn(resultColumn);
      if (columnContract == null ||
          columnContract.diagnostics.isNotEmpty ||
          columnContract.source != 'catalog_column' ||
          columnContract.sourceTable == null ||
          columnContract.sourceTable!.trim().isEmpty ||
          columnContract.sourceColumn == null ||
          columnContract.sourceColumn!.trim().isEmpty) {
        return const TableEditabilityState(
          isEditable: false,
          reason:
              'Every displayed column must map directly to one catalog table.',
        );
      }
      final sourceTable = columnContract.sourceTable!;
      if (tableName == null) {
        tableName = sourceTable;
      } else if (tableName != sourceTable) {
        return const TableEditabilityState(
          isEditable: false,
          reason: 'Joined result sets are read-only in the table editor.',
        );
      }
      resultToSourceColumn[resultColumn] = columnContract.sourceColumn!;
    }

    final resolvedTableName = tableName;
    if (resolvedTableName == null) {
      return TableEditabilityState.noResults;
    }
    final object = schema.objectNamed(resolvedTableName);
    if (object == null || object.kind != SchemaObjectKind.table) {
      return const TableEditabilityState(
        isEditable: false,
        reason: 'The query result does not resolve to a base table.',
      );
    }

    final primaryKeyColumns = <SchemaColumn>[
      for (final column in object.columns)
        if (column.primaryKey) column,
    ];
    if (primaryKeyColumns.length != 1) {
      return const TableEditabilityState(
        isEditable: false,
        reason:
            'A single-column primary key must be selected to edit table rows.',
      );
    }
    final primaryKeyColumn = primaryKeyColumns.single;
    String? primaryKeyResultColumn;
    for (final entry in resultToSourceColumn.entries) {
      if (entry.value == primaryKeyColumn.name) {
        primaryKeyResultColumn = entry.key;
        break;
      }
    }
    if (primaryKeyResultColumn == null) {
      return const TableEditabilityState(
        isEditable: false,
        reason:
            'The primary key column must be present in the result set before editing.',
      );
    }

    final editableColumns = <String, String>{};
    final resultContractBySourceColumn = <String, QueryResultColumnContract>{};
    for (final resultColumn in tab.resultColumns) {
      final sourceColumn = resultToSourceColumn[resultColumn];
      final columnContract = tab.resultContractForColumn(resultColumn);
      if (sourceColumn != null && columnContract != null) {
        resultContractBySourceColumn[sourceColumn] = columnContract;
      }
    }
    for (final entry in resultToSourceColumn.entries) {
      final resultColumn = entry.key;
      final sourceColumnName = entry.value;
      final sourceColumn = _schemaColumn(resolvedTableName, sourceColumnName);
      final columnContract = tab.resultContractForColumn(resultColumn);
      final descriptor = sourceColumn == null || columnContract == null
          ? null
          : _columnDescriptor(
              tableName: resolvedTableName,
              schemaColumn: sourceColumn,
              contract: columnContract,
            );
      if (sourceColumn == null ||
          columnContract == null ||
          sourceColumn.primaryKey ||
          sourceColumn.generatedExpr != null ||
          descriptor!.isSpatial ||
          descriptor.family == NativeTypeFamily.binary) {
        readOnlyColumns.add(resultColumn);
        continue;
      }
      editableColumns[resultColumn] = sourceColumnName;
    }
    final insertableColumns = <String, String>{};
    for (final sourceColumn in object.columns) {
      final columnContract = resultContractBySourceColumn[sourceColumn.name];
      final descriptor = _columnDescriptor(
        tableName: resolvedTableName,
        schemaColumn: sourceColumn,
        contract: columnContract,
      );
      if (sourceColumn.generatedExpr != null ||
          descriptor.isSpatial ||
          descriptor.family == NativeTypeFamily.binary) {
        continue;
      }
      insertableColumns[sourceColumn.name] = sourceColumn.name;
    }

    return TableEditabilityState(
      isEditable: true,
      reason: editableColumns.isEmpty
          ? 'Rows can be inserted or deleted by primary key, but no result columns are editable.'
          : 'Inserts, updates, and deletes are parameterized by primary key.',
      tableName: resolvedTableName,
      primaryKeyColumn: primaryKeyColumn.name,
      primaryKeyResultColumn: primaryKeyResultColumn,
      editableColumns: editableColumns,
      insertableColumns: insertableColumns,
      readOnlyColumns: readOnlyColumns,
    );
  }

  String? _resultSourceColumn(QueryTabState tab, String resultColumnName) {
    return tab.resultContractForColumn(resultColumnName)?.sourceColumn;
  }

  QueryResultColumnContract? _resultContractForSourceColumn(
    QueryTabState tab,
    String sourceColumnName,
  ) {
    for (final resultColumn in tab.resultColumns) {
      final contract = tab.resultContractForColumn(resultColumn);
      if (contract?.sourceColumn == sourceColumnName) {
        return contract;
      }
    }
    return null;
  }

  SchemaColumn? _schemaColumn(String tableName, String columnName) {
    final object = schema.objectNamed(tableName);
    if (object == null) {
      return null;
    }
    for (final column in object.columns) {
      if (column.name == columnName) {
        return column;
      }
    }
    return null;
  }

  NativeTypeDescriptor _columnDescriptor({
    required String tableName,
    required SchemaColumn schemaColumn,
    required QueryResultColumnContract? contract,
  }) {
    final toolingColumn = toolingMetadata?.columnTypeFor(
      tableName: tableName,
      columnName: schemaColumn.name,
    );
    if (toolingColumn != null) {
      return toolingColumn.nativeTypeDescriptor;
    }
    return describeNativeType(
      typeName: contract?.typeName?.trim().isNotEmpty == true
          ? contract!.typeName
          : schemaColumn.type,
    );
  }

  _CoercedTableEditValue _coerceTableEditValue({
    required Object? value,
    required String tableName,
    required QueryResultColumnContract? contract,
    required SchemaColumn schemaColumn,
  }) {
    final descriptor = _columnDescriptor(
      tableName: tableName,
      schemaColumn: schemaColumn,
      contract: contract,
    );
    if (descriptor.isSpatial || descriptor.family == NativeTypeFamily.binary) {
      return _CoercedTableEditValue.failure(
        '${schemaColumn.name} is view/copy-only in the table editor.',
      );
    }
    final nullable = contract?.nullable ?? !schemaColumn.notNull;
    if (value == null) {
      if (!nullable) {
        return _CoercedTableEditValue.failure(
          '${schemaColumn.name} cannot be NULL.',
        );
      }
      return const _CoercedTableEditValue.success(null);
    }

    if (value is! String) {
      return _CoercedTableEditValue.success(value);
    }

    final rawText = value;
    final trimmed = rawText.trim();
    switch (descriptor.family) {
      case NativeTypeFamily.numeric:
        if (_isIntegerDescriptor(descriptor)) {
          final parsed = int.tryParse(trimmed);
          if (parsed == null) {
            return _CoercedTableEditValue.failure(
              '${schemaColumn.name} expects an integer value.',
            );
          }
          return _CoercedTableEditValue.success(parsed);
        }
        final parsed = double.tryParse(trimmed);
        if (parsed == null) {
          return _CoercedTableEditValue.failure(
            '${schemaColumn.name} expects a numeric value.',
          );
        }
        return _CoercedTableEditValue.success(parsed);
      case NativeTypeFamily.boolean:
        final parsed = _parseBooleanEditValue(trimmed);
        if (parsed == null) {
          return _CoercedTableEditValue.failure(
            '${schemaColumn.name} expects true or false.',
          );
        }
        return _CoercedTableEditValue.success(parsed);
      case NativeTypeFamily.binary:
      case NativeTypeFamily.spatial:
        return _CoercedTableEditValue.failure(
          '${schemaColumn.name} is view/copy-only in the table editor.',
        );
      case NativeTypeFamily.text:
      case NativeTypeFamily.uuid:
      case NativeTypeFamily.enumValue:
      case NativeTypeFamily.temporal:
      case NativeTypeFamily.network:
      case NativeTypeFamily.macAddress:
      case NativeTypeFamily.unknown:
        return _CoercedTableEditValue.success(rawText);
    }
  }

  bool _isIntegerDescriptor(NativeTypeDescriptor descriptor) {
    final baseType = descriptor.baseTypeName.toUpperCase();
    final valueKind = descriptor.valueKind?.toLowerCase() ?? '';
    return baseType.contains('INT') || valueKind.contains('int');
  }

  bool? _parseBooleanEditValue(String value) {
    switch (value.toLowerCase()) {
      case 'true':
      case 't':
      case '1':
      case 'yes':
      case 'y':
        return true;
      case 'false':
      case 'f':
      case '0':
      case 'no':
      case 'n':
        return false;
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _workspaceSaveDebounce?.cancel();
    unawaited(_excelImportSubscription?.cancel() ?? Future<void>.value());
    unawaited(_sqlDumpImportSubscription?.cancel() ?? Future<void>.value());
    unawaited(_sqliteImportSubscription?.cancel() ?? Future<void>.value());
    if (hasOpenDatabase) {
      unawaited(_persistWorkspaceStateNow());
    }
    unawaited(_gateway.dispose());
    super.dispose();
  }

  QueryTabState _applyFirstPage(
    QueryTabState tab,
    QueryResultPage page, {
    QueryContract? queryContract,
    required String statusMessage,
  }) {
    return tab.copyWith(
      resultColumns: page.columns,
      resultRows: page.rows,
      cursorId: page.cursorId,
      rowsAffected: page.rowsAffected,
      elapsed: page.elapsed,
      hasMoreRows: !page.done,
      phase: QueryPhase.completed,
      statusMessage: statusMessage,
      queryContract: queryContract,
    );
  }

  Future<void> _loadExecutionPlanForTab(
    String tabId, {
    required int generation,
    required String sql,
    required List<Object?> params,
  }) async {
    try {
      var planPage = await _gateway.runQuery(
        sql: 'EXPLAIN $sql',
        params: params,
        pageSize: config.defaultPageSize,
      );
      if (!_isCurrentGeneration(tabId, generation)) {
        if (planPage.cursorId != null) {
          unawaited(_gateway.cancelQuery(planPage.cursorId!));
        }
        return;
      }

      final columns = <String>[...planPage.columns];
      final rows = <Map<String, Object?>>[...planPage.rows];
      while (planPage.cursorId != null) {
        planPage = await _gateway.fetchNextPage(
          cursorId: planPage.cursorId!,
          pageSize: config.defaultPageSize,
        );
        if (!_isCurrentGeneration(tabId, generation)) {
          if (planPage.cursorId != null) {
            unawaited(_gateway.cancelQuery(planPage.cursorId!));
          }
          return;
        }
        if (columns.isEmpty && planPage.columns.isNotEmpty) {
          columns.addAll(planPage.columns);
        }
        rows.addAll(planPage.rows);
      }

      if (!_isCurrentGeneration(tabId, generation)) {
        return;
      }
      _mutateTab(
        tabId,
        (current) => current.copyWith(
          executionPlan: QueryExecutionPlanState(
            columns: columns,
            rows: rows,
            isLoading: false,
          ),
        ),
        notify: false,
      );
      _safeNotify();
    } catch (error) {
      if (!_isCurrentGeneration(tabId, generation)) {
        return;
      }
      final failure = QueryErrorDetails.fromError(
        error,
        stage: QueryErrorStage.opening,
      );
      _mutateTab(
        tabId,
        (current) => current.copyWith(
          executionPlan: current.executionPlan.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          ),
        ),
        notify: false,
      );
      _safeNotify();
      _logWarning(
        'load_execution_plan',
        'Execution plan could not be loaded.',
        category: 'query',
        databasePath: databasePath,
        sql: sql,
        error: error,
        details: <String, Object?>{'tab_id': tabId},
      );
    }
  }

  List<QueryMessageEntry> _appendMessage(
    List<QueryMessageEntry> history,
    QueryMessageLevel level,
    String message, {
    DateTime? timestamp,
  }) {
    final updated = <QueryMessageEntry>[
      ...history,
      QueryMessageEntry(
        level: level,
        message: message,
        timestamp: timestamp ?? DateTime.now(),
      ),
    ];
    if (updated.length <= _maxMessageHistoryEntries) {
      return updated;
    }
    return updated.sublist(updated.length - _maxMessageHistoryEntries);
  }

  List<QueryHistoryEntry> _appendQueryHistory(
    List<QueryHistoryEntry> history,
    QueryHistoryEntry entry,
  ) {
    final updated = <QueryHistoryEntry>[...history, entry];
    final maxEntries = config.queryHistoryLimit;
    if (updated.length <= maxEntries) {
      return updated;
    }
    return updated.sublist(updated.length - maxEntries);
  }

  QueryHistoryEntry _buildQueryHistoryEntry(
    QueryTabState tab, {
    required QueryHistoryOutcome outcome,
    String? errorMessage,
    int? rowsLoaded,
    int? rowsAffected,
    Duration? elapsed,
  }) {
    return QueryHistoryEntry(
      sql: tab.lastSql ?? tab.sql,
      parameterJson: tab.lastParameterJson ?? tab.parameterJson,
      ranAt: tab.lastRunStartedAt ?? DateTime.now(),
      outcome: outcome,
      elapsed: elapsed ?? Duration.zero,
      rowsLoaded: rowsLoaded,
      rowsAffected: rowsAffected,
      errorMessage: errorMessage,
    );
  }

  bool _isExplainSql(String sql) {
    return RegExp(r'^\s*EXPLAIN\b', caseSensitive: false).hasMatch(sql);
  }

  bool _shouldLoadExecutionPlan({
    required String sql,
    required QueryResultPage page,
  }) {
    return !_isExplainSql(sql) && page.rowsAffected == null;
  }

  Future<void> _cancelAllOpenCursors() async {
    for (final tab in tabs) {
      if (tab.cursorId == null) {
        continue;
      }
      try {
        await _gateway.cancelQuery(tab.cursorId!);
      } catch (_) {
        // Ignore stale cancellation failures during workspace switches.
      }
    }
  }

  List<Object?>? _parseParameters(String tabId, String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const <Object?>[];
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) {
        _setTabError(
          tabId,
          const QueryErrorDetails(
            stage: QueryErrorStage.validation,
            message: 'Parameters must be a JSON array such as [1, "alice"].',
          ),
        );
        return null;
      }
      return decoded.cast<Object?>();
    } catch (error) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.validation,
          message: 'Could not parse parameter JSON: $error',
        ),
      );
      return null;
    }
  }

  bool _isCurrentGeneration(String tabId, int generation) {
    final tab = tabById(tabId);
    return tab != null && tab.executionGeneration == generation;
  }

  bool _validateQueryContractParameters({
    required String tabId,
    required QueryContract contract,
    required List<Object?> parameterValues,
  }) {
    final expectedCount = contract.parameters.isEmpty
        ? 0
        : contract.parameters.fold<int>(
            0,
            (highest, parameter) =>
                highest > parameter.position ? highest : parameter.position,
          );

    if (parameterValues.length != expectedCount) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.validation,
          message:
              'This query expects $expectedCount parameters, but received '
              '${parameterValues.length}.',
        ),
      );
      return false;
    }

    final missing = <String>[];
    for (final parameter in contract.parameters) {
      if (parameter.nullable == false) {
        final index = parameter.position <= 0 ? 0 : parameter.position - 1;
        final rawValue = index < 0 || index >= parameterValues.length
            ? null
            : parameterValues[index];
        if (rawValue == null) {
          missing.add(parameter.name);
        }
      }
    }
    if (missing.isNotEmpty) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.validation,
          message: 'Required parameters missing values: ${missing.join(', ')}.',
        ),
      );
      return false;
    }

    return true;
  }

  void _setTabError(String tabId, QueryErrorDetails error) {
    _mutateTab(
      tabId,
      (current) => current.copyWith(
        phase: QueryPhase.failed,
        error: error,
        statusMessage: null,
        messageHistory: _appendMessage(
          current.messageHistory,
          QueryMessageLevel.error,
          '${error.stageLabel}: ${error.message}',
        ),
      ),
      notify: false,
    );
    _safeNotify();
    _logError(
      'tab_error',
      error.message,
      category: 'query',
      databasePath: databasePath,
      details: <String, Object?>{
        'tab_id': tabId,
        'stage': error.stage.name,
        if (error.code != null) 'code': error.code,
        if (error.location != null) 'location': error.location!.shortLabel,
      },
    );
  }

  void _setWorkspaceError(String message) {
    workspaceError = message;
    workspaceMessage = null;
    _safeNotify();
    _logError('workspace_error', message, databasePath: databasePath);
  }

  String? _validateAppConfig(AppConfig next) {
    if (next.appearance.activeTheme.trim().isEmpty) {
      return 'Active theme cannot be empty.';
    }
    if (next.defaultPageSize <= 0) {
      return 'Page size must be a positive integer.';
    }
    if (next.queryHistoryLimit <= 0) {
      return 'Query history depth must be a positive integer.';
    }
    if (next.csvDelimiter.isEmpty) {
      return 'CSV delimiter cannot be empty.';
    }
    if (next.editorSettings.autocompleteMaxSuggestions <= 0) {
      return 'Autocomplete suggestions must be a positive integer.';
    }
    if (next.editorSettings.indentSpaces <= 0) {
      return 'Indent spaces must be a positive integer.';
    }
    if (next.writeQueue.capacity <= 0) {
      return 'Write queue capacity must be a positive integer.';
    }
    if (next.writeQueue.defaultTimeoutMs < 0) {
      return 'Write queue timeout cannot be negative.';
    }
    if (next.writeQueue.maxBatch <= 0) {
      return 'Write queue max batch must be a positive integer.';
    }
    if (next.writeQueue.maxGroupDelayUs < 0) {
      return 'Write queue group delay cannot be negative.';
    }

    final snippetIds = <String>{};
    final snippetTriggers = <String>{};
    for (final snippet in next.snippets) {
      if (snippet.id.trim().isEmpty) {
        return 'Snippet identifiers cannot be empty.';
      }
      if (snippet.name.trim().isEmpty) {
        return 'Snippet names cannot be empty.';
      }
      if (snippet.trigger.trim().isEmpty) {
        return 'Snippet triggers cannot be empty.';
      }
      if (snippet.body.trim().isEmpty) {
        return 'Snippet bodies cannot be empty.';
      }
      if (!snippetIds.add(snippet.id.trim())) {
        return 'Snippet identifiers must be unique.';
      }
      if (!snippetTriggers.add(snippet.trigger.trim().toLowerCase())) {
        return 'Snippet triggers must be unique.';
      }
    }

    return null;
  }

  Future<void> _persistConfig([String? statusMessage]) async {
    try {
      await _configStore.save(config);
      if (statusMessage != null) {
        workspaceMessage = statusMessage;
        workspaceError = null;
      }
      _logInfo(
        'persist_config',
        'Persisted application configuration.',
        category: 'config',
        details: <String, Object?>{
          'theme_id': config.appearance.activeTheme,
          'verbosity': config.logging.verbosity.name,
        },
      );
    } catch (error) {
      workspaceError = error.toString();
      workspaceMessage = null;
      _logError(
        'persist_config',
        'Persisting application configuration failed.',
        category: 'config',
        error: error,
      );
    } finally {
      _safeNotify();
    }
  }

  void _setSqlDumpImportError(String message, {SqlDumpImportJobPhase? phase}) {
    final session = sqlDumpImportSession;
    if (session == null) {
      workspaceError = message;
      workspaceMessage = null;
      _safeNotify();
      _logError('sql_dump_import_error', message, category: 'import.sql_dump');
      return;
    }
    sqlDumpImportSession = session.copyWith(
      error: message,
      phase: phase ?? session.phase,
    );
    if ((phase ?? session.phase) == SqlDumpImportJobPhase.failed) {
      workspaceError = message;
      workspaceMessage = null;
    }
    _safeNotify();
    _logError(
      'sql_dump_import_error',
      message,
      category: 'import.sql_dump',
      details: <String, Object?>{
        'phase': (phase ?? session.phase).name,
        'source_path': session.sourcePath,
      },
    );
  }

  void _setExcelImportError(String message, {ExcelImportJobPhase? phase}) {
    final session = excelImportSession;
    if (session == null) {
      workspaceError = message;
      workspaceMessage = null;
      _safeNotify();
      _logError('excel_import_error', message, category: 'import.excel');
      return;
    }
    excelImportSession = session.copyWith(
      error: message,
      phase: phase ?? session.phase,
    );
    if ((phase ?? session.phase) == ExcelImportJobPhase.failed) {
      workspaceError = message;
      workspaceMessage = null;
    }
    _safeNotify();
    _logError(
      'excel_import_error',
      message,
      category: 'import.excel',
      details: <String, Object?>{
        'phase': (phase ?? session.phase).name,
        'source_path': session.sourcePath,
      },
    );
  }

  void _setSqliteImportError(String message, {SqliteImportJobPhase? phase}) {
    final session = sqliteImportSession;
    if (session == null) {
      workspaceError = message;
      workspaceMessage = null;
      _safeNotify();
      _logError('sqlite_import_error', message, category: 'import.sqlite');
      return;
    }
    sqliteImportSession = session.copyWith(
      error: message,
      phase: phase ?? session.phase,
    );
    if ((phase ?? session.phase) == SqliteImportJobPhase.failed) {
      workspaceError = message;
      workspaceMessage = null;
    }
    _safeNotify();
    _logError(
      'sqlite_import_error',
      message,
      category: 'import.sqlite',
      details: <String, Object?>{
        'phase': (phase ?? session.phase).name,
        'source_path': session.sourcePath,
      },
    );
  }

  void _mutateSqlDumpImportTable(
    String sourceName,
    SqlDumpImportTableDraft Function(SqlDumpImportTableDraft table) transform,
  ) {
    final session = sqlDumpImportSession;
    if (session == null) {
      return;
    }
    final updatedTables = <SqlDumpImportTableDraft>[
      for (final table in session.tables)
        if (table.sourceName == sourceName) transform(table) else table,
    ];
    sqlDumpImportSession = session.copyWith(tables: updatedTables, error: null);
    _safeNotify();
  }

  void _mutateExcelImportSheet(
    String sourceName,
    ExcelImportSheetDraft Function(ExcelImportSheetDraft sheet) transform,
  ) {
    final session = excelImportSession;
    if (session == null) {
      return;
    }
    final updatedSheets = <ExcelImportSheetDraft>[
      for (final sheet in session.sheets)
        if (sheet.sourceName == sourceName) transform(sheet) else sheet,
    ];
    excelImportSession = session.copyWith(sheets: updatedSheets, error: null);
    _safeNotify();
  }

  void _mutateSqliteImportTable(
    String sourceName,
    SqliteImportTableDraft Function(SqliteImportTableDraft table) transform,
  ) {
    final session = sqliteImportSession;
    if (session == null) {
      return;
    }
    final updatedTables = <SqliteImportTableDraft>[
      for (final table in session.tables)
        if (table.sourceName == sourceName) transform(table) else table,
    ];
    sqliteImportSession = session.copyWith(tables: updatedTables, error: null);
    _safeNotify();
  }

  void _mutateActiveTab(
    QueryTabState Function(QueryTabState current) transform, {
    bool persist = false,
  }) {
    _mutateTab(activeTabId, transform, persist: persist);
  }

  void _mutateTab(
    String tabId,
    QueryTabState Function(QueryTabState current) transform, {
    bool persist = false,
    bool notify = true,
  }) {
    final index = tabs.indexWhere((tab) => tab.id == tabId);
    if (index < 0) {
      return;
    }
    final updated = <QueryTabState>[...tabs];
    updated[index] = transform(updated[index]);
    tabs = updated;
    if (persist) {
      _scheduleWorkspaceStateSave();
    }
    if (notify) {
      _safeNotify();
    }
  }

  void _resetTabs({required bool notify, bool resetCounters = false}) {
    if (resetCounters) {
      _nextTabIdCounter = 1;
      _nextTabTitleCounter = 1;
    }
    final title = _newTabTitle();
    tabs = <QueryTabState>[
      QueryTabState.initial(
        id: _newTabId(),
        title: title,
        exportPath: _suggestExportPathForTitle(title),
      ),
    ];
    _activeTabId = tabs.first.id;
    if (notify) {
      _safeNotify();
    }
  }

  void _restoreTabs(
    PersistedWorkspaceState? persistedState, {
    required bool notify,
  }) {
    if (persistedState == null || persistedState.tabs.isEmpty) {
      _resetTabs(notify: notify, resetCounters: true);
      return;
    }

    final restoredTabs = <QueryTabState>[
      for (final draft in persistedState.tabs)
        QueryTabState.initial(
          id: draft.id,
          title: draft.title,
          sql: draft.sql,
          parameterJson: draft.parameterJson,
          exportPath: draft.exportPath.isEmpty
              ? _suggestExportPathForTitle(draft.title)
              : draft.exportPath,
        ).copyWith(
          queryContract: draft.queryContract,
          messageHistory: draft.messageHistory,
          queryHistory: draft.queryHistory,
        ),
    ];
    tabs = restoredTabs;
    _activeTabId =
        restoredTabs.any((tab) => tab.id == persistedState.activeTabId)
        ? persistedState.activeTabId
        : restoredTabs.first.id;
    _trimQueryHistoriesToLimit();
    _recomputeTabCounters();
    if (notify) {
      _safeNotify();
    }
  }

  void _recomputeTabCounters() {
    var maxId = 0;
    var maxTitle = 0;
    final idPattern = RegExp(r'^query-tab-(\d+)$');
    final titlePattern = RegExp(r'^Query (\d+)$');
    for (final tab in tabs) {
      final idMatch = idPattern.firstMatch(tab.id);
      if (idMatch != null) {
        maxId = maxId > int.parse(idMatch.group(1)!)
            ? maxId
            : int.parse(idMatch.group(1)!);
      }
      final titleMatch = titlePattern.firstMatch(tab.title);
      if (titleMatch != null) {
        maxTitle = maxTitle > int.parse(titleMatch.group(1)!)
            ? maxTitle
            : int.parse(titleMatch.group(1)!);
      }
    }
    _nextTabIdCounter = maxId + 1;
    _nextTabTitleCounter = maxTitle + 1;
  }

  String _newTabId() => 'query-tab-${_nextTabIdCounter++}';

  String _newTabTitle() => 'Query ${_nextTabTitleCounter++}';

  void _trimQueryHistoriesToLimit() {
    final limit = config.queryHistoryLimit;
    if (limit <= 0) {
      return;
    }
    var changed = false;
    tabs = <QueryTabState>[
      for (final tab in tabs)
        if (tab.queryHistory.length <= limit)
          tab
        else
          () {
            changed = true;
            return tab.copyWith(
              queryHistory: tab.queryHistory.sublist(
                tab.queryHistory.length - limit,
              ),
            );
          }(),
    ];
    if (changed) {
      _scheduleWorkspaceStateSave();
    }
  }

  Future<void> _restoreStartupQueryState() async {
    final replay = _latestRestorableQuery();
    if (replay != null) {
      _activeTabId = replay.tabId;
      loadHistoryEntryIntoTab(replay.tabId, replay.entry);
      await runTab(replay.tabId);
      return;
    }

    final firstTable = schema.tables.isEmpty ? null : schema.tables.first.name;
    if (firstTable == null) {
      return;
    }
    final fallbackSql =
        'SELECT *\n'
        'FROM ${_quoteIdentifier(firstTable)}\n'
        'LIMIT ${config.defaultPageSize};';
    _mutateActiveTab(
      (tab) => tab.copyWith(sql: fallbackSql, parameterJson: ''),
      persist: true,
    );
    await runActiveTab();
  }

  _RestoredQueryReplay? _latestRestorableQuery() {
    final latest = _latestCompletedQuery();
    if (latest == null || !_canRestoreStartupQuery(latest.entry)) {
      return null;
    }
    return latest;
  }

  _RestoredQueryReplay? _latestCompletedQuery() {
    _RestoredQueryReplay? latest;
    for (final tab in tabs) {
      for (final entry in tab.queryHistory) {
        if (entry.outcome != QueryHistoryOutcome.completed) {
          continue;
        }
        final candidate = _RestoredQueryReplay(tabId: tab.id, entry: entry);
        if (latest == null ||
            candidate.entry.ranAt.isAfter(latest.entry.ranAt)) {
          latest = candidate;
        }
      }
    }
    return latest;
  }

  bool _canRestoreStartupQuery(QueryHistoryEntry entry) {
    return entry.rowsAffected == null && _isStartupReplaySafeSql(entry.sql);
  }

  bool _isStartupReplaySafeSql(String sql) {
    final keyword = _leadingSqlKeyword(sql);
    return switch (keyword) {
      'SELECT' || 'EXPLAIN' || 'PRAGMA' || 'VALUES' || 'WITH' => true,
      _ => false,
    };
  }

  String? _leadingSqlKeyword(String sql) {
    final match = RegExp(
      r'^(?:\s|--[^\r\n]*(?:\r?\n|$)|/\*[\s\S]*?\*/)*([A-Za-z]+)',
      caseSensitive: false,
    ).firstMatch(sql);
    return match?.group(1)?.toUpperCase();
  }

  void _scheduleWorkspaceStateSave() {
    final currentDatabasePath = databasePath;
    if (currentDatabasePath == null) {
      return;
    }
    _workspaceSaveDebounce?.cancel();
    _workspaceSaveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistWorkspaceStateNow(databasePath: currentDatabasePath));
    });
  }

  Future<void> _persistWorkspaceStateNow({String? databasePath}) async {
    final targetPath = databasePath ?? this.databasePath;
    if (targetPath == null) {
      return;
    }
    try {
      await _workspaceStateStore.save(targetPath, _serializeWorkspaceState());
    } catch (error) {
      _logError(
        'persist_workspace_state',
        'Could not save workspace state.',
        databasePath: targetPath,
        error: error,
      );
      workspaceError = 'Could not save workspace state: $error';
      workspaceMessage = null;
      _safeNotify();
    }
  }

  Future<void> _loadSavedQueryLibrary(String databasePath) async {
    try {
      savedQueryLibrary = await _savedQueryLibraryStore.load(databasePath);
    } catch (error, stackTrace) {
      savedQueryLibrary = SavedQueryLibrary.empty;
      _logWarning(
        'load_saved_query_library',
        'Could not load saved query library.',
        databasePath: databasePath,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _persistSavedQueryLibrary() async {
    final targetPath = databasePath;
    if (targetPath == null) {
      return;
    }
    try {
      await _savedQueryLibraryStore.save(targetPath, savedQueryLibrary);
    } catch (error, stackTrace) {
      _logError(
        'persist_saved_query_library',
        'Could not save query library.',
        databasePath: targetPath,
        error: error,
        stackTrace: stackTrace,
      );
      workspaceError = 'Could not save query library: $error';
      workspaceMessage = null;
    }
  }

  PersistedWorkspaceState _serializeWorkspaceState() {
    return PersistedWorkspaceState(
      schemaVersion: PersistedWorkspaceState.currentSchemaVersion,
      activeTabId: _activeTabId,
      schemaFingerprint: toolingMetadata?.schemaFingerprint,
      schemaFingerprintAlgorithm: toolingMetadata?.schemaFingerprintAlgorithm,
      tabs: <WorkspaceTabDraft>[
        for (final tab in tabs)
          WorkspaceTabDraft(
            id: tab.id,
            title: tab.title,
            sql: tab.sql,
            parameterJson: tab.parameterJson,
            exportPath: tab.exportPath.trim().isEmpty
                ? suggestExportPath(tab.id)
                : tab.exportPath,
            queryContract: tab.queryContract,
            messageHistory: tab.messageHistory,
            queryHistory: tab.queryHistory,
          ),
      ],
    );
  }

  String _suggestExportPathForTitle(String title) {
    final safeTitle = title.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    if (databasePath == null) {
      return p.join(
        Directory.current.path,
        'decent-bench-${safeTitle.isEmpty ? 'query' : safeTitle}.csv',
      );
    }
    final directory = p.dirname(databasePath!);
    final basename = p.basenameWithoutExtension(databasePath!);
    final suffix = safeTitle.isEmpty ? 'query' : safeTitle;
    return p.join(directory, '$basename-$suffix.csv');
  }

  String _suggestImportTargetPath(String sourcePath) {
    return suggestNewDecentDbTargetPath(sourcePath);
  }

  String _quoteIdentifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _createSavedQueryId() {
    return 'query-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

class _RestoredQueryReplay {
  const _RestoredQueryReplay({required this.tabId, required this.entry});

  final String tabId;
  final QueryHistoryEntry entry;
}

class _CoercedTableEditValue {
  const _CoercedTableEditValue.success(this.value) : error = null;

  const _CoercedTableEditValue.failure(this.error) : value = null;

  final Object? value;
  final String? error;
}
