import 'app_config.dart';
import 'sql_vocabulary.dart';

class SqlFormatter {
  const SqlFormatter();

  String format(String sql, {required EditorSettings settings}) {
    final trimmed = sql.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final protected = <String>[];
    var working = _protectLiteralsAndComments(trimmed, protected);

    working = working.replaceAll(RegExp(r'\s+'), ' ');
    working = working.replaceAll(RegExp(r'\s*,\s*'), ', ');
    working = working.replaceAll(RegExp(r'\s*\(\s*'), '(');
    working = working.replaceAll(RegExp(r'\s*\)\s*'), ')');
    working = working.replaceAllMapped(
      RegExp(r'\s*([=<>])\s*'),
      (match) => ' ${match.group(1)} ',
    );
    working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (settings.formatUppercaseKeywords) {
      working = _uppercaseKeywords(working);
    }

    for (final clause in _newlineClauses) {
      working = working.replaceAllMapped(
        RegExp('\\s+${RegExp.escape(clause)}\\b', caseSensitive: false),
        (_) => '\n$clause',
      );
    }

    working = working.replaceAllMapped(
      RegExp(r'\b(AND|OR)\b', caseSensitive: false),
      (match) => '\n  ${match.group(1)!.toUpperCase()}',
    );

    working = _reflowCreateTableDefinitions(working);
    working = _restoreProtectedSegments(working, protected);
    return _indentMultilineClauses(working, settings.indentSpaces).trim();
  }

