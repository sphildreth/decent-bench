import 'dart:math' as math;

import 'workspace_models.dart';

class ColumnStatistics {
  const ColumnStatistics({
    required this.columnName,
    required this.loadedRowCount,
    required this.nonNullCount,
    required this.nullCount,
    required this.distinctCount,
    required this.topValues,
    this.nativeType,
    this.numericMin,
    this.numericMax,
    this.numericAverage,
    this.temporalMin,
    this.temporalMax,
    this.stringMinLength,
    this.stringMaxLength,
  });

  final String columnName;
  final int loadedRowCount;
  final int nonNullCount;
  final int nullCount;
  final int distinctCount;
  final List<ColumnTopValue> topValues;
  final NativeTypeDescriptor? nativeType;
  final num? numericMin;
  final num? numericMax;
  final double? numericAverage;
  final DateTime? temporalMin;
  final DateTime? temporalMax;
  final int? stringMinLength;
  final int? stringMaxLength;

  double get nullRatio =>
      loadedRowCount == 0 ? 0 : nullCount / loadedRowCount.toDouble();

  bool get hasNumericSummary =>
      numericMin != null && numericMax != null && numericAverage != null;

  bool get hasTemporalSummary => temporalMin != null && temporalMax != null;

  bool get hasStringSummary =>
      stringMinLength != null && stringMaxLength != null;

  List<MapEntry<String, String>> get summaryRows {
    final rows = <MapEntry<String, String>>[
      MapEntry('Loaded rows', '$loadedRowCount'),
      MapEntry('Non-null', '$nonNullCount'),
      MapEntry('Nulls', '$nullCount (${_formatPercent(nullRatio)})'),
      MapEntry('Distinct', '$distinctCount'),
      if (nativeType != null) MapEntry('Type family', nativeType!.familyLabel),
    ];
    if (hasNumericSummary) {
      rows.addAll(<MapEntry<String, String>>[
        MapEntry('Min', '$numericMin'),
        MapEntry('Max', '$numericMax'),
        MapEntry('Average', numericAverage!.toStringAsFixed(3)),
      ]);
    }
    if (hasTemporalSummary) {
      rows.addAll(<MapEntry<String, String>>[
        MapEntry('Earliest', temporalMin!.toIso8601String()),
        MapEntry('Latest', temporalMax!.toIso8601String()),
      ]);
    }
    if (hasStringSummary) {
      rows.addAll(<MapEntry<String, String>>[
        MapEntry('Min length', '$stringMinLength'),
        MapEntry('Max length', '$stringMaxLength'),
      ]);
    }
    return rows;
  }

  String toClipboardText() {
    final buffer = StringBuffer()
      ..writeln('Column: $columnName')
      ..writeln('Loaded rows: $loadedRowCount')
      ..writeln('Non-null: $nonNullCount')
      ..writeln('Nulls: $nullCount (${_formatPercent(nullRatio)})')
      ..writeln('Distinct: $distinctCount');
    if (nativeType != null) {
      buffer.writeln('Type family: ${nativeType!.familyLabel}');
    }
    if (hasNumericSummary) {
      buffer
        ..writeln('Min: $numericMin')
        ..writeln('Max: $numericMax')
        ..writeln('Average: ${numericAverage!.toStringAsFixed(3)}');
    }
    if (hasTemporalSummary) {
      buffer
        ..writeln('Earliest: ${temporalMin!.toIso8601String()}')
        ..writeln('Latest: ${temporalMax!.toIso8601String()}');
    }
    if (topValues.isNotEmpty) {
      buffer.writeln('Top values:');
      for (final value in topValues) {
        buffer.writeln('- ${value.label}: ${value.count}');
      }
    }
    return buffer.toString().trimRight();
  }
}

class ColumnTopValue {
  const ColumnTopValue({required this.label, required this.count});

  final String label;
  final int count;
}

ColumnStatistics buildColumnStatistics({
  required String columnName,
  required List<Map<String, Object?>> rows,
  NativeTypeDescriptor? nativeType,
  int topValueLimit = 5,
}) {
  var nullCount = 0;
  var nonNullCount = 0;
  num? numericMin;
  num? numericMax;
  var numericSum = 0.0;
  var numericCount = 0;
  DateTime? temporalMin;
  DateTime? temporalMax;
  int? stringMinLength;
  int? stringMaxLength;
  final counts = <String, int>{};

  for (final row in rows) {
    final value = row[columnName];
    if (value == null) {
      nullCount++;
      continue;
    }
    nonNullCount++;
    final label = _valueLabel(value, nativeType: nativeType);
    counts[label] = (counts[label] ?? 0) + 1;

    final number = _asNumber(value);
    if (number != null) {
      numericMin = numericMin == null ? number : math.min(numericMin, number);
      numericMax = numericMax == null ? number : math.max(numericMax, number);
      numericSum += number.toDouble();
      numericCount++;
    }

    final temporal = _asDateTime(value);
    if (temporal != null) {
      temporalMin = temporalMin == null || temporal.isBefore(temporalMin)
          ? temporal
          : temporalMin;
      temporalMax = temporalMax == null || temporal.isAfter(temporalMax)
          ? temporal
          : temporalMax;
    }

    final stringLength = value is String ? value.length : null;
    if (stringLength != null) {
      stringMinLength = stringMinLength == null
          ? stringLength
          : math.min(stringMinLength, stringLength);
      stringMaxLength = stringMaxLength == null
          ? stringLength
          : math.max(stringMaxLength, stringLength);
    }
  }

  final topValues = counts.entries.toList()
    ..sort((left, right) {
      final byCount = right.value.compareTo(left.value);
      return byCount != 0 ? byCount : left.key.compareTo(right.key);
    });

  return ColumnStatistics(
    columnName: columnName,
    loadedRowCount: rows.length,
    nonNullCount: nonNullCount,
    nullCount: nullCount,
    distinctCount: counts.length,
    topValues: <ColumnTopValue>[
      for (final entry in topValues.take(topValueLimit))
        ColumnTopValue(label: entry.key, count: entry.value),
    ],
    nativeType: nativeType,
    numericMin: numericMin,
    numericMax: numericMax,
    numericAverage: numericCount == 0 ? null : numericSum / numericCount,
    temporalMin: temporalMin,
    temporalMax: temporalMax,
    stringMinLength: stringMinLength,
    stringMaxLength: stringMaxLength,
  );
}

num? _asNumber(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _valueLabel(Object value, {NativeTypeDescriptor? nativeType}) {
  if (value is NativeEnumCellValue) {
    return value.displayString(descriptor: nativeType);
  }
  return formatTypedCellValue(value, typeName: nativeType?.typeName);
}

String _formatPercent(double value) {
  return '${(value * 100).toStringAsFixed(1)}%';
}
