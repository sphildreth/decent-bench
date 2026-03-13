import 'dart:convert';
import 'dart:typed_data';

import '../domain/import_models.dart';
import '../../workspace/domain/workspace_models.dart';

class TypeInferenceService {
  const TypeInferenceService();

  List<ImportColumnDraft> inferColumns(
    List<Map<String, Object?>> rows,
    Iterable<String> orderedKeys,
  ) {
    final columns = <ImportColumnDraft>[];
    for (final key in orderedKeys) {
      final values = rows.map((row) => row[key]).toList(growable: false);
      final containsNulls = values.any((value) => value == null);
      final inferred = inferTargetType(values, columnName: key);
      columns.add(
        ImportColumnDraft(
          sourceName: key,
          targetName: sanitizeIdentifier(key, fallbackPrefix: 'column'),
          inferredTargetType: inferred,
          targetType: inferred,
          containsNulls: containsNulls,
        ),
      );
    }
    return columns;
  }

  String inferTargetType(Iterable<Object?> values, {String? columnName}) {
    final nonNull = values
        .where((value) => value != null)
        .toList(growable: false);
    if (nonNull.isEmpty) {
      return 'TEXT';
    }
    if (_allValuesAreBooleans(nonNull, columnName: columnName)) {
      return 'BOOLEAN';
    }
    if (nonNull.every(_isUuidLike)) {
      return 'UUID';
    }
    if (_shouldAttemptTimestampInference(nonNull, columnName: columnName) &&
        nonNull.every(
          (value) => _isTimestampLike(
            value,
            allowEpoch: _looksLikeTemporalColumnName(columnName),
          ),
        )) {
      return 'TIMESTAMP';
    }
    if (nonNull.every(_isIntegerLike)) {
      if (nonNull.any(_hasLeadingZeroString)) {
        return 'TEXT';
      }
      return 'INTEGER';
    }
    if (_allValuesAreDecimals(nonNull, columnName: columnName)) {
      return 'DECIMAL(18,6)';
    }
    if (nonNull.every(_isDoubleLike)) {
      return 'FLOAT64';
    }
    if (nonNull.every((value) => value is Uint8List)) {
      return 'BLOB';
    }
    return 'TEXT';
  }

