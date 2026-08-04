class ExplainPlanNode {
  const ExplainPlanNode({
    required this.lineNumber,
    required this.depth,
    required this.operation,
    required this.detail,
    this.tableName,
    this.indexName,
    this.estimatedRows,
    this.estimatedCost,
    this.actualRows,
  });

  final int lineNumber;
  final int depth;
  final String operation;
  final String detail;
  final String? tableName;
  final String? indexName;
  final int? estimatedRows;
  final double? estimatedCost;
  final int? actualRows;
}

class ExplainPlanVisualization {
  const ExplainPlanVisualization({required this.nodes, required this.rawText});

  final List<ExplainPlanNode> nodes;
  final String rawText;

  bool get hasNodes => nodes.isNotEmpty;
}

/// Recognized plan operator kinds. Multi-word operators (e.g. `HASH JOIN`,
/// `STREAMING AGGREGATE`) are normalized to a single token here so that
/// downstream rendering can badge them deterministically.
const List<String> kKnownPlanOperators = <String>[
  'SCAN',
  'SEARCH',
  'FILTER',
  'SORT',
  'JOIN',
  'HASH JOIN',
  'INDEXED JOIN',
  'NESTED LOOP',
  'AGGREGATE',
  'STREAMING AGGREGATE',
  'PROJECTION',
  'LIMIT',
  'INSERT',
  'UPDATE',
  'DELETE',
  'VIEW SCAN',
  'EXPANDED VIEW',
];

ExplainPlanVisualization buildExplainPlanVisualization(
  List<Map<String, Object?>> rows,
  String columnName,
) {
  final lines = <String>[
    for (final row in rows)
      for (final line in _asLines(row[columnName])) line,
  ];
  return ExplainPlanVisualization(
    nodes: <ExplainPlanNode>[
      for (var index = 0; index < lines.length; index++)
        _parsePlanLine(index + 1, lines[index]),
    ],
    rawText: lines.join('\n'),
  );
}

List<String> _asLines(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  final text = value.toString();
  return text
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .toList();
}

ExplainPlanNode _parsePlanLine(int lineNumber, String line) {
  final depth = _lineDepth(line);
  final normalized = line
      .replaceFirst(RegExp(r'^[\s|`+\-\\]+'), '')
      .replaceFirst(RegExp(r'^\d+\s+'), '')
      .trim();
  final operation = _operationFor(normalized);
  return ExplainPlanNode(
    lineNumber: lineNumber,
    depth: depth,
    operation: operation,
    detail: normalized.isEmpty ? line.trim() : normalized,
    tableName: _extractTableName(normalized),
    indexName: _firstMatch(
      normalized,
      RegExp(
        r'\b(?:INDEX|USING\s+(?:COVERING\s+)?INDEX)\s+("?[\w.]+"?)',
        caseSensitive: false,
      ),
    ),
    estimatedRows: _numberAfter(
      normalized,
      RegExp(
        r'\b(?:est(?:imated)? rows?|rows?)\s*[=:]\s*(\d+)',
        caseSensitive: false,
      ),
    ),
    estimatedCost: _doubleAfter(
      normalized,
      RegExp(
        r'\b(?:est(?:imated)? cost|cost)\s*[=:]\s*(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
    ),
    actualRows: _numberAfter(
      normalized,
      RegExp(r'\bactual rows?\s*[=:]\s*(\d+)', caseSensitive: false),
    ),
  );
}

String? _extractTableName(String normalized) {
  return _firstMatch(
        normalized,
        RegExp(
          r'\b(?:TABLE|FROM|ON)\s+("?[\w.]+"?)',
          caseSensitive: false,
        ),
      ) ??
      _firstMatch(
        normalized,
        RegExp(
          r'(?:^|\s)(?:SCAN|SEARCH|VIEW\s+SCAN|EXPANDED\s+VIEW)\s+'
          r'("?[\w.]+"?)',
          caseSensitive: false,
        ),
      );
}

int _lineDepth(String line) {
  final leading = RegExp(r'^\s*').firstMatch(line)?.group(0)?.length ?? 0;
  if (leading > 0) {
    return leading ~/ 2;
  }
  var markerDepth = 0;
  for (final codeUnit in line.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    if (char == '|' ||
        char == '+' ||
        char == '-' ||
        char == '`' ||
        char == r'\') {
      markerDepth++;
      continue;
    }
    break;
  }
  return markerDepth ~/ 2;
}

String _operationFor(String detail) {
  final upper = detail.toUpperCase();
  // Iterate longest operators first so multi-word kinds like
  // `STREAMING AGGREGATE` and `HASH JOIN` match before their shorter
  // single-word prefixes (`AGGREGATE`, `JOIN`).
  final operatorsByLength = <String>[
    for (final operation in kKnownPlanOperators)
      if (operation.contains(' ')) operation,
    for (final operation in kKnownPlanOperators)
      if (!operation.contains(' ')) operation,
  ];
  for (final operation in operatorsByLength) {
    if (upper.startsWith(operation) ||
        upper.contains(' $operation ') ||
        upper.contains(' $operation\t')) {
      return operation;
    }
  }
  final first = RegExp(r'^[A-Z_]+').firstMatch(upper)?.group(0);
  return first == null || first.isEmpty ? 'STEP' : first;
}

String? _firstMatch(String text, RegExp pattern) {
  return pattern.firstMatch(text)?.group(1)?.replaceAll('"', '');
}

int? _numberAfter(String text, RegExp pattern) {
  final match = pattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1) ?? '');
}

double? _doubleAfter(String text, RegExp pattern) {
  final match = pattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  return double.tryParse(match.group(1) ?? '');
}
