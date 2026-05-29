import 'dart:convert';
import 'dart:typed_data';

import 'workspace_model_helpers.dart';

enum NativeTypeFamily {
  numeric,
  boolean,
  text,
  binary,
  uuid,
  enumValue,
  temporal,
  network,
  macAddress,
  spatial,
  unknown,
}

class NativeTypeDescriptor {
  const NativeTypeDescriptor({
    required this.typeName,
    required this.baseTypeName,
    required this.family,
    this.valueKind,
    this.spatial,
    this.enumLabels = const <String>[],
  });

  final String typeName;
  final String baseTypeName;
  final NativeTypeFamily family;
  final String? valueKind;
  final ToolingSpatialTypeInfo? spatial;
  final List<String> enumLabels;

  bool get isNativeV25Type {
    return switch (family) {
      NativeTypeFamily.enumValue ||
      NativeTypeFamily.temporal ||
      NativeTypeFamily.network ||
      NativeTypeFamily.macAddress ||
      NativeTypeFamily.spatial => true,
      _ => false,
    };
  }

  bool get isSpatial => family == NativeTypeFamily.spatial;

  String get familyLabel {
    return switch (family) {
      NativeTypeFamily.numeric => 'Numeric',
      NativeTypeFamily.boolean => 'Boolean',
      NativeTypeFamily.text => 'Text',
      NativeTypeFamily.binary => 'Binary',
      NativeTypeFamily.uuid => 'UUID',
      NativeTypeFamily.enumValue => 'Enum',
      NativeTypeFamily.temporal => 'Temporal',
      NativeTypeFamily.network => 'Network',
      NativeTypeFamily.macAddress => 'MAC address',
      NativeTypeFamily.spatial => 'Spatial',
      NativeTypeFamily.unknown => 'Unknown',
    };
  }

  String get summaryLabel {
    final base = baseTypeName.isEmpty ? 'UNKNOWN' : baseTypeName;
    final parts = <String>['$base $familyLabel'];
    if (valueKind != null && valueKind!.trim().isNotEmpty) {
      parts.add('value kind ${valueKind!.trim()}');
    }
    final spatialInfo = spatial;
    if (spatialInfo != null) {
      parts.add(spatialInfo.summaryLabel);
    }
    if (enumLabels.isNotEmpty) {
      parts.add('labels ${enumLabels.join(", ")}');
    }
    return parts.join(' | ');
  }

  String? enumLabelForId(int labelId) {
    final index = labelId - 1;
    if (index < 0 || index >= enumLabels.length) {
      return null;
    }
    return enumLabels[index];
  }
}

class NativeEnumCellValue {
  const NativeEnumCellValue({required this.typeId, required this.labelId});

  final int typeId;
  final int labelId;

  String displayString({NativeTypeDescriptor? descriptor}) {
    final label = descriptor?.enumLabelForId(labelId);
    final identity = 'type $typeId, label $labelId';
    return label == null ? 'ENUM($identity)' : '$label ($identity)';
  }
}

class NativeIntervalCellValue {
  const NativeIntervalCellValue({
    required this.months,
    required this.days,
    required this.microseconds,
  });

  final int months;
  final int days;
  final int microseconds;

  String displayString() {
    final parts = <String>[
      if (months != 0) '${months}mo',
      if (days != 0) '${days}d',
      if (microseconds != 0) _formatTimeMicros(microseconds),
    ];
    return parts.isEmpty ? '0us' : parts.join(' ');
  }
}

NativeTypeDescriptor describeNativeType({
  String? typeName,
  String? valueKind,
  ToolingSpatialTypeInfo? spatial,
}) {
  final rawType = typeName?.trim() ?? '';
  final baseType = baseTypeName(rawType);
  final family = nativeTypeFamily(baseType, valueKind: valueKind);
  return NativeTypeDescriptor(
    typeName: rawType,
    baseTypeName: baseType,
    family: family,
    valueKind: valueKind,
    spatial: spatial,
    enumLabels: family == NativeTypeFamily.enumValue
        ? parseEnumLabels(rawType)
        : const <String>[],
  );
}

String formatCellValue(Object? value) {
  return formatTypedCellValue(value);
}

String formatTypedCellValue(Object? value, {String? typeName}) {
  if (value == null) {
    return 'NULL';
  }
  final descriptor = describeNativeType(typeName: typeName);
  if (value is NativeEnumCellValue) {
    return value.displayString(descriptor: descriptor);
  }
  if (value is NativeIntervalCellValue) {
    return value.displayString();
  }
  if (value is Duration) {
    return descriptor.baseTypeName == 'TIME'
        ? _formatTimeMicros(value.inMicroseconds)
        : '${value.inMicroseconds}us';
  }
  if (value is DateTime) {
    if (descriptor.baseTypeName == 'DATE') {
      final utc = value.toUtc();
      return '${utc.year.toString().padLeft(4, "0")}-'
          '${utc.month.toString().padLeft(2, "0")}-'
          '${utc.day.toString().padLeft(2, "0")}';
    }
    return value.toIso8601String();
  }
  if (value is Uint8List) {
    if (descriptor.isSpatial) {
      final type = descriptor.baseTypeName.isEmpty
          ? 'SPATIAL'
          : descriptor.baseTypeName;
      return '$type EWKB (${value.length} bytes)';
    }
    if (descriptor.baseTypeName == 'UUID' && value.length == 16) {
      return _formatUuidBytes(value);
    }
    return base64Encode(value);
  }
  return '$value';
}

