import '../domain/import_models.dart';
import 'type_inference_service.dart';

GenericImportInspection buildInspectionFromMaterializedSource({
  required MaterializedImportSource materialized,
  required TypeInferenceService typeInferenceService,
}) {
  final drafts = materialized.tables
      .map((table) {
        final orderedKeys = _orderedKeys(table.rows);
        final columns = typeInferenceService.inferColumns(
          table.rows,
          orderedKeys,
        );
        final targetNames = typeInferenceService.distinctTargetNames(
          columns.map((column) => column.targetName),
          fallbackPrefix: 'column',
        );
        final adjustedColumns = <ImportColumnDraft>[
          for (var index = 0; index < columns.length; index++)
            columns[index].copyWith(targetName: targetNames[index]),
        ];
        return ImportTableDraft(
          sourceId: table.sourceId,
          sourceName: table.sourceName,
          targetName: table.suggestedTargetName,
          selected: true,
          rowCount: table.rows.length,
          columns: adjustedColumns,
          previewRows: table.rows
              .take(genericImportPreviewRowLimit)
              .toList(growable: false),
          description: table.description,
          warnings: table.warnings,
        );
      })
      .toList(growable: false);

  return GenericImportInspection(
    sourcePath: materialized.sourcePath,
    format: materialized.format,
    options: materialized.options,
    tables: drafts,
    warnings: materialized.warnings,
    explanation: materialized.explanation,
  );
}

List<String> _orderedKeys(List<Map<String, Object?>> rows) {
  final keys = <String>[];
  final seen = <String>{};
  for (final row in rows) {
    for (final key in row.keys) {
      if (seen.add(key)) {
        keys.add(key);
      }
    }
  }
  return keys;
}
