import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:decentdb/decentdb.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../domain/sqlite_import_models.dart';
import '../domain/workspace_models.dart';

Future<SqliteImportInspection> inspectSqliteSourceInBackground(
  String sourcePath,
) {
  return Isolate.run(() => inspectSqliteSourceFile(sourcePath));
}

SqliteImportInspection inspectSqliteSourceFile(String sourcePath) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw BridgeFailure('SQLite source file does not exist: $sourcePath');
  }

  final database = sqlite.sqlite3.open(sourcePath);
  try {
    database.execute('PRAGMA foreign_keys = ON;');
    final tables = <SqliteImportTableDraft>[];
    final warnings = <String>[];
    for (final table in _listUserTables(database)) {
      final draft = _inspectTable(database, table.name, table.sql);
      tables.add(draft);
      if (draft.strict) {
        warnings.add(
          '${draft.sourceName} uses STRICT in SQLite; Decent Bench imports it as a regular DecentDB table.',
        );
      }
      if (draft.withoutRowId) {
        warnings.add(
          '${draft.sourceName} uses WITHOUT ROWID in SQLite; Decent Bench preserves data and keys but not WITHOUT ROWID storage semantics.',
        );
      }
    }

    return SqliteImportInspection(
      sourcePath: sourcePath,
      tables: tables,
      warnings: warnings,
    );
  } finally {
    database.close();
  }
}

Future<SqliteImportPreview> loadSqlitePreviewInBackground(
  String sourcePath,
  String tableName, {
  int limit = 8,
}) {
  return Isolate.run(
    () => loadSqlitePreview(sourcePath, tableName, limit: limit),
  );
}

SqliteImportPreview loadSqlitePreview(
  String sourcePath,
  String tableName, {
  int limit = 8,
}) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw BridgeFailure('SQLite source file does not exist: $sourcePath');
  }

  final database = sqlite.sqlite3.open(sourcePath);
  try {
    final quotedTable = _quoteSqliteIdent(tableName);
    final rows = database.select('SELECT * FROM $quotedTable LIMIT $limit');
    final previewRows = <Map<String, Object?>>[
      for (final row in rows)
        <String, Object?>{for (final column in row.keys) column: row[column]},
    ];
    return SqliteImportPreview(tableName: tableName, rows: previewRows);
  } finally {
    database.close();
  }
}

@pragma('vm:entry-point')
Future<void> sqliteImportWorkerMain(List<Object?> bootstrap) async {
  final mainPort = bootstrap[0]! as SendPort;
  final libraryPath = bootstrap[1]! as String;
  final request = SqliteImportRequest.fromMap(
    (bootstrap[2]! as Map<Object?, Object?>).map(
      (key, value) => MapEntry(key as String, value),
    ),
  );

  final commandPort = ReceivePort();
  mainPort.send(commandPort.sendPort);

  var cancelled = false;
  late final StreamSubscription<Object?> commandSubscription;
  commandSubscription = commandPort.listen((message) {
    if (message == 'cancel') {
      cancelled = true;
    }
  });

  try {
    final summary = await _runSqliteImport(
      request: request,
      libraryPath: libraryPath,
      sendUpdate: (update) => mainPort.send(update.toMap()),
      isCancelled: () => cancelled,
    );
    mainPort.send(
      SqliteImportUpdate(
        kind: cancelled
            ? SqliteImportUpdateKind.cancelled
            : SqliteImportUpdateKind.completed,
        jobId: request.jobId,
        summary: summary,
      ).toMap(),
    );
  } on _SqliteImportCancelled catch (error) {
    mainPort.send(
      SqliteImportUpdate(
        kind: SqliteImportUpdateKind.cancelled,
        jobId: request.jobId,
        summary: error.summary,
        message: error.summary.statusMessage,
      ).toMap(),
    );
  } catch (error) {
    mainPort.send(
      SqliteImportUpdate(
        kind: SqliteImportUpdateKind.failed,
        jobId: request.jobId,
        message: error.toString(),
      ).toMap(),
    );
  } finally {
    await commandSubscription.cancel();
    commandPort.close();
  }
}

