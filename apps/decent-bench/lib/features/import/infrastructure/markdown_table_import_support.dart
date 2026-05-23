import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/import_models.dart';
import 'type_inference_service.dart';

MaterializedImportSource materializeMarkdownTableSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw StateError('Markdown source file does not exist: $sourcePath');
  }

  final warnings = <String>[];
  final text = _decodeMarkdownText(
    file.readAsBytesSync(),
    options.encoding,
    warnings,
  );
  final parsedTables = _parseMarkdownTables(
    text,
    options: options,
    warnings: warnings,
  );
  if (parsedTables.isEmpty) {
    throw StateError('No Markdown tables found in $sourcePath.');
  }

  final tables = <MaterializedImportTableData>[];
  for (var index = 0; index < parsedTables.length; index++) {
    final parsed = parsedTables[index];
    final orderedNames = typeInferenceService.distinctTargetNames(
      parsed.headerNames,
      fallbackPrefix: 'column',
    );
    final mappedRows = <Map<String, Object?>>[
      for (final row in parsed.rows)
        <String, Object?>{
          for (
            var columnIndex = 0;
            columnIndex < orderedNames.length;
            columnIndex++
          )
            orderedNames[columnIndex]:
                columnIndex < row.cells.length &&
                    row.cells[columnIndex].trim().isNotEmpty
                ? row.cells[columnIndex].trim()
                : null,
        },
    ];
    final suggestedName = typeInferenceService.sanitizeIdentifier(
      '${p.basenameWithoutExtension(sourcePath)}_table_${index + 1}',
      fallbackPrefix: 'markdown_table',
    );
    tables.add(
      MaterializedImportTableData(
        sourceId: 'table_${index + 1}',
        sourceName: 'Markdown table ${index + 1}',
        suggestedTargetName: suggestedName,
        rows: mappedRows,
        description:
            'Markdown pipe table starting at source row ${parsed.startRowNumber}.',
        warnings: parsed.warnings,
      ),
    );
    warnings.addAll(parsed.warnings);
  }

  return MaterializedImportSource(
    sourcePath: sourcePath,
    format: format,
    options: options,
    tables: tables,
    warnings: warnings,
    explanation:
        'Each detected Markdown pipe table becomes its own DecentDB table draft. Prose, headings, lists, and fenced code blocks are ignored.',
  );
}

