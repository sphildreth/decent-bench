import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import_modules/domain/import_typed_batch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts current import table drafts to typed schemas', () {
    final table = ImportTableDraft(
      sourceId: 'people',
      sourceName: 'People',
      targetName: 'people',
      selected: true,
      rowCount: 2,
      columns: const <ImportColumnDraft>[
        ImportColumnDraft(
          sourceName: 'id',
          targetName: 'id',
          inferredTargetType: 'INTEGER',
          targetType: 'INTEGER',
          containsNulls: false,
        ),
        ImportColumnDraft(
          sourceName: 'name',
          targetName: 'name',
          inferredTargetType: 'TEXT',
          targetType: 'TEXT',
          containsNulls: true,
        ),
      ],
      previewRows: const <Map<String, Object?>>[],
    );

    final schema = ImportTypedSchema.fromImportTables(<ImportTableDraft>[
      table,
    ]);

    expect(schema.tables.single.targetName, 'people');
    expect(schema.tables.single.columns.first.targetType, 'INTEGER');
    expect(schema.tables.single.columns.last.nullable, isTrue);
    expect(schema.toMap()['tables'], isA<List<Map<String, Object?>>>());
  });

  test('converts materialized row maps to typed batches in column order', () {
    final table = ImportTableDraft(
      sourceId: 'people',
      sourceName: 'People',
      targetName: 'people',
      selected: true,
      rowCount: 2,
      columns: const <ImportColumnDraft>[
        ImportColumnDraft(
          sourceName: 'id',
          targetName: 'id',
          inferredTargetType: 'INTEGER',
          targetType: 'INTEGER',
          containsNulls: false,
        ),
        ImportColumnDraft(
          sourceName: 'name',
          targetName: 'name',
          inferredTargetType: 'TEXT',
          targetType: 'TEXT',
          containsNulls: false,
        ),
      ],
      previewRows: const <Map<String, Object?>>[],
    );

    final batch = ImportTypedBatch.fromMaterializedTable(
      table: table,
      rows: const <Map<String, Object?>>[
        <String, Object?>{'name': 'Ada', 'id': 1},
        <String, Object?>{'name': 'Lin', 'id': 2},
      ],
    );

    expect(batch.tableTargetName, 'people');
    expect(batch.rows, <List<Object?>>[
      <Object?>[1, 'Ada'],
      <Object?>[2, 'Lin'],
    ]);
    expect(batch.toMap()['warnings'], isA<List<Map<String, Object?>>>());
  });
}
