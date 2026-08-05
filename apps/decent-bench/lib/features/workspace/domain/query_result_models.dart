import 'dart:convert';

import 'workspace_model_helpers.dart';
import 'native_type_models.dart';

class QueryResultPage {
  const QueryResultPage({
    required this.cursorId,
    required this.columns,
    required this.rows,
    required this.done,
    required this.rowsAffected,
    required this.elapsed,
  });

  final String? cursorId;
  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final bool done;
  final int? rowsAffected;
  final Duration elapsed;

  factory QueryResultPage.fromMap(Map<String, Object?> map) {
    return QueryResultPage(
      cursorId: map['cursorId'] as String?,
      columns: ((map['columns'] as List?) ?? const <Object?>[]).cast<String>(),
      rows: ((map['rows'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (row) => row.map(
              (key, value) => MapEntry(key as String, decodeCell(value)),
            ),
          )
          .toList(),
      done: map['done']! as bool,
      rowsAffected: map['rowsAffected'] as int?,
      elapsed: Duration(microseconds: map['elapsedMicros']! as int),
    );
  }

  static Object? decodeCell(Object? value) {
    if (value is Map && value['kind'] == 'decimal') {
      final unscaled = value['unscaled'] as int;
      final scale = value['scale'] as int;
      return formatDecimalValue(unscaled, scale);
    }
    if (value is Map && value['kind'] == 'native_enum') {
      return NativeEnumCellValue(
        typeId: asInt(value['typeId']) ?? 0,
        labelId: asInt(value['labelId']) ?? 0,
      );
    }
    if (value is Map && value['kind'] == 'native_interval') {
      return NativeIntervalCellValue(
        months: asInt(value['months']) ?? 0,
        days: asInt(value['days']) ?? 0,
        microseconds: asInt(value['microseconds']) ?? 0,
      );
    }
    if (value is Map && value['kind'] == 'duration') {
      return Duration(microseconds: asInt(value['microseconds']) ?? 0);
    }
    if (value is Map && value['kind'] == 'blob') {
      return base64Decode(value['base64']! as String);
    }
    if (value is Map && value['kind'] == 'datetime') {
      return DateTime.parse(value['iso8601']! as String);
    }
    return value;
  }
}

class CsvExportResult {
  const CsvExportResult({required this.rowCount, required this.path});

  final int rowCount;
  final String path;

  factory CsvExportResult.fromMap(Map<String, Object?> map) {
    return CsvExportResult(
      rowCount: map['rowCount']! as int,
      path: map['path']! as String,
    );
  }
}

class JsonExportResult {
  const JsonExportResult({required this.rowCount, required this.path});

  final int rowCount;
  final String path;

  factory JsonExportResult.fromMap(Map<String, Object?> map) {
    return JsonExportResult(
      rowCount: map['rowCount']! as int,
      path: map['path']! as String,
    );
  }
}

class ExcelExportResult {
  const ExcelExportResult({required this.rowCount, required this.path});

  final int rowCount;
  final String path;

  factory ExcelExportResult.fromMap(Map<String, Object?> map) {
    return ExcelExportResult(
      rowCount: map['rowCount']! as int,
      path: map['path']! as String,
    );
  }
}

class ParquetExportResult {
  const ParquetExportResult({
    required this.rowCount,
    required this.path,
    this.schemaFingerprint,
    this.warnings = const <String>[],
    this.duration,
  });

  final int rowCount;
  final String path;
  final String? schemaFingerprint;
  final List<String> warnings;
  final Duration? duration;

  factory ParquetExportResult.fromMap(Map<String, Object?> map) {
    return ParquetExportResult(
      rowCount: map['rowCount']! as int,
      path: map['path']! as String,
      schemaFingerprint: map['schemaFingerprint'] as String?,
      warnings: (map['warnings'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
    );
  }
}