String formatSpatialWkbBase64(Object? value) {
  return value is Uint8List ? base64Encode(value) : formatCellValue(value);
}

class ToolingSpatialTypeInfo {
  const ToolingSpatialTypeInfo({
    required this.subtype,
    required this.dimensions,
    required this.srid,
  });

  final String subtype;
  final String dimensions;
  final int srid;

  String get summaryLabel {
    final parts = <String>[
      if (subtype.trim().isNotEmpty) subtype.trim(),
      if (dimensions.trim().isNotEmpty) dimensions.trim(),
      if (srid != 0) 'SRID $srid',
    ];
    return parts.isEmpty ? 'spatial metadata unavailable' : parts.join(' ');
  }

  factory ToolingSpatialTypeInfo.fromMap(Map<String, Object?> map) {
    return ToolingSpatialTypeInfo(
      subtype: map['subtype'] as String? ?? '',
      dimensions: map['dimensions'] as String? ?? '',
      srid: asInt(map['srid']) ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'subtype': subtype,
      'dimensions': dimensions,
      'srid': srid,
    };
  }
}

String formatDecimalValue(int unscaled, int scale) {
  if (scale == 0) {
    return '$unscaled';
  }

  final negative = unscaled < 0;
  final digits = unscaled.abs().toString().padLeft(scale + 1, '0');
  final split = digits.length - scale;
  final whole = digits.substring(0, split);
  final fraction = digits.substring(split);
  return '${negative ? "-" : ""}$whole.$fraction';
}

String baseTypeName(String typeName) {
  final trimmed = typeName.trim().toUpperCase();
  if (trimmed.isEmpty) {
    return '';
  }
  final match = RegExp(r'^[A-Z][A-Z0-9_]*').firstMatch(trimmed);
  return match?.group(0) ?? trimmed;
}

NativeTypeFamily nativeTypeFamily(String baseType, {String? valueKind}) {
  final kind = valueKind?.trim().toLowerCase() ?? '';
  if (kind.contains('geometry') || kind.contains('geography')) {
    return NativeTypeFamily.spatial;
  }
  return switch (baseType) {
    'INT' ||
    'INTEGER' ||
    'INT64' ||
    'BIGINT' ||
    'FLOAT' ||
    'FLOAT64' ||
    'DOUBLE' ||
    'REAL' ||
    'DECIMAL' => NativeTypeFamily.numeric,
    'BOOL' || 'BOOLEAN' => NativeTypeFamily.boolean,
    'TEXT' || 'VARCHAR' || 'CHAR' || 'STRING' => NativeTypeFamily.text,
    'BLOB' || 'BYTES' => NativeTypeFamily.binary,
    'UUID' => NativeTypeFamily.uuid,
    'ENUM' => NativeTypeFamily.enumValue,
    'DATE' ||
    'TIME' ||
    'TIMESTAMP' ||
    'TIMESTAMPTZ' ||
    'INTERVAL' => NativeTypeFamily.temporal,
    'IPADDR' || 'INET' || 'CIDR' => NativeTypeFamily.network,
    'MACADDR' || 'MACADDR8' => NativeTypeFamily.macAddress,
    'GEOMETRY' || 'GEOGRAPHY' => NativeTypeFamily.spatial,
    _ => NativeTypeFamily.unknown,
  };
}

List<String> parseEnumLabels(String typeName) {
  final open = typeName.indexOf('(');
  final close = typeName.lastIndexOf(')');
  if (open < 0 || close <= open) {
    return const <String>[];
  }
  final labels = <String>[];
  final text = typeName.substring(open + 1, close);
  var index = 0;
  while (index < text.length) {
    while (index < text.length &&
        (text[index].trim().isEmpty || text[index] == ',')) {
      index++;
    }
    if (index >= text.length || text[index] != "'") {
      break;
    }
    index++;
    final label = StringBuffer();
    while (index < text.length) {
      final char = text[index];
      if (char == "'") {
        if (index + 1 < text.length && text[index + 1] == "'") {
          label.write("'");
          index += 2;
          continue;
        }
        index++;
        break;
      }
      label.write(char);
      index++;
    }
    labels.add(label.toString());
    while (index < text.length && text[index] != ',') {
      index++;
    }
  }
  return labels;
}

String _formatTimeMicros(int microseconds) {
  final negative = microseconds < 0;
  final absolute = microseconds.abs();
  final hours = absolute ~/ Duration.microsecondsPerHour;
  final minutes =
      (absolute % Duration.microsecondsPerHour) ~/
      Duration.microsecondsPerMinute;
  final seconds =
      (absolute % Duration.microsecondsPerMinute) ~/
      Duration.microsecondsPerSecond;
  final micros = absolute % Duration.microsecondsPerSecond;
  final base =
      '${hours.toString().padLeft(2, "0")}:'
      '${minutes.toString().padLeft(2, "0")}:'
      '${seconds.toString().padLeft(2, "0")}';
  final suffix = micros == 0 ? '' : '.${micros.toString().padLeft(6, "0")}';
  return '${negative ? "-" : ""}$base$suffix';
}

String _formatUuidBytes(Uint8List bytes) {
  final hex = <String>[
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
