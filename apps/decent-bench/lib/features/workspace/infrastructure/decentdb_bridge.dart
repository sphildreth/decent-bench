import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:decentdb/decentdb.dart' hide SchemaSnapshot;

import '../domain/excel_import_models.dart';
import '../domain/sql_dump_import_models.dart';
import '../domain/sqlite_import_models.dart';
import '../domain/workspace_models.dart';
import 'excel_import_support.dart';
import 'native_library_resolver.dart';
import 'sql_dump_import_support.dart';
import 'sqlite_import_support.dart';
import 'xlsx_export_support.dart';

abstract class WorkspaceDatabaseGateway {
  String? get resolvedLibraryPath;

  Future<String> initialize();

  Future<DatabaseSession> openDatabase(String path);

  Future<SchemaSnapshot> loadSchema();

  Future<ToolingMetadata> getToolingMetadata();

  Future<QueryContract> describeQueryContract(String sql);

  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  });

  Future<QueryResultPage> fetchNextPage({
    required String cursorId,
    required int pageSize,
  });

  Future<void> cancelQuery(String cursorId);

  Future<CsvExportResult> exportCsv({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required String delimiter,
    required bool includeHeaders,
  });

  Future<JsonExportResult> exportJson({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required String format,
    required bool pretty,
    required bool includeMetadata,
  });

  Future<ExcelExportResult> exportExcel({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required bool includeHeaders,
  });

  Future<SqliteImportInspection> inspectSqliteSource({
    required String sourcePath,
  });

  Future<ExcelImportInspection> inspectExcelSource({
    required String sourcePath,
    required bool headerRow,
  });

  Future<SqlDumpImportInspection> inspectSqlDumpSource({
    required String sourcePath,
    required String encoding,
  });

  Future<SqliteImportPreview> loadSqlitePreview({
    required String sourcePath,
    required String tableName,
    int limit,
  });

  Stream<SqliteImportUpdate> importSqlite({
    required SqliteImportRequest request,
  });

  Stream<ExcelImportUpdate> importExcel({required ExcelImportRequest request});

  Stream<SqlDumpImportUpdate> importSqlDump({
    required SqlDumpImportRequest request,
  });

  Future<void> cancelImport(String jobId);

  Future<List<WorkspaceBranchInfo>> listBranches();

  Future<WorkspaceBranchInfo> createBranch({
    required String branchName,
    required String fromRef,
  });

  Future<void> deleteBranch({required String branchName});

  Future<List<WorkspaceSnapshotInfo>> listSnapshots();

  Future<WorkspaceSnapshotInfo> createSnapshot({required String name});

  Future<void> deleteSnapshot({required String ref});

  Future<QueryResultPage> runQueryOnBranch({
    required String sql,
    required String branchName,
    required List<Object?> params,
    required int pageSize,
  });

  Future<WorkspaceBranchDiff> branchDiff({
    required String leftRef,
    required String rightRef,
  });

  Future<WorkspaceBranchDiff> restoreBranch({
    required String branchName,
    required String targetRef,
    required bool dryRun,
  });

  Future<WorkspaceBranchDiff> mergeBranch({
    required String sourceBranch,
    required String targetBranch,
    required bool dryRun,
  });

  Future<void> dispose();
}

class DecentDbBridge implements WorkspaceDatabaseGateway {
  DecentDbBridge({NativeLibraryResolver? resolver})
    : _resolver = resolver ?? NativeLibraryResolver();

  final NativeLibraryResolver _resolver;
  final Map<int, Completer<Map<String, Object?>>> _pending =
      <int, Completer<Map<String, Object?>>>{};
  final Map<String, _SqliteImportOperation> _imports =
      <String, _SqliteImportOperation>{};
  final Map<String, _ExcelImportOperation> _excelImports =
      <String, _ExcelImportOperation>{};
  final Map<String, _SqlDumpImportOperation> _sqlDumpImports =
      <String, _SqlDumpImportOperation>{};

  Isolate? _isolate;
  SendPort? _workerPort;
  ReceivePort? _responses;
  int _nextRequestId = 1;

  @override
  String? resolvedLibraryPath;

