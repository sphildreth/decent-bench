import 'dart:async';
import 'dart:io';

import 'package:decent_bench/app/logging/app_logger.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/excel_import_models.dart';
import 'package:decent_bench/features/workspace/domain/saved_query_models.dart';
import 'package:decent_bench/features/workspace/domain/sql_dump_import_models.dart';
import 'package:decent_bench/features/workspace/domain/sqlite_import_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_state.dart';
import 'package:decent_bench/features/workspace/infrastructure/app_config_store.dart';
import 'package:decent_bench/features/workspace/infrastructure/app_lifecycle_service.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';
import 'package:decent_bench/features/workspace/infrastructure/saved_query_library_store.dart';
import 'package:decent_bench/features/workspace/infrastructure/workspace_state_store.dart';

class InMemoryConfigStore implements WorkspaceConfigStore {
  InMemoryConfigStore([AppConfig? config])
    : _config = config ?? AppConfig.defaults();

  AppConfig _config;

  @override
  Future<AppConfig> load() async => _config;

  @override
  Future<void> save(AppConfig config) async {
    _config = config;
  }

  @override
  String describeLocation() => 'memory://config.toml';
}

class InMemoryWorkspaceStateStore implements WorkspaceStateStore {
  final Map<String, PersistedWorkspaceState> _states =
      <String, PersistedWorkspaceState>{};

  @override
  Future<void> clear(String databasePath) async {
    _states.remove(databasePath);
  }

  @override
  Future<PersistedWorkspaceState?> load(String databasePath) async {
    return _states[databasePath];
  }

  @override
  Future<void> save(String databasePath, PersistedWorkspaceState state) async {
    _states[databasePath] = state;
  }
}

class InMemorySavedQueryLibraryStore implements SavedQueryLibraryStore {
  final Map<String, SavedQueryLibrary> _libraries =
      <String, SavedQueryLibrary>{};
  final Map<String, SavedQueryLibrary> _pathLibraries =
      <String, SavedQueryLibrary>{};

  @override
  String describeLocation(String databasePath) {
    return 'memory://$databasePath/queries.toml';
  }

  @override
  Future<SavedQueryLibrary> load(String databasePath) async {
    return _libraries[databasePath] ?? SavedQueryLibrary.empty;
  }

  @override
  Future<SavedQueryLibrary> loadFromPath(String path) async {
    return _pathLibraries[path] ?? SavedQueryLibrary.empty;
  }

  @override
  Future<void> save(String databasePath, SavedQueryLibrary library) async {
    _libraries[databasePath] = library;
  }

  @override
  Future<void> saveToPath(String path, SavedQueryLibrary library) async {
    _pathLibraries[path] = library;
  }
}

class FakeAppLifecycleService implements AppLifecycleService {
  bool requestedExit = false;

  @override
  Future<void> requestExit() async {
    requestedExit = true;
  }
}

class RecordedLogEntry {
  const RecordedLogEntry({
    required this.level,
    required this.category,
    required this.message,
    this.operation,
    this.databasePath,
    this.sql,
    this.rowCount,
    this.rowsAffected,
    this.elapsedNanos,
    this.details,
  });

  final LogVerbosity level;
  final String category;
  final String message;
  final String? operation;
  final String? databasePath;
  final String? sql;
  final int? rowCount;
  final int? rowsAffected;
  final int? elapsedNanos;
  final Map<String, Object?>? details;
}

class RecordingAppLogger extends AppLogger {
  RecordingAppLogger({this.minimumLevel = LogVerbosity.debug});

  @override
  String get logDatabasePath => '/tmp/decent-bench-log.ddb';

  LogVerbosity minimumLevel;
  final List<RecordedLogEntry> entries = <RecordedLogEntry>[];
  bool initialized = false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize({LogVerbosity? minimumLevel}) async {
    initialized = true;
    if (minimumLevel != null) {
      this.minimumLevel = minimumLevel;
    }
  }

  @override
  void log({
    required LogVerbosity level,
    required String category,
    required String message,
    String? operation,
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.value < minimumLevel.value) {
      return;
    }
    entries.add(
      RecordedLogEntry(
        level: level,
        category: category,
        message: message,
        operation: operation,
        databasePath: databasePath,
        sql: sql,
        rowCount: rowCount,
        rowsAffected: rowsAffected,
        elapsedNanos: elapsedNanos,
        details: <String, Object?>{
          ...?details,
          if (error != null) 'error': error.toString(),
          if (stackTrace != null) 'stack_trace': stackTrace.toString(),
        },
      ),
    );
  }

  @override
  void updateMinimumLevel(LogVerbosity minimumLevel) {
    this.minimumLevel = minimumLevel;
  }
}

class FakeWorkspaceGateway implements WorkspaceDatabaseGateway {
  FakeWorkspaceGateway({
    ExcelImportInspection? excelInspection,
    SqlDumpImportInspection? sqlDumpInspection,
    SqliteImportInspection? sqliteInspection,
    Map<String, SqliteImportPreview>? sqlitePreviews,
  }) : excelInspection =
           excelInspection ?? _defaultExcelInspection('/tmp/source.xlsx'),
       sqlDumpInspection =
           sqlDumpInspection ?? _defaultSqlDumpInspection('/tmp/source.sql'),
       sqliteInspection =
           sqliteInspection ?? _defaultSqliteInspection('/tmp/source.sqlite'),
       sqlitePreviews = sqlitePreviews ?? _defaultSqlitePreviews();

  @override
  String? resolvedLibraryPath = '/tmp/libdecentdb.so';

