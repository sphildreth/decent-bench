import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/import_target_types.dart';
import 'package:decent_bench/features/workspace/domain/sql_autocomplete.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final schema = SchemaSnapshot(
    objects: const <SchemaObjectSummary>[
      SchemaObjectSummary(
        name: 'tasks',
        kind: SchemaObjectKind.table,
        columns: <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: 'INTEGER',
            notNull: true,
            unique: true,
            primaryKey: true,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
          SchemaColumn(
            name: 'title',
            type: 'TEXT',
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
      SchemaObjectSummary(
        name: 'active_tasks',
        kind: SchemaObjectKind.view,
        columns: <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: 'ANY',
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
        ],
        ddl: 'CREATE VIEW active_tasks AS SELECT id FROM tasks;',
      ),
    ],
    indexes: const <IndexSummary>[],
    loadedAt: DateTime(2026, 3, 10),
  );
  const engine = SqlAutocompleteEngine();

  test('suggests tables and views after FROM', () {
    final result = engine.suggest(
      sql: 'SELECT * FROM ta',
      cursorOffset: 'SELECT * FROM ta'.length,
      schema: schema,
      config: AppConfig.defaults(),
    );

    expect(result.suggestions.map((item) => item.label), contains('tasks'));
    expect(
      result.suggestions.every(
        (item) => item.kind == AutocompleteSuggestionKind.object,
      ),
      isTrue,
    );
  });

  test('suggests columns after alias dot', () {
    final result = engine.suggest(
      sql: 'SELECT t. FROM tasks t',
      cursorOffset: 'SELECT t.'.length,
      schema: schema,
      config: AppConfig.defaults(),
    );

    expect(
      result.suggestions.map((item) => item.label),
      containsAll(<String>['id', 'title']),
    );
    expect(
      result.suggestions.every(
        (item) => item.kind == AutocompleteSuggestionKind.column,
      ),
      isTrue,
    );
  });

  test('suggests functions and snippets in general contexts', () {
    final config = AppConfig.defaults();
    final result = engine.suggest(
      sql: 'SELECT cou',
      cursorOffset: 'SELECT cou'.length,
      schema: schema,
      config: config,
    );

    expect(result.suggestions.map((item) => item.label), contains('COUNT'));
  });

  test('suggests native v2.5 types and spatial functions', () {
    final config = AppConfig.defaults();
    final typeResult = engine.suggest(
      sql: 'CREATE TABLE places (shape geo',
      cursorOffset: 'CREATE TABLE places (shape geo'.length,
      schema: schema,
      config: config,
    );
    final functionResult = engine.suggest(
      sql: 'SELECT st_d',
      cursorOffset: 'SELECT st_d'.length,
      schema: schema,
      config: config,
    );
    final snippetResult = engine.suggest(
      sql: 'spa',
      cursorOffset: 'spa'.length,
      schema: schema,
      config: config,
    );

    expect(
      typeResult.suggestions.map((item) => item.label),
      containsAll(<String>['GEOMETRY', 'GEOGRAPHY']),
    );
    expect(
      functionResult.suggestions.map((item) => item.label),
      containsAll(<String>['ST_DISTANCE', 'ST_DWITHIN']),
    );
    expect(
      snippetResult.suggestions.map((item) => item.detail),
      contains('snippet: Spatial Nearby Query'),
    );
  });

  test('suggests v2.8 SQL parity keywords, functions, and qualifiers', () {
    final config = AppConfig.defaults();
    final pragmaResult = engine.suggest(
      sql: 'pra',
      cursorOffset: 'pra'.length,
      schema: schema,
      config: config,
    );
    final seriesResult = engine.suggest(
      sql: 'gen',
      cursorOffset: 'gen'.length,
      schema: schema,
      config: config,
    );
    final sqliteSchemaResult = engine.suggest(
      sql: 'sqli',
      cursorOffset: 'sqli'.length,
      schema: schema,
      config: config,
    );
    final informationSchemaResult = engine.suggest(
      sql: 'info',
      cursorOffset: 'info'.length,
      schema: schema,
      config: config,
    );
    final collateBinaryResult = engine.suggest(
      sql: 'bin',
      cursorOffset: 'bin'.length,
      schema: schema,
      config: config,
    );
    final collateNoCaseResult = engine.suggest(
      sql: 'noc',
      cursorOffset: 'noc'.length,
      schema: schema,
      config: config,
    );
    final collateRtrimResult = engine.suggest(
      sql: 'rtr',
      cursorOffset: 'rtr'.length,
      schema: schema,
      config: config,
    );
    final mainQualifierResult = engine.suggest(
      sql: 'mai',
      cursorOffset: 'mai'.length,
      schema: schema,
      config: config,
    );
    final tempQualifierResult = engine.suggest(
      sql: 'tem',
      cursorOffset: 'tem'.length,
      schema: schema,
      config: config,
    );
    final dotQualifiedMainResult = engine.suggest(
      sql: 'SELECT * FROM main.',
      cursorOffset: 'SELECT * FROM main.'.length,
      schema: schema,
      config: config,
    );
    final dotQualifiedTempResult = engine.suggest(
      sql: 'SELECT * FROM temp.',
      cursorOffset: 'SELECT * FROM temp.'.length,
      schema: schema,
      config: config,
    );

    expect(
      pragmaResult.suggestions.map((item) => item.label),
      contains('PRAGMA'),
    );
    expect(
      seriesResult.suggestions.map((item) => item.label),
      contains('GENERATE_SERIES'),
    );
    expect(
      sqliteSchemaResult.suggestions.map((item) => item.label),
      contains('SQLITE_SCHEMA'),
    );
    expect(
      informationSchemaResult.suggestions.map((item) => item.label),
      contains('INFORMATION_SCHEMA'),
    );
    expect(
      collateBinaryResult.suggestions.map((item) => item.label),
      contains('BINARY'),
    );
    expect(
      collateNoCaseResult.suggestions.map((item) => item.label),
      contains('NOCASE'),
    );
    expect(
      collateRtrimResult.suggestions.map((item) => item.label),
      contains('RTRIM'),
    );
    expect(
      mainQualifierResult.suggestions.map((item) => item.detail),
      contains('snippet: Main Schema Qualifier'),
    );
    expect(
      tempQualifierResult.suggestions.map((item) => item.detail),
      contains('snippet: Temp Schema Qualifier'),
    );
    expect(
      dotQualifiedMainResult.suggestions.map((item) => item.label),
      contains('main.'),
    );
    expect(
      dotQualifiedTempResult.suggestions.map((item) => item.label),
      contains('temp.'),
    );
  });

  test('native import target types are selectable', () {
    expect(
      decentDbImportTargetTypes,
      containsAll(<String>[
        'TIMESTAMPTZ',
        'IPADDR',
        'CIDR',
        'MACADDR',
        'GEOMETRY',
        'GEOGRAPHY',
      ]),
    );
  });
}