  @override
  Future<String> initialize() async {
    if (_workerPort != null && resolvedLibraryPath != null) {
      return resolvedLibraryPath!;
    }

    resolvedLibraryPath = await _resolver.resolve();
    _responses = ReceivePort();
    _isolate = await Isolate.spawn<List<Object?>>(_workerMain, <Object?>[
      _responses!.sendPort,
      resolvedLibraryPath!,
    ]);

    final readyCompleter = Completer<void>();
    _responses!.listen((message) {
      if (message is SendPort) {
        _workerPort = message;
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete();
        }
        return;
      }

      if (message is! Map<Object?, Object?>) {
        return;
      }

      final response = message.map(
        (key, value) => MapEntry(key as String, value),
      );
      final requestId = response['id'] as int;
      final completer = _pending.remove(requestId);
      if (completer == null) {
        return;
      }

      if (response['ok'] as bool) {
        final data =
            (response['data'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{};
        completer.complete(
          data.map((key, value) => MapEntry(key as String, value)),
        );
      } else {
        final error = (response['error'] as Map<Object?, Object?>).map(
          (key, value) => MapEntry(key as String, value),
        );
        completer.completeError(
          BridgeFailure(
            error['message']! as String,
            code: error['code'] as String?,
          ),
          StackTrace.fromString(error['stack'] as String? ?? ''),
        );
      }
    });

    await readyCompleter.future;
    return resolvedLibraryPath!;
  }

  @override
  Future<DatabaseSession> openDatabase(String path) async {
    final data = await _request('openDatabase', <String, Object?>{
      'path': path,
    });
    return DatabaseSession.fromMap(data);
  }

  @override
  Future<SchemaSnapshot> loadSchema() async {
    final data = await _request('loadSchema');
    return SchemaSnapshot.fromMap(data);
  }

  @override
  Future<ToolingMetadata> getToolingMetadata() async {
    final data = await _request('getToolingMetadata');
    return ToolingMetadata.fromMap(data);
  }

  @override
  Future<QueryContract> describeQueryContract(String sql) async {
    final data = await _request('describeQueryContract', <String, Object?>{
      'sql': sql,
    });
    return QueryContract.fromMap(data);
  }

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  }) async {
    final data = await _request('runQuery', <String, Object?>{
      'sql': sql,
      'params': params,
      'pageSize': pageSize,
    });
    return QueryResultPage.fromMap(data);
  }

  @override
  Future<QueryResultPage> fetchNextPage({
    required String cursorId,
    required int pageSize,
  }) async {
    final data = await _request('fetchNextPage', <String, Object?>{
      'cursorId': cursorId,
      'pageSize': pageSize,
    });
    return QueryResultPage.fromMap(data);
  }

  @override
  Future<void> cancelQuery(String cursorId) async {
    await _request('cancelQuery', <String, Object?>{'cursorId': cursorId});
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
    final data = await _request('exportCsv', <String, Object?>{
      'sql': sql,
      'params': params,
      'pageSize': pageSize,
      'path': path,
      'delimiter': delimiter,
      'includeHeaders': includeHeaders,
    });
    return CsvExportResult.fromMap(data);
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
    final data = await _request('exportJson', <String, Object?>{
      'sql': sql,
      'params': params,
      'pageSize': pageSize,
      'path': path,
      'format': format,
      'pretty': pretty,
      'includeMetadata': includeMetadata,
    });
    return JsonExportResult.fromMap(data);
  }

  @override
  Future<ExcelExportResult> exportExcel({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required bool includeHeaders,
  }) async {
    final data = await _request('exportExcel', <String, Object?>{
      'sql': sql,
      'params': params,
      'pageSize': pageSize,
      'path': path,
      'includeHeaders': includeHeaders,
    });
    return ExcelExportResult.fromMap(data);
  }

  @override
  Future<SqliteImportInspection> inspectSqliteSource({
    required String sourcePath,
  }) async {
    return inspectSqliteSourceInBackground(sourcePath);
  }

  @override
  Future<ExcelImportInspection> inspectExcelSource({
    required String sourcePath,
    required bool headerRow,
  }) async {
    return inspectExcelSourceInBackground(sourcePath, headerRow: headerRow);
  }

  @override
  Future<SqlDumpImportInspection> inspectSqlDumpSource({
    required String sourcePath,
    required String encoding,
  }) async {
    return inspectSqlDumpSourceInBackground(sourcePath, encoding: encoding);
  }

  @override
  Future<SqliteImportPreview> loadSqlitePreview({
    required String sourcePath,
    required String tableName,
    int limit = 8,
  }) async {
    return loadSqlitePreviewInBackground(sourcePath, tableName, limit: limit);
  }

  @override
  Stream<SqliteImportUpdate> importSqlite({
    required SqliteImportRequest request,
  }) {
    final existing = _imports[request.jobId];
    if (existing != null) {
      return existing.controller.stream;
    }

    final operation = _SqliteImportOperation(
      controller: StreamController<SqliteImportUpdate>(),
      receivePort: ReceivePort(),
    );
    _imports[request.jobId] = operation;
    unawaited(_startImportOperation(request, operation));
    return operation.controller.stream;
  }

  @override
  Stream<ExcelImportUpdate> importExcel({required ExcelImportRequest request}) {
    final existing = _excelImports[request.jobId];
    if (existing != null) {
      return existing.controller.stream;
    }

    final operation = _ExcelImportOperation(
      controller: StreamController<ExcelImportUpdate>(),
      receivePort: ReceivePort(),
    );
    _excelImports[request.jobId] = operation;
    unawaited(_startExcelImportOperation(request, operation));
    return operation.controller.stream;
  }

  @override
  Stream<SqlDumpImportUpdate> importSqlDump({
    required SqlDumpImportRequest request,
  }) {
    final existing = _sqlDumpImports[request.jobId];
    if (existing != null) {
      return existing.controller.stream;
    }

    final operation = _SqlDumpImportOperation(
      controller: StreamController<SqlDumpImportUpdate>(),
      receivePort: ReceivePort(),
    );
    _sqlDumpImports[request.jobId] = operation;
    unawaited(_startSqlDumpImportOperation(request, operation));
    return operation.controller.stream;
  }

  @override
  Future<void> cancelImport(String jobId) async {
    final operation = _imports[jobId];
    if (operation != null) {
      operation.commandPort?.send('cancel');
      return;
    }
    final excelOperation = _excelImports[jobId];
    if (excelOperation != null) {
      excelOperation.commandPort?.send('cancel');
      return;
    }
    final sqlDumpOperation = _sqlDumpImports[jobId];
    sqlDumpOperation?.commandPort?.send('cancel');
  }

  @override
  Future<void> dispose() async {
    if (_workerPort != null) {
      try {
        await _request('shutdown');
      } catch (_) {
        // Ignore shutdown races.
      }
    }
    for (final operation in _imports.values.toList()) {
      operation.commandPort?.send('cancel');
      operation.receivePort.close();
      await operation.controller.close();
      operation.isolate?.kill(priority: Isolate.immediate);
    }
    _imports.clear();
    for (final operation in _excelImports.values.toList()) {
      operation.commandPort?.send('cancel');
      operation.receivePort.close();
      await operation.controller.close();
      operation.isolate?.kill(priority: Isolate.immediate);
    }
    _excelImports.clear();
    for (final operation in _sqlDumpImports.values.toList()) {
      operation.commandPort?.send('cancel');
      operation.receivePort.close();
      await operation.controller.close();
      operation.isolate?.kill(priority: Isolate.immediate);
    }
    _sqlDumpImports.clear();
    _responses?.close();
    _responses = null;
    _workerPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  @override
  Future<List<WorkspaceBranchInfo>>
  listBranches() async => throw const BranchWorkflowUnavailable(
    'Native branch APIs are not publicly exposed by the current Dart binding.',
  );

  @override
  Future<WorkspaceBranchInfo> createBranch({
    required String branchName,
    required String fromRef,
  }) async => throw const BranchWorkflowUnavailable(
    'Native branch APIs are not publicly exposed by the current Dart binding.',
  );

  @override
  Future<void> deleteBranch({required String branchName}) async {
    throw const BranchWorkflowUnavailable(
      'Native branch APIs are not publicly exposed by the current Dart binding.',
    );
  }

  @override
  Future<List<WorkspaceSnapshotInfo>>
  listSnapshots() async => throw const BranchWorkflowUnavailable(
    'Native branch APIs are not publicly exposed by the current Dart binding.',
  );

  @override
  Future<WorkspaceSnapshotInfo> createSnapshot({
    required String name,
  }) async => throw const BranchWorkflowUnavailable(
    'Native branch APIs are not publicly exposed by the current Dart binding.',
  );

  @override
  Future<void> deleteSnapshot({required String ref}) async {
    throw const BranchWorkflowUnavailable(
      'Native branch APIs are not publicly exposed by the current Dart binding.',
    );
  }

  @override
  Future<QueryResultPage> runQueryOnBranch({
    required String sql,
    required String branchName,
    required List<Object?> params,
    required int pageSize,
  }) async => throw const BranchWorkflowUnavailable(
    'Native branch APIs are not publicly exposed by the current Dart binding.',
  );

  @override
  Future<WorkspaceBranchDiff> branchDiff({
    required String leftRef,
    required String rightRef,
  }) async => throw const BranchWorkflowUnavailable(
    'Native branch APIs are not publicly exposed by the current Dart binding.',
  );

  @override
  Future<WorkspaceBranchDiff> restoreBranch({
    required String branchName,
    required String targetRef,
    required bool dryRun,
  }) async => throw const BranchWorkflowUnavailable(
    'Native branch APIs are not publicly exposed by the current Dart binding.',
  );

  @override
  Future<WorkspaceBranchDiff> mergeBranch({
    required String sourceBranch,
    required String targetBranch,
    required bool dryRun,
  }) async => throw const BranchWorkflowUnavailable(
    'Native branch APIs are not publicly exposed by the current Dart binding.',
  );

  Future<Map<String, Object?>> _request(
    String action, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) async {
    await initialize();
    final workerPort = _workerPort;
    final responses = _responses;
    if (workerPort == null || responses == null) {
      throw const BridgeFailure('DecentDB worker isolate is not available.');
    }

    final requestId = _nextRequestId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[requestId] = completer;

    workerPort.send(<String, Object?>{
      'id': requestId,
      'replyPort': responses.sendPort,
      'action': action,
      'payload': payload,
    });

    return completer.future;
  }

  Future<void> _startImportOperation(
    SqliteImportRequest request,
    _SqliteImportOperation operation,
  ) async {
    try {
      final libraryPath = await initialize();
      operation.isolate = await Isolate.spawn<List<Object?>>(
        sqliteImportWorkerMain,
        <Object?>[operation.receivePort.sendPort, libraryPath, request.toMap()],
      );

      operation.receivePort.listen((message) async {
        if (message is SendPort) {
          operation.commandPort = message;
          return;
        }
        if (message is! Map<Object?, Object?>) {
          return;
        }

        final update = SqliteImportUpdate.fromMap(
          message.map((key, value) => MapEntry(key as String, value)),
        );
        if (!operation.controller.isClosed) {
          operation.controller.add(update);
        }
        if (_isTerminalImportUpdate(update.kind)) {
          await _closeImportOperation(request.jobId);
        }
      });
    } catch (error, stackTrace) {
      if (!operation.controller.isClosed) {
        operation.controller.add(
          SqliteImportUpdate(
            kind: SqliteImportUpdateKind.failed,
            jobId: request.jobId,
            message: '$error\n$stackTrace',
          ),
        );
      }
      await _closeImportOperation(request.jobId);
    }
  }

  Future<void> _startExcelImportOperation(
    ExcelImportRequest request,
    _ExcelImportOperation operation,
  ) async {
    try {
      final libraryPath = await initialize();
      operation.isolate = await Isolate.spawn<List<Object?>>(
        excelImportWorkerMain,
        <Object?>[operation.receivePort.sendPort, libraryPath, request.toMap()],
      );

      operation.receivePort.listen((message) async {
        if (message is SendPort) {
          operation.commandPort = message;
          return;
        }
        if (message is! Map<Object?, Object?>) {
          return;
        }

        final update = ExcelImportUpdate.fromMap(
          message.map((key, value) => MapEntry(key as String, value)),
        );
        if (!operation.controller.isClosed) {
          operation.controller.add(update);
        }
        if (_isTerminalExcelImportUpdate(update.kind)) {
          await _closeExcelImportOperation(request.jobId);
        }
      });
    } catch (error, stackTrace) {
      if (!operation.controller.isClosed) {
        operation.controller.add(
          ExcelImportUpdate(
            kind: ExcelImportUpdateKind.failed,
            jobId: request.jobId,
            message: '$error\n$stackTrace',
          ),
        );
      }
      await _closeExcelImportOperation(request.jobId);
    }
  }

  Future<void> _startSqlDumpImportOperation(
    SqlDumpImportRequest request,
    _SqlDumpImportOperation operation,
  ) async {
    try {
      final libraryPath = await initialize();
      operation.isolate = await Isolate.spawn<List<Object?>>(
        sqlDumpImportWorkerMain,
        <Object?>[operation.receivePort.sendPort, libraryPath, request.toMap()],
      );

      operation.receivePort.listen((message) async {
        if (message is SendPort) {
          operation.commandPort = message;
          return;
        }
        if (message is! Map<Object?, Object?>) {
          return;
        }

        final update = SqlDumpImportUpdate.fromMap(
          message.map((key, value) => MapEntry(key as String, value)),
        );
        if (!operation.controller.isClosed) {
          operation.controller.add(update);
        }
        if (_isTerminalSqlDumpImportUpdate(update.kind)) {
          await _closeSqlDumpImportOperation(request.jobId);
        }
      });
    } catch (error, stackTrace) {
      if (!operation.controller.isClosed) {
        operation.controller.add(
          SqlDumpImportUpdate(
            kind: SqlDumpImportUpdateKind.failed,
            jobId: request.jobId,
            message: '$error\n$stackTrace',
          ),
        );
      }
      await _closeSqlDumpImportOperation(request.jobId);
    }
  }

  Future<void> _closeImportOperation(String jobId) async {
    final operation = _imports.remove(jobId);
    if (operation == null) {
      return;
    }
    operation.receivePort.close();
    if (!operation.controller.isClosed) {
      await operation.controller.close();
    }
    operation.isolate?.kill(priority: Isolate.immediate);
  }

  Future<void> _closeExcelImportOperation(String jobId) async {
    final operation = _excelImports.remove(jobId);
    if (operation == null) {
      return;
    }
    operation.receivePort.close();
    if (!operation.controller.isClosed) {
      await operation.controller.close();
    }
    operation.isolate?.kill(priority: Isolate.immediate);
  }

  Future<void> _closeSqlDumpImportOperation(String jobId) async {
    final operation = _sqlDumpImports.remove(jobId);
    if (operation == null) {
      return;
    }
    operation.receivePort.close();
    if (!operation.controller.isClosed) {
      await operation.controller.close();
    }
    operation.isolate?.kill(priority: Isolate.immediate);
  }
}