  int cancelCount = 0;
  String? lastExportPath;
  bool? lastExcelIncludeHeaders;
  String? lastRunQuerySql;
  List<Object?>? lastRunQueryParams;
  String? lastBranchQuerySql;
  String? lastCreatedBranchName;
  String? lastCreatedBranchFromRef;
  String? lastCreatedSnapshotName;
  String? lastBranchDiffLeftRef;
  String? lastBranchDiffRightRef;
  String? lastRestoreBranchName;
  String? lastRestoreTargetRef;
  bool? lastRestoreDryRun;
  String? lastMergeSourceBranch;
  String? lastMergeTargetBranch;
  bool? lastMergeDryRun;
  ExcelImportInspection excelInspection;
  SqlDumpImportInspection sqlDumpInspection;
  SqliteImportInspection sqliteInspection;
  Map<String, SqliteImportPreview> sqlitePreviews;
  ExcelImportRequest? lastExcelImportRequest;
  SqlDumpImportRequest? lastSqlDumpImportRequest;
  SqliteImportRequest? lastSqliteImportRequest;
  String? lastCancelledImportJobId;
  bool holdImportOpen = false;
  bool failNextImport = false;
  bool holdExcelImportOpen = false;
  bool failNextExcelImport = false;
  bool holdSqlDumpImportOpen = false;
  bool failNextSqlDumpImport = false;
  Object? openDatabaseError;
  bool branchApiAvailable = false;
  String branchApiUnavailableReason =
      'Native DecentDB branch and snapshot operations require a public Dart '
      'binding API. Decent Bench does not call private binding internals or '
      'C ABI surfaces that are not exported by the public Dart package.';
  List<WorkspaceBranchInfo> branches = const <WorkspaceBranchInfo>[
    WorkspaceBranchInfo(name: 'main', isCurrent: true),
  ];
  List<WorkspaceSnapshotInfo> snapshots = const <WorkspaceSnapshotInfo>[];
  WorkspaceBranchDiff branchDiffResult = WorkspaceBranchDiff.empty;
  StreamController<ExcelImportUpdate>? _excelImportController;
  StreamController<SqlDumpImportUpdate>? _sqlDumpImportController;
  StreamController<SqliteImportUpdate>? _importController;

  SchemaSnapshot snapshot = SchemaSnapshot(
    objects: <SchemaObjectSummary>[
      SchemaObjectSummary(
        name: 'tasks',
        kind: SchemaObjectKind.table,
        ddl:
            'CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT NOT NULL, CHECK (length(title) > 0));',
        checks: const <SchemaCheckConstraint>[
          SchemaCheckConstraint(name: '', exprSql: 'length(title) > 0'),
        ],
        columns: const <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: 'INTEGER',
            notNull: true,
            unique: true,
            primaryKey: true,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
          SchemaColumn(
            name: 'title',
            type: 'TEXT',
            notNull: true,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
        ],
      ),
      SchemaObjectSummary(
        name: 'active_tasks',
        kind: SchemaObjectKind.view,
        ddl: 'CREATE VIEW active_tasks AS SELECT id, title FROM tasks;',
        columns: const <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: 'ANY',
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
          SchemaColumn(
            name: 'title',
            type: 'ANY',
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
        ],
      ),
    ],
    indexes: const <IndexSummary>[
      IndexSummary(
        name: 'idx_tasks_title',
        table: 'tasks',
        columns: <String>['title'],
        unique: false,
        kind: 'btree',
        ddl: 'CREATE INDEX idx_tasks_title ON tasks (title);',
      ),
    ],
    triggers: const <TriggerSummary>[
      TriggerSummary(
        name: 'tasks_after_insert',
        targetName: 'tasks',
        targetKind: 'table',
        timing: 'after',
        events: <String>['insert'],
        eventsMask: 1,
        forEachRow: true,
        temporary: false,
        actionSql: "INSERT INTO task_audit(action) VALUES ('insert')",
        ddl:
            "CREATE TRIGGER tasks_after_insert AFTER INSERT ON tasks FOR EACH ROW EXECUTE FUNCTION decentdb_exec_sql('INSERT INTO task_audit(action) VALUES (''insert'')');",
      ),
    ],
    loadedAt: DateTime(2026, 3, 9),
  );
  ToolingMetadata toolingMetadata = const ToolingMetadata(
    metadataVersion: 1,
    engineVersion: '2.6.0',
    databaseFormatVersion: 8,
    schemaCookie: 1,
    tempSchemaCookie: 0,
    schemaFingerprint:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    schemaFingerprintAlgorithm: 'sha256:decentdb-tooling-schema-v1',
    columnTypeMetadata: <ToolingColumnTypeMetadata>[
      ToolingColumnTypeMetadata(
        tableName: 'tasks',
        columnName: 'id',
        columnType: 'INT64',
        typeInfo: ToolingTypeInfo(
          typeName: 'INT64',
          valueKind: 'int64',
          cValueTag: 1,
        ),
      ),
      ToolingColumnTypeMetadata(
        tableName: 'tasks',
        columnName: 'title',
        columnType: 'TEXT',
        typeInfo: ToolingTypeInfo(
          typeName: 'TEXT',
          valueKind: 'text',
          cValueTag: 4,
        ),
      ),
    ],
    capabilities: ToolingCapabilities(
      queryContractVersion: 1,
      queryDescribe: true,
      deterministicJson: true,
    ),
  );
  Object? toolingMetadataError;
  Object? queryContractError;
  String? lastDescribedQuerySql;

  @override
  Future<void> cancelQuery(String cursorId) async {
    cancelCount++;
  }

  @override
  Future<void> cancelImport(String jobId) async {
    lastCancelledImportJobId = jobId;
    final sqlDumpController = _sqlDumpImportController;
    if (sqlDumpController != null && !sqlDumpController.isClosed) {
      sqlDumpController.add(
        SqlDumpImportUpdate(
          kind: SqlDumpImportUpdateKind.cancelled,
          jobId: jobId,
          summary: _buildCancelledSqlDumpSummary(jobId),
        ),
      );
      await sqlDumpController.close();
      _sqlDumpImportController = null;
      return;
    }
    final excelController = _excelImportController;
    if (excelController != null && !excelController.isClosed) {
      excelController.add(
        ExcelImportUpdate(
          kind: ExcelImportUpdateKind.cancelled,
          jobId: jobId,
          summary: _buildCancelledExcelSummary(jobId),
        ),
      );
      await excelController.close();
      _excelImportController = null;
      return;
    }
    final controller = _importController;
    if (controller == null || controller.isClosed) {
      return;
    }
    controller.add(
      SqliteImportUpdate(
        kind: SqliteImportUpdateKind.cancelled,
        jobId: jobId,
        summary: _buildCancelledSummary(jobId),
      ),
    );
    await controller.close();
    _importController = null;
  }

