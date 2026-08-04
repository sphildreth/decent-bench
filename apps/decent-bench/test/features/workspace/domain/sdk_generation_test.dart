import 'package:decent_bench/features/workspace/domain/saved_query_models.dart';
import 'package:decent_bench/features/workspace/domain/sdk_generation.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/decentdb_test_constants.dart';

void main() {
  test('builds TypeScript SDK declarations from schema and saved queries', () {
    final schema = _schema();
    final metadata = _metadata(
      fingerprint:
          '1111111111111111111111111111111111111111111111111111111111111111',
    );
    final query = SavedQuery(
      id: 'active-accounts',
      name: 'Active accounts',
      sql: 'SELECT id, status, location FROM accounts WHERE region = ?',
      createdAt: DateTime.utc(2026, 5, 19),
      updatedAt: DateTime.utc(2026, 5, 19),
      schemaFingerprint: metadata.schemaFingerprint,
      queryContract: QueryContract(
        contractVersion: 1,
        sql: 'SELECT id, status, location FROM accounts WHERE region = ?',
        statementKind: 'query',
        readOnly: true,
        schemaCookie: 1,
        tempSchemaCookie: 0,
        schemaFingerprint: metadata.schemaFingerprint,
        parameters: const <QueryParameterContract>[
          QueryParameterContract(
            position: 1,
            name: 'region',
            typeName: 'TEXT',
            nullable: false,
            source: 'parameter',
            diagnostics: <String>[],
          ),
        ],
        resultColumns: const <QueryResultColumnContract>[
          QueryResultColumnContract(
            ordinal: 0,
            name: 'id',
            typeName: 'INT64',
            nullable: false,
            source: 'table',
            sourceTable: 'accounts',
            sourceColumn: 'id',
            diagnostics: <String>[],
          ),
          QueryResultColumnContract(
            ordinal: 1,
            name: 'status',
            typeName: "ENUM('active','paused')",
            nullable: true,
            source: 'table',
            sourceTable: 'accounts',
            sourceColumn: 'status',
            diagnostics: <String>[],
          ),
          QueryResultColumnContract(
            ordinal: 2,
            name: 'location',
            typeName: 'GEOMETRY',
            nullable: true,
            source: 'table',
            sourceTable: 'accounts',
            sourceColumn: 'location',
            diagnostics: <String>[],
          ),
        ],
        diagnostics: const <String>[],
      ),
    );

    final ir = buildSdkGenerationIr(
      schema: schema,
      toolingMetadata: metadata,
      savedQueryLibrary: SavedQueryLibrary(queries: <SavedQuery>[query]),
    );
    final source = generateTypeScriptSdk(ir);

    expect(ir.tables.single.typescriptName, 'Accounts');
    expect(ir.tables.single.columns[1].enumLabels, <String>[
      'active',
      'paused',
    ]);
    expect(ir.savedQueries.single.typescriptName, 'ActiveAccounts');
    expect(ir.savedQueries.single.warnings, isEmpty);
    expect(source, contains("export const engineVersion = '$expectedDecentDbVersion';"));
    expect(source, contains('export interface AccountsRow {'));
    expect(source, contains('id: number;'));
    expect(source, contains("status?: 'active' | 'paused' | null;"));
    expect(source, contains('location?: DecentSpatialValue | null;'));
    expect(source, contains('export interface ActiveAccountsParams {'));
    expect(source, contains('region: string;'));
    expect(source, contains('export interface ActiveAccountsRow {'));
  });

  test('reports saved query drift without blocking generation', () {
    final ir = buildSdkGenerationIr(
      schema: _schema(),
      toolingMetadata: _metadata(
        fingerprint:
            '2222222222222222222222222222222222222222222222222222222222222222',
      ),
      savedQueryLibrary: SavedQueryLibrary(
        queries: <SavedQuery>[
          SavedQuery(
            id: 'stale',
            name: 'Stale query',
            sql: 'SELECT id FROM accounts',
            createdAt: DateTime.utc(2026, 5, 19),
            updatedAt: DateTime.utc(2026, 5, 19),
            schemaFingerprint:
                '1111111111111111111111111111111111111111111111111111111111111111',
          ),
        ],
      ),
    );

    expect(ir.savedQueries.single.warnings, isNotEmpty);
    expect(
      generateTypeScriptSdk(ir),
      contains('Saved query schema fingerprint differs'),
    );
  });

  test('compatibility report flags breaking schema changes', () {
    final previous = buildSdkGenerationIr(
      schema: _schema(),
      toolingMetadata: _metadata(
        fingerprint:
            '1111111111111111111111111111111111111111111111111111111111111111',
      ),
    );
    final current = buildSdkGenerationIr(
      schema: SchemaSnapshot(
        objects: const <SchemaObjectSummary>[
          SchemaObjectSummary(
            name: 'accounts',
            kind: SchemaObjectKind.table,
            columns: <SchemaColumn>[
              SchemaColumn(
                name: 'id',
                type: 'TEXT',
                notNull: true,
                unique: true,
                primaryKey: true,
                refTable: null,
                refColumn: null,
                refOnDelete: null,
                refOnUpdate: null,
              ),
            ],
          ),
        ],
        indexes: const <IndexSummary>[],
        loadedAt: DateTime.utc(2026, 5, 19),
      ),
      toolingMetadata: _metadata(
        fingerprint:
            '3333333333333333333333333333333333333333333333333333333333333333',
      ),
    );

    final report = compareSdkGenerationIr(previous: previous, current: current);

    expect(report.schemaDrifted, isTrue);
    expect(report.isBreaking, isTrue);
    expect(
      report.breakingChanges,
      contains('Column type changed: accounts.id number -> string.'),
    );
    expect(
      report.breakingChanges,
      contains('Column removed: accounts.status.'),
    );
  });
}

