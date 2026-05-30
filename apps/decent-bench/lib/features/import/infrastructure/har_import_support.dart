import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/import_models.dart';
import 'generic_import_draft_builder.dart';
import 'type_inference_service.dart';

MaterializedImportSource materializeHarSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw StateError('HAR source file does not exist: $sourcePath');
  }

  final warnings = <String>[];
  final text = _decodeText(file.readAsBytesSync(), options.encoding, warnings);
  final decoded = jsonDecode(text);
  if (decoded is! Map || decoded['log'] is! Map) {
    throw StateError('HAR import requires a top-level `log` object.');
  }
  final log = decoded['log']! as Map;
  final entries = log['entries'];
  if (entries is! List || entries.isEmpty) {
    throw StateError('HAR import requires a non-empty `log.entries` array.');
  }

  final requestRows = <Map<String, Object?>>[];
  final responseRows = <Map<String, Object?>>[];
  final timingRows = <Map<String, Object?>>[];
  final headerRows = <Map<String, Object?>>[];

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    if (entry is! Map) {
      warnings.add(
        'Skipped HAR entry ${index + 1} because it is not an object.',
      );
      continue;
    }
    final entryId = index + 1;
    final request = entry['request'] is Map ? entry['request']! as Map : null;
    final response = entry['response'] is Map
        ? entry['response']! as Map
        : null;
    final timings = entry['timings'] is Map ? entry['timings']! as Map : null;

    requestRows.add(<String, Object?>{
      '_entry_id': entryId,
      'started_date_time': entry['startedDateTime'],
      'total_time_ms': entry['time'],
      'pageref': entry['pageref'],
      'method': request?['method'],
      'url': request?['url'],
      'http_version': request?['httpVersion'],
      'query_string_count': _listLength(request?['queryString']),
      'cookies_count': _listLength(request?['cookies']),
      'headers_count': _listLength(request?['headers']),
      'post_mime_type': request?['postData'] is Map
          ? (request!['postData']! as Map)['mimeType']
          : null,
      'post_text_length': request?['postData'] is Map
          ? ((request!['postData']! as Map)['text']?.toString().length)
          : null,
    });

    responseRows.add(<String, Object?>{
      '_entry_id': entryId,
      'status': response?['status'],
      'status_text': response?['statusText'],
      'http_version': response?['httpVersion'],
      'redirect_url': response?['redirectURL'],
      'headers_count': _listLength(response?['headers']),
      'cookies_count': _listLength(response?['cookies']),
      'content_mime_type': response?['content'] is Map
          ? (response!['content']! as Map)['mimeType']
          : null,
      'content_size': response?['content'] is Map
          ? (response!['content']! as Map)['size']
          : null,
      'body_size': response?['bodySize'],
      'headers_size': response?['headersSize'],
    });

    if (timings != null) {
      timingRows.add(<String, Object?>{
        '_entry_id': entryId,
        for (final entry in timings.entries)
          entry.key.toString().replaceAll('-', '_'): entry.value,
      });
    }
    _addHarHeaderRows(
      rows: headerRows,
      entryId: entryId,
      direction: 'request',
      headers: request?['headers'],
    );
    _addHarHeaderRows(
      rows: headerRows,
      entryId: entryId,
      direction: 'response',
      headers: response?['headers'],
    );
  }

  final baseName = typeInferenceService.sanitizeIdentifier(
    p.basenameWithoutExtension(sourcePath),
    fallbackPrefix: 'har',
  );
  return MaterializedImportSource(
    sourcePath: sourcePath,
    format: format,
    options: options,
    tables: <MaterializedImportTableData>[
      MaterializedImportTableData(
        sourceId: 'requests',
        sourceName: 'Requests',
        suggestedTargetName: '${baseName}_requests',
        rows: requestRows,
        description: 'One row per HAR entry request.',
      ),
      MaterializedImportTableData(
        sourceId: 'responses',
        sourceName: 'Responses',
        suggestedTargetName: '${baseName}_responses',
        rows: responseRows,
        description: 'One row per HAR entry response.',
      ),
      if (timingRows.isNotEmpty)
        MaterializedImportTableData(
          sourceId: 'timings',
          sourceName: 'Timings',
          suggestedTargetName: '${baseName}_timings',
          rows: timingRows,
          description: 'HAR timing fields linked by `_entry_id`.',
        ),
      if (headerRows.isNotEmpty)
        MaterializedImportTableData(
          sourceId: 'headers',
          sourceName: 'Headers',
          suggestedTargetName: '${baseName}_headers',
          rows: headerRows,
          description: 'Request and response headers linked by `_entry_id`.',
        ),
    ],
    warnings: warnings,
    explanation:
        'Previewing HAR entries as request, response, timing, and header tables linked by `_entry_id`.',
  );
}

GenericImportInspection inspectHarSourceSync({
  required String sourcePath,
  required ImportFormatDefinition format,
  required GenericImportOptions options,
  required TypeInferenceService typeInferenceService,
}) {
  return buildInspectionFromMaterializedSource(
    materialized: materializeHarSourceSync(
      sourcePath: sourcePath,
      format: format,
      options: options,
      typeInferenceService: typeInferenceService,
    ),
    typeInferenceService: typeInferenceService,
  );
}

void _addHarHeaderRows({
  required List<Map<String, Object?>> rows,
  required int entryId,
  required String direction,
  required dynamic headers,
}) {
  if (headers is! List) {
    return;
  }
  for (var index = 0; index < headers.length; index++) {
    final header = headers[index];
    if (header is! Map) {
      continue;
    }
    rows.add(<String, Object?>{
      '_entry_id': entryId,
      'direction': direction,
      'ordinal': index + 1,
      'name': header['name'],
      'value': header['value'],
      'comment': header['comment'],
    });
  }
}

int _listLength(dynamic value) {
  return value is List ? value.length : 0;
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