  @override
  Future<List<WorkspaceBranchInfo>> listBranches() async {
    _ensureBranchApiAvailable();
    return branches;
  }

  @override
  Future<WorkspaceBranchInfo> createBranch({
    required String branchName,
    required String fromRef,
  }) async {
    _ensureBranchApiAvailable();
    lastCreatedBranchName = branchName;
    lastCreatedBranchFromRef = fromRef;
    final branch = WorkspaceBranchInfo(name: branchName, parentRef: fromRef);
    branches = <WorkspaceBranchInfo>[...branches, branch];
    return branch;
  }

  @override
  Future<void> deleteBranch({required String branchName}) async {
    _ensureBranchApiAvailable();
    branches = <WorkspaceBranchInfo>[
      for (final branch in branches)
        if (branch.name != branchName) branch,
    ];
  }

  @override
  Future<List<WorkspaceSnapshotInfo>> listSnapshots() async {
    _ensureBranchApiAvailable();
    return snapshots;
  }

  @override
  Future<WorkspaceSnapshotInfo> createSnapshot({required String name}) async {
    _ensureBranchApiAvailable();
    lastCreatedSnapshotName = name;
    final snapshot = WorkspaceSnapshotInfo(
      name: name,
      ref: 'snapshot:$name',
      branch: branches
          .firstWhere(
            (branch) => branch.isCurrent,
            orElse: () => branches.first,
          )
          .name,
      createdAt: DateTime(2026, 5, 19, 12),
    );
    snapshots = <WorkspaceSnapshotInfo>[...snapshots, snapshot];
    return snapshot;
  }

  @override
  Future<void> deleteSnapshot({required String ref}) async {
    _ensureBranchApiAvailable();
    snapshots = <WorkspaceSnapshotInfo>[
      for (final snapshot in snapshots)
        if (snapshot.ref != ref) snapshot,
    ];
  }

  @override
  Future<QueryResultPage> runQueryOnBranch({
    required String sql,
    required String branchName,
    required List<Object?> params,
    required int pageSize,
  }) async {
    _ensureBranchApiAvailable();
    lastBranchQuerySql = sql;
    return runQuery(sql: sql, params: params, pageSize: pageSize);
  }

  @override
  Future<WorkspaceBranchDiff> branchDiff({
    required String leftRef,
    required String rightRef,
  }) async {
    _ensureBranchApiAvailable();
    lastBranchDiffLeftRef = leftRef;
    lastBranchDiffRightRef = rightRef;
    return branchDiffResult;
  }

  @override
  Future<WorkspaceBranchDiff> restoreBranch({
    required String branchName,
    required String targetRef,
    required bool dryRun,
  }) async {
    _ensureBranchApiAvailable();
    lastRestoreBranchName = branchName;
    lastRestoreTargetRef = targetRef;
    lastRestoreDryRun = dryRun;
    return branchDiffResult;
  }

  @override
  Future<WorkspaceBranchDiff> mergeBranch({
    required String sourceBranch,
    required String targetBranch,
    required bool dryRun,
  }) async {
    _ensureBranchApiAvailable();
    lastMergeSourceBranch = sourceBranch;
    lastMergeTargetBranch = targetBranch;
    lastMergeDryRun = dryRun;
    return branchDiffResult;
  }

  void _ensureBranchApiAvailable() {
    if (!branchApiAvailable) {
      throw BranchWorkflowUnavailable(branchApiUnavailableReason);
    }
  }

  @override
  Future<void> dispose() async {
    await _excelImportController?.close();
    _excelImportController = null;
    await _sqlDumpImportController?.close();
    _sqlDumpImportController = null;
    await _importController?.close();
    _importController = null;
  }

  @override
  Future<CsvExportResult> exportCsv({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required String delimiter,
    required bool includeHeaders,
  }) async {
    lastExportPath = path;
    return CsvExportResult(rowCount: 2, path: path);
  }

  @override
  Future<JsonExportResult> exportJson({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required String format,
    required bool pretty,
    required bool includeMetadata,
  }) async {
    lastExportPath = path;
    return JsonExportResult(rowCount: 2, path: path);
  }

  @override
  Future<ExcelExportResult> exportExcel({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required bool includeHeaders,
  }) async {
    lastExportPath = path;
    lastExcelIncludeHeaders = includeHeaders;
    return ExcelExportResult(rowCount: 2, path: path);
  }