class _SqliteImportOperation {
  _SqliteImportOperation({required this.controller, required this.receivePort});

  final StreamController<SqliteImportUpdate> controller;
  final ReceivePort receivePort;
  SendPort? commandPort;
  Isolate? isolate;
}

class _ExcelImportOperation {
  _ExcelImportOperation({required this.controller, required this.receivePort});

  final StreamController<ExcelImportUpdate> controller;
  final ReceivePort receivePort;
  SendPort? commandPort;
  Isolate? isolate;
}

class _SqlDumpImportOperation {
  _SqlDumpImportOperation({
    required this.controller,
    required this.receivePort,
  });

  final StreamController<SqlDumpImportUpdate> controller;
  final ReceivePort receivePort;
  SendPort? commandPort;
  Isolate? isolate;
}

bool _isTerminalImportUpdate(SqliteImportUpdateKind kind) {
  return kind == SqliteImportUpdateKind.completed ||
      kind == SqliteImportUpdateKind.failed ||
      kind == SqliteImportUpdateKind.cancelled;
}

bool _isTerminalExcelImportUpdate(ExcelImportUpdateKind kind) {
  return kind == ExcelImportUpdateKind.completed ||
      kind == ExcelImportUpdateKind.failed ||
      kind == ExcelImportUpdateKind.cancelled;
}

