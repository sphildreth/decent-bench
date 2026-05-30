import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/import_models.dart';
import 'generic_import_draft_builder.dart';
import 'type_inference_service.dart';

MaterializedImportSource materializeFixedWidthSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw StateError('Fixed-width source file does not exist: $sourcePath');
  }

  final warnings = <String>[];
  final decoded = _decodeText(file.readAsBytesSync(), options.encoding);
  warnings.addAll(decoded.warnings);
  final lines = const LineSplitter()
      .convert(decoded.text)
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    throw StateError(
      'No non-empty fixed-width rows were found in $sourcePath.',
    );
  }

  final ranges = _detectFixedWidthRanges(lines);
  if (ranges.isEmpty) {
    throw StateError(
      'No fixed-width column boundaries could be detected in $sourcePath.',
    );
  }
  final headerValues = options.headerRow
      ? _extractFixedWidthFields(lines.first, ranges)
      : null;
  final headerNames = <String>[
    for (var index = 0; index < ranges.length; index++)
      if (headerValues != null &&
          index < headerValues.length &&
          headerValues[index].trim().isNotEmpty)
        headerValues[index].trim()
      else
        'column_${index + 1}',
  ];
  final distinctNames = typeInferenceService.distinctTargetNames(
    headerNames,
    fallbackPrefix: 'column',
  );

  var skippedRows = 0;
  final rows = <Map<String, Object?>>[];
  final dataLines = options.headerRow ? lines.skip(1) : lines;
  for (final line in dataLines) {
    if (options.malformedRowStrategy == DelimitedMalformedRowStrategy.skipRow &&
        line.length < ranges.last.start) {
      skippedRows++;
      continue;
    }
    final values = _extractFixedWidthFields(line, ranges);
    rows.add(<String, Object?>{
      for (var index = 0; index < distinctNames.length; index++)
        distinctNames[index]:
            index < values.length && values[index].trim().isNotEmpty
            ? values[index].trim()
            : null,
    });
  }
  if (skippedRows > 0) {
    warnings.add(
      'Skipped $skippedRows malformed fixed-width row${skippedRows == 1 ? '' : 's'} while previewing the file.',
    );
  }

  final tableName = typeInferenceService.sanitizeIdentifier(
    p.basenameWithoutExtension(sourcePath),
    fallbackPrefix: 'fixed_width',
  );
  return MaterializedImportSource(
    sourcePath: sourcePath,
    format: format,
    options: options,
    tables: <MaterializedImportTableData>[
      MaterializedImportTableData(
        sourceId: 'primary_table',
        sourceName: p.basename(sourcePath),
        suggestedTargetName: tableName,
        rows: rows,
        description:
            'Detected ${ranges.length} fixed-width column${ranges.length == 1 ? '' : 's'} from whitespace-aligned boundaries.',
        warnings: skippedRows > 0
            ? <String>[
                'Skipped $skippedRows malformed row${skippedRows == 1 ? '' : 's'} during preview.',
              ]
            : const <String>[],
      ),
    ],
    warnings: warnings,
    explanation:
        'Previewing fixed-width text as one DecentDB table. Column boundaries are inferred from stable runs of whitespace; rename columns and override target types before import.',
  );
}

GenericImportInspection inspectFixedWidthSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  return buildInspectionFromMaterializedSource(
    materialized: materializeFixedWidthSourceSync(
      sourcePath: sourcePath,
      format: format,
      options: options,
      typeInferenceService: typeInferenceService,
    ),
    typeInferenceService: typeInferenceService,
  );
}

bool looksLikeFixedWidthText(String text) {
  final lines = const LineSplitter()
      .convert(text)
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .take(6)
      .toList(growable: false);
  if (lines.length < 2) {
    return false;
  }
  final ranges = _detectFixedWidthRanges(lines);
  if (ranges.length < 2) {
    return false;
  }
  return lines.take(3).every((line) => RegExp(r'\S\s{2,}\S').hasMatch(line));
}

List<_FixedWidthRange> _detectFixedWidthRanges(List<String> lines) {
  final sample = lines.take(12).toList(growable: false);
  if (sample.isEmpty) {
    return const <_FixedWidthRange>[];
  }
  final candidateLine = sample.firstWhere(
    (line) => RegExp(r'\S\s{2,}\S').hasMatch(line),
    orElse: () => sample.first,
  );
  final starts = <int>[];
  final matches = RegExp(r'\S+(?:\s(?!\s)\S+)*').allMatches(candidateLine);
  for (final match in matches) {
    starts.add(match.start);
  }
  if (starts.length < 2) {
    return const <_FixedWidthRange>[];
  }
  final maxLength = sample.fold<int>(
    0,
    (max, line) => line.length > max ? line.length : max,
  );
  return <_FixedWidthRange>[
    for (var index = 0; index < starts.length; index++)
      _FixedWidthRange(
        starts[index],
        index + 1 < starts.length ? starts[index + 1] : maxLength,
      ),
  ];
}

List<String> _extractFixedWidthFields(
  String line,
  List<_FixedWidthRange> ranges,
) {
  return <String>[
    for (final range in ranges)
      if (range.start >= line.length)
        ''
      else
        line
            .substring(
              range.start,
              range.end > line.length ? line.length : range.end,
            )
            .trimRight(),
  ];
}

_DecodedText _decodeText(List<int> bytes, GenericImportEncoding encoding) {
  return switch (encoding) {
    GenericImportEncoding.utf8 => _DecodedText(
      text: utf8.decode(bytes),
      warnings: const <String>[],
    ),
    GenericImportEncoding.latin1 => _DecodedText(
      text: latin1.decode(bytes),
      warnings: const <String>[],
    ),
    GenericImportEncoding.auto => _decodeAuto(bytes),
  };
}

_DecodedText _decodeAuto(List<int> bytes) {
  try {
    return _DecodedText(text: utf8.decode(bytes), warnings: const <String>[]);
  } on FormatException {
    return _DecodedText(
      text: latin1.decode(bytes),
      warnings: const <String>[
        'The file was decoded as Latin-1 after UTF-8 decoding failed.',
      ],
    );
  }
}

class _FixedWidthRange {
  const _FixedWidthRange(this.start, this.end);

  final int start;
  final int end;
}

class _DecodedText {
  const _DecodedText({required this.text, required this.warnings});

  final String text;
  final List<String> warnings;
}
