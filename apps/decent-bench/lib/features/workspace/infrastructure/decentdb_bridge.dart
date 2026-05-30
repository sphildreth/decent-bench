import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:decentdb/decentdb.dart' hide SchemaSnapshot;

import '../domain/app_config.dart';
import '../domain/excel_import_models.dart';
import '../domain/sql_dump_import_models.dart';
import '../domain/sqlite_import_models.dart';
import '../domain/workspace_models.dart';
import 'excel_import_support.dart';
import 'decentdb_native_release_asset.dart';
import 'native_library_resolver.dart';
import 'sql_dump_import_support.dart';
import 'sqlite_import_support.dart';
import 'xlsx_export_support.dart';

abstract class DatabaseLifecycleGateway {
  String? get resolvedLibraryPath;
  Future<String> initialize();
  Future<DatabaseSession> openDatabase(
    String path, {
    WriteQueueSettings? writeQueue,
  });
  Future<void> dispose();
}

abstract class SchemaIntrospectionGateway {
  Future<SchemaSnapshot> loadSchema();
  Future<OperationalMetricsSnapshot> loadOperationalMetrics({int maxRows});
  Future<ToolingMetadata> getToolingMetadata();
  Future<QueryContract> describeQueryContract(String sql);
}

abstract class QueryExecutionGateway {
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    Duration? timeout,
  });
  Future<QueryResultPage> fetchNextPage({
    required String cursorId,
    required int pageSize,
    Duration? timeout,
  });
  Future<void> cancelQuery(String cursorId);
  Future<QueuedWriteResult> executeQueuedWrite({
    required String sql,
    required List<Object?> params,
    int? timeoutMs,
  });
}

abstract class ExportGateway {
  Future<CsvExportResult> exportCsv({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required String delimiter,
    required bool includeHeaders,
    Duration? timeout,
  });
  Future<JsonExportResult> exportJson({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required String format,
    required bool pretty,
    required bool includeMetadata,
    Duration? timeout,
  });
  Future<ExcelExportResult> exportExcel({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required bool includeHeaders,
    Duration? timeout,
  });
}

abstract class ImportGateway {
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
}

abstract class BranchWorkflowGateway {
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
}

abstract class WorkspaceDatabaseGateway
    implements
        DatabaseLifecycleGateway,
        SchemaIntrospectionGateway,
        QueryExecutionGateway,
        ExportGateway,
        ImportGateway,
        BranchWorkflowGateway {}

class DecentDbBridge implements WorkspaceDatabaseGateway {
  DecentDbBridge({NativeLibraryResolver? resolver})
    : _resolver = resolver ?? NativeLibraryResolver();

  final NativeLibraryResolver _resolver;
  final Map<int, Completer<Map<String, Object?>>> _pending =
      <int, Completer<Map<String, Object?>>>{};
  final Map<String, _ImportOperation<SqliteImportUpdate>> _imports =
      <String, _ImportOperation<SqliteImportUpdate>>{};
  final Map<String, _ImportOperation<ExcelImportUpdate>> _excelImports =
      <String, _ImportOperation<ExcelImportUpdate>>{};
  final Map<String, _ImportOperation<SqlDumpImportUpdate>> _sqlDumpImports =
      <String, _ImportOperation<SqlDumpImportUpdate>>{};

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

    try {
      resolvedLibraryPath = await _resolver.resolve();
    } on NativeLibraryResolutionFailure {
      resolvedLibraryPath =
          await DecentDbNativeReleaseAsset.ensureAvailableForCurrentProject();
    }
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
  Future<DatabaseSession> openDatabase(
    String path, {
    WriteQueueSettings? writeQueue,
  }) async {
    final data = await _request('openDatabase', <String, Object?>{
      'path': path,
      if (writeQueue != null) 'writeQueue': _serializeWriteQueue(writeQueue),
    });
    return DatabaseSession.fromMap(data);
  }

  @override
  Future<SchemaSnapshot> loadSchema() async {
    final data = await _request('loadSchema', const <String, Object?>{}, const Duration(seconds: 60));
    return SchemaSnapshot.fromMap(data);
  }