  @override
  Future<QueryResultPage> fetchNextPage({
    required String cursorId,
    required int pageSize,
  }) async {
    return switch (cursorId) {
      'cursor-projects' => QueryResultPage(
        cursorId: null,
        columns: const <String>['id', 'name'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'id': 11, 'name': 'Keep testing'},
        ],
        done: true,
        rowsAffected: null,
        elapsed: const Duration(milliseconds: 4),
      ),
      _ => QueryResultPage(
        cursorId: null,
        columns: const <String>['id', 'title'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'id': 2, 'title': 'Keep paging'},
        ],
        done: true,
        rowsAffected: null,
        elapsed: const Duration(milliseconds: 4),
      ),
    };
  }

  @override
  Future<String> initialize() async => resolvedLibraryPath!;

  @override
  Stream<ExcelImportUpdate> importExcel({
    required ExcelImportRequest request,
  }) async* {
    lastExcelImportRequest = request;
    if (holdExcelImportOpen) {
      final controller = StreamController<ExcelImportUpdate>();
      _excelImportController = controller;
      Future<void>.microtask(() {
        if (controller.isClosed) {
          return;
        }
        controller.add(
          ExcelImportUpdate(
            kind: ExcelImportUpdateKind.progress,
            jobId: request.jobId,
            progress: ExcelImportProgress(
              jobId: request.jobId,
              currentSheet: request.selectedSheets.first.targetName,
              completedSheets: 0,
              totalSheets: request.selectedSheets.length,
              currentSheetRowsCopied: 0,
              currentSheetRowCount: request.selectedSheets.first.rowCount,
              totalRowsCopied: 0,
              message: 'Preparing Excel import...',
            ),
          ),
        );
      });
      yield* controller.stream;
      return;
    }

    yield ExcelImportUpdate(
      kind: ExcelImportUpdateKind.progress,
      jobId: request.jobId,
      progress: ExcelImportProgress(
        jobId: request.jobId,
        currentSheet: request.selectedSheets.first.targetName,
        completedSheets: 0,
        totalSheets: request.selectedSheets.length,
        currentSheetRowsCopied: request.selectedSheets.first.rowCount,
        currentSheetRowCount: request.selectedSheets.first.rowCount,
        totalRowsCopied: request.selectedSheets.first.rowCount,
        message: 'Copying ${request.selectedSheets.first.targetName}...',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    if (failNextExcelImport) {
      failNextExcelImport = false;
      yield ExcelImportUpdate(
        kind: ExcelImportUpdateKind.failed,
        jobId: request.jobId,
        message: 'Excel import failed in the fake gateway.',
      );
      return;
    }

    final targetFile = File(request.targetPath);
    await targetFile.parent.create(recursive: true);
    if (!await targetFile.exists()) {
      await targetFile.writeAsString('');
    }

    yield ExcelImportUpdate(
      kind: ExcelImportUpdateKind.completed,
      jobId: request.jobId,
      summary: _buildCompletedExcelSummary(request),
    );
  }

  @override
  Stream<SqlDumpImportUpdate> importSqlDump({
    required SqlDumpImportRequest request,
  }) async* {
    lastSqlDumpImportRequest = request;
    if (holdSqlDumpImportOpen) {
      final controller = StreamController<SqlDumpImportUpdate>();
      _sqlDumpImportController = controller;
      Future<void>.microtask(() {
        if (controller.isClosed) {
          return;
        }
        controller.add(
          SqlDumpImportUpdate(
            kind: SqlDumpImportUpdateKind.progress,
            jobId: request.jobId,
            progress: SqlDumpImportProgress(
              jobId: request.jobId,
              currentTable: request.selectedTables.first.targetName,
              completedTables: 0,
              totalTables: request.selectedTables.length,
              currentTableRowsCopied: 0,
              currentTableRowCount: request.selectedTables.first.rowCount,
              totalRowsCopied: 0,
              message: 'Preparing SQL dump import...',
            ),
          ),
        );
      });
      yield* controller.stream;
      return;
    }

    yield SqlDumpImportUpdate(
      kind: SqlDumpImportUpdateKind.progress,
      jobId: request.jobId,
      progress: SqlDumpImportProgress(
        jobId: request.jobId,
        currentTable: request.selectedTables.first.targetName,
        completedTables: 0,
        totalTables: request.selectedTables.length,
        currentTableRowsCopied: request.selectedTables.first.rowCount,
        currentTableRowCount: request.selectedTables.first.rowCount,
        totalRowsCopied: request.selectedTables.first.rowCount,
        message: 'Copying ${request.selectedTables.first.targetName}...',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    if (failNextSqlDumpImport) {
      failNextSqlDumpImport = false;
      yield SqlDumpImportUpdate(
        kind: SqlDumpImportUpdateKind.failed,
        jobId: request.jobId,
        message: 'SQL dump import failed in the fake gateway.',
      );
      return;
    }

    final targetFile = File(request.targetPath);
    await targetFile.parent.create(recursive: true);
    if (!await targetFile.exists()) {
      await targetFile.writeAsString('');
    }

    yield SqlDumpImportUpdate(
      kind: SqlDumpImportUpdateKind.completed,
      jobId: request.jobId,
      summary: _buildCompletedSqlDumpSummary(request),
    );
  }

  @override
  Stream<SqliteImportUpdate> importSqlite({
    required SqliteImportRequest request,
  }) async* {
    lastSqliteImportRequest = request;
    if (holdImportOpen) {
      final controller = StreamController<SqliteImportUpdate>();
      _importController = controller;
      Future<void>.microtask(() {
        if (controller.isClosed) {
          return;
        }
        controller.add(
          SqliteImportUpdate(
            kind: SqliteImportUpdateKind.progress,
            jobId: request.jobId,
            progress: SqliteImportProgress(
              jobId: request.jobId,
              currentTable: request.selectedTables.first.targetName,
              completedTables: 0,
              totalTables: request.selectedTables.length,
              currentTableRowsCopied: 0,
              currentTableRowCount: request.selectedTables.first.rowCount,
              totalRowsCopied: 0,
              message: 'Preparing SQLite import...',
            ),
          ),
        );
      });
      yield* controller.stream;
      return;
    }

    yield SqliteImportUpdate(
      kind: SqliteImportUpdateKind.progress,
      jobId: request.jobId,
      progress: SqliteImportProgress(
        jobId: request.jobId,
        currentTable: request.selectedTables.first.targetName,
        completedTables: 0,
        totalTables: request.selectedTables.length,
        currentTableRowsCopied: request.selectedTables.first.rowCount,
        currentTableRowCount: request.selectedTables.first.rowCount,
        totalRowsCopied: request.selectedTables.first.rowCount,
        message: 'Copying ${request.selectedTables.first.targetName}...',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    if (failNextImport) {
      failNextImport = false;
      yield SqliteImportUpdate(
        kind: SqliteImportUpdateKind.failed,
        jobId: request.jobId,
        message: 'SQLite import failed in the fake gateway.',
      );
      return;
    }

    final targetFile = File(request.targetPath);
    await targetFile.parent.create(recursive: true);
    if (!await targetFile.exists()) {
      await targetFile.writeAsString('');
    }

    yield SqliteImportUpdate(
      kind: SqliteImportUpdateKind.completed,
      jobId: request.jobId,
      summary: _buildCompletedSummary(request),
    );
  }

  @override
  Future<ExcelImportInspection> inspectExcelSource({
    required String sourcePath,
    required bool headerRow,
  }) async {
    return ExcelImportInspection(
      sourcePath: sourcePath,
      headerRow: headerRow,
      sheets: excelInspection.sheets,
      warnings: excelInspection.warnings,
    );
  }

  @override
  Future<SqliteImportInspection> inspectSqliteSource({
    required String sourcePath,
  }) async {
    return SqliteImportInspection(
      sourcePath: sourcePath,
      tables: sqliteInspection.tables,
      warnings: sqliteInspection.warnings,
    );
  }

  @override
  Future<SqlDumpImportInspection> inspectSqlDumpSource({
    required String sourcePath,
    required String encoding,
  }) async {
    return SqlDumpImportInspection(
      sourcePath: sourcePath,
      requestedEncoding: encoding,
      resolvedEncoding: encoding == 'auto'
          ? sqlDumpInspection.resolvedEncoding
          : encoding,
      tables: sqlDumpInspection.tables,
      warnings: sqlDumpInspection.warnings,
      skippedStatements: sqlDumpInspection.skippedStatements,
      totalStatements: sqlDumpInspection.totalStatements,
    );
  }

  @override
  Future<SchemaSnapshot> loadSchema() async => snapshot;

  @override
  Future<ToolingMetadata> getToolingMetadata() async {
    final error = toolingMetadataError;
    if (error != null) {
      throw error;
    }
    return toolingMetadata;
  }

  @override
  Future<QueryContract> describeQueryContract(String sql) async {
    lastDescribedQuerySql = sql;
    final error = queryContractError;
    if (error != null) {
      throw error;
    }
    if (sql.toUpperCase().contains('BROKEN')) {
      throw const BridgeFailure('syntax error near BROKEN', code: 'ERR_SQL');
    }
    return _fakeQueryContract(sql, toolingMetadata.schemaFingerprint);
  }

  @override
  Future<SqliteImportPreview> loadSqlitePreview({
    required String sourcePath,
    required String tableName,
    int limit = 8,
  }) async {
    return sqlitePreviews[tableName] ??
        SqliteImportPreview(
          tableName: tableName,
          rows: const <Map<String, Object?>>[],
        );
  }

  @override
  Future<DatabaseSession> openDatabase(String path) async {
    final error = openDatabaseError;
    if (error != null) {
      throw error;
    }
    final file = File(path);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('');
    }
    return DatabaseSession(path: path, engineVersion: '1.6.1');
  }

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  }) async {
    lastRunQuerySql = sql;
    lastRunQueryParams = <Object?>[...params];
    if (sql.toUpperCase().startsWith('EXPLAIN')) {
      if (sql.toLowerCase().contains('projects')) {
        return QueryResultPage(
          cursorId: null,
          columns: const <String>['query_plan'],
          rows: const <Map<String, Object?>>[
            <String, Object?>{
              'query_plan':
                  'SCAN projects USING COVERING INDEX idx_projects_name',
            },
          ],
          done: true,
          rowsAffected: null,
          elapsed: const Duration(milliseconds: 1),
        );
      }
      return QueryResultPage(
        cursorId: null,
        columns: const <String>['query_plan'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{
            'query_plan': 'SCAN tasks USING COVERING INDEX idx_tasks_title',
          },
        ],
        done: true,
        rowsAffected: null,
        elapsed: const Duration(milliseconds: 1),
      );
    }
    if (sql.toUpperCase().contains('BROKEN')) {
      throw const BridgeFailure('syntax error near BROKEN', code: 'ERR_SQL');
    }
    if (sql.toUpperCase().startsWith('CREATE')) {
      return QueryResultPage(
        cursorId: null,
        columns: const <String>[],
        rows: const <Map<String, Object?>>[],
        done: true,
        rowsAffected: 0,
        elapsed: const Duration(milliseconds: 2),
      );
    }
    if (sql.toUpperCase().startsWith('INSERT') ||
        sql.toUpperCase().startsWith('UPDATE') ||
        sql.toUpperCase().startsWith('DELETE')) {
      return QueryResultPage(
        cursorId: null,
        columns: const <String>[],
        rows: const <Map<String, Object?>>[],
        done: true,
        rowsAffected: 1,
        elapsed: const Duration(milliseconds: 2),
      );
    }
    if (sql.toLowerCase().contains('projects')) {
      return QueryResultPage(
        cursorId: 'cursor-projects',
        columns: const <String>['id', 'name'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'id': 10, 'name': 'Phase 3'},
        ],
        done: false,
        rowsAffected: null,
        elapsed: const Duration(milliseconds: 5),
      );
    }
    return QueryResultPage(
      cursorId: 'cursor-1',
      columns: const <String>['id', 'title'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'title': 'Ship phase 1'},
      ],
      done: false,
      rowsAffected: null,
      elapsed: const Duration(milliseconds: 5),
    );
  }

  SqliteImportSummary _buildCompletedSummary(SqliteImportRequest request) {
    return SqliteImportSummary(
      jobId: request.jobId,
      sourcePath: request.sourcePath,
      targetPath: request.targetPath,
      importedTables: request.selectedTables
          .map((table) => table.targetName)
          .toList(),
      rowsCopiedByTable: <String, int>{
        for (final table in request.selectedTables)
          table.targetName: table.rowCount,
      },
      indexesCreated: <String>[
        for (final table in request.selectedTables)
          for (final index in table.indexes) index.name,
      ],
      targetTableCount: request.selectedTables.length,
      targetIndexCount: request.selectedTables.fold<int>(
        0,
        (sum, table) => sum + table.indexes.length,
      ),
      targetViewCount: 0,
      targetTriggerCount: 0,
      databaseFileBytes: 8192,
      walFileBytes: 0,
      skippedItems: <SqliteImportSkippedItem>[
        for (final table in request.selectedTables) ...table.skippedItems,
      ],
      warnings: sqliteInspection.warnings,
      statusMessage:
          'Imported ${request.selectedTables.fold<int>(0, (sum, table) => sum + table.rowCount)} rows from ${request.selectedTables.length} SQLite table${request.selectedTables.length == 1 ? '' : 's'}.',
      rolledBack: false,
    );
  }

  SqliteImportSummary _buildCancelledSummary(String jobId) {
    final request = lastSqliteImportRequest;
    if (request == null) {
      return SqliteImportSummary(
        jobId: jobId,
        sourcePath: sqliteInspection.sourcePath,
        targetPath: '/tmp/import-cancelled.ddb',
        importedTables: const <String>[],
        rowsCopiedByTable: const <String, int>{},
        indexesCreated: const <String>[],
        targetTableCount: 0,
        targetIndexCount: 0,
        targetViewCount: 0,
        targetTriggerCount: 0,
        databaseFileBytes: 0,
        walFileBytes: 0,
        skippedItems: const <SqliteImportSkippedItem>[],
        warnings: const <String>[],
        statusMessage: 'SQLite import cancelled and rolled back.',
        rolledBack: true,
      );
    }
    return SqliteImportSummary(
      jobId: jobId,
      sourcePath: request.sourcePath,
      targetPath: request.targetPath,
      importedTables: const <String>[],
      rowsCopiedByTable: const <String, int>{},
      indexesCreated: const <String>[],
      targetTableCount: 0,
      targetIndexCount: 0,
      targetViewCount: 0,
      targetTriggerCount: 0,
      databaseFileBytes: 0,
      walFileBytes: 0,
      skippedItems: const <SqliteImportSkippedItem>[],
      warnings: sqliteInspection.warnings,
      statusMessage: 'SQLite import cancelled and rolled back.',
      rolledBack: true,
    );
  }

  ExcelImportSummary _buildCompletedExcelSummary(ExcelImportRequest request) {
    return ExcelImportSummary(
      jobId: request.jobId,
      sourcePath: request.sourcePath,
      targetPath: request.targetPath,
      importedTables: request.selectedSheets
          .map((sheet) => sheet.targetName)
          .toList(),
      rowsCopiedByTable: <String, int>{
        for (final sheet in request.selectedSheets)
          sheet.targetName: sheet.rowCount,
      },
      warnings: excelInspection.warnings,
      statusMessage:
          'Imported ${request.selectedSheets.fold<int>(0, (sum, sheet) => sum + sheet.rowCount)} rows from ${request.selectedSheets.length} workbook sheet${request.selectedSheets.length == 1 ? '' : 's'}.',
      rolledBack: false,
    );
  }

  ExcelImportSummary _buildCancelledExcelSummary(String jobId) {
    final request = lastExcelImportRequest;
    if (request == null) {
      return ExcelImportSummary(
        jobId: jobId,
        sourcePath: excelInspection.sourcePath,
        targetPath: '/tmp/excel-import-cancelled.ddb',
        importedTables: const <String>[],
        rowsCopiedByTable: const <String, int>{},
        warnings: const <String>[],
        statusMessage: 'Excel import cancelled and rolled back.',
        rolledBack: true,
      );
    }
    return ExcelImportSummary(
      jobId: jobId,
      sourcePath: request.sourcePath,
      targetPath: request.targetPath,
      importedTables: const <String>[],
      rowsCopiedByTable: const <String, int>{},
      warnings: excelInspection.warnings,
      statusMessage: 'Excel import cancelled and rolled back.',
      rolledBack: true,
    );
  }

  SqlDumpImportSummary _buildCompletedSqlDumpSummary(
    SqlDumpImportRequest request,
  ) {
    return SqlDumpImportSummary(
      jobId: request.jobId,
      sourcePath: request.sourcePath,
      targetPath: request.targetPath,
      importedTables: request.selectedTables
          .map((table) => table.targetName)
          .toList(),
      rowsCopiedByTable: <String, int>{
        for (final table in request.selectedTables)
          table.targetName: table.rowCount,
      },
      skippedStatementCount: sqlDumpInspection.skippedStatementCount,
      warnings: sqlDumpInspection.warnings,
      skippedStatements: sqlDumpInspection.skippedStatements,
      statusMessage:
          'Imported ${request.selectedTables.fold<int>(0, (sum, table) => sum + table.rowCount)} rows from ${request.selectedTables.length} parsed table${request.selectedTables.length == 1 ? '' : 's'}.',
      rolledBack: false,
    );
  }

  SqlDumpImportSummary _buildCancelledSqlDumpSummary(String jobId) {
    final request = lastSqlDumpImportRequest;
    if (request == null) {
      return SqlDumpImportSummary(
        jobId: jobId,
        sourcePath: sqlDumpInspection.sourcePath,
        targetPath: '/tmp/sql-dump-import-cancelled.ddb',
        importedTables: const <String>[],
        rowsCopiedByTable: const <String, int>{},
        skippedStatementCount: sqlDumpInspection.skippedStatementCount,
        warnings: sqlDumpInspection.warnings,
        skippedStatements: sqlDumpInspection.skippedStatements,
        statusMessage: 'SQL dump import cancelled and rolled back.',
        rolledBack: true,
      );
    }
    return SqlDumpImportSummary(
      jobId: jobId,
      sourcePath: request.sourcePath,
      targetPath: request.targetPath,
      importedTables: const <String>[],
      rowsCopiedByTable: const <String, int>{},
      skippedStatementCount: sqlDumpInspection.skippedStatementCount,
      warnings: sqlDumpInspection.warnings,
      skippedStatements: sqlDumpInspection.skippedStatements,
      statusMessage: 'SQL dump import cancelled and rolled back.',
      rolledBack: true,
    );
  }
}

