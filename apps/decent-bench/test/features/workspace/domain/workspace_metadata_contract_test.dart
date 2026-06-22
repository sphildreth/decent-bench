import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolingMetadata', () {
    test('decodes deterministic column metadata and spatial type details', () {
      final metadata = ToolingMetadata.fromMap(<String, Object?>{
        'metadata_version': 1,
        'engine_version': '2.14.0',
        'database_format_version': 8,
        'schema_cookie': 4,
        'temp_schema_cookie': 0,
        'schema_fingerprint': List<String>.filled(64, 'f').join(),
        'schema_fingerprint_algorithm': 'sha256:decentdb-tooling-schema-v1',
        'column_type_metadata': <Map<String, Object?>>[
          <String, Object?>{
            'table_name': 'sites',
            'column_name': 'name',
            'column_type': 'TEXT',
            'type_info': <String, Object?>{
              'type_name': 'TEXT',
              'value_kind': 'text',
              'c_value_tag': 4,
            },
          },
          <String, Object?>{
            'table_name': 'sites',
            'column_name': 'location',
            'column_type': 'GEOGRAPHY',
            'type_info': <String, Object?>{
              'type_name': 'GEOGRAPHY',
              'value_kind': 'geography_ewkb',
              'c_value_tag': 10,
              'spatial': <String, Object?>{
                'subtype': 'POINT',
                'dimensions': 'XY',
                'srid': 4326,
              },
            },
          },
        ],
        'capabilities': <String, Object?>{
          'query_contract_version': 1,
          'query_describe': true,
          'deterministic_json': true,
        },
      });

      expect(metadata.metadataVersion, 1);
      expect(metadata.schemaFingerprint, hasLength(64));
      expect(metadata.capabilities.queryDescribe, isTrue);
      expect(metadata.columnTypeMetadata.first.columnName, 'location');
      expect(
        metadata
            .columnTypeFor(tableName: 'sites', columnName: 'location')
            ?.typeInfo
            .spatial
            ?.srid,
        4326,
      );
      final descriptor = metadata
          .columnTypeFor(tableName: 'sites', columnName: 'location')!
          .nativeTypeDescriptor;
      expect(descriptor.family, NativeTypeFamily.spatial);
      expect(descriptor.summaryLabel, contains('SRID 4326'));
    });

    test('describes native semantic families and formats typed values', () {
      final enumDescriptor = describeNativeType(
        typeName: "ENUM('draft','published')",
      );

      expect(enumDescriptor.family, NativeTypeFamily.enumValue);
      expect(enumDescriptor.enumLabelForId(2), 'published');
      expect(
        formatTypedCellValue(
          const NativeEnumCellValue(typeId: 9, labelId: 2),
          typeName: "ENUM('draft','published')",
        ),
        'published (type 9, label 2)',
      );
      expect(
        formatTypedCellValue(
          const NativeIntervalCellValue(months: 1, days: 2, microseconds: 3),
          typeName: 'INTERVAL',
        ),
        '1mo 2d 00:00:00.000003',
      );
      expect(
        formatTypedCellValue(
          Duration(hours: 9, minutes: 30, seconds: 1, microseconds: 25),
          typeName: 'TIME',
        ),
        '09:30:01.000025',
      );
    });
  });

  group('QueryContract', () {
    test('decodes parameters and result columns in stable ordinal order', () {
      final contract = QueryContract.fromMap(<String, Object?>{
        'contract_version': 1,
        'sql': 'SELECT id, email FROM users WHERE id = \$1',
        'statement_kind': 'query',
        'read_only': true,
        'schema_cookie': 7,
        'temp_schema_cookie': 0,
        'schema_fingerprint': List<String>.filled(64, 'a').join(),
        'parameters': <Map<String, Object?>>[
          <String, Object?>{
            'position': 2,
            'name': r'$2',
            'type_name': 'TEXT',
            'nullable': true,
            'source': 'catalog_column',
            'source_table': 'users',
            'source_column': 'email',
            'diagnostics': <String>[],
          },
          <String, Object?>{
            'position': 1,
            'name': r'$1',
            'type_name': 'INT64',
            'nullable': false,
            'source': 'catalog_column',
            'source_table': 'users',
            'source_column': 'id',
            'diagnostics': <String>[],
          },
        ],
        'result_columns': <Map<String, Object?>>[
          <String, Object?>{
            'ordinal': 1,
            'name': 'email',
            'type_name': 'TEXT',
            'nullable': false,
            'source': 'catalog_column',
            'source_table': 'users',
            'source_column': 'email',
            'diagnostics': <String>[],
          },
          <String, Object?>{
            'ordinal': 0,
            'name': 'id',
            'type_name': 'INT64',
            'nullable': false,
            'source': 'catalog_column',
            'source_table': 'users',
            'source_column': 'id',
            'diagnostics': <String>[],
          },
        ],
        'diagnostics': <String>['inferred from catalog'],
      });

      expect(contract.parameters.map((parameter) => parameter.name), <String>[
        r'$1',
        r'$2',
      ]);
      expect(contract.resultColumns.map((column) => column.name), <String>[
        'id',
        'email',
      ]);
      expect(contract.parameters.first.sourceLabel, 'users.id');
      expect(contract.resultColumns.first.nullabilityLabel, 'not null');
      expect(contract.diagnostics.single, 'inferred from catalog');
    });

    test('uses safe defaults for partial forward-compatible payloads', () {
      final contract = QueryContract.fromMap(const <String, Object?>{
        'result_columns': <Map<String, Object?>>[
          <String, Object?>{'name': 'expr'},
        ],
      });

      expect(contract.contractVersion, 0);
      expect(contract.statementKind, 'unknown');
      expect(contract.resultColumns.single.displayType, 'UNKNOWN');
      expect(contract.resultColumns.single.source, 'unknown');
    });
  });
}
