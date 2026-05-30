import 'import_models.dart';
import 'import_transforms.dart';

class TransformedImportTable {
  const TransformedImportTable({
    required this.columns,
    required this.rows,
    required this.warnings,
  });

  final List<ImportColumnDraft> columns;
  final List<Map<String, Object?>> rows;
  final List<String> warnings;
}

TransformedImportTable applyImportTransformPlan({
  required MaterializedImportTableData source,
  required ImportTableDraft draft,
}) {
  final plan = draft.transformPlan;
  final warnings = <String>[];
  var rows = <Map<String, Object?>>[
    for (final row in source.rows)
      <String, Object?>{
        for (final column in draft.columns)
          column.targetName: row[column.sourceName],
      },
  ];
  var columns = <ImportColumnDraft>[
    for (final column in draft.columns)
      column.copyWith(sourceName: column.targetName),
  ];

  if (plan.rowFilters.isNotEmpty) {
    final before = rows.length;
    rows = <Map<String, Object?>>[
      for (final row in rows)
        if (plan.rowFilters.every((filter) => filter.keeps(row))) row,
    ];
    final filtered = before - rows.length;
    if (filtered > 0) {
      warnings.add(
        '${draft.targetName}: filtered $filtered row${filtered == 1 ? '' : 's'}.',
      );
    }
  }

  if (plan.defaultValues.isNotEmpty) {
    for (final row in rows) {
      for (final transform in plan.defaultValues) {
        transform.apply(row);
      }
    }
  }

  for (final transform in plan.computedColumns) {
    if (columns.any((column) => column.targetName == transform.columnName)) {
      throw StateError(
        'Computed column `${transform.columnName}` already exists in `${draft.targetName}`.',
      );
    }
    columns = <ImportColumnDraft>[
      ...columns,
      ImportColumnDraft(
        sourceName: transform.columnName,
        targetName: transform.columnName,
        inferredTargetType: transform.targetType,
        targetType: transform.targetType,
        containsNulls: true,
      ),
    ];
    for (final row in rows) {
      row[transform.columnName] = transform.expression.evaluate(
        row,
        warnings: warnings,
        outputColumn: '${draft.targetName}.${transform.columnName}',
      );
    }
  }

  final deduplication = plan.deduplication;
  if (deduplication != null && deduplication.keyColumns.isNotEmpty) {
    final before = rows.length;
    final byKey = <String, Map<String, Object?>>{};
    for (final row in rows) {
      final key = importDeduplicationKey(row, deduplication.keyColumns);
      if (deduplication.keep == ImportDeduplicationKeep.last ||
          !byKey.containsKey(key)) {
        byKey[key] = row;
      }
    }
    rows = byKey.values.toList(growable: false);
    final dropped = before - rows.length;
    if (dropped > 0) {
      warnings.add(
        '${draft.targetName}: deduplicated $dropped row${dropped == 1 ? '' : 's'} by ${deduplication.keyColumns.join(", ")}.',
      );
    }
  }

  if (plan.columnOrder.isNotEmpty) {
    final byName = <String, ImportColumnDraft>{
      for (final column in columns) column.targetName: column,
    };
    columns = <ImportColumnDraft>[
      for (final name in plan.columnOrder)
        if (byName.containsKey(name)) byName.remove(name)!,
      ...byName.values,
    ];
  }

  return TransformedImportTable(
    columns: columns,
    rows: rows,
    warnings: warnings,
  );
}