QueryContract _fakeQueryContract(String sql, String schemaFingerprint) {
  final upperSql = sql.toUpperCase();
  final isCreate = upperSql.startsWith('CREATE');
  final usesProjects = sql.toLowerCase().contains('projects');
  final columns = usesProjects
      ? const <QueryResultColumnContract>[
          QueryResultColumnContract(
            ordinal: 0,
            name: 'id',
            typeName: 'INT64',
            nullable: false,
            source: 'catalog_column',
            sourceTable: 'projects',
            sourceColumn: 'id',
            diagnostics: <String>[],
          ),
          QueryResultColumnContract(
            ordinal: 1,
            name: 'name',
            typeName: 'TEXT',
            nullable: false,
            source: 'catalog_column',
            sourceTable: 'projects',
            sourceColumn: 'name',
            diagnostics: <String>[],
          ),
        ]
      : isCreate
      ? const <QueryResultColumnContract>[]
      : const <QueryResultColumnContract>[
          QueryResultColumnContract(
            ordinal: 0,
            name: 'id',
            typeName: 'INT64',
            nullable: false,
            source: 'catalog_column',
            sourceTable: 'tasks',
            sourceColumn: 'id',
            diagnostics: <String>[],
          ),
          QueryResultColumnContract(
            ordinal: 1,
            name: 'title',
            typeName: 'TEXT',
            nullable: false,
            source: 'catalog_column',
            sourceTable: 'tasks',
            sourceColumn: 'title',
            diagnostics: <String>[],
          ),
        ];
  return QueryContract(
    contractVersion: 1,
    sql: sql,
    statementKind: isCreate ? 'create' : 'query',
    readOnly: !isCreate,
    schemaCookie: 1,
    tempSchemaCookie: 0,
    schemaFingerprint: schemaFingerprint,
    parameters: sql.contains(r'$1')
        ? const <QueryParameterContract>[
            QueryParameterContract(
              position: 1,
              name: r'$1',
              typeName: 'INT64',
              nullable: false,
              source: 'catalog_column',
              sourceTable: 'tasks',
              sourceColumn: 'id',
              diagnostics: <String>[],
            ),
          ]
        : const <QueryParameterContract>[],
    resultColumns: columns,
    diagnostics: const <String>[],
  );
}