bool _isTerminalSqlDumpImportUpdate(SqlDumpImportUpdateKind kind) {
  return kind == SqlDumpImportUpdateKind.completed ||
      kind == SqlDumpImportUpdateKind.failed ||
      kind == SqlDumpImportUpdateKind.cancelled;
}

@pragma('vm:entry-point')
Future<void> _workerMain(List<Object?> bootstrap) async {
  final mainPort = bootstrap[0]! as SendPort;
  final libraryPath = bootstrap[1]! as String;
  final worker = _BridgeWorkerState(mainPort, libraryPath);
  await worker.run();
}

class _BridgeWorkerState {
  _BridgeWorkerState(this._mainPort, this._libraryPath);

  final SendPort _mainPort;
  final String _libraryPath;
  final ReceivePort _receivePort = ReceivePort();

  Database? _database;
  final Map<String, Statement> _cursors = <String, Statement>{};
  var _nextCursorId = 1;

  Future<void> run() async {
    _mainPort.send(_receivePort.sendPort);

    await for (final raw in _receivePort) {
      if (raw is! Map<Object?, Object?>) {
        continue;
      }

      final message = raw.map((key, value) => MapEntry(key as String, value));
      final requestId = message['id']! as int;
      final replyPort = message['replyPort']! as SendPort;
      final action = message['action']! as String;
      final payload =
          ((message['payload'] as Map?) ?? const <Object?, Object?>{}).map(
            (key, value) => MapEntry(key as String, value),
          );

      try {
        final data = await _handle(action, payload);
        replyPort.send(<String, Object?>{
          'id': requestId,
          'ok': true,
          'data': data,
        });
        if (action == 'shutdown') {
          break;
        }
      } catch (error, stackTrace) {
        final failure = error is BridgeFailure
            ? error
            : BridgeFailure(error.toString());
        replyPort.send(<String, Object?>{
          'id': requestId,
          'ok': false,
          'error': <String, Object?>{
            'message': failure.message,
            'code': failure.code,
            'stack': stackTrace.toString(),
          },
        });
      }
    }
  }

  Future<void> _closeAll() async {
    for (final statement in _cursors.values) {
      statement.dispose();
    }
    _cursors.clear();
    _database?.close();
    _database = null;
  }

  Future<Map<String, Object?>> _handle(
    String action,
    Map<String, Object?> payload,
  ) async {
    switch (action) {
      case 'openDatabase':
        return _handleOpenDatabase(payload);
      case 'loadSchema':
        return _handleLoadSchema();
      case 'getToolingMetadata':
        return _handleGetToolingMetadata();
      case 'describeQueryContract':
        return _handleDescribeQueryContract(payload);
      case 'runQuery':
        return _handleRunQuery(payload);
      case 'fetchNextPage':
        return _handleFetchNextPage(payload);
      case 'cancelQuery':
        return _handleCancelQuery(payload);
      case 'exportCsv':
        return _handleExportCsv(payload);
      case 'exportJson':
        return _handleExportJson(payload);
      case 'exportExcel':
        return _handleExportExcel(payload);
      case 'shutdown':
        await _closeAll();
        _receivePort.close();
        return const <String, Object?>{};
    }

    throw BridgeFailure('Unsupported worker action: $action');
  }

  Database _requireDatabase() {
    if (_database == null) {
      throw const BridgeFailure('Open or create a DecentDB file first.');
    }
    return _database!;
  }

  Map<String, Object?> _serializePage(
    ResultPage page, {
    required String? cursorId,
    required int? rowsAffected,
    required Duration elapsed,
  }) {
    final originalColumns = page.columns;
    final normalizedColumns = _normalizeResultColumns(page.columns);
    final normalizeJsonType = _isJsonTvfResultColumns(originalColumns);
    final normalizedRows = <Map<String, Object?>>[
      for (final row in page.rows)
        _normalizeResultRow(
          <String, Object?>{
            for (var i = 0; i < row.columns.length; i++)
              row.columns[i]: _encodeCell(row.values[i]),
          },
          originalColumns,
          normalizedColumns,
          normalizeJsonType: normalizeJsonType,
        ),
    ];
    return <String, Object?>{
      'cursorId': cursorId,
      'columns': normalizedColumns,
      'rows': normalizedRows,
      'done': page.isLast,
      'rowsAffected': rowsAffected,
      'elapsedMicros': elapsed.inMicroseconds,
    };
  }

  Future<Map<String, Object?>> _handleOpenDatabase(
    Map<String, Object?> payload,
  ) async {
    await _closeAll();
    final path = payload['path']! as String;
    _database = Database.open(path, libraryPath: _libraryPath);
    return <String, Object?>{
      'path': path,
      'engineVersion': _database!.engineVersion,
    };
  }

