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