ExcelImportInspection _defaultExcelInspection(String sourcePath) {
  return ExcelImportInspection(
    sourcePath: sourcePath,
    headerRow: true,
    warnings: const <String>['Workbook formulas are imported as formula text.'],
    sheets: const <ExcelImportSheetDraft>[
      ExcelImportSheetDraft(
        sourceName: 'people',
        targetName: 'people',
        selected: true,
        rowCount: 2,
        columns: <ExcelImportColumnDraft>[
          ExcelImportColumnDraft(
            sourceIndex: 0,
            sourceName: 'id',
            targetName: 'id',
            inferredTargetType: 'INTEGER',
            targetType: 'INTEGER',
            containsNulls: false,
          ),
          ExcelImportColumnDraft(
            sourceIndex: 1,
            sourceName: 'name',
            targetName: 'name',
            inferredTargetType: 'TEXT',
            targetType: 'TEXT',
            containsNulls: false,
          ),
          ExcelImportColumnDraft(
            sourceIndex: 2,
            sourceName: 'active',
            targetName: 'active',
            inferredTargetType: 'BOOLEAN',
            targetType: 'BOOLEAN',
            containsNulls: false,
          ),
        ],
        previewRows: <Map<String, Object?>>[
          <String, Object?>{'id': 1, 'name': 'Ada', 'active': true},
          <String, Object?>{'id': 2, 'name': 'Grace', 'active': false},
        ],
      ),
      ExcelImportSheetDraft(
        sourceName: 'metrics',
        targetName: 'metrics',
        selected: true,
        rowCount: 2,
        columns: <ExcelImportColumnDraft>[
          ExcelImportColumnDraft(
            sourceIndex: 0,
            sourceName: 'quarter',
            targetName: 'quarter',
            inferredTargetType: 'TEXT',
            targetType: 'TEXT',
            containsNulls: false,
          ),
          ExcelImportColumnDraft(
            sourceIndex: 1,
            sourceName: 'revenue',
            targetName: 'revenue',
            inferredTargetType: 'FLOAT64',
            targetType: 'FLOAT64',
            containsNulls: false,
          ),
        ],
        previewRows: <Map<String, Object?>>[
          <String, Object?>{'quarter': 'Q1', 'revenue': 1200.5},
          <String, Object?>{'quarter': 'Q2', 'revenue': 1800.25},
        ],
      ),
    ],
  );
}

