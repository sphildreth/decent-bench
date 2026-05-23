import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/import_models.dart';
import 'generic_import_draft_builder.dart';
import 'type_inference_service.dart';

MaterializedImportSource materializeJsonLogStreamSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw StateError('JSON log source file does not exist: $sourcePath');
  }
  final warnings = <String>[];
  final text = _decodeText(file.readAsBytesSync(), options.encoding, warnings);
  final rows = <Map<String, Object?>>[];
  var skipped = 0;
  var lineNumber = 0;
  for (final rawLine in const LineSplitter().convert(text)) {
    lineNumber++;
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        skipped++;
        warnings.add('Line $lineNumber is valid JSON but not an object.');
        continue;
      }
      final row = _flattenRecord(decoded);
      final timestamp = _extractTimestamp(row);
      if (timestamp != null) {
        row['_event_timestamp'] = timestamp.toUtc().toIso8601String();
      }
      row['_source_line'] = lineNumber;
      rows.add(row);
    } on FormatException catch (error) {
      if (options.malformedRowStrategy ==
          DelimitedMalformedRowStrategy.skipRow) {
        skipped++;
        continue;
      }
      throw StateError('Invalid JSON log object on line $lineNumber: $error');
    }
  }
  if (rows.isEmpty) {
    throw StateError('No JSON log objects were found in $sourcePath.');
  }
  if (skipped > 0) {
    warnings.add(
      'Skipped $skipped non-object or malformed JSON log line${skipped == 1 ? '' : 's'}.',
    );
  }
  final tableName = typeInferenceService.sanitizeIdentifier(
    p.basenameWithoutExtension(sourcePath),
    fallbackPrefix: 'json_log',
  );
  return MaterializedImportSource(
    sourcePath: sourcePath,
    format: format,
    options: options,
    tables: <MaterializedImportTableData>[
      MaterializedImportTableData(
        sourceId: 'events',
        sourceName: 'Events',
        suggestedTargetName: tableName,
        rows: rows,
        description:
            'JSON log objects with `_source_line` provenance and `_event_timestamp` when a timestamp field is detected.',
      ),
    ],
    warnings: warnings,
    explanation:
        'Previewing line-oriented JSON logs as event rows. Known timestamp fields are copied into `_event_timestamp`; nested structures are flattened or retained as JSON text.',
  );
}

MaterializedImportSource materializeDelimitedLogSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw StateError('Log source file does not exist: $sourcePath');
  }
  final warnings = <String>[];
  final text = _decodeText(file.readAsBytesSync(), options.encoding, warnings);
  final parsed = parseDelimitedLogText(text, skipMalformed: true);
  if (parsed.rows.isEmpty) {
    throw StateError(
      'No supported log records were detected in $sourcePath. Supported templates are IIS W3C `#Fields`, Apache/Nginx access logs, and key=value app logs.',
    );
  }
  warnings.addAll(parsed.warnings);
  final tableName = typeInferenceService.sanitizeIdentifier(
    p.basenameWithoutExtension(sourcePath),
    fallbackPrefix: 'log_events',
  );
  return MaterializedImportSource(
    sourcePath: sourcePath,
    format: format,
    options: options,
    tables: <MaterializedImportTableData>[
      MaterializedImportTableData(
        sourceId: 'log_events',
        sourceName: parsed.templateName,
        suggestedTargetName: tableName,
        rows: parsed.rows,
        description: '${parsed.templateName} parsed into structured rows.',
      ),
    ],
    warnings: warnings,
    explanation:
        'Previewing recognized web/app log lines as structured events with source-line provenance and timestamp fields preserved when present.',
  );
}

GenericImportInspection inspectJsonLogStreamSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  return buildInspectionFromMaterializedSource(
    materialized: materializeJsonLogStreamSourceSync(
      sourcePath: sourcePath,
      format: format,
      options: options,
      typeInferenceService: typeInferenceService,
    ),
    typeInferenceService: typeInferenceService,
  );
}

GenericImportInspection inspectDelimitedLogSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  return buildInspectionFromMaterializedSource(
    materialized: materializeDelimitedLogSourceSync(
      sourcePath: sourcePath,
      format: format,
      options: options,
      typeInferenceService: typeInferenceService,
    ),
    typeInferenceService: typeInferenceService,
  );
}

bool looksLikeJsonLogStream(String text) {
  final lines = const LineSplitter()
      .convert(text)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .take(5)
      .toList(growable: false);
  if (lines.isEmpty) {
    return false;
  }
  var objectCount = 0;
  var hasLogSignal = false;
  for (final line in lines) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map) {
        objectCount++;
        hasLogSignal = hasLogSignal || _hasJsonLogSignal(decoded);
      }
    } catch (_) {
      return false;
    }
  }
  return objectCount == lines.length && hasLogSignal;
}

bool _hasJsonLogSignal(Map<dynamic, dynamic> value) {
  const fields = <String>{
    '@timestamp',
    'timestamp',
    'time',
    'ts',
    'datetime',
    'created_at',
    'level',
    'severity',
    'message',
    'msg',
    'event',
    'logger',
  };
  return value.keys.map((key) => '$key'.toLowerCase()).any(fields.contains);
}

bool looksLikeSupportedLogTemplate(String text) {
  return parseDelimitedLogText(text, skipMalformed: true).rows.isNotEmpty;
}

