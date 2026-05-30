import 'package:decent_bench/features/import/domain/import_models.dart';

class ImportTypedSchema {
  const ImportTypedSchema({required this.tables});

  final List<ImportTypedTable> tables;

  factory ImportTypedSchema.fromImportTables(List<ImportTableDraft> tables) {
    return ImportTypedSchema(
      tables: <ImportTypedTable>[
        for (final table in tables) ImportTypedTable.fromImportTable(table),
      ],
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'tables': <Map<String, Object?>>[
        for (final table in tables) table.toMap(),
      ],
    };
  }
}

class ImportTypedTable {
  const ImportTypedTable({
    required this.sourceName,
    required this.targetName,
    required this.columns,
    this.sourceMetadata = const <String, Object?>{},
  });

  final String sourceName;
  final String targetName;
  final List<ImportTypedColumn> columns;
  final Map<String, Object?> sourceMetadata;

  factory ImportTypedTable.fromImportTable(ImportTableDraft table) {
    return ImportTypedTable(
      sourceName: table.sourceName,
      targetName: table.targetName,
      columns: <ImportTypedColumn>[
        for (final column in table.columns)
          ImportTypedColumn.fromImportColumn(column),
      ],
      sourceMetadata: <String, Object?>{
        'sourceId': table.sourceId,
        'rowCount': table.rowCount,
        if (table.description != null) 'description': table.description,
      },
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'sourceName': sourceName,
      'targetName': targetName,
      'columns': <Map<String, Object?>>[
        for (final column in columns) column.toMap(),
      ],
      'sourceMetadata': sourceMetadata,
    };
  }
}

class ImportTypedColumn {
  const ImportTypedColumn({
    required this.sourceName,
    required this.targetName,
    required this.targetType,
    this.sourcePhysicalType,
    this.sourceLogicalType,
    this.nullable = true,
    this.precision,
    this.scale,
    this.timezone,
    this.encoding,
    this.metadata = const <String, Object?>{},
  });

  final String sourceName;
  final String targetName;
  final String targetType;
  final String? sourcePhysicalType;
  final String? sourceLogicalType;
  final bool nullable;
  final int? precision;
  final int? scale;
  final String? timezone;
  final String? encoding;
  final Map<String, Object?> metadata;

  factory ImportTypedColumn.fromImportColumn(ImportColumnDraft column) {
    return ImportTypedColumn(
      sourceName: column.sourceName,
      targetName: column.targetName,
      sourcePhysicalType: column.inferredTargetType,
      sourceLogicalType: column.inferredTargetType,
      targetType: column.targetType,
      nullable: column.containsNulls,
      metadata: <String, Object?>{'compatibilityPath': 'generic_import_draft'},
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'sourceName': sourceName,
      'targetName': targetName,
      'targetType': targetType,
      'sourcePhysicalType': sourcePhysicalType,
      'sourceLogicalType': sourceLogicalType,
      'nullable': nullable,
      'precision': precision,
      'scale': scale,
      'timezone': timezone,
      'encoding': encoding,
      'metadata': metadata,
    };
  }
}

class ImportTypedBatch {
  const ImportTypedBatch({
    required this.tableTargetName,
    required this.columns,
    required this.rows,
    this.warnings = const <ImportTypedCellWarning>[],
  });

  final String tableTargetName;
  final List<ImportTypedColumn> columns;
  final List<List<Object?>> rows;
  final List<ImportTypedCellWarning> warnings;

  factory ImportTypedBatch.fromMaterializedTable({
    required ImportTableDraft table,
    required List<Map<String, Object?>> rows,
  }) {
    final columns = <ImportTypedColumn>[
      for (final column in table.columns)
        ImportTypedColumn.fromImportColumn(column),
    ];
    return ImportTypedBatch(
      tableTargetName: table.targetName,
      columns: columns,
      rows: <List<Object?>>[
        for (final row in rows)
          <Object?>[for (final column in table.columns) row[column.sourceName]],
      ],
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'tableTargetName': tableTargetName,
      'columns': <Map<String, Object?>>[
        for (final column in columns) column.toMap(),
      ],
      'rows': rows,
      'warnings': <Map<String, Object?>>[
        for (final warning in warnings) warning.toMap(),
      ],
    };
  }
}

class ImportTypedCellWarning {
  const ImportTypedCellWarning({
    required this.rowIndex,
    required this.columnTargetName,
    required this.code,
    required this.message,
  });

  final int rowIndex;
  final String columnTargetName;
  final String code;
  final String message;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'rowIndex': rowIndex,
      'columnTargetName': columnTargetName,
      'code': code,
      'message': message,
    };
  }
}