  String _protectLiteralsAndComments(
    String sql,
    List<String> protectedSegments,
  ) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < sql.length) {
      final current = sql[index];
      if (current == "'" || current == '"') {
        final end = _consumeQuoted(sql, index, current);
        final placeholder = '__P${protectedSegments.length}__';
        protectedSegments.add(sql.substring(index, end));
        buffer.write(placeholder);
        index = end;
        continue;
      }
      if (sql.startsWith('--', index)) {
        final end = _consumeLineComment(sql, index);
        final placeholder = '__P${protectedSegments.length}__';
        protectedSegments.add(sql.substring(index, end));
        buffer.write(placeholder);
        index = end;
        continue;
      }
      if (sql.startsWith('/*', index)) {
        final end = _consumeBlockComment(sql, index);
        final placeholder = '__P${protectedSegments.length}__';
        protectedSegments.add(sql.substring(index, end));
        buffer.write(placeholder);
        index = end;
        continue;
      }
      buffer.write(current);
      index++;
    }
    return buffer.toString();
  }

  int _consumeQuoted(String sql, int start, String quote) {
    var index = start + 1;
    while (index < sql.length) {
      if (sql[index] == quote) {
        if (quote == "'" && index + 1 < sql.length && sql[index + 1] == quote) {
          index += 2;
          continue;
        }
        return index + 1;
      }
      index++;
    }
    return sql.length;
  }

  int _consumeLineComment(String sql, int start) {
    final nextNewline = sql.indexOf('\n', start);
    return nextNewline < 0 ? sql.length : nextNewline;
  }

  int _consumeBlockComment(String sql, int start) {
    final end = sql.indexOf('*/', start + 2);
    return end < 0 ? sql.length : end + 2;
  }

  String _uppercaseKeywords(String sql) {
    var working = sql;
    final combined = <String>{
      ...decentDbSqlKeywords,
      ...decentDbSqlFunctions,
    }.toList()..sort((left, right) => right.length.compareTo(left.length));
    for (final keyword in combined) {
      working = working.replaceAllMapped(
        RegExp('\\b${RegExp.escape(keyword)}\\b', caseSensitive: false),
        (_) => keyword.toUpperCase(),
      );
    }
    return working;
  }

  String _restoreProtectedSegments(String sql, List<String> protectedSegments) {
    var working = sql;
    for (var i = 0; i < protectedSegments.length; i++) {
      working = working.replaceAll('__P${i}__', protectedSegments[i]);
    }
    return working;
  }

  String _reflowCreateTableDefinitions(String sql) {
    final pattern = RegExp(
      r'\bCREATE\s+(?:TEMP\s+)?TABLE\b',
      caseSensitive: false,
    );
    final matches = pattern.allMatches(sql).toList(growable: false);
    if (matches.isEmpty) {
      return sql;
    }

    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) {
        continue;
      }

      final openParenIndex = _findCreateTableOpenParen(sql, match.end);
      if (openParenIndex < 0) {
        continue;
      }
      final closeParenIndex = _findMatchingParen(sql, openParenIndex);
      if (closeParenIndex < 0) {
        continue;
      }

      final definitions = _splitTopLevelCommaSeparated(
        sql.substring(openParenIndex + 1, closeParenIndex),
      );
      if (definitions.length <= 1) {
        continue;
      }

      buffer.write(sql.substring(cursor, openParenIndex + 1));
      buffer
        ..write('\n')
        ..write(definitions.join(',\n'));
      cursor = closeParenIndex;
    }

    if (cursor == 0) {
      return sql;
    }
    buffer.write(sql.substring(cursor));
    return buffer.toString();
  }

  int _findCreateTableOpenParen(String sql, int start) {
    final openParenIndex = sql.indexOf('(', start);
    if (openParenIndex < 0) {
      return -1;
    }
    final between = sql.substring(start, openParenIndex);
    if (RegExp(r'\bAS\b', caseSensitive: false).hasMatch(between)) {
      return -1;
    }
    return openParenIndex;
  }

  int _findMatchingParen(String sql, int openParenIndex) {
    var depth = 0;
    for (var index = openParenIndex; index < sql.length; index++) {
      final current = sql[index];
      if (current == '(') {
        depth++;
      } else if (current == ')') {
        depth--;
        if (depth == 0) {
          return index;
        }
      }
    }
    return -1;
  }

  List<String> _splitTopLevelCommaSeparated(String input) {
    final parts = <String>[];
    var depth = 0;
    var segmentStart = 0;
    for (var index = 0; index < input.length; index++) {
      final current = input[index];
      if (current == '(') {
        depth++;
        continue;
      }
      if (current == ')') {
        if (depth > 0) {
          depth--;
        }
        continue;
      }
      if (current == ',' && depth == 0) {
        final part = input.substring(segmentStart, index).trim();
        if (part.isNotEmpty) {
          parts.add(part);
        }
        segmentStart = index + 1;
      }
    }
    final tail = input.substring(segmentStart).trim();
    if (tail.isNotEmpty) {
      parts.add(tail);
    }
    return parts;
  }

  String _indentMultilineClauses(String sql, int indentSpaces) {
    final indent = ' ' * indentSpaces;
    final lines = sql
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return '';
    }

    final buffer = StringBuffer(lines.first.trimLeft());
    for (final line in lines.skip(1)) {
      final upper = line.trimLeft().toUpperCase();
      final shouldIndent =
          upper.startsWith('AND ') ||
          upper.startsWith('OR ') ||
          upper.startsWith('ON ') ||
          upper.startsWith('WHEN ') ||
          upper.startsWith('ELSE ');
      buffer
        ..writeln()
        ..write(shouldIndent ? '$indent${line.trimLeft()}' : line.trimLeft());
    }
    return buffer.toString();
  }
}

const List<String> _newlineClauses = <String>[
  'WITH RECURSIVE',
  'WITH',
  'SELECT',
  'FROM',
  'WHERE',
  'GROUP BY',
  'HAVING',
  'WINDOW',
  'ORDER BY',
  'LIMIT',
  'OFFSET',
  'INSERT INTO',
  'VALUES',
  'UPDATE',
  'SET',
  'DELETE FROM',
  'LEFT JOIN',
  'RIGHT JOIN',
  'INNER JOIN',
  'OUTER JOIN',
  'CROSS JOIN',
  'JOIN',
  'ON CONFLICT',
  'RETURNING',
  'EXPLAIN ANALYZE',
  'EXPLAIN',
  'UNION ALL',
  'UNION',
  'INTERSECT',
  'EXCEPT',
  'CREATE TABLE',
  'CREATE TEMP TABLE',
  'CREATE VIEW',
  'CREATE TEMP VIEW',
  'CREATE INDEX',
  'CREATE TRIGGER',
  'DROP TABLE',
  'DROP VIEW',
  'DROP INDEX',
  'DROP TRIGGER',
  'BEGIN',
  'SAVEPOINT',
  'RELEASE',
  'ROLLBACK',
  'COMMIT',
];
