import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../domain/import_models.dart';
import 'generic_import_draft_builder.dart';
import 'type_inference_service.dart';

const String _officeNamespace =
    'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
const String _tableNamespace =
    'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
const String _textNamespace = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';

MaterializedImportSource materializeOdsSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw StateError('ODS source file does not exist: $sourcePath');
  }

  final warnings = <String>[];
  final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  final contentEntry = archive.files.firstWhere(
    (entry) => entry.isFile && entry.name == 'content.xml',
    orElse: () => throw StateError('ODS workbook is missing content.xml.'),
  );
  final content = utf8.decode(contentEntry.content as List<int>);
  final document = XmlDocument.parse(content);
  final spreadsheets = document
      .findAllElements('spreadsheet', namespace: _officeNamespace)
      .toList(growable: false);
  final spreadsheet = spreadsheets.isEmpty ? null : spreadsheets.first;
  if (spreadsheet == null) {
    throw StateError('ODS workbook does not contain an office:spreadsheet.');
  }

  final tables = <MaterializedImportTableData>[];
  final sheetElements = spreadsheet
      .findElements('table', namespace: _tableNamespace)
      .toList(growable: false);
  final workbookName = typeInferenceService.sanitizeIdentifier(
    p.basenameWithoutExtension(sourcePath),
    fallbackPrefix: 'ods',
  );
  for (var sheetIndex = 0; sheetIndex < sheetElements.length; sheetIndex++) {
    final sheet = sheetElements[sheetIndex];
    final sheetName =
        _attributeValue(sheet, 'name') ?? 'Sheet ${sheetIndex + 1}';
    final parsed = _parseOdsSheet(
      sheet,
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
        description: 'ODS worksheet `$sheetName`.',
        warnings: parsed.warnings,
      ),
    );
  }
  if (tables.isEmpty) {
    throw StateError('No importable ODS worksheets found.');
  }

  return MaterializedImportSource(
    sourcePath: sourcePath,
    format: format,
    options: options,
    tables: tables,
    warnings: warnings,
    explanation:
        'Each ODS worksheet becomes its own DecentDB table draft. Repeated sparse cells are expanded within safety limits and cached formula values are imported when present.',
  );
}

GenericImportInspection inspectOdsSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  return buildInspectionFromMaterializedSource(
    materialized: materializeOdsSourceSync(
      sourcePath: sourcePath,
      format: format,
      options: options,
      typeInferenceService: typeInferenceService,
    ),
    typeInferenceService: typeInferenceService,
  );
}

_OdsSheet _parseOdsSheet(
  XmlElement sheet, {
  required String sheetName,
  required GenericImportOptions options,
}) {
  final warnings = <String>[];
  final rawRows = <List<Object?>>[];
  for (final rowElement in sheet.findElements(
    'table-row',
    namespace: _tableNamespace,
  )) {
    final repeatRows = _safeRepeatCount(
      _attributeValue(rowElement, 'number-rows-repeated'),
      warnings: warnings,
      context: '$sheetName repeated rows',
    );
    final row = _parseOdsRow(
      rowElement,
      sheetName: sheetName,
      warnings: warnings,
    );
    if (row.any((value) => value != null && '$value'.trim().isNotEmpty)) {
      for (var index = 0; index < repeatRows; index++) {
        rawRows.add(List<Object?>.from(row));
      }
    }
  }
  if (rawRows.isEmpty) {
    return _OdsSheet(rows: const <Map<String, Object?>>[], warnings: warnings);
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
  return _OdsSheet(
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

List<Object?> _parseOdsRow(
  XmlElement row, {
  required String sheetName,
  required List<String> warnings,
}) {
  final values = <Object?>[];
  for (final cell in row.children.whereType<XmlElement>().where(
    (element) =>
        element.name.local == 'table-cell' ||
        element.name.local == 'covered-table-cell',
  )) {
    final repeat = _safeRepeatCount(
      _attributeValue(cell, 'number-columns-repeated'),
      warnings: warnings,
      context: '$sheetName repeated cells',
    );
    final value = cell.name.local == 'covered-table-cell'
        ? null
        : _odsCellValue(cell, sheetName: sheetName, warnings: warnings);
    for (var index = 0; index < repeat; index++) {
      values.add(value);
    }
  }
  return values;
}

Object? _odsCellValue(
  XmlElement cell, {
  required String sheetName,
  required List<String> warnings,
}) {
  if (_attributeValue(cell, 'formula') != null) {
    warnings.add(
      '$sheetName contains formula cells. Cached formula values are imported when available.',
    );
  }
  final valueType = _attributeValue(cell, 'value-type');
  return switch (valueType) {
    'float' || 'currency' || 'percentage' =>
      num.tryParse(_attributeValue(cell, 'value') ?? '') ??
          _paragraphText(cell),
    'boolean' =>
      (_attributeValue(cell, 'boolean-value') ?? '').toLowerCase() == 'true',
    'date' =>
      DateTime.tryParse(
            _attributeValue(cell, 'date-value') ?? '',
          )?.toUtc().toIso8601String() ??
          _paragraphText(cell),
    'time' => _attributeValue(cell, 'time-value') ?? _paragraphText(cell),
    'string' => _paragraphText(cell),
    _ => _paragraphText(cell),
  };
}

String? _paragraphText(XmlElement cell) {
  final parts = <String>[];
  for (final paragraph in cell.findAllElements(
    'p',
    namespace: _textNamespace,
  )) {
    final text = paragraph.innerText.trim();
    if (text.isNotEmpty) {
      parts.add(text);
    }
  }
  final joined = parts.join('\n').trim();
  return joined.isEmpty ? null : joined;
}

int _safeRepeatCount(
  String? value, {
  required List<String> warnings,
  required String context,
}) {
  final parsed = value == null ? 1 : int.tryParse(value) ?? 1;
  if (parsed <= 0) {
    return 1;
  }
  const maxRepeat = 10000;
  if (parsed > maxRepeat) {
    warnings.add('$context truncated a repeat count of $parsed to $maxRepeat.');
    return maxRepeat;
  }
  return parsed;
}

String? _attributeValue(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) {
      return attribute.value;
    }
  }
  return null;
}

class _OdsSheet {
  const _OdsSheet({required this.rows, required this.warnings});

  final List<Map<String, Object?>> rows;
  final List<String> warnings;
}
