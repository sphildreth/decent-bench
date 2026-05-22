class ImportModuleManifestException implements Exception {
  const ImportModuleManifestException(this.message);

  final String message;

  @override
  String toString() => 'ImportModuleManifestException: $message';
}

class ImportModuleManifestParser {
  const ImportModuleManifestParser();

  Map<String, Object?> parse(String source) {
    final root = <String, Object?>{};
    Map<String, Object?> current = root;
    String? currentArraySection;

    final lines = source.split(RegExp(r'\r?\n'));
    for (var index = 0; index < lines.length; index++) {
      final rawLine = lines[index];
      final line = _stripComment(rawLine).trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('[[') && line.endsWith(']]')) {
        final sectionName = line.substring(2, line.length - 2).trim();
        final list = root.putIfAbsent(
          sectionName,
          () => <Map<String, Object?>>[],
        );
        if (list is! List<Map<String, Object?>>) {
          throw ImportModuleManifestException(
            'Line ${index + 1}: section `$sectionName` conflicts with a scalar section.',
          );
        }
        final item = <String, Object?>{};
        list.add(item);
        current = item;
        currentArraySection = sectionName;
        continue;
      }
      if (line.startsWith('[') && line.endsWith(']')) {
        final sectionName = line.substring(1, line.length - 1).trim();
        final section = root.putIfAbsent(
          sectionName,
          () => <String, Object?>{},
        );
        if (section is! Map<String, Object?>) {
          throw ImportModuleManifestException(
            'Line ${index + 1}: section `$sectionName` conflicts with an array section.',
          );
        }
        current = section;
        currentArraySection = null;
        continue;
      }
      final equalsIndex = line.indexOf('=');
      if (equalsIndex <= 0) {
        throw ImportModuleManifestException(
          'Line ${index + 1}: expected `key = value`.',
        );
      }
      final key = line.substring(0, equalsIndex).trim();
      final valueText = line.substring(equalsIndex + 1).trim();
      if (key.isEmpty) {
        throw ImportModuleManifestException(
          'Line ${index + 1}: empty key is not allowed.',
        );
      }
      if (current.containsKey(key)) {
        final section = currentArraySection ?? 'section';
        throw ImportModuleManifestException(
          'Line ${index + 1}: duplicate key `$key` in $section.',
        );
      }
      if (valueText.startsWith('"""')) {
        final consumed = _parseMultilineString(
          lines: lines,
          startIndex: index,
          initialValue: valueText,
        );
        current[key] = consumed.value;
        index = consumed.endIndex;
        continue;
      }
      current[key] = _parseValue(valueText, index + 1);
    }
    return root;
  }

  String _stripComment(String line) {
    var inString = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"' && (index == 0 || line[index - 1] != '\\')) {
        inString = !inString;
      }
      if (char == '#' && !inString) {
        return line.substring(0, index);
      }
    }
    return line;
  }

  Object? _parseValue(String value, int lineNumber) {
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
    final integer = int.tryParse(value);
    if (integer != null) {
      return integer;
    }
    if (value.startsWith('"') && value.endsWith('"')) {
      return _unescape(value.substring(1, value.length - 1));
    }
    if (value.startsWith('[') && value.endsWith(']')) {
      final content = value.substring(1, value.length - 1).trim();
      if (content.isEmpty) {
        return <String>[];
      }
      return _splitArray(
        content,
        lineNumber,
      ).map((item) => _parseValue(item, lineNumber)).toList(growable: false);
    }
    throw ImportModuleManifestException(
      'Line $lineNumber: unsupported TOML value `$value`.',
    );
  }

  List<String> _splitArray(String content, int lineNumber) {
    final items = <String>[];
    final buffer = StringBuffer();
    var inString = false;
    for (var index = 0; index < content.length; index++) {
      final char = content[index];
      if (char == '"' && (index == 0 || content[index - 1] != '\\')) {
        inString = !inString;
      }
      if (char == ',' && !inString) {
        items.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    if (inString) {
      throw ImportModuleManifestException(
        'Line $lineNumber: unterminated string in array.',
      );
    }
    items.add(buffer.toString().trim());
    return items.where((item) => item.isNotEmpty).toList(growable: false);
  }

  String _unescape(String value) {
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\\', '\\');
  }

  _MultilineString _parseMultilineString({
    required List<String> lines,
    required int startIndex,
    required String initialValue,
  }) {
    var content = initialValue.substring(3);
    if (content.endsWith('"""') && content.length >= 3) {
      return _MultilineString(
        _unescape(content.substring(0, content.length - 3)),
        startIndex,
      );
    }
    final buffer = StringBuffer();
    if (content.isNotEmpty) {
      buffer.writeln(content);
    }
    for (var index = startIndex + 1; index < lines.length; index++) {
      final line = lines[index];
      final endIndex = line.indexOf('"""');
      if (endIndex >= 0) {
        buffer.write(line.substring(0, endIndex));
        return _MultilineString(_unescape(buffer.toString()), index);
      }
      buffer.writeln(line);
    }
    throw ImportModuleManifestException(
      'Line ${startIndex + 1}: unterminated multiline string.',
    );
  }
}

class _MultilineString {
  const _MultilineString(this.value, this.endIndex);

  final String value;
  final int endIndex;
}
