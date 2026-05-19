import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/domain/import_transform_application.dart';
import 'package:decent_bench/features/import/domain/import_transforms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyImportTransformPlan', () {
    test('filters, defaults, computes, deduplicates, and reorders rows', () {
      final source = MaterializedImportTableData(
        sourceId: 'people',
        sourceName: 'People',
        suggestedTargetName: 'people',
        rows: const <Map<String, Object?>>[
          <String, Object?>{
            'first': 'Ada',
            'last': 'Lovelace',
            'status': null,
            'score': '10',
          },
          <String, Object?>{
            'first': 'Ada',
            'last': 'Lovelace',
            'status': 'drop',
            'score': '5',
          },
          <String, Object?>{
            'first': 'Grace',
            'last': 'Hopper',
            'status': 'keep',
            'score': '7',
          },
          <String, Object?>{
            'first': 'Grace',
            'last': 'Hopper',
            'status': 'keep',
            'score': '8',
          },
        ],
      );
      final draft = _draft(
        transformPlan: ImportTransformPlan(
          rowFilters: const <ImportRowFilterTransform>[
            ImportRowFilterTransform(
              columnName: 'status',
              operator: ImportRowFilterOperator.notEquals,
              value: 'drop',
            ),
          ],
          defaultValues: const <ImportDefaultValueTransform>[
            ImportDefaultValueTransform(columnName: 'status', value: 'keep'),
          ],
          computedColumns: const <ImportComputedColumnTransform>[
            ImportComputedColumnTransform(
              columnName: 'full_name',
              targetType: 'TEXT',
              expression: ImportExpression.call('concat', <ImportExpression>[
                ImportExpression.column('first'),
                ImportExpression.literal(' '),
                ImportExpression.column('last'),
              ]),
            ),
            ImportComputedColumnTransform(
              columnName: 'double_score',
              targetType: 'INTEGER',
              expression: ImportExpression.call('multiply', <ImportExpression>[
                ImportExpression.call('to_integer', <ImportExpression>[
                  ImportExpression.column('score'),
                ]),
                ImportExpression.literal(2),
              ]),
            ),
          ],
          deduplication: const ImportDeduplicationTransform(
            keyColumns: <String>['first', 'last'],
            keep: ImportDeduplicationKeep.last,
          ),
          columnOrder: const <String>[
            'full_name',
            'score',
            'double_score',
            'status',
          ],
        ),
      );

      final result = applyImportTransformPlan(source: source, draft: draft);

      expect(
        result.columns.map((column) => column.targetName).take(4),
        <String>['full_name', 'score', 'double_score', 'status'],
      );
      expect(result.rows, hasLength(2));
      expect(result.rows.first['full_name'], 'Ada Lovelace');
      expect(result.rows.first['status'], 'keep');
      expect(result.rows.first['double_score'], 20);
      expect(result.rows.last['full_name'], 'Grace Hopper');
      expect(result.rows.last['score'], '8');
      expect(result.rows.last['double_score'], 16);
      expect(
        result.warnings,
        containsAll(<String>[
          'people: filtered 1 row.',
          'people: deduplicated 1 row by first, last.',
        ]),
      );
    });

    test('records row-local computed expression warnings', () {
      final source = MaterializedImportTableData(
        sourceId: 'metrics',
        sourceName: 'Metrics',
        suggestedTargetName: 'metrics',
        rows: const <Map<String, Object?>>[
          <String, Object?>{'value': 'not-a-number', 'divisor': 0},
        ],
      );

      final result = applyImportTransformPlan(
        source: source,
        draft: _metricsDraft(
          transformPlan: const ImportTransformPlan(
            computedColumns: <ImportComputedColumnTransform>[
              ImportComputedColumnTransform(
                columnName: 'as_int',
                targetType: 'INTEGER',
                expression: ImportExpression.call(
                  'to_integer',
                  <ImportExpression>[ImportExpression.column('value')],
                ),
              ),
              ImportComputedColumnTransform(
                columnName: 'ratio',
                targetType: 'REAL',
                expression: ImportExpression.call('divide', <ImportExpression>[
                  ImportExpression.literal(10),
                  ImportExpression.column('divisor'),
                ]),
              ),
            ],
          ),
        ),
      );

      expect(result.rows.single['as_int'], isNull);
      expect(result.rows.single['ratio'], isNull);
      expect(
        result.warnings,
        containsAll(<String>[
          'metrics.as_int: could not convert `not-a-number` to integer',
          'metrics.ratio: division by zero',
        ]),
      );
    });

    test('serializes table transform plans through import draft maps', () {
      final draft = _draft(
        transformPlan: const ImportTransformPlan(
          rowFilters: <ImportRowFilterTransform>[
            ImportRowFilterTransform(
              columnName: 'status',
              operator: ImportRowFilterOperator.equals,
              value: 'active',
            ),
          ],
          deduplication: ImportDeduplicationTransform(
            keyColumns: <String>['id'],
          ),
        ),
      );

      final restored = ImportTableDraft.fromMap(draft.toMap());

      expect(restored.transformPlan.rowFilters.single.columnName, 'status');
      expect(restored.transformPlan.rowFilters.single.value, 'active');
      expect(restored.transformPlan.deduplication!.keyColumns, <String>['id']);
    });
  });
}

ImportTableDraft _draft({
  ImportTransformPlan transformPlan = const ImportTransformPlan(),
}) {
  return ImportTableDraft(
    sourceId: 'people',
    sourceName: 'People',
    targetName: 'people',
    selected: true,
    rowCount: 4,
    columns: const <ImportColumnDraft>[
      ImportColumnDraft(
        sourceName: 'first',
        targetName: 'first',
        inferredTargetType: 'TEXT',
        targetType: 'TEXT',
        containsNulls: false,
      ),
      ImportColumnDraft(
        sourceName: 'last',
        targetName: 'last',
        inferredTargetType: 'TEXT',
        targetType: 'TEXT',
        containsNulls: false,
      ),
      ImportColumnDraft(
        sourceName: 'status',
        targetName: 'status',
        inferredTargetType: 'TEXT',
        targetType: 'TEXT',
        containsNulls: true,
      ),
      ImportColumnDraft(
        sourceName: 'score',
        targetName: 'score',
        inferredTargetType: 'TEXT',
        targetType: 'TEXT',
        containsNulls: false,
      ),
    ],
    previewRows: const <Map<String, Object?>>[],
    transformPlan: transformPlan,
  );
}

ImportTableDraft _metricsDraft({
  ImportTransformPlan transformPlan = const ImportTransformPlan(),
}) {
  return ImportTableDraft(
    sourceId: 'metrics',
    sourceName: 'Metrics',
    targetName: 'metrics',
    selected: true,
    rowCount: 1,
    columns: const <ImportColumnDraft>[
      ImportColumnDraft(
        sourceName: 'value',
        targetName: 'value',
        inferredTargetType: 'TEXT',
        targetType: 'TEXT',
        containsNulls: false,
      ),
      ImportColumnDraft(
        sourceName: 'divisor',
        targetName: 'divisor',
        inferredTargetType: 'INTEGER',
        targetType: 'INTEGER',
        containsNulls: false,
      ),
    ],
    previewRows: const <Map<String, Object?>>[],
    transformPlan: transformPlan,
  );
}
