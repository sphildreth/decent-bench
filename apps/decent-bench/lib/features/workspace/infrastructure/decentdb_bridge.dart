import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:decentdb/decentdb.dart';

import '../domain/workspace_models.dart';
import 'native_library_resolver.dart';

abstract class WorkspaceDatabaseGateway {
  String? get resolvedLibraryPath;

  Future<String> initialize();

  Future<DatabaseSession> openDatabase(String path);

  Future<SchemaSnapshot> loadSchema();

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

  Future<void> dispose();
}

class DecentDbBridge implements WorkspaceDatabaseGateway {
  DecentDbBridge({NativeLibraryResolver? resolver})
    : _resolver = resolver ?? NativeLibraryResolver();

  final NativeLibraryResolver _resolver;
  final Map<int, Completer<Map<String, Object?>>> _pending =
      <int, Completer<Map<String, Object?>>>{};

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
  Future<void> dispose() async {
    if (_workerPort != null) {
      try {
        await _request('shutdown');
      } catch (_) {
        // Ignore shutdown races.
      }
    }
    _responses?.close();
    _responses = null;
    _workerPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

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
}

@pragma('vm:entry-point')
Future<void> _workerMain(List<Object?> bootstrap) async {
  final mainPort = bootstrap[0]! as SendPort;
  final libraryPath = bootstrap[1]! as String;
  final receivePort = ReceivePort();
  mainPort.send(receivePort.sendPort);

  Database? database;
  final cursors = <String, Statement>{};
  var nextCursorId = 1;

  Future<void> closeAll() async {
    for (final statement in cursors.values) {
      statement.dispose();
    }
    cursors.clear();
    database?.close();
    database = null;
  }

  Map<String, Object?> serializePage(
    ResultPage page, {
    required String? cursorId,
    required int? rowsAffected,
    required Duration elapsed,
  }) {
    return <String, Object?>{
      'cursorId': cursorId,
      'columns': page.columns,
      'rows': <Map<String, Object?>>[
        for (final row in page.rows)
          <String, Object?>{
            for (var i = 0; i < row.columns.length; i++)
              row.columns[i]: _encodeCell(row.values[i]),
          },
      ],
      'done': page.isLast,
      'rowsAffected': rowsAffected,
      'elapsedMicros': elapsed.inMicroseconds,
    };
  }

  Future<Map<String, Object?>> handle(
    String action,
    Map<String, Object?> payload,
  ) async {
    switch (action) {
      case 'openDatabase':
        await closeAll();
        final path = payload['path']! as String;
        database = Database.open(path, libraryPath: libraryPath);
        return <String, Object?>{
          'path': path,
          'engineVersion': database!.engineVersion,
        };
      case 'loadSchema':
        final db = _requireDatabase(database);
        final tables = db.schema.listTables()..sort();
        final views = db.schema.listViews()..sort();
        final objects = <Map<String, Object?>>[
          for (final table in tables)
            <String, Object?>{
              'name': table,
              'kind': 'table',
              'columns': _serializeColumns(db.schema.getTableColumns(table)),
            },
          for (final view in views)
            <String, Object?>{
              'name': view,
              'kind': 'view',
              'ddl': db.schema.getViewDdl(view),
              'columns': _serializeColumns(db.schema.getTableColumns(view)),
            },
        ];
        final indexes = db.schema.listIndexes()
          ..sort((left, right) {
            final byTable = left.table.compareTo(right.table);
            return byTable != 0 ? byTable : left.name.compareTo(right.name);
          });
        return <String, Object?>{
          'objects': objects,
          'indexes': <Map<String, Object?>>[
            for (final index in indexes)
              <String, Object?>{
                'name': index.name,
                'table': index.table,
                'columns': index.columns,
                'unique': index.unique,
                'kind': index.kind,
              },
          ],
          'loadedAt': DateTime.now().toUtc().toIso8601String(),
        };
      case 'runQuery':
        final db = _requireDatabase(database);
        final sql = payload['sql']! as String;
        final params = ((payload['params'] as List?) ?? const <Object?>[])
            .cast<Object?>();
        final pageSize = payload['pageSize']! as int;
        final stopwatch = Stopwatch()..start();
        final stmt = db.prepare(sql);
        stmt.bindAll(params);
        if (stmt.columnCount == 0) {
          try {
            final rowsAffected = stmt.execute();
            return serializePage(
              const ResultPage(<String>[], <Row>[], true),
              cursorId: null,
              rowsAffected: rowsAffected,
              elapsed: stopwatch.elapsed,
            );
          } finally {
            stmt.dispose();
          }
        }

        final cursorId = 'cursor-${nextCursorId++}';
        final page = stmt.nextPage(pageSize);
        if (!page.isLast) {
          cursors[cursorId] = stmt;
        } else {
          stmt.dispose();
        }
        return serializePage(
          page,
          cursorId: page.isLast ? null : cursorId,
          rowsAffected: null,
          elapsed: stopwatch.elapsed,
        );
      case 'fetchNextPage':
        final cursorId = payload['cursorId']! as String;
        final pageSize = payload['pageSize']! as int;
        final stmt = cursors[cursorId];
        if (stmt == null) {
          throw const BridgeFailure('Query cursor is no longer available.');
        }
        final stopwatch = Stopwatch()..start();
        final page = stmt.nextPage(pageSize);
        if (page.isLast) {
          stmt.dispose();
          cursors.remove(cursorId);
        }
        return serializePage(
          page,
          cursorId: page.isLast ? null : cursorId,
          rowsAffected: null,
          elapsed: stopwatch.elapsed,
        );
      case 'cancelQuery':
        final cursorId = payload['cursorId']! as String;
        final stmt = cursors.remove(cursorId);
        stmt?.dispose();
        return const <String, Object?>{};
      case 'exportCsv':
        final db = _requireDatabase(database);
        final sql = payload['sql']! as String;
        final params = ((payload['params'] as List?) ?? const <Object?>[])
            .cast<Object?>();
        final pageSize = payload['pageSize']! as int;
        final path = payload['path']! as String;
        final delimiter = payload['delimiter']! as String;
        final includeHeaders = payload['includeHeaders']! as bool;

        final file = File(path);
        await file.parent.create(recursive: true);
        final stmt = db.prepare(sql);
        stmt.bindAll(params);
        if (stmt.columnCount == 0) {
          stmt.dispose();
          throw const BridgeFailure(
            'The current statement does not produce rows and cannot be exported.',
          );
        }

        final sink = file.openWrite();
        var rowCount = 0;
        try {
          if (includeHeaders) {
            sink.writeln(
              stmt.columnNames
                  .map((item) => _escapeCsv(item, delimiter))
                  .join(delimiter),
            );
          }
          while (true) {
            final page = stmt.nextPage(pageSize);
            for (final row in page.rows) {
              sink.writeln(
                row.values
                    .map((value) => _escapeCsv(_csvValue(value), delimiter))
                    .join(delimiter),
              );
              rowCount++;
            }
            if (page.isLast) {
              break;
            }
          }
        } finally {
          await sink.flush();
          await sink.close();
          stmt.dispose();
        }
        return <String, Object?>{'rowCount': rowCount, 'path': path};
      case 'shutdown':
        await closeAll();
        receivePort.close();
        return const <String, Object?>{};
    }

    throw BridgeFailure('Unsupported worker action: $action');
  }

  await for (final raw in receivePort) {
    if (raw is! Map<Object?, Object?>) {
      continue;
    }

    final message = raw.map((key, value) => MapEntry(key as String, value));
    final requestId = message['id']! as int;
    final replyPort = message['replyPort']! as SendPort;
    final action = message['action']! as String;
    final payload = ((message['payload'] as Map?) ?? const <Object?, Object?>{})
        .map((key, value) => MapEntry(key as String, value));

    try {
      final data = await handle(action, payload);
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

Database _requireDatabase(Database? database) {
  if (database == null) {
    throw const BridgeFailure('Open or create a DecentDB file first.');
  }
  return database;
}

List<Map<String, Object?>> _serializeColumns(List<ColumnInfo> columns) {
  return <Map<String, Object?>>[
    for (final column in columns)
      <String, Object?>{
        'name': column.name,
        'type': column.type,
        'notNull': column.notNull,
        'unique': column.unique,
        'primaryKey': column.primaryKey,
        'refTable': column.refTable,
        'refColumn': column.refColumn,
        'refOnDelete': column.refOnDelete,
        'refOnUpdate': column.refOnUpdate,
      },
  ];
}

Object? _encodeCell(Object? value) {
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

String _csvValue(Object? value) {
  if (value == null) {
    return '';
  }
  if (value case (unscaled: final int unscaled, scale: final int scale)) {
    return formatDecimalValue(unscaled, scale);
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Uint8List) {
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
