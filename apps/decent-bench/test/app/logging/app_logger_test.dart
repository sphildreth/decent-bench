import 'dart:io';

import 'package:decent_bench/app/logging/app_logger.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/excel_import_models.dart';
import 'package:decent_bench/features/workspace/domain/sql_dump_import_models.dart';
import 'package:decent_bench/features/workspace/domain/sqlite_import_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logger initializes the log database schema', () async {
    final gateway = _FakeLogGateway();
    final logger = DecentBenchLogger(
      gatewayFactory: () => gateway,
      logDatabasePath: '/tmp/decent-bench-log-test.ddb',
    );
    addTearDown(logger.dispose);

    await logger.initialize();

    expect(gateway.openedPath, '/tmp/decent-bench-log-test.ddb');
    expect(
      gateway.executedSql.any(
        (sql) => sql.contains('CREATE TABLE IF NOT EXISTS app_logs'),
      ),
      isTrue,
    );
    expect(
      gateway.executedSql.any(
        (sql) =>
            sql.contains('CREATE INDEX IF NOT EXISTS idx_app_logs_logged_at'),
      ),
      isTrue,
    );
    expect(gateway.inserts, hasLength(1));
    expect(gateway.inserts.single.params[3], 'logging');
    expect(gateway.inserts.single.params[4], 'initialize');
  });

  test('logger respects the configured verbosity threshold', () async {
    final gateway = _FakeLogGateway();
    final logger = DecentBenchLogger(
      gatewayFactory: () => gateway,
      logDatabasePath: '/tmp/decent-bench-log-test.ddb',
    );
    addTearDown(logger.dispose);

    await logger.initialize(minimumLevel: LogVerbosity.warning);
    logger.info(category: 'workspace', operation: 'init', message: 'skip me');
    logger.error(category: 'workspace', operation: 'init', message: 'keep me');
    await logger.dispose();

    final inserted = gateway.inserts;
    expect(inserted, hasLength(2));
    expect(inserted.last.params[2], 'Errors');
    expect(inserted.last.params[5], 'keep me');
  });

  test('logger writes structured query timing records', () async {
    final gateway = _FakeLogGateway();
    final logger = DecentBenchLogger(
      gatewayFactory: () => gateway,
      logDatabasePath: '/tmp/decent-bench-log-test.ddb',
    );
    addTearDown(logger.dispose);

    await logger.initialize(minimumLevel: LogVerbosity.information);
    logger.logQueryTiming(
      databasePath: '/tmp/workbench.ddb',
      sql: 'SELECT * FROM tasks',
      rowCount: 42,
      elapsedNanos: 987654321,
      rowsAffected: 0,
      details: const <String, Object?>{'tab_id': 'query-tab-1'},
    );
    await logger.dispose();

    expect(gateway.inserts, hasLength(2));
    final inserted = gateway.inserts.last;
    expect(inserted.params[6], '/tmp/workbench.ddb');
    expect(inserted.params[7], 'SELECT * FROM tasks');
    expect(inserted.params[8], 42);
    expect(inserted.params[9], 0);
    expect(inserted.params[10], 987654321);
    expect((inserted.params[11] as String), contains('"tab_id":"query-tab-1"'));
  });

  test('logger skips schema DDL when the log objects already exist', () async {
    final gateway = _FakeLogGateway()
      ..schema = SchemaSnapshot(
        objects: <SchemaObjectSummary>[
          const SchemaObjectSummary(
            name: 'app_logs',
            kind: SchemaObjectKind.table,
            columns: <SchemaColumn>[],
          ),
        ],
        indexes: const <IndexSummary>[
          IndexSummary(
            name: 'idx_app_logs_logged_at',
            table: 'app_logs',
            columns: <String>['logged_at_utc'],
            unique: false,
            kind: 'index',
          ),
        ],
        loadedAt: DateTime.utc(2026, 3, 11),
      );
    final logger = DecentBenchLogger(
      gatewayFactory: () => gateway,
      logDatabasePath: '/tmp/decent-bench-log-test.ddb',
    );
    addTearDown(logger.dispose);

    await logger.initialize();

    expect(
      gateway.executedSql.where((sql) => sql.contains('CREATE TABLE')),
      isEmpty,
    );
    expect(
      gateway.executedSql.where((sql) => sql.contains('CREATE INDEX')),
      isEmpty,
    );
    expect(gateway.inserts, hasLength(1));
  });

  test('logger recreates an incompatible log database once', () async {
    final directory = await Directory.systemTemp.createTemp(
      'decent-bench-log-recovery-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final logDatabasePath = '${directory.path}/decent-bench-log.ddb';
    await File(logDatabasePath).writeAsString('stale');
    await File('$logDatabasePath-wal').writeAsString('stale wal');

    final gateway = _FakeLogGateway()
      ..failOpenCount = 1
      ..openError = const BridgeFailure(
        'database corruption: unsupported database format version 3 on page 1; expected 8',
        code: 'corruption',
      );
    final logger = DecentBenchLogger(
      gatewayFactory: () => gateway,
      logDatabasePath: logDatabasePath,
    );
    addTearDown(logger.dispose);

    await logger.initialize();

    expect(gateway.openCalls, 2);
    expect(await File(logDatabasePath).exists(), isFalse);
    expect(await File('$logDatabasePath-wal').exists(), isFalse);
    expect(gateway.inserts, hasLength(1));
  });

  test(
    'logger stops retrying after a non-recoverable initialization failure',
    () async {
      final gateway = _FakeLogGateway()
        ..openError = const BridgeFailure('permission denied', code: 'io')
        ..failOpenForever = true;
      final logger = DecentBenchLogger(
        gatewayFactory: () => gateway,
        logDatabasePath: '/tmp/decent-bench-log-test.ddb',
      );
      addTearDown(logger.dispose);

      logger.error(category: 'workspace', operation: 'init', message: 'first');
      logger.error(category: 'workspace', operation: 'init', message: 'second');
      await logger.dispose();

      expect(gateway.openCalls, 1);
      expect(gateway.inserts, isEmpty);
    },
  );
}

