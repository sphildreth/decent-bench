import 'dart:convert';

class AppConfig {
  static const int defaultPageSizeValue = 1000;
  static const String defaultCsvDelimiter = ',';
  static const bool defaultCsvIncludeHeaders = true;
  static const int maxRecentFiles = 8;

  final List<String> recentFiles;
  final int defaultPageSize;
  final String csvDelimiter;
  final bool csvIncludeHeaders;

  const AppConfig({
    required this.recentFiles,
    required this.defaultPageSize,
    required this.csvDelimiter,
    required this.csvIncludeHeaders,
  });

  factory AppConfig.defaults() {
    return const AppConfig(
      recentFiles: <String>[],
      defaultPageSize: defaultPageSizeValue,
      csvDelimiter: defaultCsvDelimiter,
      csvIncludeHeaders: defaultCsvIncludeHeaders,
    );
  }

  AppConfig copyWith({
    List<String>? recentFiles,
    int? defaultPageSize,
    String? csvDelimiter,
    bool? csvIncludeHeaders,
  }) {
    return AppConfig(
      recentFiles: recentFiles ?? this.recentFiles,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
      csvDelimiter: csvDelimiter ?? this.csvDelimiter,
      csvIncludeHeaders: csvIncludeHeaders ?? this.csvIncludeHeaders,
    );
  }

  AppConfig pushRecentFile(String path) {
    final updated = <String>[
      path,
      ...recentFiles.where((item) => item != path),
    ];
    return copyWith(recentFiles: updated.take(maxRecentFiles).toList());
  }

  String toToml() {
    final buffer = StringBuffer()
      ..writeln('# Decent Bench phase 1 configuration')
      ..writeln('default_page_size = $defaultPageSize')
      ..writeln('csv_delimiter = ${jsonEncode(csvDelimiter)}')
      ..writeln('csv_include_headers = $csvIncludeHeaders')
      ..writeln('recent_files = ${jsonEncode(recentFiles)}');
    return buffer.toString();
  }

  static AppConfig fromToml(String source) {
    var config = AppConfig.defaults();
    for (final rawLine in const LineSplitter().convert(source)) {
      final commentFree = rawLine.split('#').first.trim();
      if (commentFree.isEmpty || !commentFree.contains('=')) {
        continue;
      }

      final separatorIndex = commentFree.indexOf('=');
      final key = commentFree.substring(0, separatorIndex).trim();
      final value = commentFree.substring(separatorIndex + 1).trim();

      switch (key) {
        case 'default_page_size':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            config = config.copyWith(defaultPageSize: parsed);
          }
          break;
        case 'csv_delimiter':
          final parsed = _decodeJsonString(value);
          if (parsed != null && parsed.isNotEmpty) {
            config = config.copyWith(csvDelimiter: parsed);
          }
          break;
        case 'csv_include_headers':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(csvIncludeHeaders: parsed);
          }
          break;
        case 'recent_files':
          final parsed = _decodeStringList(value);
          if (parsed != null) {
            config = config.copyWith(
              recentFiles: parsed.take(maxRecentFiles).toList(),
            );
          }
          break;
      }
    }

    return config;
  }

  static String? _decodeJsonString(String raw) {
    try {
      final parsed = jsonDecode(raw);
      return parsed is String ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  static List<String>? _decodeStringList(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        return null;
      }
      return parsed.whereType<String>().toList();
    } catch (_) {
      return null;
    }
  }

  static bool? _parseBool(String raw) {
    if (raw == 'true') {
      return true;
    }
    if (raw == 'false') {
      return false;
    }
    return null;
  }
}