  @override
  Future<OperationalMetricsSnapshot> loadOperationalMetrics({
    int maxRows = 20,
  }) async {
    final data = await _request('loadOperationalMetrics', <String, Object?>{
      'maxRows': maxRows,
    });
    return OperationalMetricsSnapshot.fromMap(data);
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
    Duration? timeout,
  }) async {
    final data = await _request('runQuery', <String, Object?>{
      'sql': sql,
      'params': params,
      'pageSize': pageSize,
    }, timeout);
    return QueryResultPage.fromMap(data);
  }

  @override
  Future<QueryResultPage> fetchNextPage({
    required String cursorId,
    required int pageSize,
    Duration? timeout,
  }) async {
    final data = await _request('fetchNextPage', <String, Object?>{
      'cursorId': cursorId,
      'pageSize': pageSize,
    }, timeout);
    return QueryResultPage.fromMap(data);
  }

  @override
  Future<void> cancelQuery(String cursorId) async {
    await _request('cancelQuery', <String, Object?>{'cursorId': cursorId});
  }

  @override
  Future<QueuedWriteResult> executeQueuedWrite({
    required String sql,
    required List<Object?> params,
    int? timeoutMs,
  }) async {
    final payload = <String, Object?>{'sql': sql, 'params': params};
    if (timeoutMs != null) {
      payload['timeoutMs'] = timeoutMs;
    }
    final data = await _request('executeQueuedWrite', payload);
    return QueuedWriteResult.fromMap(data);
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
    final data = await _request('exportCsv', <String, Object?>{
      'sql': sql,
      'params': params,
      'pageSize': pageSize,
      'path': path,
      'delimiter': delimiter,
      'includeHeaders': includeHeaders,
    }, timeout);
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
    Duration? timeout,
  }) async {
    final data = await _request('exportJson', <String, Object?>{
      'sql': sql,
      'params': params,
      'pageSize': pageSize,
      'path': path,
      'format': format,
      'pretty': pretty,
      'includeMetadata': includeMetadata,
    }, timeout);
    return JsonExportResult.fromMap(data);
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
    final data = await _request('exportExcel', <String, Object?>{
      'sql': sql,
      'params': params,
      'pageSize': pageSize,
      'path': path,
      'includeHeaders': includeHeaders,
    }, timeout);
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

    final operation = _ImportOperation<SqliteImportUpdate>(
      controller: StreamController<SqliteImportUpdate>(),
      receivePort: ReceivePort(),
    );
    _imports[request.jobId] = operation;
    unawaited(_startGenericImportOperation<SqliteImportUpdate>(
      jobId: request.jobId,
      operation: operation,
      toMap: () => request.toMap(),
      workerMain: sqliteImportWorkerMain,
      updateFromMap: (map) => SqliteImportUpdate.fromMap(map),
      isTerminal: (update) => _isTerminalImportUpdate(update.kind),
      makeFailed: (jobId, message) => SqliteImportUpdate(
        kind: SqliteImportUpdateKind.failed,
        jobId: jobId,
        message: message,
      ),
      operations: _imports,
    ));
    return operation.controller.stream;
  }

  @override
  Stream<ExcelImportUpdate> importExcel({required ExcelImportRequest request}) {
    final existing = _excelImports[request.jobId];
    if (existing != null) {
      return existing.controller.stream;
    }

    final operation = _ImportOperation<ExcelImportUpdate>(
      controller: StreamController<ExcelImportUpdate>(),
      receivePort: ReceivePort(),
    );
    _excelImports[request.jobId] = operation;
    unawaited(_startGenericImportOperation<ExcelImportUpdate>(
      jobId: request.jobId,
      operation: operation,
      toMap: () => request.toMap(),
      workerMain: excelImportWorkerMain,
      updateFromMap: (map) => ExcelImportUpdate.fromMap(map),
      isTerminal: (update) => _isTerminalExcelImportUpdate(update.kind),
      makeFailed: (jobId, message) => ExcelImportUpdate(
        kind: ExcelImportUpdateKind.failed,
        jobId: jobId,
        message: message,
      ),
      operations: _excelImports,
    ));
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

    final operation = _ImportOperation<SqlDumpImportUpdate>(
      controller: StreamController<SqlDumpImportUpdate>(),
      receivePort: ReceivePort(),
    );
    _sqlDumpImports[request.jobId] = operation;
    unawaited(_startGenericImportOperation<SqlDumpImportUpdate>(
      jobId: request.jobId,
      operation: operation,
      toMap: () => request.toMap(),
      workerMain: sqlDumpImportWorkerMain,
      updateFromMap: (map) => SqlDumpImportUpdate.fromMap(map),
      isTerminal: (update) => _isTerminalSqlDumpImportUpdate(update.kind),
      makeFailed: (jobId, message) => SqlDumpImportUpdate(
        kind: SqlDumpImportUpdateKind.failed,
        jobId: jobId,
        message: message,
      ),
      operations: _sqlDumpImports,
    ));
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
  Future<List<WorkspaceBranchInfo>> listBranches() async {
    final data = await _request('listBranches', const <String, Object?>{}, _branchRequestTimeout);
    return _bridgeMapList(
      data['branches'],
    ).map(WorkspaceBranchInfo.fromMap).toList(growable: false);
  }

  @override
  Future<WorkspaceBranchInfo> createBranch({
    required String branchName,
    required String fromRef,
  }) async {
    final data = await _request('createBranch', <String, Object?>{
      'branchName': branchName,
      'fromRef': fromRef,
    }, _branchRequestTimeout);
    return WorkspaceBranchInfo.fromMap(
      (data['branch']! as Map<Object?, Object?>).map(
        (key, value) => MapEntry(key as String, value),
      ),
    );
  }

  @override
  Future<void> deleteBranch({required String branchName}) async {
    await _request('deleteBranch', <String, Object?>{'branchName': branchName}, _branchRequestTimeout);
  }

  @override
  Future<List<WorkspaceSnapshotInfo>> listSnapshots() async {
    final data = await _request('listSnapshots', const <String, Object?>{}, _branchRequestTimeout);
    return _bridgeMapList(
      data['snapshots'],
    ).map(WorkspaceSnapshotInfo.fromMap).toList(growable: false);
  }

  @override
  Future<WorkspaceSnapshotInfo> createSnapshot({required String name}) async {
    final data = await _request('createSnapshot', <String, Object?>{
      'name': name,
    }, _branchRequestTimeout);
    return WorkspaceSnapshotInfo.fromMap(
      (data['snapshot']! as Map<Object?, Object?>).map(
        (key, value) => MapEntry(key as String, value),
      ),
    );
  }

  @override
  Future<void> deleteSnapshot({required String ref}) async {
    await _request('deleteSnapshot', <String, Object?>{'ref': ref}, _branchRequestTimeout);
  }

  @override
  Future<QueryResultPage> runQueryOnBranch({
    required String sql,
    required String branchName,
    required List<Object?> params,
    required int pageSize,
  }) async {
    final data = await _request('runQueryOnBranch', <String, Object?>{
      'sql': sql,
      'branchName': branchName,
      'params': params,
      'pageSize': pageSize,
    }, _branchRequestTimeout);
    return QueryResultPage.fromMap(data);
  }

  @override
  Future<WorkspaceBranchDiff> branchDiff({
    required String leftRef,
    required String rightRef,
  }) async {
    final data = await _request('branchDiff', <String, Object?>{
      'leftRef': leftRef,
      'rightRef': rightRef,
    }, _branchRequestTimeout);
    return WorkspaceBranchDiff.fromMap(data);
  }

  @override
  Future<WorkspaceBranchDiff> restoreBranch({
    required String branchName,
    required String targetRef,
    required bool dryRun,
  }) async {
    final data = await _request('restoreBranch', <String, Object?>{
      'branchName': branchName,
      'targetRef': targetRef,
      'dryRun': dryRun,
    }, _branchRequestTimeout);
    return WorkspaceBranchDiff.fromMap(data);
  }

  @override
  Future<WorkspaceBranchDiff> mergeBranch({
    required String sourceBranch,
    required String targetBranch,
    required bool dryRun,
  }) async {
    final data = await _request('mergeBranch', <String, Object?>{
      'sourceBranch': sourceBranch,
      'targetBranch': targetBranch,
      'dryRun': dryRun,
    }, _branchRequestTimeout);
    return WorkspaceBranchDiff.fromMap(data);
  }

  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _branchRequestTimeout = Duration(seconds: 10);

  Future<Map<String, Object?>> _request(
    String action, [
    Map<String, Object?> payload = const <String, Object?>{},
    Duration? timeout,
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

    final effectiveTimeout = timeout ?? _requestTimeout;
    try {
      return await completer.future.timeout(effectiveTimeout);
    } on TimeoutException {
      _pending.remove(requestId);
      throw BridgeFailure(
        'DecentDB worker request "$action" timed out after ${effectiveTimeout.inSeconds}s. '
        'The worker isolate may be unresponsive or the operation is taking too long.',
        code: 'DDB_ERR_TIMEOUT',
      );
    }
  }

  Future<void> _startGenericImportOperation<T>({
    required String jobId,
    required _ImportOperation<T> operation,
    required Map<String, Object?> Function() toMap,
    required Future<void> Function(List<Object?>) workerMain,
    required T Function(Map<String, Object?>) updateFromMap,
    required bool Function(T) isTerminal,
    required T Function(String jobId, String error) makeFailed,
    required Map<String, _ImportOperation<T>> operations,
  }) async {
    try {
      final libraryPath = await initialize();
      operation.isolate = await Isolate.spawn<List<Object?>>(
        workerMain,
        <Object?>[operation.receivePort.sendPort, libraryPath, toMap()],
      );
      operation.receivePort.listen((message) async {
        if (message is SendPort) {
          operation.commandPort = message;
          return;
        }
        if (message is! Map<Object?, Object?>) return;
        final update = updateFromMap(
          message.map((key, value) => MapEntry(key as String, value)),
        );
        if (!operation.controller.isClosed) {
          operation.controller.add(update);
        }
        if (isTerminal(update)) {
          await _closeImportOperation(jobId, operations);
        }
      });
    } catch (error, stackTrace) {
      if (!operation.controller.isClosed) {
        operation.controller.add(
          makeFailed(jobId, '$error\n$stackTrace'),
        );
      }
      await _closeImportOperation(jobId, operations);
    }
  }

  Future<void> _closeImportOperation<T>(
    String jobId,
    Map<String, _ImportOperation<T>> operations,
  ) async {
    final operation = operations.remove(jobId);
    if (operation == null) return;
    operation.receivePort.close();
    if (!operation.controller.isClosed) {
      await operation.controller.close();
    }
    operation.isolate?.kill(priority: Isolate.immediate);
  }
}

class _ImportOperation<T> {
  _ImportOperation({required this.controller, required this.receivePort});
  final StreamController<T> controller;
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
        final failure = _bridgeFailureFromError(error);
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
      case 'loadOperationalMetrics':
        return _handleLoadOperationalMetrics(payload);
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
      case 'executeQueuedWrite':
        return _handleExecuteQueuedWrite(payload);
      case 'listBranches':
        return _handleListBranches();
      case 'createBranch':
        return _handleCreateBranch(payload);
      case 'deleteBranch':
        return _handleDeleteBranch(payload);
      case 'listSnapshots':
        return _handleListSnapshots();
      case 'createSnapshot':
        return _handleCreateSnapshot(payload);
      case 'deleteSnapshot':
        return _handleDeleteSnapshot(payload);
      case 'runQueryOnBranch':
        return _handleRunQueryOnBranch(payload);
      case 'branchDiff':
        return _handleBranchDiff(payload);
      case 'restoreBranch':
        return _handleRestoreBranch(payload);
      case 'mergeBranch':
        return _handleMergeBranch(payload);
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
    final writeQueue = (payload['writeQueue'] as Map<Object?, Object?>?)?.map(
      (key, value) => MapEntry(key as String, value),
    );
    final openOptions = _writeQueueOpenOptionsFromPayload(writeQueue);
    _database = Database.open(
      path,
      libraryPath: _libraryPath,
      options: openOptions,
    );
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
          'columns': _serializeTableColumns(table),
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
    final result = <String, Object?>{
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
    return result;
  }

  Future<Map<String, Object?>> _handleLoadOperationalMetrics(
    Map<String, Object?> payload,
  ) async {
    final db = _requireDatabase();
    final maxRows = (payload['maxRows'] as int? ?? 20).clamp(1, 200);
    final views = <Map<String, Object?>>[_nativeWriteQueueMetricsView(db)];
    for (final spec in _operationalMetricQueries) {
      final view = _queryOperationalMetricView(db, spec, maxRows: maxRows);
      if (!((view['available'] as bool?) ?? false) &&
          _isSysSchemaBoundaryError(view['error'] as String?)) {
        views.add(_sysInspectionPreparedBoundaryView());
        break;
      }
      views.add(view);
    }
    return <String, Object?>{'views': views};
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
    final pragmaPage = _tryHandleApplicationMetadataPragma(
      db,
      sql,
      params,
      stopwatch,
    );
    if (pragmaPage != null) {
      return pragmaPage;
    }
    final returnsRows = _statementReturnsRows(sql);
    if (!returnsRows) {
      return _executeNonReturningQuery(db, sql, params, stopwatch);
    }

    return _executeReturningQuery(db, sql, params, pageSize, stopwatch);
  }

  Map<String, Object?>? _tryHandleApplicationMetadataPragma(
    Database db,
    String sql,
    List<Object?> params,
    Stopwatch stopwatch,
  ) {
    final match = RegExp(
      r'^\s*PRAGMA\s+(?:(?:main|temp)\.)?(user_version|application_id)\s*(?:=\s*(-?\d+))?\s*;?\s*$',
      caseSensitive: false,
    ).firstMatch(sql);
    if (match == null) {
      return null;
    }
    if (params.isNotEmpty) {
      throw const BridgeFailure('PRAGMA statements do not accept parameters.');
    }

    final key = match.group(1)!.toLowerCase();
    final rawValue = match.group(2);
    if (rawValue != null) {
      final value = int.parse(rawValue);
      if (value < -2147483648 || value > 2147483647) {
        throw BridgeFailure(
          'PRAGMA $key requires a signed 32-bit integer value.',
          code: 'DDB_ERR_SQL',
        );
      }
      _setApplicationPragmaValue(db, key, value);
      return _serializePage(
        const ResultPage(<String>[], <Row>[], true),
        cursorId: null,
        rowsAffected: 0,
        elapsed: stopwatch.elapsed,
      );
    }

    final value = _loadApplicationPragmaValue(db, key);
    return _serializePage(
      ResultPage(
        <String>[key],
        <Row>[
          Row(<String>[key], <Object?>[value]),
        ],
        true,
      ),
      cursorId: null,
      rowsAffected: null,
      elapsed: stopwatch.elapsed,
    );
  }

  void _setApplicationPragmaValue(Database db, String key, int value) {
    const table = '"__decentdb_application_pragmas"';
    final keySql = _sqlStringLiteral(key);
    db.executeDirect(
      'CREATE TABLE IF NOT EXISTS $table '
      '(name TEXT PRIMARY KEY, value INT64 NOT NULL)',
    );
    db.executeDirect('DELETE FROM $table WHERE name = $keySql');
    db.executeDirect(
      'INSERT INTO $table (name, value) VALUES ($keySql, $value)',
    );
  }

  int _loadApplicationPragmaValue(Database db, String key) {
    const table = '"__decentdb_application_pragmas"';
    final keySql = _sqlStringLiteral(key);
    try {
      final stmt = db.prepare('SELECT value FROM $table WHERE name = $keySql');
      try {
        final page = stmt.nextPage(1);
        final rawValue = page.rows.isEmpty
            ? null
            : page.rows.first.values.first;
        return rawValue is int ? rawValue : 0;
      } finally {
        stmt.dispose();
      }
    } on DecentDbException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('unknown table') ||
          message.contains('no such table')) {
        return 0;
      }
      rethrow;
    }
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

  Future<Map<String, Object?>> _handleExecuteQueuedWrite(
    Map<String, Object?> payload,
  ) async {
    final db = _requireDatabase();
    final sql = payload['sql']! as String;
    final params = ((payload['params'] as List?) ?? const <Object?>[])
        .cast<Object?>();
    final timeoutMs = payload['timeoutMs'] as int?;
    final queuedSql = _inlineQueuedWriteParameters(sql, params);
    final rowsAffected = db.executeQueued(queuedSql, timeoutMs: timeoutMs);
    return <String, Object?>{'rowsAffected': rowsAffected};
  }

  Future<Map<String, Object?>> _handleListBranches() async {
    final workflow = _requireDatabase().branchWorkflow;
    final branches = workflow.listBranches();
    return <String, Object?>{
      'branches': <Map<String, Object?>>[
        for (final branch in branches) _serializeBranchInfo(branch),
      ],
    };
  }

  Future<Map<String, Object?>> _handleCreateBranch(
    Map<String, Object?> payload,
  ) async {
    final workflow = _requireDatabase().branchWorkflow;
    final branch = workflow.createBranch(
      payload['branchName']! as String,
      from: _nativeBranchRef(payload['fromRef'] as String?),
    );
    return <String, Object?>{'branch': _serializeBranchInfo(branch)};
  }

  Future<Map<String, Object?>> _handleDeleteBranch(
    Map<String, Object?> payload,
  ) async {
    final workflow = _requireDatabase().branchWorkflow;
    workflow.deleteBranch(payload['branchName']! as String);
    return const <String, Object?>{};
  }

  Future<Map<String, Object?>> _handleListSnapshots() async {
    final workflow = _requireDatabase().branchWorkflow;
    final branchNamesById = <String, String>{
      for (final branch in workflow.listBranches())
        branch.branchId: branch.name,
    };
    final snapshots = workflow.listSnapshots();
    return <String, Object?>{
      'snapshots': <Map<String, Object?>>[
        for (final snapshot in snapshots)
          _serializeSnapshotInfo(
            snapshot,
            branchName: branchNamesById[snapshot.branchId],
          ),
      ],
    };
  }

  Future<Map<String, Object?>> _handleCreateSnapshot(
    Map<String, Object?> payload,
  ) async {
    final workflow = _requireDatabase().branchWorkflow;
    final snapshot = workflow.createSnapshot(payload['name']! as String);
    return <String, Object?>{
      'snapshot': _serializeSnapshotInfo(snapshot, branchName: 'main'),
    };
  }

  Future<Map<String, Object?>> _handleDeleteSnapshot(
    Map<String, Object?> payload,
  ) async {
    final workflow = _requireDatabase().branchWorkflow;
    workflow.deleteSnapshot(_snapshotNameFromRef(payload['ref']! as String));
    return const <String, Object?>{};
  }

  Future<Map<String, Object?>> _handleRunQueryOnBranch(
    Map<String, Object?> payload,
  ) async {
    final workflow = _requireDatabase().branchWorkflow;
    final sql = payload['sql']! as String;
    final branchName = payload['branchName']! as String;
    final params = ((payload['params'] as List?) ?? const <Object?>[])
        .cast<Object?>();
    final pageSize = payload['pageSize']! as int;
    final stopwatch = Stopwatch()..start();
    final result = workflow.executeSql(branchName, sql, params);
    final page = result.firstPage(pageSize);
    if (!page.isLast) {
      throw BridgeFailure(
        'Branch-scoped SQL returned more than $pageSize rows. Add a LIMIT '
        'clause before running large branch result sets.',
      );
    }
    return _serializePage(
      page,
      cursorId: null,
      rowsAffected: result.returnsRows ? null : result.affectedRows,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<Map<String, Object?>> _handleBranchDiff(
    Map<String, Object?> payload,
  ) async {
    final workflow = _requireDatabase().branchWorkflow;
    final diff = workflow.diff(
      _nativeBranchRef(payload['leftRef']! as String)!,
      _nativeBranchRef(payload['rightRef']! as String)!,
    );
    return _serializeBranchDiffReport(diff);
  }

  Future<Map<String, Object?>> _handleRestoreBranch(
    Map<String, Object?> payload,
  ) async {
    final workflow = _requireDatabase().branchWorkflow;
    final report = workflow.restore(
      payload['branchName']! as String,
      _nativeBranchRef(payload['targetRef']! as String)!,
      dryRun: payload['dryRun'] as bool? ?? true,
    );
    return _serializeBranchRestoreReport(report);
  }

  Future<Map<String, Object?>> _handleMergeBranch(
    Map<String, Object?> payload,
  ) async {
    final workflow = _requireDatabase().branchWorkflow;
    final sourceBranch = payload['sourceBranch']! as String;
    final targetBranch = payload['targetBranch']! as String;
    final dryRun = payload['dryRun'] as bool? ?? true;
    final report = workflow.merge(sourceBranch, targetBranch, dryRun: dryRun);
    if (dryRun) {
      final diff = _serializeBranchDiffReport(
        workflow.diff(targetBranch, sourceBranch),
      );
      if (report.conflicts.isEmpty) {
        return diff;
      }
      return _appendBranchMergeConflicts(diff, report.conflicts);
    }
    return _serializeBranchMergeReport(report);
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

class _OperationalMetricQuery {
  const _OperationalMetricQuery({
    required this.name,
    required this.label,
    required this.query,
  });

  final String name;
  final String label;
  final String query;
}

const List<_OperationalMetricQuery> _operationalMetricQueries =
    <_OperationalMetricQuery>[
      _OperationalMetricQuery(
        name: 'sys.wal_metrics',
        label: 'WAL metrics',
        query: 'SELECT * FROM sys.wal_metrics',
      ),
      _OperationalMetricQuery(
        name: 'sys.storage_metrics',
        label: 'Storage metrics',
        query: 'SELECT * FROM sys.storage_metrics',
      ),
      _OperationalMetricQuery(
        name: 'sys.write_queue_metrics',
        label: 'Write queue metrics',
        query: 'SELECT * FROM sys.write_queue_metrics',
      ),
      _OperationalMetricQuery(
        name: 'sys.sync_status',
        label: 'Sync status',
        query: 'SELECT * FROM sys.sync_status',
      ),
      _OperationalMetricQuery(
        name: 'sys.sync_retention',
        label: 'Sync retention',
        query: 'SELECT * FROM sys.sync_retention',
      ),
      _OperationalMetricQuery(
        name: 'sys.sync_peer_lag',
        label: 'Sync peer lag',
        query: 'SELECT * FROM sys.sync_peer_lag',
      ),
      _OperationalMetricQuery(
        name: 'sys.sync_relay_status',
        label: 'Sync relay status',
        query: 'SELECT * FROM sys.sync_relay_status',
      ),
      _OperationalMetricQuery(
        name: 'sys.reactive_metrics',
        label: 'Reactive metrics',
        query: 'SELECT * FROM sys.reactive_metrics',
      ),
      _OperationalMetricQuery(
        name: 'sys.reactive_subscriptions',
        label: 'Reactive subscriptions',
        query: 'SELECT * FROM sys.reactive_subscriptions',
      ),
      _OperationalMetricQuery(
        name: 'sys.extensions',
        label: 'Lua extensions',
        query: 'SELECT * FROM sys.extensions',
      ),
      _OperationalMetricQuery(
        name: 'sys.extension_functions',
        label: 'Lua extension functions',
        query: 'SELECT * FROM sys.extension_functions',
      ),
      _OperationalMetricQuery(
        name: 'sys.extension_collations',
        label: 'Lua extension collations',
        query: 'SELECT * FROM sys.extension_collations',
      ),
      _OperationalMetricQuery(
        name: 'sys.extension_dependencies',
        label: 'Lua extension dependencies',
        query: 'SELECT * FROM sys.extension_dependencies',
      ),
      _OperationalMetricQuery(
        name: 'sys.extension_validation',
        label: 'Lua extension validation',
        query: 'SELECT * FROM sys.extension_validation',
      ),
      _OperationalMetricQuery(
        name: 'sys.process_coordination',
        label: 'Process coordination',
        query: 'SELECT * FROM sys.process_coordination',
      ),
      _OperationalMetricQuery(
        name: 'sys.process_readers',
        label: 'Process readers',
        query: 'SELECT * FROM sys.process_readers',
      ),
      _OperationalMetricQuery(
        name: 'sys.process_lock_metrics',
        label: 'Process lock metrics',
        query: 'SELECT * FROM sys.process_lock_metrics',
      ),
    ];

Map<String, Object?> _serializeWriteQueue(WriteQueueSettings settings) {
  return <String, Object?>{
    'enabled': settings.enabled,
    'capacity': settings.capacity,
    'defaultTimeoutMs': settings.defaultTimeoutMs,
    'maxBatch': settings.maxBatch,
    'maxGroupDelayUs': settings.maxGroupDelayUs,
  };
}

String? _writeQueueOpenOptionsFromPayload(Map<String, Object?>? payload) {
  if (payload == null) {
    return null;
  }
  final enabled = payload['enabled'] as bool? ?? false;
  if (!enabled) {
    return null;
  }
  return WriteQueueSettings(
    enabled: enabled,
    capacity: payload['capacity'] as int? ?? WriteQueueSettings.defaultCapacity,
    defaultTimeoutMs:
        payload['defaultTimeoutMs'] as int? ??
        WriteQueueSettings.defaultDefaultTimeoutMs,
    maxBatch: payload['maxBatch'] as int? ?? WriteQueueSettings.defaultMaxBatch,
    maxGroupDelayUs:
        payload['maxGroupDelayUs'] as int? ??
        WriteQueueSettings.defaultMaxGroupDelayUs,
  ).toDecentDbOpenOptions();
}

BridgeFailure _bridgeFailureFromError(Object error) {
  if (error is BridgeFailure) {
    return error;
  }
  if (error is DecentDbException) {
    return BridgeFailure(error.message, code: _decentDbErrorCodeName(error));
  }
  final message = error.toString();
  final unknownCodeMatch = RegExp(
    r'Unknown DecentDB error code: (\d+)',
  ).firstMatch(message);
  if (unknownCodeMatch != null) {
    return BridgeFailure(
      message,
      code: _nativeStatusName(int.tryParse(unknownCodeMatch.group(1)!)),
    );
  }
  final parsed = _tryParseDiagnosticJson(message);
  if (parsed != null) {
    return parsed;
  }
  return BridgeFailure(message);
}

BridgeFailure? _tryParseDiagnosticJson(String raw) {
  if (!raw.startsWith('{')) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final version = decoded['version'];
    if (version is! num) {
      return null;
    }
    final msg = decoded['message'] as String? ?? raw;
    final codeName = decoded['code_name'] as String?;
    final subcode = decoded['subcode'] as String?;
    final retryable = decoded['retryable'] as bool? ?? false;
    final permanent = decoded['permanent'] as bool? ?? false;
    final sqlstate = decoded['sqlstate'] as String?;
    final docAnchor = decoded['docs'] as String?;
    final code = codeName != null ? 'DDB_$codeName' : null;
    return BridgeFailure(
      msg,
      code: code,
      subcode: subcode,
      retryable: retryable,
      permanent: permanent,
      sqlstate: sqlstate,
      docAnchor: docAnchor,
      diagnosticJson: raw,
    );
  } catch (_) {
    return null;
  }
}

List<Map<String, Object?>> _bridgeMapList(Object? value) {
  final rawItems = (value as List?) ?? const <Object?>[];
  return <Map<String, Object?>>[
    for (final item in rawItems)
      if (item is Map) item.map((key, value) => MapEntry(key as String, value)),
  ];
}

String _decentDbErrorCodeName(DecentDbException error) {
  return _nativeStatusName(error.code.code) ??
      'DDB_ERR_${error.code.name.toUpperCase()}';
}

String? _nativeStatusName(int? code) {
  return switch (code) {
    1 => 'DDB_ERR_IO',
    2 => 'DDB_ERR_CORRUPTION',
    3 => 'DDB_ERR_CONSTRAINT',
    4 => 'DDB_ERR_TRANSACTION',
    5 => 'DDB_ERR_SQL',
    6 => 'DDB_ERR_INTERNAL',
    7 => 'DDB_ERR_PANIC',
    8 => 'DDB_ERR_UNSUPPORTED_FORMAT_VERSION',
    9 => 'DDB_ERR_BUSY',
    10 => 'DDB_ERR_TIMEOUT',
    11 => 'DDB_ERR_CANCELED',
    12 => 'DDB_ERR_QUEUE_FULL',
    13 => 'DDB_ERR_QUEUE_CLOSED',
    _ => null,
  };
}

Map<String, Object?> _serializeBranchInfo(BranchInfo branch) {
  return <String, Object?>{
    'name': branch.name,
    'isCurrent': branch.isMain,
    if (branch.baseHeadId != null) 'parentRef': branch.baseHeadId,
    'createdAt': branch.createdAt.toIso8601String(),
  };
}

Map<String, Object?> _serializeSnapshotInfo(
  NamedSnapshot snapshot, {
  String? branchName,
}) {
  return <String, Object?>{
    'name': snapshot.name,
    'ref': 'snapshot:${snapshot.name}',
    'branch': ?branchName,
    'createdAt': snapshot.createdAt.toIso8601String(),
  };
}

Map<String, Object?> _serializeBranchDiffReport(BranchDiffReport diff) {
  return <String, Object?>{
    'leftRef': diff.leftRef,
    'rightRef': diff.rightRef,
    'rows': <Map<String, Object?>>[
      for (final table in diff.tables) ...<Map<String, Object?>>[
        ..._serializeBranchDiffRows(table.table, 'added', table.added),
        ..._serializeBranchDiffRows(table.table, 'modified', table.updated),
        ..._serializeBranchDiffRows(table.table, 'removed', table.deleted),
      ],
    ],
    'addedRows': diff.addedRowCount,
    'modifiedRows': diff.updatedRowCount,
    'removedRows': diff.deletedRowCount,
  };
}

Map<String, Object?> _serializeBranchRestoreReport(BranchRestoreReport report) {
  return <String, Object?>{
    'leftRef': report.previousHeadId ?? report.branch,
    'rightRef': report.targetRef,
    'rows': const <Map<String, Object?>>[],
    'addedRows': report.addedRowCount,
    'modifiedRows': report.updatedRowCount,
    'removedRows': report.deletedRowCount,
  };
}

Map<String, Object?> _serializeBranchMergeReport(BranchMergeReport report) {
  var addedRows = 0;
  var modifiedRows = 0;
  var removedRows = 0;
  final rows = <Map<String, Object?>>[];
  for (final change in report.applied) {
    final operation = _workspaceMergeOperation(change.operation);
    if (operation == 'added') {
      addedRows++;
    } else if (operation == 'removed') {
      removedRows++;
    } else {
      modifiedRows++;
    }
    rows.add(
      _serializeWorkspaceBranchDiffRow(
        tableName: change.table,
        operation: operation,
        primaryKey: change.primaryKey,
      ),
    );
  }
  for (final conflict in report.conflicts) {
    modifiedRows++;
    rows.add(
      _serializeWorkspaceBranchDiffRow(
        tableName: conflict.table,
        operation: 'conflict:${conflict.conflictType}',
        primaryKey: conflict.primaryKey,
        after: <String, Object?>{'message': conflict.message},
      ),
    );
  }
  return <String, Object?>{
    'leftRef': report.source,
    'rightRef': report.target,
    'rows': rows,
    'addedRows': addedRows,
    'modifiedRows': modifiedRows,
    'removedRows': removedRows,
  };
}

Map<String, Object?> _appendBranchMergeConflicts(
  Map<String, Object?> diff,
  List<BranchMergeConflict> conflicts,
) {
  final rows = <Map<String, Object?>>[
    ..._bridgeMapList(diff['rows']),
    for (final conflict in conflicts)
      _serializeWorkspaceBranchDiffRow(
        tableName: conflict.table,
        operation: 'conflict:${conflict.conflictType}',
        primaryKey: conflict.primaryKey,
        after: <String, Object?>{'message': conflict.message},
      ),
  ];
  return <String, Object?>{
    ...diff,
    'rows': rows,
    'modifiedRows': (diff['modifiedRows'] as int? ?? 0) + conflicts.length,
  };
}

List<Map<String, Object?>> _serializeBranchDiffRows(
  String tableName,
  String operation,
  List<BranchRowDiff> rows,
) {
  return <Map<String, Object?>>[
    for (final row in rows)
      _serializeWorkspaceBranchDiffRow(
        tableName: tableName,
        operation: operation,
        primaryKey: row.primaryKey,
        before: _branchRowValues(row.before),
        after: _branchRowValues(row.after),
      ),
  ];
}

Map<String, Object?> _serializeWorkspaceBranchDiffRow({
  required String tableName,
  required String operation,
  required List<String> primaryKey,
  Map<String, Object?>? before,
  Map<String, Object?>? after,
}) {
  return <String, Object?>{
    'tableName': tableName,
    'operation': operation,
    if (primaryKey.isNotEmpty) 'primaryKey': primaryKey.join(', '),
    'before': ?before,
    'after': ?after,
  };
}

Map<String, Object?>? _branchRowValues(List<String>? values) {
  if (values == null) {
    return null;
  }
  return <String, Object?>{'values': values};
}

String _workspaceMergeOperation(String operation) {
  return switch (operation.toLowerCase()) {
    'insert' || 'added' || 'add' => 'added',
    'delete' || 'deleted' || 'remove' || 'removed' => 'removed',
    _ => 'modified',
  };
}

String? _nativeBranchRef(String? ref) {
  final trimmed = ref?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('snapshot:')) {
    return trimmed.substring('snapshot:'.length);
  }
  return trimmed;
}

String _snapshotNameFromRef(String ref) {
  return _nativeBranchRef(ref) ?? ref;
}

Map<String, Object?> _nativeWriteQueueMetricsView(Database db) {
  const name = 'native.write_queue_metrics';
  const label = 'Write queue API metrics';
  const query = 'Database.writeQueueMetrics()';
  try {
    final metrics = db.writeQueueMetrics();
    return <String, Object?>{
      'name': name,
      'label': label,
      'query': query,
      'available': true,
      'columns': metrics.keys.toList(growable: false),
      'rows': <Map<String, Object?>>[metrics],
      'truncated': false,
    };
  } catch (error) {
    final failure = _bridgeFailureFromError(error);
    return <String, Object?>{
      'name': name,
      'label': label,
      'query': query,
      'available': false,
      'columns': const <String>[],
      'rows': const <Map<String, Object?>>[],
      'error': failure.toString(),
      'truncated': false,
    };
  }
}

Map<String, Object?> _queryOperationalMetricView(
  Database db,
  _OperationalMetricQuery spec, {
  required int maxRows,
}) {
  try {
    final stmt = db.prepare(spec.query);
    try {
      final page = stmt.nextPage(maxRows);
      return <String, Object?>{
        'name': spec.name,
        'label': spec.label,
        'query': spec.query,
        'available': true,
        'columns': page.columns,
        'rows': <Map<String, Object?>>[
          for (final row in page.rows)
            <String, Object?>{
              for (var index = 0; index < row.columns.length; index++)
                row.columns[index]: _encodeCell(row.values[index]),
            },
        ],
        'truncated': !page.isLast,
      };
    } finally {
      stmt.dispose();
    }
  } catch (error) {
    final failure = _bridgeFailureFromError(error);
    return <String, Object?>{
      'name': spec.name,
      'label': spec.label,
      'query': spec.query,
      'available': false,
      'columns': const <String>[],
      'rows': const <Map<String, Object?>>[],
      'error': failure.toString(),
      'truncated': false,
    };
  }
}

bool _isSysSchemaBoundaryError(String? error) {
  final normalized = error?.toLowerCase() ?? '';
  return normalized.contains('schema-qualified objects outside main/temp') &&
      normalized.contains("schema 'sys'");
}

Map<String, Object?> _sysInspectionPreparedBoundaryView() {
  return <String, Object?>{
    'name': 'decentdb.sys_inspection_views',
    'label': 'DecentDB sys.* SQL metrics',
    'query': 'SELECT * FROM sys.*',
    'available': false,
    'columns': const <String>[],
    'rows': const <Map<String, Object?>>[],
    'error':
        'Unavailable through the current Dart prepared-statement paging path. '
        'DecentDB v2.8 exposes these inspection views through direct SQL '
        'execution, but the Dart binding does not yet expose direct-result '
        'paging. Native public metrics APIs are shown when available.',
    'truncated': false,
  };
}

String _inlineQueuedWriteParameters(String sql, List<Object?> params) {
  if (params.isEmpty) {
    return sql;
  }
  var rendered = sql;
  for (var index = params.length; index >= 1; index--) {
    rendered = rendered.replaceAll('\$$index', _sqlLiteral(params[index - 1]));
  }
  if (RegExp(r'\$\d+').hasMatch(rendered)) {
    throw const BridgeFailure(
      'Queued writes require every positional parameter to be bound.',
    );
  }
  return rendered;
}

String _sqlStringLiteral(String value) {
  return "'${value.replaceAll("'", "''")}'";
}

String _sqlLiteral(Object? value) {
  if (value == null) {
    return 'NULL';
  }
  if (value is bool) {
    return value ? 'TRUE' : 'FALSE';
  }
  if (value is int || value is double) {
    return '$value';
  }
  if (value is DecimalValue) {
    return formatDecimalValue(value.scaled, value.scale);
  }
  if (value is String) {
    return _sqlStringLiteral(value);
  }
  if (value is Uint8List) {
    final hex = value
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return "X'$hex'";
  }
  if (value is DateTime) {
    return _sqlStringLiteral(value.toIso8601String());
  }
  if (value is Duration) {
    return '${value.inMicroseconds}';
  }
  if (value is DecentDBIntervalValue) {
    return _sqlStringLiteral(
      NativeIntervalCellValue(
        months: value.months,
        days: value.days,
        microseconds: value.microseconds,
      ).displayString(),
    );
  }
  if (value is DecentDBEnumValue) {
    throw const BridgeFailure(
      'Queued writes do not support native enum parameter inlining yet.',
    );
  }
  return _sqlStringLiteral(value.toString());
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

List<Map<String, Object?>> _serializeTableColumns(SchemaTableInfo table) {
  final serialized = <Map<String, Object?>>[];
  for (final column in table.columns) {
    final foreignKey =
        column.foreignKey ??
        _foreignKeyForColumn(table.foreignKeys, column.name);
    serialized.add(<String, Object?>{
      'name': column.name,
      'type': column.type,
      'notNull': !column.nullable,
      'unique': column.unique,
      'primaryKey': column.primaryKey,
      'defaultExpr': column.defaultSql,
      'generatedExpr': column.generatedSql,
      'generatedStored': column.generatedStored,
      'refTable': foreignKey?.referencedTable,
      'refColumn': _referencedColumnFor(column.name, foreignKey),
      'refOnDelete': foreignKey?.onDelete,
      'refOnUpdate': foreignKey?.onUpdate,
    });
  }
  return serialized;
}

ForeignKeyInfo? _foreignKeyForColumn(
  List<ForeignKeyInfo> foreignKeys,
  String columnName,
) {
  for (final foreignKey in foreignKeys) {
    if (foreignKey.columns.contains(columnName)) {
      return foreignKey;
    }
  }
  return null;
}

String? _referencedColumnFor(String columnName, ForeignKeyInfo? foreignKey) {
  if (foreignKey == null || foreignKey.columns.isEmpty) {
    return null;
  }
  final localIndex = foreignKey.columns.indexOf(columnName);
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