Future<SqliteImportSummary> _runSqliteImport({
  required SqliteImportRequest request,
  required String libraryPath,
  required void Function(SqliteImportUpdate update) sendUpdate,
  required bool Function() isCancelled,
}) async {
  if (request.selectedTables.isEmpty) {
    throw const BridgeFailure('Select at least one SQLite table to import.');
  }

  _validateRequestNames(request);

  final sourceFile = File(request.sourcePath);
  if (!sourceFile.existsSync()) {
    throw BridgeFailure(
      'SQLite source file does not exist: ${request.sourcePath}',
    );
  }

  final targetFile = File(request.targetPath);
  if (request.importIntoExistingTarget) {
    if (!targetFile.existsSync()) {
      throw BridgeFailure(
        'Target DecentDB file does not exist: ${request.targetPath}',
      );
    }
  } else {
    targetFile.parent.createSync(recursive: true);
    if (targetFile.existsSync()) {
      if (!request.replaceExistingTarget) {
        throw BridgeFailure(
          'Refusing to replace an existing DecentDB file without confirmation: ${request.targetPath}',
        );
      }
      targetFile.deleteSync();
      final walFile = File('${request.targetPath}-wal');
      if (walFile.existsSync()) {
        walFile.deleteSync();
      }
    }
  }

  final source = sqlite.sqlite3.open(request.sourcePath);
  final target = Database.open(request.targetPath, libraryPath: libraryPath);
  var transactionOpen = false;
  final rowsCopied = <String, int>{};
  final indexesCreated = <String>[];
  final skippedItems = <SqliteImportSkippedItem>[
    for (final table in request.selectedTables) ...table.skippedItems,
  ];
  final warnings = <String>[];

  try {
    source.execute('PRAGMA foreign_keys = ON;');

    final orderedTables = _toposortSelectedTables(
      request.selectedTables,
      warnings,
    );

    final existingTables = target.schema.listTables().toSet();
    final colliding = orderedTables
        .map((table) => table.targetName)
        .where(existingTables.contains)
        .toList();
    if (colliding.isNotEmpty) {
      throw BridgeFailure(
        'Target already contains table(s): ${colliding.join(", ")}. Rename them or choose another DecentDB file.',
      );
    }

    target.begin();
    transactionOpen = true;

    for (var i = 0; i < orderedTables.length; i++) {
      final table = orderedTables[i];
      _throwIfCancelled(isCancelled);
      target.execute(
        _buildCreateTableSql(table, orderedTables, skippedItems, warnings),
      );
      sendUpdate(
        SqliteImportUpdate(
          kind: SqliteImportUpdateKind.progress,
          jobId: request.jobId,
          progress: SqliteImportProgress(
            jobId: request.jobId,
            currentTable: table.targetName,
            completedTables: i,
            totalTables: orderedTables.length,
            currentTableRowsCopied: 0,
            currentTableRowCount: table.rowCount,
            totalRowsCopied: rowsCopied.values.fold<int>(
              0,
              (sum, value) => sum + value,
            ),
            message: 'Created table ${table.targetName}.',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    for (var i = 0; i < orderedTables.length; i++) {
      final table = orderedTables[i];
      final copied = await _copyTableData(
        source: source,
        target: target,
        request: request,
        table: table,
        completedTables: i,
        totalTables: orderedTables.length,
        priorRowsCopied: rowsCopied.values.fold<int>(
          0,
          (sum, value) => sum + value,
        ),
        sendUpdate: sendUpdate,
        isCancelled: isCancelled,
      );
      rowsCopied[table.targetName] = copied;
    }

    for (final table in orderedTables) {
      _throwIfCancelled(isCancelled);
      for (final index in table.indexes) {
        final indexName = _normalizeImportedIndexName(index.name);
        target.execute(
          'CREATE INDEX ${_quoteDecentIdent(indexName)} ON '
          '${_quoteDecentIdent(table.targetName)}(${_quoteDecentIdent(_targetColumnName(table, index.column))})',
        );
        indexesCreated.add(indexName);
      }
      await Future<void>.delayed(Duration.zero);
    }

    target.commit();
    transactionOpen = false;

    return SqliteImportSummary(
      jobId: request.jobId,
      sourcePath: request.sourcePath,
      targetPath: request.targetPath,
      importedTables: orderedTables.map((table) => table.targetName).toList(),
      rowsCopiedByTable: rowsCopied,
      indexesCreated: indexesCreated,
      skippedItems: skippedItems,
      warnings: warnings,
      statusMessage:
          'Imported ${rowsCopied.values.fold<int>(0, (sum, value) => sum + value)} rows from ${orderedTables.length} SQLite table${orderedTables.length == 1 ? '' : 's'}.',
      rolledBack: false,
    );
  } on _SqliteImportCancelledSignal {
    if (transactionOpen) {
      try {
        target.rollback();
      } catch (_) {
        // Best-effort rollback for cancellation.
      }
    }
    final summary = SqliteImportSummary(
      jobId: request.jobId,
      sourcePath: request.sourcePath,
      targetPath: request.targetPath,
      importedTables: rowsCopied.keys.toList(),
      rowsCopiedByTable: rowsCopied,
      indexesCreated: indexesCreated,
      skippedItems: skippedItems,
      warnings: warnings,
      statusMessage: 'SQLite import cancelled and rolled back.',
      rolledBack: true,
    );
    throw _SqliteImportCancelled(summary);
  } catch (_) {
    if (transactionOpen) {
      try {
        target.rollback();
      } catch (_) {
        // Best-effort rollback on failure.
      }
    }
    rethrow;
  } finally {
    target.close();
    source.close();
  }
}

Future<int> _copyTableData({
  required sqlite.Database source,
  required Database target,
  required SqliteImportRequest request,
  required SqliteImportTableDraft table,
  required int completedTables,
  required int totalTables,
  required int priorRowsCopied,
  required void Function(SqliteImportUpdate update) sendUpdate,
  required bool Function() isCancelled,
}) async {
  final sourceColumns = table.columns
      .map((column) => _quoteSqliteIdent(column.sourceName))
      .join(', ');
  final sourceStatement = source.prepare(
    'SELECT $sourceColumns FROM ${_quoteSqliteIdent(table.sourceName)}',
  );
  final placeholders = <String>[
    for (var i = 0; i < table.columns.length; i++)
      _placeholderForType(table.columns[i].targetType, i + 1),
  ];
  final targetStatement = target.prepare(
    'INSERT INTO ${_quoteDecentIdent(table.targetName)} '
    '(${table.columns.map((column) => _quoteDecentIdent(column.targetName)).join(", ")}) '
    'VALUES (${placeholders.join(", ")})',
  );

  var copied = 0;
  try {
    final cursor = sourceStatement.selectCursor();
    while (cursor.moveNext()) {
      _throwIfCancelled(isCancelled);
      final row = cursor.current;
      final values = <Object?>[
        for (final column in table.columns)
          _adaptImportValue(row[column.sourceName], column.targetType),
      ];
      targetStatement.reset();
      targetStatement.clearBindings();
      targetStatement.bindAll(values);
      targetStatement.execute();
      copied++;

      if (copied == 1 || copied % 200 == 0 || copied == table.rowCount) {
        sendUpdate(
          SqliteImportUpdate(
            kind: SqliteImportUpdateKind.progress,
            jobId: request.jobId,
            progress: SqliteImportProgress(
              jobId: request.jobId,
              currentTable: table.targetName,
              completedTables: completedTables,
              totalTables: totalTables,
              currentTableRowsCopied: copied,
              currentTableRowCount: table.rowCount,
              totalRowsCopied: priorRowsCopied + copied,
              message: 'Copying ${table.targetName}...',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
    }
  } finally {
    targetStatement.dispose();
    sourceStatement.close();
  }
  return copied;
}

void _validateRequestNames(SqliteImportRequest request) {
  final selectedTables = request.selectedTables;
  final targetTableNames = <String>{};
  for (final table in selectedTables) {
    final targetTableName = table.targetName.trim();
    if (targetTableName.isEmpty) {
      throw BridgeFailure(
        'Each selected SQLite table needs a target DecentDB table name.',
      );
    }
    if (!targetTableNames.add(targetTableName)) {
      throw BridgeFailure(
        'Target table names must be unique. Duplicate: $targetTableName',
      );
    }

    final targetColumnNames = <String>{};
    for (final column in table.columns) {
      final targetColumnName = column.targetName.trim();
      if (targetColumnName.isEmpty) {
        throw BridgeFailure(
          'Each imported column needs a target name (${table.sourceName}.${column.sourceName}).',
        );
      }
      if (!targetColumnNames.add(targetColumnName)) {
        throw BridgeFailure(
          'Target column names must be unique within ${table.targetName}. Duplicate: $targetColumnName',
        );
      }
    }
  }
}

void _throwIfCancelled(bool Function() isCancelled) {
  if (!isCancelled()) {
    return;
  }
  throw const _SqliteImportCancelledSignal();
}

List<({String name, String? sql})> _listUserTables(sqlite.Database database) {
  final result = database.select(
    "SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  return <({String name, String? sql})>[
    for (final row in result)
      (name: row['name']! as String, sql: row['sql'] as String?),
  ];
}

SqliteImportTableDraft _inspectTable(
  sqlite.Database database,
  String tableName,
  String? tableSql,
) {
  final columns = <SqliteImportColumnDraft>[];
  final columnIndex = <String, int>{};
  final columnInfo = database.select(
    'PRAGMA table_info(${_quoteSqliteIdent(tableName)})',
  );

  for (final row in columnInfo) {
    final sourceName = row['name']! as String;
    final declaredType = (row['type'] as String?) ?? '';
    final inferredType = mapSqliteDeclaredTypeToDecentDb(declaredType);
    final column = SqliteImportColumnDraft(
      sourceName: sourceName,
      targetName: sourceName,
      declaredType: declaredType,
      inferredTargetType: inferredType,
      targetType: inferredType,
      notNull: (row['notnull'] as int?) == 1,
      primaryKey: ((row['pk'] as int?) ?? 0) > 0,
      unique: false,
    );
    columnIndex[sourceName] = columns.length;
    columns.add(column);
  }

  final foreignKeys = <SqliteImportForeignKey>[];
  final foreignKeyRows = database.select(
    'PRAGMA foreign_key_list(${_quoteSqliteIdent(tableName)})',
  );
  for (final row in foreignKeyRows) {
    foreignKeys.add(
      SqliteImportForeignKey(
        fromColumn: row['from']! as String,
        toTable: row['table']! as String,
        toColumn: row['to']! as String,
      ),
    );
  }

  final indexes = <SqliteImportIndex>[];
  final skippedItems = <SqliteImportSkippedItem>[];
  final indexRows = database.select(
    'PRAGMA index_list(${_quoteSqliteIdent(tableName)})',
  );
  for (final row in indexRows) {
    final indexName = row['name']! as String;
    final unique = (row['unique'] as int?) == 1;
    final origin = ((row['origin'] as String?) ?? '').toLowerCase();
    if (origin == 'pk') {
      continue;
    }
    final indexColumns = database.select(
      'PRAGMA index_info(${_quoteSqliteIdent(indexName)})',
    );
    if (indexColumns.length != 1) {
      skippedItems.add(
        SqliteImportSkippedItem(
          name: indexName,
          tableName: tableName,
          reason: unique
              ? 'Composite UNIQUE constraints are not imported in Phase 4.'
              : 'Composite indexes are not imported in Phase 4.',
        ),
      );
      continue;
    }
    final columnName = indexColumns.first['name']! as String;
    if (unique && columnIndex.containsKey(columnName)) {
      final idx = columnIndex[columnName]!;
      columns[idx] = columns[idx].copyWith(unique: true);
      continue;
    }
    indexes.add(
      SqliteImportIndex(name: indexName, column: columnName, unique: unique),
    );
  }

  final rowCountResult = database.select(
    'SELECT COUNT(*) AS row_count FROM ${_quoteSqliteIdent(tableName)}',
  );
  final rowCount = rowCountResult.first['row_count']! as int;

  final upperSql = (tableSql ?? '').toUpperCase();
  return SqliteImportTableDraft(
    sourceName: tableName,
    targetName: tableName,
    selected: true,
    rowCount: rowCount,
    strict: upperSql.contains('STRICT'),
    withoutRowId: upperSql.contains('WITHOUT ROWID'),
    columns: columns,
    foreignKeys: foreignKeys,
    indexes: indexes,
    skippedItems: skippedItems,
    previewRows: const <Map<String, Object?>>[],
    previewLoaded: false,
  );
}

List<SqliteImportTableDraft> _toposortSelectedTables(
  List<SqliteImportTableDraft> tables,
  List<String> warnings,
) {
  final bySourceName = <String, SqliteImportTableDraft>{
    for (final table in tables) table.sourceName: table,
  };
  final dependencies = <String, Set<String>>{
    for (final table in tables) table.sourceName: <String>{},
  };
  final reverseEdges = <String, Set<String>>{
    for (final table in tables) table.sourceName: <String>{},
  };

  for (final table in tables) {
    for (final foreignKey in table.foreignKeys) {
      final target = bySourceName[foreignKey.toTable];
      if (target == null) {
        warnings.add(
          'Skipping foreign key ${table.sourceName}.${foreignKey.fromColumn} -> ${foreignKey.toTable}.${foreignKey.toColumn} because the referenced table is not selected.',
        );
        continue;
      }
      dependencies[table.sourceName]!.add(target.sourceName);
      reverseEdges[target.sourceName]!.add(table.sourceName);
    }
  }

  final indegree = <String, int>{
    for (final entry in dependencies.entries) entry.key: entry.value.length,
  };
  final queue = Queue<String>()
    ..addAll(
      indegree.entries
          .where((entry) => entry.value == 0)
          .map((entry) => entry.key),
    );

  final ordered = <SqliteImportTableDraft>[];
  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    ordered.add(bySourceName[current]!);
    for (final dependent in reverseEdges[current]!) {
      indegree[dependent] = indegree[dependent]! - 1;
      if (indegree[dependent] == 0) {
        queue.add(dependent);
      }
    }
  }

  if (ordered.length != tables.length) {
    final cycle =
        indegree.entries
            .where((entry) => entry.value > 0)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    throw BridgeFailure(
      'SQLite import cannot preserve the selected foreign key cycle: ${cycle.join(", ")}. Import a different table set or rename/drop the dependency first.',
    );
  }

  return ordered;
}

String _buildCreateTableSql(
  SqliteImportTableDraft table,
  List<SqliteImportTableDraft> selectedTables,
  List<SqliteImportSkippedItem> skippedItems,
  List<String> warnings,
) {
  final selectedBySource = <String, SqliteImportTableDraft>{
    for (final selected in selectedTables) selected.sourceName: selected,
  };
  final foreignKeyByColumn = <String, SqliteImportForeignKey>{
    for (final foreignKey in table.foreignKeys)
      foreignKey.fromColumn: foreignKey,
  };
  final primaryKeyColumns = table.columns
      .where((column) => column.primaryKey)
      .toList();
  final hasCompositePrimaryKey = primaryKeyColumns.length > 1;

  final definitions = <String>[];
  for (final column in table.columns) {
    final parts = <String>[
      _quoteDecentIdent(column.targetName),
      column.targetType,
    ];

    if (column.primaryKey && !hasCompositePrimaryKey) {
      parts.add('PRIMARY KEY');
    } else {
      if (column.notNull || column.primaryKey) {
        parts.add('NOT NULL');
      }
      if (column.unique) {
        parts.add('UNIQUE');
      }
    }

    final foreignKey = foreignKeyByColumn[column.sourceName];
    final targetTable = foreignKey == null
        ? null
        : selectedBySource[foreignKey.toTable];
    if (foreignKey != null && targetTable != null) {
      parts.add(
        'REFERENCES ${_quoteDecentIdent(targetTable.targetName)}'
        '(${_quoteDecentIdent(_targetColumnName(targetTable, foreignKey.toColumn))})',
      );
    } else if (foreignKey != null) {
      skippedItems.add(
        SqliteImportSkippedItem(
          name: '${table.sourceName}.${column.sourceName}',
          tableName: table.sourceName,
          reason:
              'Foreign key to ${foreignKey.toTable}.${foreignKey.toColumn} skipped because that table is not selected.',
        ),
      );
      warnings.add(
        'Skipping foreign key ${table.sourceName}.${column.sourceName} -> ${foreignKey.toTable}.${foreignKey.toColumn} because the referenced table is not selected.',
      );
    }

    definitions.add(parts.join(' '));
  }

  if (hasCompositePrimaryKey) {
    definitions.add(
      'PRIMARY KEY (${primaryKeyColumns.map((column) => _quoteDecentIdent(column.targetName)).join(", ")})',
    );
  }

  return 'CREATE TABLE ${_quoteDecentIdent(table.targetName)} (${definitions.join(", ")})';
}

String _targetColumnName(
  SqliteImportTableDraft table,
  String sourceColumnName,
) {
  for (final column in table.columns) {
    if (column.sourceName == sourceColumnName) {
      return column.targetName;
    }
  }
  return sourceColumnName;
}

String _placeholderForType(String targetType, int index) {
  if (_isDecimalType(targetType) || _isUuidType(targetType)) {
    return 'CAST(\$$index AS $targetType)';
  }
  return '\$$index';
}

Object? _adaptImportValue(Object? value, String targetType) {
  if (value == null) {
    return null;
  }
  if (targetType == 'BOOLEAN') {
    if (value is bool) {
      return value;
    }
    if (value is int && (value == 0 || value == 1)) {
      return value == 1;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return value;
  }
  if (targetType == 'TEXT' && value is Uint8List) {
    return formatCellValue(value);
  }
  if (targetType == 'BLOB' && value is String) {
    return Uint8List.fromList(value.codeUnits);
  }
  if (targetType == 'TIMESTAMP' && value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc() ?? value;
  }
  if (targetType == 'TIMESTAMP' && value is DateTime) {
    return value.toUtc();
  }
  return value;
}

String mapSqliteDeclaredTypeToDecentDb(String declaredType) {
  final normalized = declaredType.trim().toUpperCase();
  if (normalized.isEmpty) {
    return 'TEXT';
  }
  if (normalized.contains('BOOL')) {
    return 'BOOLEAN';
  }
  if (normalized.contains('INT')) {
    return 'INTEGER';
  }
  if (normalized.contains('UUID') ||
      normalized.contains('GUID') ||
      normalized.contains('UNIQUEIDENTIFIER') ||
      normalized.contains('CHAR(36)')) {
    return 'UUID';
  }
  if (normalized.contains('REAL') ||
      normalized.contains('FLOA') ||
      normalized.contains('DOUB')) {
    return 'FLOAT64';
  }
  if (normalized.contains('BLOB')) {
    return 'BLOB';
  }
  if (normalized.contains('DECIMAL') || normalized.contains('NUMERIC')) {
    final mapped = normalized.replaceAll('NUMERIC', 'DECIMAL');
    if (mapped.contains('(')) {
      return mapped;
    }
    return 'DECIMAL(18,6)';
  }
  if (normalized.contains('DATE') || normalized.contains('TIME')) {
    return 'TIMESTAMP';
  }
  if (normalized.contains('CHAR') ||
      normalized.contains('CLOB') ||
      normalized.contains('TEXT') ||
      normalized.contains('VARCHAR') ||
      normalized.contains('JSON')) {
    return 'TEXT';
  }
  return 'TEXT';
}

String _normalizeImportedIndexName(String sourceName) {
  return sourceName.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9_]+'),
    '_',
  );
}

String _quoteSqliteIdent(String value) {
  return '"${value.replaceAll('"', '""')}"';
}

String _quoteDecentIdent(String value) {
  return '"${value.replaceAll('"', '""')}"';
}

bool _isDecimalType(String targetType) {
  return targetType.startsWith('DECIMAL') || targetType.startsWith('NUMERIC');
}

bool _isUuidType(String targetType) {
  return targetType == 'UUID';
}

class _SqliteImportCancelled implements Exception {
  const _SqliteImportCancelled(this.summary);

  final SqliteImportSummary summary;
}

class _SqliteImportCancelledSignal implements Exception {
  const _SqliteImportCancelledSignal();
}