ParsedDelimitedLog parseDelimitedLogText(
  String text, {
  required bool skipMalformed,
}) {
  final lines = const LineSplitter().convert(text);
  final warnings = <String>[];
  final rows = <Map<String, Object?>>[];
  var templateName = 'Application Log';
  var fields = <String>[];
  var inW3c = false;
  var skipped = 0;

  for (var index = 0; index < lines.length; index++) {
    final lineNumber = index + 1;
    final line = lines[index].trimRight();
    if (line.trim().isEmpty) {
      continue;
    }
    if (line.startsWith('#Fields:')) {
      fields = line
          .substring('#Fields:'.length)
          .trim()
          .split(RegExp(r'\s+'))
          .where((field) => field.isNotEmpty)
          .toList(growable: false);
      inW3c = fields.isNotEmpty;
      templateName = 'IIS W3C Log';
      continue;
    }
    if (line.startsWith('#')) {
      continue;
    }
    if (inW3c) {
      final values = line.split(RegExp(r'\s+'));
      if (values.length != fields.length) {
        skipped++;
        continue;
      }
      final row = <String, Object?>{'_source_line': lineNumber};
      for (var fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
        row[_normalizeLogColumn(fields[fieldIndex])] = _dashToNull(
          values[fieldIndex],
        );
      }
      final date = row['date'];
      final time = row['time'];
      if (date is String && time is String) {
        row['_event_timestamp'] = '${date}T${time}Z';
      }
      rows.add(row);
      continue;
    }

    final access = _parseAccessLogLine(line, lineNumber);
    if (access != null) {
      templateName = 'Common Access Log';
      rows.add(access);
      continue;
    }
    final app = _parseKeyValueLogLine(line, lineNumber);
    if (app != null) {
      rows.add(app);
      continue;
    }
    if (!skipMalformed) {
      throw StateError('Unsupported log line $lineNumber: $line');
    }
    skipped++;
  }
  if (skipped > 0 && rows.isNotEmpty) {
    warnings.add(
      'Skipped $skipped unsupported log line${skipped == 1 ? '' : 's'}.',
    );
  }
  return ParsedDelimitedLog(
    templateName: templateName,
    rows: rows,
    warnings: warnings,
  );
}

Map<String, Object?>? _parseAccessLogLine(String line, int lineNumber) {
  final match = RegExp(
    r'^(\S+) (\S+) (\S+) \[([^\]]+)\] "([A-Z]+) ([^"]*?) HTTP/([^"]+)" (\d{3}) (\S+)(?: "([^"]*)" "([^"]*)")?$',
  ).firstMatch(line);
  if (match == null) {
    return null;
  }
  return <String, Object?>{
    '_source_line': lineNumber,
    'remote_host': _dashToNull(match.group(1)!),
    'ident': _dashToNull(match.group(2)!),
    'user': _dashToNull(match.group(3)!),
    'timestamp': match.group(4),
    'method': match.group(5),
    'path': match.group(6),
    'http_version': match.group(7),
    'status': int.tryParse(match.group(8)!),
    'bytes': match.group(9) == '-' ? null : int.tryParse(match.group(9)!),
    'referer': _dashToNull(match.group(10)),
    'user_agent': _dashToNull(match.group(11)),
  };
}

Map<String, Object?>? _parseKeyValueLogLine(String line, int lineNumber) {
  final matches = RegExp(
    r'([A-Za-z_][A-Za-z0-9_.-]*)=(?:"([^"]*)"|(\S+))',
  ).allMatches(line).toList(growable: false);
  if (matches.length < 2) {
    return null;
  }
  final row = <String, Object?>{'_source_line': lineNumber};
  final prefix = line.substring(0, matches.first.start).trim();
  final prefixParts = prefix
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  final maybeTimestamp = prefixParts.isEmpty ? null : prefixParts.first;
  if (maybeTimestamp != null && DateTime.tryParse(maybeTimestamp) != null) {
    row['_event_timestamp'] = DateTime.parse(
      maybeTimestamp,
    ).toUtc().toIso8601String();
  }
  for (final match in matches) {
    row[_normalizeLogColumn(match.group(1)!)] = _dashToNull(
      match.group(2) ?? match.group(3),
    );
  }
  return row;
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

Map<String, Object?> _flattenRecord(dynamic value, {String prefix = ''}) {
  final result = <String, Object?>{};
  if (value is Map) {
    for (final entry in value.entries) {
      final key = prefix.isEmpty ? '${entry.key}' : '${prefix}__${entry.key}';
      final entryValue = entry.value;
      if (entryValue is Map) {
        result.addAll(_flattenRecord(entryValue, prefix: key));
      } else if (entryValue is List) {
        result[key] = jsonEncode(entryValue);
      } else {
        result[key] = entryValue;
      }
    }
    return result;
  }
  result[prefix.isEmpty ? 'value' : prefix] = value;
  return result;
}

DateTime? _extractTimestamp(Map<String, Object?> row) {
  const keys = <String>[
    '_event_timestamp',
    '@timestamp',
    'timestamp',
    'time',
    'ts',
    'date',
    'datetime',
    'created_at',
  ];
  for (final key in keys) {
    final value = row[key];
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
    }
  }
  return null;
}

String _normalizeLogColumn(String value) {
  return value
      .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .toLowerCase();
}

Object? _dashToNull(String? value) {
  return value == null || value == '-' ? null : value;
}

class ParsedDelimitedLog {
  const ParsedDelimitedLog({
    required this.templateName,
    required this.rows,
    required this.warnings,
  });

  final String templateName;
  final List<Map<String, Object?>> rows;
  final List<String> warnings;
}