class _FakeLogGateway implements WorkspaceDatabaseGateway {
  final List<String> executedSql = <String>[];
  final List<_ExecutedInsert> inserts = <_ExecutedInsert>[];
  String? openedPath;
  SchemaSnapshot schema = SchemaSnapshot.empty();
  int openCalls = 0;
  int failOpenCount = 0;
  Object? openError;
  bool failOpenForever = false;

  @override
  String? get resolvedLibraryPath => '/tmp/libdecentdb.so';

  @override
  Future<void> cancelImport(String jobId) async {}

  @override
  Future<WorkspaceBranchDiff> branchDiff({
    required String leftRef,
    required String rightRef,
  }) async {
    throw const BranchWorkflowUnavailable();
  }

  @override
  Future<void> cancelQuery(String cursorId) async {}

  @override
  Future<WorkspaceBranchInfo> createBranch({
    required String branchName,
    required String fromRef,
  }) async {
    throw const BranchWorkflowUnavailable();
  }

  @override
  Future<WorkspaceSnapshotInfo> createSnapshot({required String name}) async {
    throw const BranchWorkflowUnavailable();
  }

  @override
  Future<void> deleteBranch({required String branchName}) async {}

  @override
  Future<void> deleteSnapshot({required String ref}) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<WorkspaceBranchInfo>> listBranches() async {
    throw const BranchWorkflowUnavailable();
  }

  @override
  Future<List<WorkspaceSnapshotInfo>> listSnapshots() async {
    throw const BranchWorkflowUnavailable();
  }

  @override
  Future<WorkspaceBranchDiff> mergeBranch({
    required String sourceBranch,
    required String targetBranch,
    required bool dryRun,
  }) async {
    throw const BranchWorkflowUnavailable();
  }

  @override
  Future<WorkspaceBranchDiff> restoreBranch({
    required String branchName,
    required String targetRef,
    required bool dryRun,
  }) async {
    throw const BranchWorkflowUnavailable();
  }