  Object? coerceValue(Object? value, String targetType) {
    if (value == null) {
      return null;
    }
    if (targetType == 'TEXT') {
      if (value is Uint8List) {
        return formatCellValue(value);
      }
      if (value is List || value is Map) {
        return jsonEncode(value);
      }
      return '$value';
    }
    if (targetType == 'BOOLEAN') {
      return _coerceBooleanValue(value);
    }
    if (targetType == 'INTEGER') {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value.trim()) ?? value;
      }
      return value;
    }
    if (targetType == 'FLOAT64') {
      return _tryParseFloat64Value(value) ?? value;
    }
    if (targetType == 'BLOB') {
      if (value is Uint8List) {
        return value;
      }
      if (value is String) {
        return Uint8List.fromList(value.codeUnits);
      }
      return Uint8List.fromList(utf8.encode('$value'));
    }
    if (targetType == 'TIMESTAMP') {
      if (value is DateTime) {
        return value.toUtc();
      }
      return _tryParseTimestampValue(value, allowEpoch: true) ?? value;
    }
    if (isDecimalTargetType(targetType)) {
      if (value is num) {
        return value.toString();
      }
      return '$value';
    }
    if (isUuidTargetType(targetType)) {
      return '$value';
    }
    return value;
  }

  String sanitizeIdentifier(String raw, {required String fallbackPrefix}) {
    final trimmed = raw.trim();
    final normalized = trimmed
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) {
      return '${fallbackPrefix}_1';
    }
    final startsWithDigit = RegExp(r'^[0-9]').hasMatch(normalized);
    return startsWithDigit ? '${fallbackPrefix}_$normalized' : normalized;
  }

  List<String> distinctTargetNames(
    Iterable<String> rawNames, {
    required String fallbackPrefix,
  }) {
    final used = <String>{};
    final result = <String>[];
    for (final rawName in rawNames) {
      final base = sanitizeIdentifier(rawName, fallbackPrefix: fallbackPrefix);
      var candidate = base;
      var suffix = 2;
      while (used.contains(candidate)) {
        candidate = '${base}_$suffix';
        suffix++;
      }
      used.add(candidate);
      result.add(candidate);
    }
    return result;
  }

  bool _allValuesAreBooleans(List<Object?> values, {String? columnName}) {
    if (values.isEmpty) {
      return false;
    }
    if (!values.every((value) => _normalizedBooleanToken(value) != null)) {
      return false;
    }

    final numericOnly = values.every(_isNumericBooleanValue);
    if (!numericOnly) {
      return true;
    }

    if (_looksLikeBooleanColumnName(columnName)) {
      return true;
    }

    return values
            .map(_normalizedBooleanToken)
            .whereType<String>()
            .toSet()
            .length >
        1;
  }

  bool _isIntegerLike(Object? value) {
    if (value is int) {
      return true;
    }
    if (value is double) {
      return value == value.roundToDouble();
    }
    return value is String && int.tryParse(value.trim()) != null;
  }

  bool _hasLeadingZeroString(Object? value) {
    if (value is! String) {
      return false;
    }
    final trimmed = value.trim();
    return trimmed.length > 1 && trimmed.startsWith('0');
  }

  bool _isDoubleLike(Object? value) {
    return _tryParseFloat64Value(value) != null;
  }

  bool _allValuesAreDecimals(List<Object?> values, {String? columnName}) {
    if (!_looksLikeDecimalColumnName(columnName) || values.isEmpty) {
      return false;
    }
    return values.every(_isFixedPrecisionDecimalLike) &&
        values.any(_hasDecimalPoint);
  }

  bool _shouldAttemptTimestampInference(
    List<Object?> values, {
    String? columnName,
  }) {
    if (_looksLikeTemporalColumnName(columnName)) {
      return true;
    }
    return values.any(_hasExplicitTemporalShape);
  }

  bool _isTimestampLike(Object? value, {required bool allowEpoch}) {
    return _tryParseTimestampValue(value, allowEpoch: allowEpoch) != null;
  }

  bool _hasExplicitTemporalShape(Object? value) {
    if (value is DateTime) {
      return true;
    }
    if (value is! String) {
      return false;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return RegExp(r'^\d{4}-\d{1,2}-\d{1,2}(?:[ T]|$)').hasMatch(trimmed) ||
        RegExp(r'^\d{1,2}\/\d{1,2}\/\d{4}(?:[ T]|$)').hasMatch(trimmed) ||
        RegExp(r'^\d{1,2}\.\d{1,2}\.\d{4}(?:[ T]|$)').hasMatch(trimmed) ||
        RegExp(r'^\d{1,2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?$').hasMatch(trimmed);
  }

  bool _isFixedPrecisionDecimalLike(Object? value) {
    if (value is num) {
      final asDouble = value.toDouble();
      return asDouble.isFinite;
    }
    if (value is! String) {
      return false;
    }
    final trimmed = value.trim();
    return RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(trimmed);
  }

  bool _hasDecimalPoint(Object? value) {
    if (value is num) {
      return value is double || value.toString().contains('.');
    }
    return value is String && value.contains('.');
  }

  double? _tryParseFloat64Value(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    switch (trimmed.toLowerCase()) {
      case 'inf':
      case '+inf':
      case 'infinity':
      case '+infinity':
        return double.infinity;
      case '-inf':
      case '-infinity':
        return double.negativeInfinity;
      case 'nan':
      case '#num!':
        return double.nan;
    }
    return double.tryParse(trimmed);
  }

  Object? _coerceBooleanValue(Object? value) {
    final normalized = _normalizedBooleanToken(value);
    return switch (normalized) {
      'true' => true,
      'false' => false,
      _ => value,
    };
  }

  String? _normalizedBooleanToken(Object? value) {
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    if (value is int) {
      if (value == 1) {
        return 'true';
      }
      if (value == 0) {
        return 'false';
      }
      return null;
    }
    if (value is double && value == value.roundToDouble()) {
      return _normalizedBooleanToken(value.toInt());
    }
    if (value is! String) {
      return null;
    }
    return switch (value.trim().toLowerCase()) {
      'true' ||
      't' ||
      '1' ||
      'yes' ||
      'y' ||
      'on' ||
      'enabled' ||
      'active' => 'true',
      'false' ||
      'f' ||
      '0' ||
      'no' ||
      'n' ||
      'off' ||
      'disabled' ||
      'inactive' => 'false',
      _ => null,
    };
  }

  bool _isNumericBooleanValue(Object? value) {
    if (value is int) {
      return value == 0 || value == 1;
    }
    if (value is double && value == value.roundToDouble()) {
      return value == 0 || value == 1;
    }
    if (value is! String) {
      return false;
    }
    return value.trim() == '0' || value.trim() == '1';
  }

  DateTime? _tryParseTimestampValue(Object? value, {required bool allowEpoch}) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is int) {
      return allowEpoch ? _tryParseEpochTimestamp(value) : null;
    }
    if (value is double && value == value.roundToDouble()) {
      return allowEpoch ? _tryParseEpochTimestamp(value.toInt()) : null;
    }
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return parsed.toUtc();
    }

    final slashParsed = _tryParseSlashDateTime(trimmed);
    if (slashParsed != null) {
      return slashParsed;
    }

    final dotParsed = _tryParseDotDateTime(trimmed);
    if (dotParsed != null) {
      return dotParsed;
    }

    final timeOnlyParsed = _tryParseTimeOnlyDateTime(trimmed);
    if (timeOnlyParsed != null) {
      return timeOnlyParsed;
    }

    if (!allowEpoch) {
      return null;
    }
    final asInteger = int.tryParse(trimmed);
    if (asInteger == null) {
      return null;
    }
    return _tryParseEpochTimestamp(asInteger);
  }

  DateTime? _tryParseTimeOnlyDateTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    final microsRaw = match.group(4) ?? '';
    final micros = microsRaw.isEmpty
        ? 0
        : int.parse(microsRaw.padRight(6, '0').substring(0, 6));
    return _buildUtcTimestamp(
      year: 0,
      month: 1,
      day: 1,
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
      second: int.tryParse(match.group(3) ?? '0') ?? 0,
      microsecond: micros,
    );
  }

  DateTime? _tryParseSlashDateTime(String value) {
    final match = RegExp(
      r'^(\d{1,2})\/(\d{1,2})\/(\d{4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    return _buildUtcTimestamp(
      year: int.parse(match.group(3)!),
      month: int.parse(match.group(1)!),
      day: int.parse(match.group(2)!),
      hour: int.tryParse(match.group(4) ?? '0') ?? 0,
      minute: int.tryParse(match.group(5) ?? '0') ?? 0,
      second: int.tryParse(match.group(6) ?? '0') ?? 0,
    );
  }

  DateTime? _tryParseDotDateTime(String value) {
    final match = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    return _buildUtcTimestamp(
      year: int.parse(match.group(3)!),
      month: int.parse(match.group(2)!),
      day: int.parse(match.group(1)!),
      hour: int.tryParse(match.group(4) ?? '0') ?? 0,
      minute: int.tryParse(match.group(5) ?? '0') ?? 0,
      second: int.tryParse(match.group(6) ?? '0') ?? 0,
    );
  }

  DateTime? _buildUtcTimestamp({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int microsecond = 0,
  }) {
    try {
      final parsed = DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
        0,
        microsecond,
      );
      if (parsed.year != year ||
          parsed.month != month ||
          parsed.day != day ||
          parsed.hour != hour ||
          parsed.minute != minute ||
          parsed.second != second ||
          parsed.microsecond != microsecond) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  DateTime? _tryParseEpochTimestamp(int value) {
    if (value >= 0 && value <= 4102444800) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value >= 0 && value <= 4102444800000) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return null;
  }

  bool _looksLikeTemporalColumnName(String? columnName) {
    if (columnName == null) {
      return false;
    }
    final normalized = columnName.trim().toLowerCase();
    return RegExp(
      r'(^|_)(date|time|datetime|timestamp|epoch)(_|$)|_at$',
    ).hasMatch(normalized);
  }

  bool _looksLikeBooleanColumnName(String? columnName) {
    if (columnName == null) {
      return false;
    }
    final normalized = columnName.trim().toLowerCase();
    return RegExp(
      r'(^is_|^has_|(^|_)(bool|boolean|flag|enabled|disabled|active|inactive)(_|$))',
    ).hasMatch(normalized);
  }

  bool _looksLikeDecimalColumnName(String? columnName) {
    if (columnName == null) {
      return false;
    }
    return RegExp(
      r'(^|_)(decimal|numeric)(_|$)',
    ).hasMatch(columnName.trim().toLowerCase());
  }

  bool _isUuidLike(Object? value) {
    if (value is! String) {
      return false;
    }
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }
}