SqlDumpImportInspection _defaultSqlDumpInspection(String sourcePath) {
  return SqlDumpImportInspection(
    sourcePath: sourcePath,
    requestedEncoding: 'auto',
    resolvedEncoding: 'utf8',
    warnings: <String>[
      'Skipped 2 unsupported session-management statements during SQL dump inspection.',
    ],
    skippedStatements: <SqlDumpImportSkippedStatement>[
      SqlDumpImportSkippedStatement(
        ordinal: 1,
        kind: 'SET',
        reason: 'Skipping unsupported SET statement #1.',
        snippet: 'SET NAMES utf8mb4',
      ),
      SqlDumpImportSkippedStatement(
        ordinal: 5,
        kind: 'LOCK TABLES',
        reason: 'Skipping unsupported LOCK TABLES statement #5.',
        snippet: 'LOCK TABLES `people` WRITE',
      ),
    ],
    totalStatements: 6,
    tables: <SqlDumpImportTableDraft>[
      SqlDumpImportTableDraft(
        sourceName: 'people',
        targetName: 'people',
        selected: true,
        rowCount: 2,
        columns: <SqlDumpImportColumnDraft>[
          SqlDumpImportColumnDraft(
            sourceIndex: 0,
            sourceName: 'id',
            targetName: 'id',
            declaredType: 'INT',
            inferredTargetType: 'INTEGER',
            targetType: 'INTEGER',
            notNull: true,
            primaryKey: true,
            unique: true,
          ),
          SqlDumpImportColumnDraft(
            sourceIndex: 1,
            sourceName: 'name',
            targetName: 'name',
            declaredType: 'VARCHAR(255)',
            inferredTargetType: 'TEXT',
            targetType: 'TEXT',
            notNull: true,
            primaryKey: false,
            unique: false,
          ),
          SqlDumpImportColumnDraft(
            sourceIndex: 2,
            sourceName: 'active',
            targetName: 'active',
            declaredType: 'TINYINT(1)',
            inferredTargetType: 'BOOLEAN',
            targetType: 'BOOLEAN',
            notNull: false,
            primaryKey: false,
            unique: false,
          ),
        ],
        previewRows: <Map<String, Object?>>[
          <String, Object?>{'id': 1, 'name': 'Ada', 'active': true},
          <String, Object?>{'id': 2, 'name': 'Grace', 'active': false},
        ],
      ),
      SqlDumpImportTableDraft(
        sourceName: 'metrics',
        targetName: 'metrics',
        selected: true,
        rowCount: 2,
        columns: <SqlDumpImportColumnDraft>[
          SqlDumpImportColumnDraft(
            sourceIndex: 0,
            sourceName: 'quarter',
            targetName: 'quarter',
            declaredType: 'VARCHAR(16)',
            inferredTargetType: 'TEXT',
            targetType: 'TEXT',
            notNull: true,
            primaryKey: true,
            unique: true,
          ),
          SqlDumpImportColumnDraft(
            sourceIndex: 1,
            sourceName: 'revenue',
            targetName: 'revenue',
            declaredType: 'DECIMAL(10,2)',
            inferredTargetType: 'DECIMAL(10,2)',
            targetType: 'DECIMAL(10,2)',
            notNull: false,
            primaryKey: false,
            unique: false,
          ),
        ],
        previewRows: <Map<String, Object?>>[
          <String, Object?>{'quarter': 'Q1', 'revenue': '1200.50'},
          <String, Object?>{'quarter': 'Q2', 'revenue': '1800.25'},
        ],
      ),
    ],
  );
}