  @override
  Future<QueryResultPage> runQueryOnBranch({
    required String sql,
    required String branchName,
    required List<Object?> params,
    required int pageSize,
  }) async {
    throw const BranchWorkflowUnavailable();
  }

  @override
  Future<CsvExportResult> exportCsv({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required String delimiter,
    required bool includeHeaders,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
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
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ExcelExportResult> exportExcel({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required bool includeHeaders,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<QueryResultPage> fetchNextPage({
    required String cursorId,
    required int pageSize,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ToolingMetadata> getToolingMetadata() async {
    return const ToolingMetadata(
      metadataVersion: 1,
      engineVersion: '2.8.0',
      databaseFormatVersion: 8,
      schemaCookie: 1,
      tempSchemaCookie: 0,
      schemaFingerprint:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      schemaFingerprintAlgorithm: 'sha256:decentdb-tooling-schema-v1',
      columnTypeMetadata: <ToolingColumnTypeMetadata>[],
      capabilities: ToolingCapabilities(
        queryContractVersion: 1,
        queryDescribe: true,
        deterministicJson: true,
      ),
    );
  }

  @override
  Future<QueryContract> describeQueryContract(String sql) async {
    return QueryContract(
      contractVersion: 1,
      sql: sql,
      statementKind: sql.trimLeft().toUpperCase().startsWith('SELECT')
          ? 'query'
          : 'insert',
      readOnly: sql.trimLeft().toUpperCase().startsWith('SELECT'),
      schemaCookie: 1,
      tempSchemaCookie: 0,
      schemaFingerprint:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      parameters: const <QueryParameterContract>[],
      resultColumns: const <QueryResultColumnContract>[],
      diagnostics: const <String>[],
    );
  }

  @override
  Stream<ExcelImportUpdate> importExcel({required ExcelImportRequest request}) {
    throw UnimplementedError();
  }

  @override
  Stream<SqlDumpImportUpdate> importSqlDump({
    required SqlDumpImportRequest request,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<SqliteImportUpdate> importSqlite({
    required SqliteImportRequest request,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> initialize() async => resolvedLibraryPath!;

  @override
  Future<ExcelImportInspection> inspectExcelSource({
    required String sourcePath,
    required bool headerRow,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<SqlDumpImportInspection> inspectSqlDumpSource({
    required String sourcePath,
    required String encoding,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<SqliteImportInspection> inspectSqliteSource({
    required String sourcePath,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<SchemaSnapshot> loadSchema() async {
    return schema;
  }

  @override
  Future<OperationalMetricsSnapshot> loadOperationalMetrics({
    int maxRows = 20,
  }) async {
    return OperationalMetricsSnapshot.empty();
  }

  @override
  Future<SqliteImportPreview> loadSqlitePreview({
    required String sourcePath,
    required String tableName,
    int limit = 8,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DatabaseSession> openDatabase(
    String path, {
    WriteQueueSettings? writeQueue,
  }) async {
    openCalls += 1;
    if (failOpenCount > 0) {
      failOpenCount -= 1;
      throw openError!;
    }
    if (failOpenForever && openError != null) {
      throw openError!;
    }
    openedPath = path;
    return DatabaseSession(path: path, engineVersion: '1.6.1');
  }

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    Duration? timeout,
  }) async {
    executedSql.add(sql);
    if (sql.contains('INSERT INTO app_logs')) {
      inserts.add(
        _ExecutedInsert(sql: sql, params: List<Object?>.from(params)),
      );
    }
    return const QueryResultPage(
      cursorId: null,
      columns: <String>[],
      rows: <Map<String, Object?>>[],
      done: true,
      rowsAffected: 1,
      elapsed: Duration(milliseconds: 1),
    );
  }

  @override
  Future<QueuedWriteResult> executeQueuedWrite({
    required String sql,
    required List<Object?> params,
    int? timeoutMs,
  }) async {
    executedSql.add(sql);
    return const QueuedWriteResult(rowsAffected: 1);
  }
}

class _ExecutedInsert {
  const _ExecutedInsert({required this.sql, required this.params});

  final String sql;
  final List<Object?> params;
}