SchemaSnapshot _schema() {
  return SchemaSnapshot(
    objects: const <SchemaObjectSummary>[
      SchemaObjectSummary(
        name: 'accounts',
        kind: SchemaObjectKind.table,
        columns: <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: 'INT64',
            notNull: true,
            unique: true,
            primaryKey: true,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
          SchemaColumn(
            name: 'status',
            type: "ENUM('active','paused')",
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
          SchemaColumn(
            name: 'location',
            type: 'GEOMETRY',
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
        ],
      ),
    ],
    indexes: const <IndexSummary>[],
    loadedAt: DateTime.utc(2026, 5, 19),
  );
}

ToolingMetadata _metadata({required String fingerprint}) {
  return ToolingMetadata(
    metadataVersion: 1,
    engineVersion: expectedDecentDbVersion,
    databaseFormatVersion: 8,
    schemaCookie: 1,
    tempSchemaCookie: 0,
    schemaFingerprint: fingerprint,
    schemaFingerprintAlgorithm: 'sha256:decentdb-tooling-schema-v1',
    columnTypeMetadata: const <ToolingColumnTypeMetadata>[
      ToolingColumnTypeMetadata(
        tableName: 'accounts',
        columnName: 'status',
        columnType: "ENUM('active','paused')",
        typeInfo: ToolingTypeInfo(
          typeName: "ENUM('active','paused')",
          valueKind: 'enum',
          cValueTag: 10,
        ),
      ),
      ToolingColumnTypeMetadata(
        tableName: 'accounts',
        columnName: 'location',
        columnType: 'GEOMETRY',
        typeInfo: ToolingTypeInfo(
          typeName: 'GEOMETRY',
          valueKind: 'geometry',
          cValueTag: 9,
          spatial: ToolingSpatialTypeInfo(
            subtype: 'POINT',
            dimensions: 'XY',
            srid: 4326,
          ),
        ),
      ),
    ],
    capabilities: const ToolingCapabilities(
      queryContractVersion: 1,
      queryDescribe: true,
      deterministicJson: true,
    ),
  );
}
