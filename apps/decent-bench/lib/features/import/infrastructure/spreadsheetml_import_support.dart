import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../domain/import_models.dart';
import 'generic_import_draft_builder.dart';
import 'type_inference_service.dart';

const String _spreadsheetMlNamespace =
    'urn:schemas-microsoft-com:office:spreadsheet';

MaterializedImportSource materializeSpreadsheetMlSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw StateError('SpreadsheetML source file does not exist: $sourcePath');
  }
  final warnings = <String>[];
  final text = _decodeText(file.readAsBytesSync(), options.encoding, warnings);
  final document = XmlDocument.parse(text);
  if (!isSpreadsheetMlDocument(document)) {
    throw StateError(
      'XML document is not an Excel XML Spreadsheet / SpreadsheetML workbook.',
    );
  }

  final workbookName = typeInferenceService.sanitizeIdentifier(
    p.basenameWithoutExtension(sourcePath),
    fallbackPrefix: 'spreadsheetml',
  );
  final tables = <MaterializedImportTableData>[];
  final worksheets = document
      .findAllElements('Worksheet', namespace: _spreadsheetMlNamespace)
      .toList(growable: false);
  for (var sheetIndex = 0; sheetIndex < worksheets.length; sheetIndex++) {
    final worksheet = worksheets[sheetIndex];
    final sheetName =
        _attributeValue(worksheet, 'Name') ?? 'Sheet ${sheetIndex + 1}';
    final table = worksheet.getElement(
      'Table',
      namespace: _spreadsheetMlNamespace,
    );
    if (table == null) {
      continue;
    }
    final parsed = _parseSpreadsheetMlTable(
      table,
      sheetName: sheetName,
      options: options,
    );
    if (parsed.rows.isEmpty) {
      warnings.add('$sheetName has no data rows to import.');
      continue;
    }
    warnings.addAll(parsed.warnings);
    final targetName = typeInferenceService.sanitizeIdentifier(
      sheetName,
      fallbackPrefix: '${workbookName}_sheet',
    );
    tables.add(
      MaterializedImportTableData(
        sourceId: 'sheet_${sheetIndex + 1}',
        sourceName: sheetName,
        suggestedTargetName: targetName,
        rows: parsed.rows,
        description: 'SpreadsheetML worksheet `$sheetName`.',
        warnings: parsed.warnings,
      ),
    );
  }
  if (tables.isEmpty) {
    throw StateError('No importable SpreadsheetML worksheets found.');
  }

  return MaterializedImportSource(
    sourcePath: sourcePath,
    format: format,
    options: options,
    tables: tables,
    warnings: warnings,
    explanation:
        'Each SpreadsheetML worksheet table becomes its own DecentDB table draft. Cached formula values are imported when present.',
  );
}

GenericImportInspection inspectSpreadsheetMlSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  return buildInspectionFromMaterializedSource(
    materialized: materializeSpreadsheetMlSourceSync(
      sourcePath: sourcePath,
      format: format,
      options: options,
      typeInferenceService: typeInferenceService,
    ),
    typeInferenceService: typeInferenceService,
  );
}

bool isSpreadsheetMlText(String text) {
  try {
    return isSpreadsheetMlDocument(XmlDocument.parse(text));
  } catch (_) {
    return false;
  }
}

bool isSpreadsheetMlDocument(XmlDocument document) {
  final root = document.rootElement;
  if (root.name.local != 'Workbook') {
    return false;
  }
  return root.name.namespaceUri == _spreadsheetMlNamespace ||
      root.attributes.any(
        (attribute) => attribute.value == _spreadsheetMlNamespace,
      );
}

_SpreadsheetTable _parseSpreadsheetMlTable(
  XmlElement table, {
  required String sheetName,
  required GenericImportOptions options,
}) {
  final warnings = <String>[];
  final rawRows = <List<Object?>>[];
  for (final rowElement in table.findElements(
    'Row',
    namespace: _spreadsheetMlNamespace,
  )) {
    final row = <Object?>[];
    var nextColumn = 1;
    for (final cell in rowElement.findElements(
      'Cell',
      namespace: _spreadsheetMlNamespace,
    )) {
      final indexText = _attributeValue(cell, 'Index');
      final explicitIndex = indexText == null ? null : int.tryParse(indexText);
      if (explicitIndex != null && explicitIndex > nextColumn) {
        while (nextColumn < explicitIndex) {
          row.add(null);
          nextColumn++;
        }
      }
      final formula = _attributeValue(cell, 'Formula');
      if (formula != null) {
        warnings.add(
          '$sheetName contains formula cells. Cached formula values are imported when available.',
        );
      }
      row.add(_spreadsheetMlCellValue(cell));
      nextColumn++;
    }
    if (row.any((value) => value != null && '$value'.trim().isNotEmpty)) {
      rawRows.add(row);
    }
  }
  if (rawRows.isEmpty) {
    return _SpreadsheetTable(
      rows: const <Map<String, Object?>>[],
      warnings: warnings,
    );
  }

  final width = rawRows.fold<int>(
    0,
    (max, row) => row.length > max ? row.length : max,
  );
  final headers = options.headerRow
      ? <String>[
          for (var index = 0; index < width; index++)
            if (index < rawRows.first.length &&
                rawRows.first[index] != null &&
                '${rawRows.first[index]}'.trim().isNotEmpty)
              '${rawRows.first[index]}'.trim()
            else
              'column_${index + 1}',
        ]
      : <String>[
          for (var index = 0; index < width; index++) 'column_${index + 1}',
        ];
  final dataRows = options.headerRow ? rawRows.skip(1) : rawRows;
  return _SpreadsheetTable(
    rows: <Map<String, Object?>>[
      for (final row in dataRows)
        <String, Object?>{
          for (var index = 0; index < headers.length; index++)
            headers[index]: index < row.length ? row[index] : null,
        },
    ],
    warnings: warnings.toSet().toList(growable: false),
  );
}

Object? _spreadsheetMlCellValue(XmlElement cell) {
  final data = cell.getElement('Data', namespace: _spreadsheetMlNamespace);
  if (data == null) {
    return null;
  }
  final text = data.innerText.trim();
  if (text.isEmpty) {
    return null;
  }
  final type = _attributeValue(data, 'Type')?.toLowerCase();
  return switch (type) {
    'number' => num.tryParse(text) ?? text,
    'boolean' => text == '1' || text.toLowerCase() == 'true',
    'datetime' => DateTime.tryParse(text)?.toUtc().toIso8601String() ?? text,
    _ => text,
  };
}

String? _attributeValue(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) {
      return attribute.value;
    }
  }
  return null;
}

String _decodeText(
  List<int> bytes,
  GenericImportEncoding encoding,
  List<String> warnings,
) {
  if (encoding == GenericImportEncoding.latin1) {
    return latin1.decode(bytes);
  }
  if (encoding == GenericImportEncoding.utf8) {
    return utf8.decode(bytes);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    warnings.add(
      'The file was decoded as Latin-1 after UTF-8 decoding failed.',
    );
    return latin1.decode(bytes);
  }
}

class _SpreadsheetTable {
  const _SpreadsheetTable({required this.rows, required this.warnings});

  final List<Map<String, Object?>> rows;
  final List<String> warnings;
}
