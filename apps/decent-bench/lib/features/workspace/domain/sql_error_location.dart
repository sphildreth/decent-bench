class QueryErrorLocation {
  const QueryErrorLocation({
    required this.offset,
    required this.line,
    required this.column,
    this.token,
  });

  final int offset;
  final int line;
  final int column;
  final String? token;

  String get shortLabel => 'L$line:C$column';
}

QueryErrorLocation? resolveQueryErrorLocation({
  required String message,
  required String executedSql,
  required String bufferText,
  required int bufferStartOffset,
}) {
  if (executedSql.trim().isEmpty || bufferText.isEmpty) {
    return null;
  }

  final lineColumnMatch = RegExp(
    r'\bline\s+(\d+)(?:\s*[,:\-]?\s*column\s+(\d+))?',
    caseSensitive: false,
  ).firstMatch(message);
  if (lineColumnMatch != null) {
    final line = int.tryParse(lineColumnMatch.group(1) ?? '');
    final column = int.tryParse(lineColumnMatch.group(2) ?? '') ?? 1;
    if (line != null && line > 0) {
      return _buildLocation(
        relativeOffset: _offsetForLineColumn(executedSql, line, column),
        bufferText: bufferText,
        bufferStartOffset: bufferStartOffset,
      );
    }
  }

  final offsetMatch = RegExp(
    r'\b(?:offset|position|pos)\s*[:=]?\s*(\d+)\b',
    caseSensitive: false,
  ).firstMatch(message);
  if (offsetMatch != null) {
    final rawOffset = int.tryParse(offsetMatch.group(1) ?? '');
    if (rawOffset != null) {
      final relativeOffset = rawOffset <= 0 ? 0 : rawOffset - 1;
      return _buildLocation(
        relativeOffset: relativeOffset,
        bufferText: bufferText,
        bufferStartOffset: bufferStartOffset,
      );
    }
  }

  final tokenMatch = RegExp(
    r"""\bnear\s+["'`]?([^\s"'`;:,()]+)["'`]?""",
    caseSensitive: false,
  ).firstMatch(message);
  final token = tokenMatch?.group(1);
  if (token == null || token.isEmpty) {
    return null;
  }

  final relativeOffset = executedSql.toLowerCase().indexOf(token.toLowerCase());
  if (relativeOffset < 0) {
    return null;
  }

  return _buildLocation(
    relativeOffset: relativeOffset,
    bufferText: bufferText,
    bufferStartOffset: bufferStartOffset,
    token: token,
  );
}

QueryErrorLocation _buildLocation({
  required int relativeOffset,
  required String bufferText,
  required int bufferStartOffset,
  String? token,
}) {
  final absoluteOffset = (bufferStartOffset + relativeOffset)
      .clamp(0, bufferText.length)
      .toInt();
  final line = _lineForOffset(bufferText, absoluteOffset);
  final column = _columnForOffset(bufferText, absoluteOffset);
  return QueryErrorLocation(
    offset: absoluteOffset,
    line: line,
    column: column,
    token: token,
  );
}

int _offsetForLineColumn(String sql, int line, int column) {
  final lines = sql.split('\n');
  if (lines.isEmpty) {
    return 0;
  }

  final clampedLineIndex = (line - 1).clamp(0, lines.length - 1);
  final linePrefix = lines
      .take(clampedLineIndex)
      .fold<int>(0, (sum, value) => sum + value.length + 1);
  final lineText = lines[clampedLineIndex];
  final clampedColumn = column <= 0
      ? 0
      : (column - 1).clamp(0, lineText.length).toInt();
  return linePrefix + clampedColumn;
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
