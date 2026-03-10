import 'dart:convert';
import 'dart:typed_data';

enum QueryPhase {
  idle,
  opening,
  running,
  fetching,
  cancelling,
  completed,
  cancelled,
  failed,
}

enum SchemaObjectKind { table, view }

class BridgeFailure implements Exception {
  final String message;
  final String? code;

  const BridgeFailure(this.message, {this.code});

  @override
  String toString() => code == null ? message : '$code: $message';
}

class DatabaseSession {
  final String path;
  final String engineVersion;

  const DatabaseSession({required this.path, required this.engineVersion});

  factory DatabaseSession.fromMap(Map<String, Object?> map) {
    return DatabaseSession(
      path: map['path']! as String,
      engineVersion: map['engineVersion']! as String,
    );
  }
}

class SchemaColumn {
  final String name;
  final String type;
  final bool notNull;
  final bool unique;
  final bool primaryKey;
  final String? refTable;
  final String? refColumn;

  const SchemaColumn({
    required this.name,
    required this.type,
    required this.notNull,
    required this.unique,
    required this.primaryKey,
    required this.refTable,
    required this.refColumn,
  });

  factory SchemaColumn.fromMap(Map<String, Object?> map) {
    return SchemaColumn(
      name: map['name']! as String,
      type: map['type']! as String,
      notNull: map['notNull']! as bool,
      unique: map['unique']! as bool,
      primaryKey: map['primaryKey']! as bool,
      refTable: map['refTable'] as String?,
      refColumn: map['refColumn'] as String?,
    );
  }

  String get descriptor {
    final flags = <String>[
      if (primaryKey) 'PK',
      if (unique) 'UNIQUE',
      if (notNull) 'NOT NULL',
      if (refTable != null && refColumn != null) 'FK->$refTable.$refColumn',
    ];
    return flags.isEmpty ? type : '$type | ${flags.join(" | ")}';
  }
}

class SchemaObjectSummary {
  final String name;
  final SchemaObjectKind kind;
  final String? ddl;
  final List<SchemaColumn> columns;

  const SchemaObjectSummary({
    required this.name,
    required this.kind,
    required this.columns,
    this.ddl,
  });

  factory SchemaObjectSummary.fromMap(Map<String, Object?> map) {
    return SchemaObjectSummary(
      name: map['name']! as String,
      kind: (map['kind'] as String) == 'view'
          ? SchemaObjectKind.view
          : SchemaObjectKind.table,
      ddl: map['ddl'] as String?,
      columns: ((map['columns'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (column) => SchemaColumn.fromMap(
              column.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
    );
  }
}

class IndexSummary {
  final String name;
  final String table;
  final List<String> columns;
  final bool unique;
  final String kind;

  const IndexSummary({
    required this.name,
    required this.table,
    required this.columns,
    required this.unique,
    required this.kind,
  });

  factory IndexSummary.fromMap(Map<String, Object?> map) {
    return IndexSummary(
      name: map['name']! as String,
      table: map['table']! as String,
      columns: ((map['columns'] as List?) ?? const <Object?>[]).cast<String>(),
      unique: map['unique']! as bool,
      kind: map['kind']! as String,
    );
  }
}

class SchemaSnapshot {
  final List<SchemaObjectSummary> objects;
  final List<IndexSummary> indexes;
  final DateTime loadedAt;

  const SchemaSnapshot({
    required this.objects,
    required this.indexes,
    required this.loadedAt,
  });

  factory SchemaSnapshot.empty() {
    return SchemaSnapshot(
      objects: const <SchemaObjectSummary>[],
      indexes: const <IndexSummary>[],
      loadedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory SchemaSnapshot.fromMap(Map<String, Object?> map) {
    return SchemaSnapshot(
      objects: ((map['objects'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (item) => SchemaObjectSummary.fromMap(
              item.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
      indexes: ((map['indexes'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (item) => IndexSummary.fromMap(
              item.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
      loadedAt: DateTime.parse(map['loadedAt']! as String),
    );
  }

  List<SchemaObjectSummary> get tables =>
      objects.where((item) => item.kind == SchemaObjectKind.table).toList();

  List<SchemaObjectSummary> get views =>
      objects.where((item) => item.kind == SchemaObjectKind.view).toList();
}

class QueryResultPage {
  final String? cursorId;
  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final bool done;
  final int? rowsAffected;
  final Duration elapsed;

  const QueryResultPage({
    required this.cursorId,
    required this.columns,
    required this.rows,
    required this.done,
    required this.rowsAffected,
    required this.elapsed,
  });

  factory QueryResultPage.fromMap(Map<String, Object?> map) {
    return QueryResultPage(
      cursorId: map['cursorId'] as String?,
      columns: ((map['columns'] as List?) ?? const <Object?>[]).cast<String>(),
      rows: ((map['rows'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (row) => row.map(
              (key, value) => MapEntry(key as String, _decodeCell(value)),
            ),
          )
          .toList(),
      done: map['done']! as bool,
      rowsAffected: map['rowsAffected'] as int?,
      elapsed: Duration(microseconds: map['elapsedMicros']! as int),
    );
  }

  static Object? _decodeCell(Object? value) {
    if (value is Map && value['kind'] == 'decimal') {
      final unscaled = value['unscaled'] as int;
      final scale = value['scale'] as int;
      return formatDecimalValue(unscaled, scale);
    }
    if (value is Map && value['kind'] == 'blob') {
      return base64Decode(value['base64']! as String);
    }
    if (value is Map && value['kind'] == 'datetime') {
      return DateTime.parse(value['iso8601']! as String);
    }
    return value;
  }
}

class CsvExportResult {
  final int rowCount;
  final String path;

  const CsvExportResult({required this.rowCount, required this.path});

  factory CsvExportResult.fromMap(Map<String, Object?> map) {
    return CsvExportResult(
      rowCount: map['rowCount']! as int,
      path: map['path']! as String,
    );
  }
}

String formatCellValue(Object? value) {
  if (value == null) {
    return 'NULL';
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Uint8List) {
    return base64Encode(value);
  }
  return '$value';
}

String formatDecimalValue(int unscaled, int scale) {
  if (scale == 0) {
    return '$unscaled';
  }

  final negative = unscaled < 0;
  final digits = unscaled.abs().toString().padLeft(scale + 1, '0');
  final split = digits.length - scale;
  final whole = digits.substring(0, split);
  final fraction = digits.substring(split);
  return '${negative ? "-" : ""}$whole.$fraction';
}