  Future<Map<String, Object?>> _handleLoadSchema() async {
    final db = _requireDatabase();
    final snapshot = db.schema.getSchemaSnapshot();
    final tables = [...snapshot.tables]
      ..sort((left, right) => left.name.compareTo(right.name));
    final views = [...snapshot.views]
      ..sort((left, right) => left.name.compareTo(right.name));
    final objects = <Map<String, Object?>>[
      for (final table in tables)
        <String, Object?>{
          'name': table.name,
          'kind': 'table',
          'temporary': table.temporary,
          'ddl': table.ddl,
          'columns': _serializeTableColumns(table.columns),
          'checks': _serializeChecks(_allTableChecks(table)),
        },
      for (final view in views)
        <String, Object?>{
          'name': view.name,
          'kind': 'view',
          'temporary': view.temporary,
          'ddl': view.ddl,
          'columns': _serializeViewColumns(view.columnNames),
        },
    ];
    final indexes = [...snapshot.indexes]
      ..sort((left, right) {
        final byTable = left.tableName.compareTo(right.tableName);
        return byTable != 0 ? byTable : left.name.compareTo(right.name);
      });
    final triggers = [...snapshot.triggers]
      ..sort((left, right) {
        final byTarget = left.targetName.compareTo(right.targetName);
        return byTarget != 0 ? byTarget : left.name.compareTo(right.name);
      });
    return <String, Object?>{
      'objects': objects,
      'indexes': <Map<String, Object?>>[
        for (final index in indexes)
          <String, Object?>{
            'name': index.name,
            'table': index.tableName,
            'columns': index.columns,
            'unique': index.unique,
            'kind': index.kind,
            'temporary': index.temporary,
            'predicateSql': index.predicateSql,
            'ddl': index.ddl,
          },
      ],
      'triggers': _serializeTriggers(triggers),
      'loadedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _handleGetToolingMetadata() async {
    final db = _requireDatabase();
    return _normalizeJsonMap(db.schema.getToolingMetadata());
  }

  Future<Map<String, Object?>> _handleDescribeQueryContract(
    Map<String, Object?> payload,
  ) async {
    final db = _requireDatabase();
    final sql = payload['sql']! as String;
    return _normalizeJsonMap(db.schema.describeQueryContract(sql));
  }

  Future<Map<String, Object?>> _handleRunQuery(
    Map<String, Object?> payload,
  ) async {
    final db = _requireDatabase();
    final sql = payload['sql']! as String;
    final params = ((payload['params'] as List?) ?? const <Object?>[])
        .cast<Object?>();
    final pageSize = payload['pageSize']! as int;
    final stopwatch = Stopwatch()..start();
    final returnsRows = _statementReturnsRows(sql);
    if (!returnsRows) {
      return _executeNonReturningQuery(db, sql, params, stopwatch);
    }

    return _executeReturningQuery(db, sql, params, pageSize, stopwatch);
  }

  Future<Map<String, Object?>> _executeNonReturningQuery(
    Database db,
    String sql,
    List<Object?> params,
    Stopwatch stopwatch,
  ) async {
    if (_isTransactionControlSql(sql) && params.isNotEmpty) {
      throw const BridgeFailure(
        'Transaction control statements do not accept parameters.',
      );
    }
    if (_isTransactionControlSql(sql)) {
      final rowsAffected = db.executeDirect(sql);
      return _serializePage(
        const ResultPage(<String>[], <Row>[], true),
        cursorId: null,
        rowsAffected: rowsAffected,
        elapsed: stopwatch.elapsed,
      );
    }

    final stmt = db.prepare(sql);
    try {
      stmt.bindAll(params);
      final rowsAffected = stmt.execute();
      return _serializePage(
        const ResultPage(<String>[], <Row>[], true),
        cursorId: null,
        rowsAffected: rowsAffected,
        elapsed: stopwatch.elapsed,
      );
    } finally {
      stmt.dispose();
    }
  }

  Map<String, Object?> _executeReturningQuery(
    Database db,
    String sql,
    List<Object?> params,
    int pageSize,
    Stopwatch stopwatch,
  ) {
    final stmt = db.prepare(sql);
    var keepStatementOpen = false;
    try {
      stmt.bindAll(params);
      final page = stmt.nextPage(pageSize);
      if (page.isLast) {
        return _serializePage(
          page,
          cursorId: null,
          rowsAffected: null,
          elapsed: stopwatch.elapsed,
        );
      }

      final cursorId = 'cursor-${_nextCursorId++}';
      _cursors[cursorId] = stmt;
      keepStatementOpen = true;
      return _serializePage(
        page,
        cursorId: cursorId,
        rowsAffected: null,
        elapsed: stopwatch.elapsed,
      );
    } finally {
      if (!keepStatementOpen) {
        stmt.dispose();
      }
    }
  }

  Future<Map<String, Object?>> _handleFetchNextPage(
    Map<String, Object?> payload,
  ) async {
    final cursorId = payload['cursorId']! as String;
    final pageSize = payload['pageSize']! as int;
    final stmt = _cursors[cursorId];
    if (stmt == null) {
      throw const BridgeFailure('Query cursor is no longer available.');
    }
    final stopwatch = Stopwatch()..start();
    final page = stmt.nextPage(pageSize);
    if (page.isLast) {
      stmt.dispose();
      _cursors.remove(cursorId);
    }
    return _serializePage(
      page,
      cursorId: page.isLast ? null : cursorId,
      rowsAffected: null,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<Map<String, Object?>> _handleCancelQuery(
    Map<String, Object?> payload,
  ) async {
    final cursorId = payload['cursorId']! as String;
    final stmt = _cursors.remove(cursorId);
    stmt?.dispose();
    return const <String, Object?>{};
  }

  Future<Map<String, Object?>> _handleExportCsv(
    Map<String, Object?> payload,
  ) async {
    final db = _requireDatabase();
    final sql = payload['sql']! as String;
    final params = ((payload['params'] as List?) ?? const <Object?>[])
        .cast<Object?>();
    final pageSize = payload['pageSize']! as int;
    final path = payload['path']! as String;
    final delimiter = payload['delimiter']! as String;
    final includeHeaders = payload['includeHeaders']! as bool;

    final file = File(path);
    await file.parent.create(recursive: true);
    if (!_statementReturnsRows(sql)) {
      throw const BridgeFailure(
        'The current statement does not produce rows and cannot be exported.',
      );
    }

    final stmt = db.prepare(sql);
    try {
      stmt.bindAll(params);
      final firstPage = stmt.nextPage(pageSize);
      if (firstPage.columns.isEmpty) {
        throw const BridgeFailure(
          'The current statement does not produce rows and cannot be exported.',
        );
      }
      final typeNamesByColumn = _queryResultTypesByColumn(db, sql);

      final sink = file.openWrite();
      var rowCount = 0;
      if (includeHeaders) {
        sink.writeln(
          firstPage.columns
              .map((item) => _escapeCsv(item, delimiter))
              .join(delimiter),
        );
      }
      for (final row in firstPage.rows) {
        sink.writeln(
          _csvRowValues(
            row,
            typeNamesByColumn,
          ).map((value) => _escapeCsv(value, delimiter)).join(delimiter),
        );
        rowCount++;
      }

      var page = firstPage;
      while (!page.isLast) {
        page = stmt.nextPage(pageSize);
        for (final row in page.rows) {
          sink.writeln(
            _csvRowValues(
              row,
              typeNamesByColumn,
            ).map((value) => _escapeCsv(value, delimiter)).join(delimiter),
          );
          rowCount++;
        }
      }
      await sink.flush();
      await sink.close();
      return <String, Object?>{'rowCount': rowCount, 'path': path};
    } finally {
      stmt.dispose();
    }
  }

  Future<Map<String, Object?>> _handleExportJson(
    Map<String, Object?> payload,
  ) async {
    final db = _requireDatabase();
    final sql = payload['sql']! as String;
    final params = ((payload['params'] as List?) ?? const <Object?>[])
        .cast<Object?>();
    final pageSize = payload['pageSize']! as int;
    final path = payload['path']! as String;
    final format = payload['format']! as String;
    final pretty = payload['pretty']! as bool;
    final includeMetadata = payload['includeMetadata']! as bool;
    final ndjson = format == 'ndjson';

    if (format != 'json' && format != 'ndjson') {
      throw const BridgeFailure('JSON export format must be json or ndjson.');
    }
    if (!_statementReturnsRows(sql)) {
      throw const BridgeFailure(
        'The current statement does not produce rows and cannot be exported.',
      );
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    final stmt = db.prepare(sql);
    try {
      stmt.bindAll(params);
      final firstPage = stmt.nextPage(pageSize);
      if (firstPage.columns.isEmpty) {
        throw const BridgeFailure(
          'The current statement does not produce rows and cannot be exported.',
        );
      }

      final typeNamesByColumn = _queryResultTypesByColumn(db, sql);
      final metadata = includeMetadata
          ? _jsonExportMetadata(db, sql, firstPage.columns, typeNamesByColumn)
          : const <String, Object?>{};
      final compactEncoder = const JsonEncoder();
      final prettyEncoder = const JsonEncoder.withIndent('  ');
      final rowEncoder = pretty && !ndjson ? prettyEncoder : compactEncoder;
      final sink = file.openWrite();
      var rowCount = 0;
      var firstRow = true;

      void writeJsonRow(Row row) {
        final object = _jsonRowObject(row, typeNamesByColumn);
        if (ndjson) {
          sink.writeln(compactEncoder.convert(object));
          rowCount++;
          return;
        }
        if (!firstRow) {
          sink.writeln(',');
        }
        final rowJson = rowEncoder.convert(object);
        sink.write(_indentJson(rowJson, includeMetadata ? 4 : 2));
        firstRow = false;
        rowCount++;
      }

      if (ndjson) {
        if (includeMetadata) {
          sink.writeln(
            compactEncoder.convert(<String, Object?>{'metadata': metadata}),
          );
        }
      } else if (includeMetadata) {
        if (pretty) {
          sink.writeln('{');
          sink.write('  "metadata": ');
          sink.write(
            _indentJsonContinuation(prettyEncoder.convert(metadata), 2),
          );
          sink.writeln(',');
          sink.writeln('  "rows": [');
        } else {
          sink.write(
            '{"metadata":${compactEncoder.convert(metadata)},"rows":[',
          );
        }
      } else {
        sink.write(pretty ? '[\n' : '[');
      }

      for (final row in firstPage.rows) {
        writeJsonRow(row);
      }
      var page = firstPage;
      while (!page.isLast) {
        page = stmt.nextPage(pageSize);
        for (final row in page.rows) {
          writeJsonRow(row);
        }
      }

      if (!ndjson) {
        if (includeMetadata) {
          if (pretty) {
            if (!firstRow) {
              sink.writeln();
            }
            sink.writeln('  ]');
            sink.writeln('}');
          } else {
            sink.write(']}');
          }
        } else {
          if (pretty) {
            if (!firstRow) {
              sink.writeln();
            }
            sink.writeln(']');
          } else {
            sink.write(']');
          }
        }
      }

      await sink.flush();
      await sink.close();
      return <String, Object?>{'rowCount': rowCount, 'path': path};
    } finally {
      stmt.dispose();
    }
  }

  Future<Map<String, Object?>> _handleExportExcel(
    Map<String, Object?> payload,
  ) async {
    final db = _requireDatabase();
    final sql = payload['sql']! as String;
    final params = ((payload['params'] as List?) ?? const <Object?>[])
        .cast<Object?>();
    final pageSize = payload['pageSize']! as int;
    final path = payload['path']! as String;
    final includeHeaders = payload['includeHeaders']! as bool;

    if (!_statementReturnsRows(sql)) {
      throw const BridgeFailure(
        'The current statement does not produce rows and cannot be exported.',
      );
    }

    final stmt = db.prepare(sql);
    try {
      stmt.bindAll(params);
      final firstPage = stmt.nextPage(pageSize);
      if (firstPage.columns.isEmpty) {
        throw const BridgeFailure(
          'The current statement does not produce rows and cannot be exported.',
        );
      }
      final typeNamesByColumn = _queryResultTypesByColumn(db, sql);

      Stream<List<Object?>> rowStream() async* {
        var page = firstPage;
        while (true) {
          for (final row in page.rows) {
            yield _xlsxRowValues(row, typeNamesByColumn);
          }
          if (page.isLast) {
            break;
          }
          page = stmt.nextPage(pageSize);
        }
      }

      final result = await writeRowsToXlsx(
        path: path,
        columns: firstPage.columns,
        rows: rowStream(),
        includeHeaders: includeHeaders,
      );
      return <String, Object?>{
        'rowCount': result.rowCount,
        'path': result.path,
      };
    } finally {
      stmt.dispose();
    }
  }
}

Map<String, String> _queryResultTypesByColumn(Database db, String sql) {
  try {
    final contract = db.schema.describeQueryContract(sql);
    final resultColumns =
        (contract['result_columns'] as List?) ?? const <Object?>[];
    return <String, String>{
      for (final raw in resultColumns)
        if (raw is Map &&
            raw['name'] is String &&
            raw['type_name'] is String &&
            (raw['type_name'] as String).trim().isNotEmpty)
          raw['name'] as String: raw['type_name'] as String,
    };
  } catch (_) {
    return const <String, String>{};
  }
}

List<String> _csvRowValues(Row row, Map<String, String> typeNamesByColumn) {
  return <String>[
    for (var index = 0; index < row.values.length; index++)
      _csvValue(
        row.values[index],
        typeName: index < row.columns.length
            ? typeNamesByColumn[row.columns[index]]
            : null,
      ),
  ];
}

Map<String, Object?> _jsonExportMetadata(
  Database db,
  String sql,
  List<String> columns,
  Map<String, String> typeNamesByColumn,
) {
  var schemaFingerprint = '';
  var schemaFingerprintAlgorithm = '';
  try {
    final tooling = db.schema.getToolingMetadata();
    schemaFingerprint = tooling['schema_fingerprint'] as String? ?? '';
    schemaFingerprintAlgorithm =
        tooling['schema_fingerprint_algorithm'] as String? ?? '';
  } catch (_) {
    // Metadata is optional for export; rows should still stream.
  }
  return <String, Object?>{
    'format_version': 1,
    'schema_fingerprint': schemaFingerprint,
    'schema_fingerprint_algorithm': schemaFingerprintAlgorithm,
    'columns': <Map<String, Object?>>[
      for (final column in columns)
        <String, Object?>{
          'name': column,
          'type_name': typeNamesByColumn[column],
        },
    ],
    'sql': sql,
  };
}

Map<String, Object?> _jsonRowObject(
  Row row,
  Map<String, String> typeNamesByColumn,
) {
  return <String, Object?>{
    for (var index = 0; index < row.values.length; index++)
      row.columns[index]: _jsonValue(
        row.values[index],
        typeName: typeNamesByColumn[row.columns[index]],
      ),
  };
}

Object? _jsonValue(Object? value, {String? typeName}) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DecimalValue) {
    return formatDecimalValue(value.scaled, value.scale);
  }
  if (value is DecentDBEnumValue) {
    final cell = NativeEnumCellValue(
      typeId: value.typeId,
      labelId: value.labelId,
    );
    return <String, Object?>{
      'display': formatTypedCellValue(cell, typeName: typeName),
      'enum_type_id': value.typeId,
      'enum_label_id': value.labelId,
    };
  }
  if (value is DecentDBIntervalValue) {
    final cell = NativeIntervalCellValue(
      months: value.months,
      days: value.days,
      microseconds: value.microseconds,
    );
    return <String, Object?>{
      'display': cell.displayString(),
      'months': value.months,
      'days': value.days,
      'microseconds': value.microseconds,
    };
  }
  if (value case (unscaled: final int unscaled, scale: final int scale)) {
    return formatDecimalValue(unscaled, scale);
  }
  if (value is Duration) {
    return formatTypedCellValue(value, typeName: typeName);
  }
  if (value is DateTime) {
    return formatTypedCellValue(value, typeName: typeName);
  }
  if (value is Uint8List) {
    final descriptor = describeNativeType(typeName: typeName);
    if (descriptor.isSpatial) {
      return <String, Object?>{
        'display': formatTypedCellValue(value, typeName: typeName),
        'ewkb_base64': base64Encode(value),
      };
    }
    if (descriptor.baseTypeName == 'UUID' && value.length == 16) {
      return formatTypedCellValue(value, typeName: typeName);
    }
    return <String, Object?>{'base64': base64Encode(value)};
  }
  return '$value';
}

List<Object?> _xlsxRowValues(Row row, Map<String, String> typeNamesByColumn) {
  return <Object?>[
    for (var index = 0; index < row.values.length; index++)
      _xlsxValue(
        row.values[index],
        typeName: index < row.columns.length
            ? typeNamesByColumn[row.columns[index]]
            : null,
      ),
  ];
}

Object? _xlsxValue(Object? value, {String? typeName}) {
  if (value == null || value is bool || value is String) {
    return value;
  }
  if (value is num && value.isFinite) {
    return value;
  }
  if (value is DecimalValue) {
    return formatDecimalValue(value.scaled, value.scale);
  }
  if (value is DecentDBEnumValue) {
    return formatTypedCellValue(
      NativeEnumCellValue(typeId: value.typeId, labelId: value.labelId),
      typeName: typeName,
    );
  }
  if (value is DecentDBIntervalValue) {
    return NativeIntervalCellValue(
      months: value.months,
      days: value.days,
      microseconds: value.microseconds,
    ).displayString();
  }
  if (value case (unscaled: final int unscaled, scale: final int scale)) {
    return formatDecimalValue(unscaled, scale);
  }
  if (value is Duration || value is DateTime) {
    return formatTypedCellValue(value, typeName: typeName);
  }
  if (value is Uint8List) {
    final descriptor = describeNativeType(typeName: typeName);
    if (descriptor.isSpatial ||
        descriptor.baseTypeName == 'UUID' && value.length == 16) {
      return formatTypedCellValue(value, typeName: typeName);
    }
    return base64Encode(value);
  }
  return '$value';
}

String _indentJson(String json, int spaces) {
  final prefix = ' ' * spaces;
  return json.split('\n').map((line) => '$prefix$line').join('\n');
}

String _indentJsonContinuation(String json, int spaces) {
  final lines = json.split('\n');
  if (lines.length <= 1) {
    return json;
  }
  final prefix = ' ' * spaces;
  return <String>[
    lines.first,
    for (final line in lines.skip(1)) '$prefix$line',
  ].join('\n');
}

bool _statementReturnsRows(String sql) {
  final keyword = _leadingSqlKeyword(sql);
  return switch (keyword) {
    'SELECT' || 'EXPLAIN' || 'PRAGMA' || 'VALUES' || 'WITH' => true,
    _ => false,
  };
}

bool _isTransactionControlSql(String sql) {
  final keyword = _leadingSqlKeyword(sql);
  return switch (keyword) {
    'BEGIN' || 'COMMIT' || 'ROLLBACK' || 'SAVEPOINT' || 'RELEASE' => true,
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

List<String> _normalizeResultColumns(List<String> columns) {
  if (_isPlanResultColumns(columns)) {
    return const <String>['query_plan'];
  }
  return <String>[for (final column in columns) column];
}

bool _isPlanResultColumns(List<String> columns) {
  return columns.length == 1 && columns.first == 'plan';
}

bool _isJsonTvfResultColumns(List<String> columns) {
  return columns.contains('key') &&
      columns.contains('value') &&
      columns.contains('type');
}

Map<String, Object?> _normalizeJsonMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry('$key', _normalizeJsonValue(value)));
}

Object? _normalizeJsonValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    return _normalizeJsonMap(value);
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        '${entry.key}': _normalizeJsonValue(entry.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final item in value) _normalizeJsonValue(item)];
  }
  return value;
}

