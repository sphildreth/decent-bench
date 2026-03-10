import 'package:decent_bench/features/workspace/domain/app_config.dart';
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
}
