import 'workspace_model_helpers.dart';
import 'native_type_models.dart';

class ToolingCapabilities {
  const ToolingCapabilities({
    required this.queryContractVersion,
    required this.queryDescribe,
    required this.deterministicJson,
  });

  final int queryContractVersion;
  final bool queryDescribe;
  final bool deterministicJson;

  factory ToolingCapabilities.fromMap(Map<String, Object?> map) {
    return ToolingCapabilities(
      queryContractVersion: asInt(map['query_contract_version']) ?? 0,
      queryDescribe: map['query_describe'] as bool? ?? false,
      deterministicJson: map['deterministic_json'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'query_contract_version': queryContractVersion,
      'query_describe': queryDescribe,
      'deterministic_json': deterministicJson,
    };
  }
}

class ToolingTypeInfo {
  const ToolingTypeInfo({
    required this.typeName,
    required this.valueKind,
    required this.cValueTag,
    this.spatial,
  });

  final String typeName;
  final String valueKind;
  final int cValueTag;
  final ToolingSpatialTypeInfo? spatial;

  NativeTypeDescriptor get nativeTypeDescriptor => describeNativeType(
    typeName: typeName,
    valueKind: valueKind,
    spatial: spatial,
  );

  factory ToolingTypeInfo.fromMap(Map<String, Object?> map) {
    final spatialMap = asStringMap(map['spatial']);
    return ToolingTypeInfo(
      typeName: map['type_name'] as String? ?? '',
      valueKind: map['value_kind'] as String? ?? '',
      cValueTag: asInt(map['c_value_tag']) ?? 0,
      spatial: spatialMap == null
          ? null
          : ToolingSpatialTypeInfo.fromMap(spatialMap),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type_name': typeName,
      'value_kind': valueKind,
      'c_value_tag': cValueTag,
      'spatial': spatial?.toJson(),
    };
  }
}

class ToolingColumnTypeMetadata {
  const ToolingColumnTypeMetadata({
    required this.tableName,
    required this.columnName,
    required this.columnType,
    required this.typeInfo,
  });

  final String tableName;
  final String columnName;
  final String columnType;
  final ToolingTypeInfo typeInfo;

  NativeTypeDescriptor get nativeTypeDescriptor {
    final type = columnType.trim().isNotEmpty ? columnType : typeInfo.typeName;
    return describeNativeType(
      typeName: type,
      valueKind: typeInfo.valueKind,
      spatial: typeInfo.spatial,
    );
  }

  factory ToolingColumnTypeMetadata.fromMap(Map<String, Object?> map) {
    return ToolingColumnTypeMetadata(
      tableName: map['table_name'] as String? ?? '',
      columnName: map['column_name'] as String? ?? '',
      columnType: map['column_type'] as String? ?? '',
      typeInfo: ToolingTypeInfo.fromMap(
        asStringMap(map['type_info']) ?? const <String, Object?>{},
      ),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'table_name': tableName,
      'column_name': columnName,
      'column_type': columnType,
      'type_info': typeInfo.toJson(),
    };
  }
}

class ToolingMetadata {
  const ToolingMetadata({
    required this.metadataVersion,
    required this.engineVersion,
    required this.databaseFormatVersion,
    required this.schemaCookie,
    required this.tempSchemaCookie,
    required this.schemaFingerprint,
    required this.schemaFingerprintAlgorithm,
    required this.columnTypeMetadata,
    required this.capabilities,
  });

  final int metadataVersion;
  final String engineVersion;
  final int databaseFormatVersion;
  final int schemaCookie;
  final int tempSchemaCookie;
  final String schemaFingerprint;
  final String schemaFingerprintAlgorithm;
  final List<ToolingColumnTypeMetadata> columnTypeMetadata;
  final ToolingCapabilities capabilities;

  factory ToolingMetadata.fromMap(Map<String, Object?> map) {
    final columns =
        asMapList(
          map['column_type_metadata'],
        ).map(ToolingColumnTypeMetadata.fromMap).toList()..sort((left, right) {
          final byTable = left.tableName.compareTo(right.tableName);
          return byTable != 0
              ? byTable
              : left.columnName.compareTo(right.columnName);
        });
    return ToolingMetadata(
      metadataVersion: asInt(map['metadata_version']) ?? 0,
      engineVersion: map['engine_version'] as String? ?? '',
      databaseFormatVersion: asInt(map['database_format_version']) ?? 0,
      schemaCookie: asInt(map['schema_cookie']) ?? 0,
      tempSchemaCookie: asInt(map['temp_schema_cookie']) ?? 0,
      schemaFingerprint: map['schema_fingerprint'] as String? ?? '',
      schemaFingerprintAlgorithm:
          map['schema_fingerprint_algorithm'] as String? ?? '',
      columnTypeMetadata: columns,
      capabilities: ToolingCapabilities.fromMap(
        asStringMap(map['capabilities']) ?? const <String, Object?>{},
      ),
    );
  }

  ToolingColumnTypeMetadata? columnTypeFor({
    required String tableName,
    required String columnName,
  }) {
    for (final column in columnTypeMetadata) {
      if (column.tableName == tableName && column.columnName == columnName) {
        return column;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'metadata_version': metadataVersion,
      'engine_version': engineVersion,
      'database_format_version': databaseFormatVersion,
      'schema_cookie': schemaCookie,
      'temp_schema_cookie': tempSchemaCookie,
      'schema_fingerprint': schemaFingerprint,
      'schema_fingerprint_algorithm': schemaFingerprintAlgorithm,
      'column_type_metadata': <Map<String, Object?>>[
        for (final column in columnTypeMetadata) column.toJson(),
      ],
      'capabilities': capabilities.toJson(),
    };
  }
}