Map<String, Object?> _normalizeResultRow(
  Map<String, Object?> row,
  List<String> originalColumns,
  List<String> normalizedColumns, {
  required bool normalizeJsonType,
}) {
  final normalized = <String, Object?>{};
  for (var i = 0; i < normalizedColumns.length; i++) {
    final normalizedName = normalizedColumns[i];
    final originalName = i < originalColumns.length
        ? originalColumns[i]
        : normalizedName;
    var value = row[originalName];
    if (normalizeJsonType && normalizedName == 'type') {
      if (value == 'integer') {
        value = 'number';
      } else if (value == 'text') {
        value = 'string';
      }
    }
    normalized[normalizedName] = value;
  }
  return normalized;
}

List<SchemaCheckConstraintInfo> _allTableChecks(SchemaTableInfo table) {
  final merged = <SchemaCheckConstraintInfo>[...table.checks];
  final seen = <String>{
    for (final check in merged)
      '${check.name ?? ''}\u0000${check.expressionSql}',
  };
  for (final column in table.columns) {
    for (final check in column.checks) {
      final signature = '${check.name ?? ''}\u0000${check.expressionSql}';
      if (seen.add(signature)) {
        merged.add(check);
      }
    }
  }
  return merged;
}

List<Map<String, Object?>> _serializeTableColumns(
  List<SchemaColumnInfo> columns,
) {
  return <Map<String, Object?>>[
    for (final column in columns)
      <String, Object?>{
        'name': column.name,
        'type': column.type,
        'notNull': !column.nullable,
        'unique': column.unique,
        'primaryKey': column.primaryKey,
        'defaultExpr': column.defaultSql,
        'generatedExpr': column.generatedSql,
        'generatedStored': column.generatedStored,
        'refTable': column.foreignKey?.referencedTable,
        'refColumn': _referencedColumnFor(column),
        'refOnDelete': column.foreignKey?.onDelete,
        'refOnUpdate': column.foreignKey?.onUpdate,
      },
  ];
}