SqliteImportInspection _defaultSqliteInspection(String sourcePath) {
  return SqliteImportInspection(
    sourcePath: sourcePath,
    warnings: const <String>[
      'audit_log uses WITHOUT ROWID in SQLite; Decent Bench preserves data and keys but not WITHOUT ROWID storage semantics.',
    ],
    tables: const <SqliteImportTableDraft>[
      SqliteImportTableDraft(
        sourceName: 'users',
        targetName: 'users',
        selected: true,
        rowCount: 2,
        strict: false,
        withoutRowId: false,
        columns: <SqliteImportColumnDraft>[
          SqliteImportColumnDraft(
            sourceName: 'id',
            targetName: 'id',
            declaredType: 'INTEGER',
            inferredTargetType: 'INTEGER',
            targetType: 'INTEGER',
            notNull: true,
            primaryKey: true,
            unique: true,
          ),
          SqliteImportColumnDraft(
            sourceName: 'name',
            targetName: 'name',
            declaredType: 'TEXT',
            inferredTargetType: 'TEXT',
            targetType: 'TEXT',
            notNull: true,
            primaryKey: false,
            unique: false,
          ),
        ],
        foreignKeys: <SqliteImportForeignKey>[],
        indexes: <SqliteImportIndex>[
          SqliteImportIndex(
            name: 'idx_users_name',
            column: 'name',
            unique: false,
          ),
        ],
        skippedItems: <SqliteImportSkippedItem>[],
        previewRows: <Map<String, Object?>>[],
        previewLoaded: false,
      ),
      SqliteImportTableDraft(
        sourceName: 'audit_log',
        targetName: 'audit_log',
        selected: true,
        rowCount: 1,
        strict: false,
        withoutRowId: true,
        columns: <SqliteImportColumnDraft>[
          SqliteImportColumnDraft(
            sourceName: 'entry_id',
            targetName: 'entry_id',
            declaredType: 'INTEGER',
            inferredTargetType: 'INTEGER',
            targetType: 'INTEGER',
            notNull: true,
            primaryKey: true,
            unique: true,
          ),
          SqliteImportColumnDraft(
            sourceName: 'actor_id',
            targetName: 'actor_id',
            declaredType: 'INTEGER',
            inferredTargetType: 'INTEGER',
            targetType: 'INTEGER',
            notNull: true,
            primaryKey: false,
            unique: false,
          ),
          SqliteImportColumnDraft(
            sourceName: 'created_at',
            targetName: 'created_at',
            declaredType: 'TEXT',
            inferredTargetType: 'TEXT',
            targetType: 'TEXT',
            notNull: false,
            primaryKey: false,
            unique: false,
          ),
        ],
        foreignKeys: <SqliteImportForeignKey>[
          SqliteImportForeignKey(
            fromColumn: 'actor_id',
            toTable: 'users',
            toColumn: 'id',
          ),
        ],
        indexes: <SqliteImportIndex>[],
        skippedItems: <SqliteImportSkippedItem>[],
        previewRows: <Map<String, Object?>>[],
        previewLoaded: false,
      ),
    ],
  );
}

Map<String, SqliteImportPreview> _defaultSqlitePreviews() {
  return <String, SqliteImportPreview>{
    'users': const SqliteImportPreview(
      tableName: 'users',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Ada'},
        <String, Object?>{'id': 2, 'name': 'Grace'},
      ],
    ),
    'audit_log': const SqliteImportPreview(
      tableName: 'audit_log',
      rows: <Map<String, Object?>>[
        <String, Object?>{
          'entry_id': 1,
          'actor_id': 1,
          'created_at': '2026-03-10T12:00:00Z',
        },
      ],
    ),
  };
}
