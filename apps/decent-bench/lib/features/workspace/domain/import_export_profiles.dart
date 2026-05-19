import 'dart:convert';
import 'dart:io';

class ImportExportProfileDocument {
  const ImportExportProfileDocument({
    required this.configVersion,
    required this.importPlan,
    required this.exportProfiles,
  });

  final int configVersion;
  final ImportPlanProfile importPlan;
  final List<ExportProfile> exportProfiles;

  static const int currentVersion = 1;

  factory ImportExportProfileDocument.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Profile document must be a JSON object.');
    }
    return ImportExportProfileDocument.fromJson(decoded);
  }

  factory ImportExportProfileDocument.fromJson(Map<String, Object?> map) {
    final version = _asInt(map['config_version']) ?? currentVersion;
    if (version != currentVersion) {
      throw FormatException('Unsupported profile config_version: $version.');
    }
    final importMap = _asStringMap(map['import']) ?? const <String, Object?>{};
    final exportItems = (map['exports'] as List? ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) => ExportProfile.fromJson(_stringMap(item)))
        .toList();
    return ImportExportProfileDocument(
      configVersion: version,
      importPlan: ImportPlanProfile.fromJson(importMap),
      exportProfiles: exportItems,
    );
  }

  static Future<ImportExportProfileDocument> loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FormatException('Profile file not found: $path');
    }
    return ImportExportProfileDocument.fromJsonString(
      await file.readAsString(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'config_version': configVersion,
      'import': importPlan.toJson(),
      'exports': <Map<String, Object?>>[
        for (final profile in exportProfiles) profile.toJson(),
      ],
    };
  }
}

class ImportPlanProfile {
  const ImportPlanProfile({
    this.name = '',
    this.sourceFormat,
    this.headerRow,
    this.delimiter,
    this.nativeTypeMappings = const <String, String>{},
    this.tableTargets = const <String, String>{},
  });

  final String name;
  final String? sourceFormat;
  final bool? headerRow;
  final String? delimiter;
  final Map<String, String> nativeTypeMappings;
  final Map<String, String> tableTargets;

  factory ImportPlanProfile.fromJson(Map<String, Object?> map) {
    return ImportPlanProfile(
      name: map['name'] as String? ?? '',
      sourceFormat: map['source_format'] as String?,
      headerRow: map['header_row'] as bool?,
      delimiter: map['delimiter'] as String?,
      nativeTypeMappings: _stringStringMap(map['native_type_mappings']),
      tableTargets: _stringStringMap(map['table_targets']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'source_format': sourceFormat,
      'header_row': headerRow,
      'delimiter': delimiter,
      'native_type_mappings': nativeTypeMappings,
      'table_targets': tableTargets,
    };
  }
}

class ExportProfile {
  const ExportProfile({
    required this.id,
    required this.name,
    required this.format,
    this.outputDirectory = '',
    this.includeHeaders = true,
    this.delimiter = ',',
    this.includeMetadata = true,
    this.nativeTypeMode = 'lossless',
  });

  final String id;
  final String name;
  final String format;
  final String outputDirectory;
  final bool includeHeaders;
  final String delimiter;
  final bool includeMetadata;
  final String nativeTypeMode;

  factory ExportProfile.fromJson(Map<String, Object?> map) {
    final id = map['id'] as String? ?? '';
    final name = map['name'] as String? ?? '';
    final format = map['format'] as String? ?? '';
    if (id.trim().isEmpty) {
      throw const FormatException('Export profile is missing id.');
    }
    if (name.trim().isEmpty) {
      throw const FormatException('Export profile is missing name.');
    }
    if (format.trim().isEmpty) {
      throw const FormatException('Export profile is missing format.');
    }
    return ExportProfile(
      id: id,
      name: name,
      format: format,
      outputDirectory: map['output_dir'] as String? ?? '',
      includeHeaders: map['include_headers'] as bool? ?? true,
      delimiter: map['delimiter'] as String? ?? ',',
      includeMetadata: map['include_metadata'] as bool? ?? true,
      nativeTypeMode: map['native_type_mode'] as String? ?? 'lossless',
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'format': format,
      'output_dir': outputDirectory,
      'include_headers': includeHeaders,
      'delimiter': delimiter,
      'include_metadata': includeMetadata,
      'native_type_mode': nativeTypeMode,
    };
  }
}

Map<String, String> _stringStringMap(Object? value) {
  final map = _asStringMap(value);
  if (map == null) {
    return const <String, String>{};
  }
  return <String, String>{
    for (final entry in map.entries)
      if (entry.value is String) entry.key: entry.value! as String,
  };
}

Map<String, Object?>? _asStringMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map<Object?, Object?>) {
    return _stringMap(value);
  }
  return null;
}

Map<String, Object?> _stringMap(Map<Object?, Object?> value) {
  return value.map((key, value) => MapEntry(key.toString(), value));
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
