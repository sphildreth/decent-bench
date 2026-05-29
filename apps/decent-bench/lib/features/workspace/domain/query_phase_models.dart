import 'dart:convert';

import 'sql_error_location.dart';
import 'workspace_model_helpers.dart';
import 'native_type_models.dart';

enum QueryPhase {
  idle,
  opening,
  running,
  fetching,
  cancelling,
  completed,
  cancelled,
  failed,
}

enum QueryErrorStage { validation, opening, paging, cancellation, export }

enum QueryMessageLevel { info, warning, error }

enum QueryHistoryOutcome { completed, failed, cancelled }

class BridgeFailure implements Exception {
  final String message;
  final String? code;

  const BridgeFailure(this.message, {this.code});

  @override
  String toString() => code == null ? message : '$code: $message';
}

class QueryErrorDetails {
  const QueryErrorDetails({
    required this.stage,
    required this.message,
    this.code,
    this.location,
  });

  final QueryErrorStage stage;
  final String message;
  final String? code;
  final QueryErrorLocation? location;

  factory QueryErrorDetails.fromError(
    Object error, {
    required QueryErrorStage stage,
    String? executedSql,
    String? bufferText,
    int bufferStartOffset = 0,
  }) {
    if (error is QueryErrorDetails) {
      if (error.location != null ||
          executedSql == null ||
          bufferText == null ||
          executedSql.trim().isEmpty) {
        return error;
      }
      return QueryErrorDetails(
        stage: error.stage,
        message: error.message,
        code: error.code,
        location: resolveQueryErrorLocation(
          message: error.message,
          executedSql: executedSql,
          bufferText: bufferText,
          bufferStartOffset: bufferStartOffset,
        ),
      );
    }
    final message = error is BridgeFailure ? error.message : error.toString();
    final code = error is BridgeFailure ? error.code : null;
    final location =
        executedSql != null &&
            bufferText != null &&
            executedSql.trim().isNotEmpty
        ? resolveQueryErrorLocation(
            message: message,
            executedSql: executedSql,
            bufferText: bufferText,
            bufferStartOffset: bufferStartOffset,
          )
        : null;
    if (error is BridgeFailure) {
      return QueryErrorDetails(
        stage: stage,
        message: message,
        code: code,
        location: location,
      );
    }
    return QueryErrorDetails(
      stage: stage,
      message: message,
      code: code,
      location: location,
    );
  }

  String get stageLabel {
    switch (stage) {
      case QueryErrorStage.validation:
        return 'Validation';
      case QueryErrorStage.opening:
        return 'Open';
      case QueryErrorStage.paging:
        return 'Paging';
      case QueryErrorStage.cancellation:
        return 'Cancellation';
      case QueryErrorStage.export:
        return 'Export';
    }
  }

  String toClipboardText({String? sql}) {
    final buffer = StringBuffer()
      ..writeln('Stage: $stageLabel')
      ..writeln('Message: $message');
    if (code != null) {
      buffer.writeln('Code: $code');
    }
    if (location != null) {
      buffer.writeln('Location: ${location!.shortLabel}');
    }
    if (sql != null && sql.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('SQL:')
        ..writeln(sql.trim());
    }
    return buffer.toString().trimRight();
  }
}

class DatabaseSession {
  const DatabaseSession({required this.path, required this.engineVersion});

  final String path;
  final String engineVersion;

  factory DatabaseSession.fromMap(Map<String, Object?> map) {
    return DatabaseSession(
      path: map['path']! as String,
      engineVersion: map['engineVersion']! as String,
    );
  }
}

class QueuedWriteResult {
  const QueuedWriteResult({required this.rowsAffected});

  final int rowsAffected;

  factory QueuedWriteResult.fromMap(Map<String, Object?> map) {
    return QueuedWriteResult(rowsAffected: map['rowsAffected']! as int);
  }
}

class OperationalMetricsSnapshot {
  const OperationalMetricsSnapshot({required this.views});

  final List<OperationalMetricView> views;

  bool get hasAvailableViews => views.any((view) => view.available);

  OperationalMetricView? view(String name) {
    for (final view in views) {
      if (view.name == name) {
        return view;
      }
    }
    return null;
  }

  factory OperationalMetricsSnapshot.empty() {
    return const OperationalMetricsSnapshot(views: <OperationalMetricView>[]);
  }

  factory OperationalMetricsSnapshot.fromMap(Map<String, Object?> map) {
    return OperationalMetricsSnapshot(
      views: ((map['views'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (view) => OperationalMetricView.fromMap(
              view.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(growable: false),
    );
  }
}

class OperationalMetricView {
  const OperationalMetricView({
    required this.name,
    required this.label,
    required this.query,
    required this.available,
    required this.columns,
    required this.rows,
    this.error,
    this.truncated = false,
  });

  final String name;
  final String label;
  final String query;
  final bool available;
  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final String? error;
  final bool truncated;

  int get rowCount => rows.length;

  factory OperationalMetricView.fromMap(Map<String, Object?> map) {
    return OperationalMetricView(
      name: map['name']! as String,
      label: map['label']! as String,
      query: map['query']! as String,
      available: map['available']! as bool,
      columns: ((map['columns'] as List?) ?? const <Object?>[]).cast<String>(),
      rows: ((map['rows'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (row) => row.map(
              (key, value) => MapEntry(key as String, _decodeMetricCell(value)),
            ),
          )
          .toList(growable: false),
      error: map['error'] as String?,
      truncated: map['truncated'] as bool? ?? false,
    );
  }

  static Object? _decodeMetricCell(Object? value) {
    return _decodeQueryResultCell(value);
  }
}

Object? _decodeQueryResultCell(Object? value) {
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