String? _referencedColumnFor(SchemaColumnInfo column) {
  final foreignKey = column.foreignKey;
  if (foreignKey == null || foreignKey.columns.isEmpty) {
    return null;
  }
  final localIndex = foreignKey.columns.indexOf(column.name);
  if (localIndex < 0 || localIndex >= foreignKey.referencedColumns.length) {
    return foreignKey.referencedColumns.isEmpty
        ? null
        : foreignKey.referencedColumns.first;
  }
  return foreignKey.referencedColumns[localIndex];
}

List<Map<String, Object?>> _serializeViewColumns(List<String> columnNames) {
  return <Map<String, Object?>>[
    for (final name in columnNames)
      <String, Object?>{
        'name': name,
        'type': 'UNKNOWN',
        'notNull': false,
        'unique': false,
        'primaryKey': false,
        'defaultExpr': null,
        'generatedExpr': null,
        'generatedStored': false,
        'refTable': null,
        'refColumn': null,
        'refOnDelete': null,
        'refOnUpdate': null,
      },
  ];
}

List<Map<String, Object?>> _serializeChecks(
  List<SchemaCheckConstraintInfo> checks,
) {
  return <Map<String, Object?>>[
    for (final check in checks)
      <String, Object?>{
        'name': check.name ?? '',
        'exprSql': check.expressionSql,
      },
  ];
}

