import 'package:flutter/services.dart';

import 'sql_editor_selection.dart';

enum SqlExecutionTargetKind { buffer, selection, statement }

class SqlExecutionTarget {
  const SqlExecutionTarget({
    required this.kind,
    required this.sql,
    required this.startOffset,
    required this.endOffset,
    required this.startLine,
    required this.startColumn,
    required this.lineCount,
  });

  final SqlExecutionTargetKind kind;
  final String sql;
  final int startOffset;
  final int endOffset;
  final int startLine;
  final int startColumn;
  final int lineCount;

  bool get hasRunnableSql => sql.trim().isNotEmpty;
  bool get isBufferTarget => kind == SqlExecutionTargetKind.buffer;

  String get runLabel {
    return switch (kind) {
      SqlExecutionTargetKind.buffer => 'Run',
      SqlExecutionTargetKind.selection => 'Run Selection',
      SqlExecutionTargetKind.statement => 'Run Statement',
    };
  }

  String? get contextLabel {
    return switch (kind) {
      SqlExecutionTargetKind.buffer => null,
      SqlExecutionTargetKind.selection =>
        '$lineCount line${lineCount == 1 ? '' : 's'} selected',
      SqlExecutionTargetKind.statement => 'Statement L$startLine:C$startColumn',
    };
  }
}

SqlExecutionTarget resolveSqlBufferTarget(TextEditingValue value) {
  final bounds = _trimmedBounds(value.text, 0, value.text.length);
  return _buildTarget(
    kind: SqlExecutionTargetKind.buffer,
    text: value.text,
    startOffset: bounds.$1,
    endOffset: bounds.$2,
  );
}

SqlExecutionTarget resolveSqlExecutionTarget(TextEditingValue value) {
  final selectionInfo = resolveSqlEditorSelectionInfo(value);
  if (selectionInfo.hasRunnableSelection) {
    return _buildTarget(
      kind: SqlExecutionTargetKind.selection,
      text: value.text,
      startOffset: selectionInfo.selection.start,
      endOffset: selectionInfo.selection.end,
    );
  }

  final bufferTarget = resolveSqlBufferTarget(value);
  final statements = _parseStatements(value.text);
  if (statements.length <= 1) {
    return bufferTarget;
  }

  final caretOffset = value.selection.isValid && value.selection.baseOffset >= 0
      ? value.selection.baseOffset.clamp(0, value.text.length).toInt()
      : value.text.length;
  final statement = _statementForCaret(statements, caretOffset);
  if (statement == null) {
    return bufferTarget;
  }

  if (statement.startOffset == bufferTarget.startOffset &&
      statement.endOffset == bufferTarget.endOffset) {
    return bufferTarget;
  }

  return _buildTarget(
    kind: SqlExecutionTargetKind.statement,
    text: value.text,
    startOffset: statement.startOffset,
    endOffset: statement.endOffset,
  );
}

class _SqlStatementRange {
  const _SqlStatementRange({
    required this.startOffset,
    required this.endOffset,
  });

  final int startOffset;
  final int endOffset;
}

SqlExecutionTarget _buildTarget({
  required SqlExecutionTargetKind kind,
  required String text,
  required int startOffset,
  required int endOffset,
}) {
  final rawStart = startOffset.clamp(0, text.length).toInt();
  final rawEnd = endOffset.clamp(rawStart, text.length).toInt();
  final trimmedBounds = _trimmedBounds(text, rawStart, rawEnd);
  final safeStart = trimmedBounds.$1;
  final safeEnd = trimmedBounds.$2;
  final sql = text.substring(safeStart, safeEnd);
  final startLine = _lineForOffset(text, safeStart);
  final startColumn = _columnForOffset(text, safeStart);
  final lineCount = sql.isEmpty ? 0 : '\n'.allMatches(sql).length + 1;

  return SqlExecutionTarget(
    kind: kind,
    sql: sql,
    startOffset: safeStart,
    endOffset: safeEnd,
    startLine: startLine,
    startColumn: startColumn,
    lineCount: lineCount,
  );
}