GenericImportInspection inspectMarkdownTableSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  final materialized = materializeMarkdownTableSourceSync(
    sourcePath: sourcePath,
    format: format,
    options: options,
    typeInferenceService: typeInferenceService,
  );
  final drafts = materialized.tables
      .map((table) {
        final orderedKeys = table.rows.isEmpty
            ? <String>[]
            : table.rows.first.keys.toList();
        final columns = typeInferenceService.inferColumns(
          table.rows,
          orderedKeys,
        );
        final targetNames = typeInferenceService.distinctTargetNames(
          columns.map((column) => column.targetName),
          fallbackPrefix: 'column',
        );
        final adjustedColumns = <ImportColumnDraft>[
          for (var i = 0; i < columns.length; i++)
            columns[i].copyWith(targetName: targetNames[i]),
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

class _MarkdownTableRow {
  const _MarkdownTableRow({required this.cells, required this.sourceRowNumber});

  final List<String> cells;
  final int sourceRowNumber;
}

class _ParsedMarkdownTable {
  const _ParsedMarkdownTable({
    required this.headerNames,
    required this.rows,
    required this.startRowNumber,
    required this.warnings,
  });

  final List<String> headerNames;
  final List<_MarkdownTableRow> rows;
  final int startRowNumber;
  final List<String> warnings;
}

List<_ParsedMarkdownTable> _parseMarkdownTables(
  String text, {
  required GenericImportOptions options,
  required List<String> warnings,
}) {
  final lines = const LineSplitter().convert(text);
  final tables = <_ParsedMarkdownTable>[];
  var index = 0;
  var inFence = false;
  String? fenceMarker;

  while (index < lines.length) {
    final line = lines[index];
    final trimmedLine = line.trim();

    if (_isFenceLine(trimmedLine)) {
      final marker = _fenceMarker(trimmedLine);
      if (!inFence) {
        inFence = true;
        fenceMarker = marker;
      } else if (marker == fenceMarker) {
        inFence = false;
        fenceMarker = null;
      }
      index++;
      continue;
    }

    if (inFence) {
      index++;
      continue;
    }

    final headerCells = _parseMarkdownTableCells(line);
    if (headerCells.isEmpty) {
      index++;
      continue;
    }
    final separatorIndex = index + 1;
    if (separatorIndex >= lines.length) {
      index++;
      continue;
    }
    final separatorLine = lines[separatorIndex];
    if (!_isMarkdownSeparatorRow(
      separatorLine,
      expectedColumns: headerCells.length,
    )) {
      index++;
      continue;
    }

    final headerNames = headerCells
        .asMap()
        .entries
        .map((entry) {
          final value = entry.value.trim();
          return value.isEmpty ? 'column_${entry.key + 1}' : value;
        })
        .toList(growable: false);
    final tableWarnings = <String>[];
    final rows = <_MarkdownTableRow>[];
    var rowIndex = separatorIndex + 1;
    while (rowIndex < lines.length) {
      final rowLine = lines[rowIndex];
      final rowTrimmed = rowLine.trim();
      if (rowTrimmed.isEmpty || _isFenceLine(rowTrimmed)) {
        break;
      }
      if (!_lineContainsMarkdownTablePipe(rowLine)) {
        break;
      }
      final cells = _parseMarkdownTableCells(rowLine);
      if (cells.length != headerNames.length) {
        final rowNumber = rowIndex + 1;
        final expected = headerNames.length;
        final actual = cells.length;
        if (options.malformedRowStrategy ==
            DelimitedMalformedRowStrategy.skipRow) {
          tableWarnings.add(
            'Source row $rowNumber: skipped Markdown table row with $actual cell${actual == 1 ? '' : 's'}; expected $expected.',
          );
        } else {
          tableWarnings.add(
            'Source row $rowNumber: Markdown table row had $actual cell${actual == 1 ? '' : 's'}; expected $expected. Missing cells are imported as null and extra cells are truncated.',
          );
        }
      }
      if (cells.length != headerNames.length &&
          options.malformedRowStrategy ==
              DelimitedMalformedRowStrategy.skipRow) {
        rowIndex++;
        continue;
      }
      final normalizedCells = List<String>.from(cells);
      if (normalizedCells.length < headerNames.length) {
        normalizedCells.addAll(
          List<String>.filled(headerNames.length - normalizedCells.length, ''),
        );
      } else if (normalizedCells.length > headerNames.length) {
        normalizedCells.removeRange(headerNames.length, normalizedCells.length);
      }
      rows.add(
        _MarkdownTableRow(
          cells: normalizedCells,
          sourceRowNumber: rowIndex + 1,
        ),
      );
      rowIndex++;
    }

    if (rows.isNotEmpty) {
      tables.add(
        _ParsedMarkdownTable(
          headerNames: headerNames,
          rows: rows,
          startRowNumber: index + 1,
          warnings: tableWarnings,
        ),
      );
      warnings.addAll(tableWarnings);
    }
    index = rowIndex;
  }

  return tables;
}

bool _lineContainsMarkdownTablePipe(String line) {
  var escaped = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '|') {
      return true;
    }
  }
  return false;
}

List<String> _parseMarkdownTableCells(String line) {
  final trimmed = line.trim();
  final rawCells = <String>[];
  var current = StringBuffer();
  var escaped = false;

  for (var i = 0; i < trimmed.length; i++) {
    final char = trimmed[i];
    if (escaped) {
      current.write(char);
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '|') {
      rawCells.add(current.toString());
      current = StringBuffer();
      continue;
    }
    current.write(char);
  }
  rawCells.add(current.toString());

  if (trimmed.startsWith('|') &&
      rawCells.isNotEmpty &&
      rawCells.first.isEmpty) {
    rawCells.removeAt(0);
  }
  if (_hasUnescapedTrailingPipe(trimmed) &&
      rawCells.isNotEmpty &&
      rawCells.last.isEmpty) {
    rawCells.removeLast();
  }

  return rawCells
      .map((cell) => cell.replaceAll(r'\|', '|'))
      .toList(growable: false);
}

bool _isMarkdownSeparatorRow(String line, {required int expectedColumns}) {
  final cells = _parseMarkdownTableCells(line);
  if (cells.length != expectedColumns) {
    return false;
  }
  return cells.every(_isMarkdownSeparatorCell);
}

bool _isMarkdownSeparatorCell(String cell) {
  final value = cell.trim();
  if (value.isEmpty) {
    return false;
  }
  return RegExp(r'^:?-{3,}:?$').hasMatch(value);
}

bool _isFenceLine(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('```') || trimmed.startsWith('~~~');
}

String _fenceMarker(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('```')) {
    return '```';
  }
  return '~~~';
}

bool _hasUnescapedTrailingPipe(String line) {
  var index = line.length - 1;
  while (index >= 0 && line[index].trim().isEmpty) {
    index--;
  }
  if (index < 0 || line[index] != '|') {
    return false;
  }
  var backslashCount = 0;
  var cursor = index - 1;
  while (cursor >= 0 && line[cursor] == r'\') {
    backslashCount++;
    cursor--;
  }
  return backslashCount.isEven;
}

String _decodeMarkdownText(
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