List<Map<String, Object?>> _serializeTriggers(
  List<SchemaTriggerInfo> triggers,
) {
  return <Map<String, Object?>>[
    for (final trigger in triggers)
      <String, Object?>{
        'name': trigger.name,
        'targetName': trigger.targetName,
        'targetKind': trigger.targetKind,
        'timing': trigger.timing,
        'events': trigger.events,
        'eventsMask': trigger.eventsMask,
        'forEachRow': trigger.forEachRow,
        'temporary': trigger.temporary,
        'actionSql': trigger.actionSql,
        'ddl': trigger.ddl,
      },
  ];
}

Object? _encodeCell(Object? value) {
  if (value is DecimalValue) {
    return <String, Object?>{
      'kind': 'decimal',
      'unscaled': value.scaled,
      'scale': value.scale,
    };
  }
  if (value is DecentDBEnumValue) {
    return <String, Object?>{
      'kind': 'native_enum',
      'typeId': value.typeId,
      'labelId': value.labelId,
    };
  }
  if (value is DecentDBIntervalValue) {
    return <String, Object?>{
      'kind': 'native_interval',
      'months': value.months,
      'days': value.days,
      'microseconds': value.microseconds,
    };
  }
  if (value is Duration) {
    return <String, Object?>{
      'kind': 'duration',
      'microseconds': value.inMicroseconds,
    };
  }
  if (value case (unscaled: final int unscaled, scale: final int scale)) {
    return <String, Object?>{
      'kind': 'decimal',
      'unscaled': unscaled,
      'scale': scale,
    };
  }
  if (value is Uint8List) {
    return <String, Object?>{'kind': 'blob', 'base64': base64Encode(value)};
  }
  if (value is DateTime) {
    return <String, Object?>{
      'kind': 'datetime',
      'iso8601': value.toIso8601String(),
    };
  }
  return value;
}

String _csvValue(Object? value, {String? typeName}) {
  if (value == null) {
    return '';
  }
  if (value is DecimalValue) {
    return formatDecimalValue(value.scaled, value.scale);
  }
  if (value is DecentDBEnumValue) {
    return formatTypedCellValue(
      NativeEnumCellValue(typeId: value.typeId, labelId: value.labelId),
      typeName: typeName,
    );
  }
  if (value is DecentDBIntervalValue) {
    return formatTypedCellValue(
      NativeIntervalCellValue(
        months: value.months,
        days: value.days,
        microseconds: value.microseconds,
      ),
      typeName: typeName,
    );
  }
  if (value case (unscaled: final int unscaled, scale: final int scale)) {
    return formatDecimalValue(unscaled, scale);
  }
  if (value is Duration) {
    return formatTypedCellValue(value, typeName: typeName);
  }
  if (value is DateTime) {
    return formatTypedCellValue(value, typeName: typeName);
  }
  if (value is Uint8List) {
    final descriptor = describeNativeType(typeName: typeName);
    if (descriptor.isSpatial || descriptor.baseTypeName == 'UUID') {
      return formatTypedCellValue(value, typeName: typeName);
    }
    return base64Encode(value);
  }
  return '$value';
}

String _escapeCsv(String value, String delimiter) {
  final escaped = value.replaceAll('"', '""');
  if (escaped.contains(delimiter) ||
      escaped.contains('"') ||
      escaped.contains('\n') ||
      escaped.contains('\r')) {
    return '"$escaped"';
  }
  return escaped;
}