List<_SqlStatementRange> _parseStatements(String text) {
  final statements = <_SqlStatementRange>[];
  var statementStart = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;
  var index = 0;

  while (index < text.length) {
    final current = text[index];
    final next = index + 1 < text.length ? text[index + 1] : null;

    if (inLineComment) {
      if (current == '\n') {
        inLineComment = false;
      }
      index++;
      continue;
    }

    if (inBlockComment) {
      if (current == '*' && next == '/') {
        inBlockComment = false;
        index += 2;
        continue;
      }
      index++;
      continue;
    }

    if (inSingleQuote) {
      if (current == '\'' && next == '\'') {
        index += 2;
        continue;
      }
      if (current == '\'') {
        inSingleQuote = false;
      }
      index++;
      continue;
    }

    if (inDoubleQuote) {
      if (current == '"' && next == '"') {
        index += 2;
        continue;
      }
      if (current == '"') {
        inDoubleQuote = false;
      }
      index++;
      continue;
    }

    if (current == '-' && next == '-') {
      inLineComment = true;
      index += 2;
      continue;
    }

    if (current == '/' && next == '*') {
      inBlockComment = true;
      index += 2;
      continue;
    }

    if (current == '\'') {
      inSingleQuote = true;
      index++;
      continue;
    }

    if (current == '"') {
      inDoubleQuote = true;
      index++;
      continue;
    }

    if (current == ';') {
      final bounds = _trimmedStatementBounds(text, statementStart, index + 1);
      if (bounds.$1 < bounds.$2) {
        statements.add(
          _SqlStatementRange(startOffset: bounds.$1, endOffset: bounds.$2),
        );
      }
      statementStart = index + 1;
    }

    index++;
  }

  final trailingBounds = _trimmedStatementBounds(
    text,
    statementStart,
    text.length,
  );
  if (trailingBounds.$1 < trailingBounds.$2) {
    statements.add(
      _SqlStatementRange(
        startOffset: trailingBounds.$1,
        endOffset: trailingBounds.$2,
      ),
    );
  }

  return statements;
}

_SqlStatementRange? _statementForCaret(
  List<_SqlStatementRange> statements,
  int caretOffset,
) {
  _SqlStatementRange? previous;
  for (final statement in statements) {
    if (caretOffset >= statement.startOffset &&
        caretOffset <= statement.endOffset) {
      return statement;
    }
    if (caretOffset < statement.startOffset) {
      return previous ?? statement;
    }
    previous = statement;
  }
  return previous;
}

(int, int) _trimmedStatementBounds(String text, int start, int end) {
  final bounds = _trimmedBounds(text, start, end);
  var leading = bounds.$1;
  final trailing = bounds.$2;

  while (leading < trailing) {
    if (_isWhitespace(text.codeUnitAt(leading))) {
      leading++;
      continue;
    }
    final current = text[leading];
    final next = leading + 1 < trailing ? text[leading + 1] : null;
    if (current == '-' && next == '-') {
      leading += 2;
      while (leading < trailing && text[leading] != '\n') {
        leading++;
      }
      continue;
    }
    if (current == '/' && next == '*') {
      leading += 2;
      while (leading + 1 < trailing) {
        if (text[leading] == '*' && text[leading + 1] == '/') {
          leading += 2;
          break;
        }
        leading++;
      }
      continue;
    }
    break;
  }

  return _trimmedBounds(text, leading, trailing);
}

(int, int) _trimmedBounds(String text, int start, int end) {
  var leading = start.clamp(0, text.length).toInt();
  var trailing = end.clamp(leading, text.length).toInt();

  while (leading < trailing && _isWhitespace(text.codeUnitAt(leading))) {
    leading++;
  }
  while (trailing > leading && _isWhitespace(text.codeUnitAt(trailing - 1))) {
    trailing--;
  }

  return (leading, trailing);
}

bool _isWhitespace(int codeUnit) {
  return codeUnit == 9 || codeUnit == 10 || codeUnit == 13 || codeUnit == 32;
}

int _lineForOffset(String text, int offset) {
  final clampedOffset = offset.clamp(0, text.length).toInt();
  if (clampedOffset == 0) {
    return 1;
  }
  return '\n'.allMatches(text.substring(0, clampedOffset)).length + 1;
}

int _columnForOffset(String text, int offset) {
  final clampedOffset = offset.clamp(0, text.length).toInt();
  final lastLineBreak = text.substring(0, clampedOffset).lastIndexOf('\n');
  return clampedOffset - (lastLineBreak + 1) + 1;
}
