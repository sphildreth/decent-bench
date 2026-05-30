import 'workspace_model_helpers.dart';
import 'native_type_models.dart';

class QueryParameterContract {
  const QueryParameterContract({
    required this.position,
    required this.name,
    this.typeName,
    this.nullable,
    required this.source,
    this.sourceTable,
    this.sourceColumn,
    required this.diagnostics,
  });

  final int position;
  final String name;
  final String? typeName;
  final bool? nullable;
  final String source;
  final String? sourceTable;
  final String? sourceColumn;
  final List<String> diagnostics;

  factory QueryParameterContract.fromMap(Map<String, Object?> map) {
    return QueryParameterContract(
      position: asInt(map['position']) ?? 0,
      name: map['name'] as String? ?? '',
      typeName: map['type_name'] as String?,
      nullable: map['nullable'] as bool?,
      source: map['source'] as String? ?? 'unknown',
      sourceTable: map['source_table'] as String?,
      sourceColumn: map['source_column'] as String?,
      diagnostics: asStringList(map['diagnostics']),
    );
  }

  String get displayType =>
      typeName?.trim().isNotEmpty == true ? typeName!.trim() : 'UNKNOWN';

  NativeTypeDescriptor get nativeTypeDescriptor =>
      describeNativeType(typeName: typeName);

  String get sourceLabel {
    if (sourceTable != null && sourceColumn != null) {
      return '$sourceTable.$sourceColumn';
    }
    if (sourceColumn != null) {
      return sourceColumn!;
    }
    return source;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'position': position,
      'name': name,
      'type_name': typeName,
      'nullable': nullable,
      'source': source,
      'source_table': sourceTable,
      'source_column': sourceColumn,
      'diagnostics': diagnostics,
    };
  }
}

class QueryResultColumnContract {
  const QueryResultColumnContract({
    required this.ordinal,
    required this.name,
    this.typeName,
    this.nullable,
    required this.source,
    this.sourceTable,
    this.sourceColumn,
    this.expressionSql,
    required this.diagnostics,
  });

  final int ordinal;
  final String name;
  final String? typeName;
  final bool? nullable;
  final String source;
  final String? sourceTable;
  final String? sourceColumn;
  final String? expressionSql;
  final List<String> diagnostics;

  factory QueryResultColumnContract.fromMap(Map<String, Object?> map) {
    return QueryResultColumnContract(
      ordinal: asInt(map['ordinal']) ?? 0,
      name: map['name'] as String? ?? '',
      typeName: map['type_name'] as String?,
      nullable: map['nullable'] as bool?,
      source: map['source'] as String? ?? 'unknown',
      sourceTable: map['source_table'] as String?,
      sourceColumn: map['source_column'] as String?,
      expressionSql: map['expression_sql'] as String?,
      diagnostics: asStringList(map['diagnostics']),
    );
  }

  String get displayType =>
      typeName?.trim().isNotEmpty == true ? typeName!.trim() : 'UNKNOWN';

  NativeTypeDescriptor get nativeTypeDescriptor =>
      describeNativeType(typeName: typeName);

  String get nullabilityLabel {
    return switch (nullable) {
      true => 'nullable',
      false => 'not null',
      null => 'nullability unknown',
    };
  }

  String get sourceLabel {
    if (sourceTable != null && sourceColumn != null) {
      return '$sourceTable.$sourceColumn';
    }
    if (sourceColumn != null) {
      return sourceColumn!;
    }
    return source;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ordinal': ordinal,
      'name': name,
      'type_name': typeName,
      'nullable': nullable,
      'source': source,
      'source_table': sourceTable,
      'source_column': sourceColumn,
      'expression_sql': expressionSql,
      'diagnostics': diagnostics,
    };
  }
}

class QueryContract {
  const QueryContract({
    required this.contractVersion,
    required this.sql,
    required this.statementKind,
    required this.readOnly,
    required this.schemaCookie,
    required this.tempSchemaCookie,
    required this.schemaFingerprint,
    required this.parameters,
    required this.resultColumns,
    required this.diagnostics,
  });

  final int contractVersion;
  final String sql;
  final String statementKind;
  final bool readOnly;
  final int schemaCookie;
  final int tempSchemaCookie;
  final String schemaFingerprint;
  final List<QueryParameterContract> parameters;
  final List<QueryResultColumnContract> resultColumns;
  final List<String> diagnostics;

  factory QueryContract.fromMap(Map<String, Object?> map) {
    final parameters =
        asMapList(
            map['parameters'],
          ).map(QueryParameterContract.fromMap).toList()
          ..sort((left, right) => left.position.compareTo(right.position));
    final resultColumns =
        asMapList(
            map['result_columns'],
          ).map(QueryResultColumnContract.fromMap).toList()
          ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
    return QueryContract(
      contractVersion: asInt(map['contract_version']) ?? 0,
      sql: map['sql'] as String? ?? '',
      statementKind: map['statement_kind'] as String? ?? 'unknown',
      readOnly: map['read_only'] as bool? ?? false,
      schemaCookie: asInt(map['schema_cookie']) ?? 0,
      tempSchemaCookie: asInt(map['temp_schema_cookie']) ?? 0,
      schemaFingerprint: map['schema_fingerprint'] as String? ?? '',
      parameters: parameters,
      resultColumns: resultColumns,
      diagnostics: asStringList(map['diagnostics']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'contract_version': contractVersion,
      'sql': sql,
      'statement_kind': statementKind,
      'read_only': readOnly,
      'schema_cookie': schemaCookie,
      'temp_schema_cookie': tempSchemaCookie,
      'schema_fingerprint': schemaFingerprint,
      'parameters': <Map<String, Object?>>[
        for (final parameter in parameters) parameter.toJson(),
      ],
      'result_columns': <Map<String, Object?>>[
        for (final column in resultColumns) column.toJson(),
      ],
      'diagnostics': diagnostics,
    };
  }
}
