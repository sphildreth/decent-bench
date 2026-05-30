import 'dart:convert';

enum ImportDefaultApplyMode { whenNull, whenNullOrEmpty, always }

enum ImportDeduplicationKeep { first, last }

enum ImportRowFilterOperator {
  equals,
  notEquals,
  lessThan,
  lessThanOrEqual,
  greaterThan,
  greaterThanOrEqual,
  contains,
  startsWith,
  endsWith,
  isNull,
  isNotNull,
}

class ImportTransformPlan {
  const ImportTransformPlan({
    this.rowFilters = const <ImportRowFilterTransform>[],
    this.defaultValues = const <ImportDefaultValueTransform>[],
    this.computedColumns = const <ImportComputedColumnTransform>[],
    this.columnOrder = const <String>[],
    this.deduplication,
  });

  final List<ImportRowFilterTransform> rowFilters;
  final List<ImportDefaultValueTransform> defaultValues;
  final List<ImportComputedColumnTransform> computedColumns;
  final List<String> columnOrder;
  final ImportDeduplicationTransform? deduplication;

  bool get isEmpty =>
      rowFilters.isEmpty &&
      defaultValues.isEmpty &&
      computedColumns.isEmpty &&
      columnOrder.isEmpty &&
      deduplication == null;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'rowFilters': <Map<String, Object?>>[
        for (final filter in rowFilters) filter.toMap(),
      ],
      'defaultValues': <Map<String, Object?>>[
        for (final transform in defaultValues) transform.toMap(),
      ],
      'computedColumns': <Map<String, Object?>>[
        for (final transform in computedColumns) transform.toMap(),
      ],
      'columnOrder': columnOrder,
      'deduplication': deduplication?.toMap(),
    };
  }

  factory ImportTransformPlan.fromMap(Map<String, Object?> map) {
    return ImportTransformPlan(
      rowFilters: _listOfMaps(
        map['rowFilters'] ?? map['row_filters'],
      ).map(ImportRowFilterTransform.fromMap).toList(growable: false),
      defaultValues: _listOfMaps(
        map['defaultValues'] ?? map['default_values'],
      ).map(ImportDefaultValueTransform.fromMap).toList(growable: false),
      computedColumns: _listOfMaps(
        map['computedColumns'] ?? map['computed_columns'],
      ).map(ImportComputedColumnTransform.fromMap).toList(growable: false),
      columnOrder:
          ((map['columnOrder'] ?? map['column_order']) as List? ??
                  const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      deduplication: _optionalMap(map['deduplication']) == null
          ? null
          : ImportDeduplicationTransform.fromMap(
              _optionalMap(map['deduplication'])!,
            ),
    );
  }
}

class ImportRowFilterTransform {
  const ImportRowFilterTransform({
    required this.columnName,
    required this.operator,
    this.value,
    this.keepWhenMatched = true,
  });

  final String columnName;
  final ImportRowFilterOperator operator;
  final Object? value;
  final bool keepWhenMatched;

  bool keeps(Map<String, Object?> row) {
    final matched = _matches(row[columnName], operator, value);
    return keepWhenMatched ? matched : !matched;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'columnName': columnName,
      'operator': operator.name,
      'value': value,
      'keepWhenMatched': keepWhenMatched,
    };
  }

  factory ImportRowFilterTransform.fromMap(Map<String, Object?> map) {
    return ImportRowFilterTransform(
      columnName: map['columnName'] as String? ?? map['column_name'] as String,
      operator: ImportRowFilterOperator.values.byName(
        map['operator'] as String? ?? ImportRowFilterOperator.equals.name,
      ),
      value: map['value'],
      keepWhenMatched:
          map['keepWhenMatched'] as bool? ??
          map['keep_when_matched'] as bool? ??
          true,
    );
  }
}

class ImportDefaultValueTransform {
  const ImportDefaultValueTransform({
    required this.columnName,
    required this.value,
    this.applyMode = ImportDefaultApplyMode.whenNull,
  });

  final String columnName;
  final Object? value;
  final ImportDefaultApplyMode applyMode;

  void apply(Map<String, Object?> row) {
    final current = row[columnName];
    final shouldApply = switch (applyMode) {
      ImportDefaultApplyMode.always => true,
      ImportDefaultApplyMode.whenNull => current == null,
      ImportDefaultApplyMode.whenNullOrEmpty =>
        current == null || current is String && current.isEmpty,
    };
    if (shouldApply) {
      row[columnName] = value;
    }
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'columnName': columnName,
      'value': value,
      'applyMode': applyMode.name,
    };
  }

  factory ImportDefaultValueTransform.fromMap(Map<String, Object?> map) {
    return ImportDefaultValueTransform(
      columnName: map['columnName'] as String? ?? map['column_name'] as String,
      value: map['value'],
      applyMode: ImportDefaultApplyMode.values.byName(
        map['applyMode'] as String? ??
            map['apply_mode'] as String? ??
            ImportDefaultApplyMode.whenNull.name,
      ),
    );
  }
}

class ImportComputedColumnTransform {
  const ImportComputedColumnTransform({
    required this.columnName,
    required this.targetType,
    required this.expression,
  });

  final String columnName;
  final String targetType;
  final ImportExpression expression;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'columnName': columnName,
      'targetType': targetType,
      'expression': expression.toMap(),
    };
  }

  factory ImportComputedColumnTransform.fromMap(Map<String, Object?> map) {
    return ImportComputedColumnTransform(
      columnName: map['columnName'] as String? ?? map['column_name'] as String,
      targetType:
          map['targetType'] as String? ??
          map['target_type'] as String? ??
          'TEXT',
      expression: ImportExpression.fromMap(_requiredMap(map['expression'])),
    );
  }
}

class ImportDeduplicationTransform {
  const ImportDeduplicationTransform({
    required this.keyColumns,
    this.keep = ImportDeduplicationKeep.first,
  });

  final List<String> keyColumns;
  final ImportDeduplicationKeep keep;

  Map<String, Object?> toMap() {
    return <String, Object?>{'keyColumns': keyColumns, 'keep': keep.name};
  }

  factory ImportDeduplicationTransform.fromMap(Map<String, Object?> map) {
    return ImportDeduplicationTransform(
      keyColumns:
          ((map['keyColumns'] ?? map['key_columns']) as List? ??
                  const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      keep: ImportDeduplicationKeep.values.byName(
        map['keep'] as String? ?? ImportDeduplicationKeep.first.name,
      ),
    );
  }
}

class ImportExpression {
  const ImportExpression.literal(this.value)
    : kind = 'literal',
      name = '',
      arguments = const <ImportExpression>[];

  const ImportExpression.column(this.name)
    : kind = 'column',
      value = null,
      arguments = const <ImportExpression>[];

  const ImportExpression.call(this.name, this.arguments)
    : kind = 'call',
      value = null;

  final String kind;
  final String name;
  final Object? value;
  final List<ImportExpression> arguments;

  Object? evaluate(
    Map<String, Object?> row, {
    List<String>? warnings,
    String? outputColumn,
  }) {
    switch (kind) {
      case 'literal':
        return value;
      case 'column':
        return row[name];
      case 'call':
        return _evaluateCall(
          row,
          warnings: warnings,
          outputColumn: outputColumn,
        );
      default:
        throw FormatException('Unsupported import expression kind: $kind.');
    }
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'kind': kind,
      if (name.isNotEmpty) 'name': name,
      if (kind == 'literal') 'value': value,
      if (arguments.isNotEmpty)
        'arguments': <Map<String, Object?>>[
          for (final argument in arguments) argument.toMap(),
        ],
    };
  }

  factory ImportExpression.fromMap(Map<String, Object?> map) {
    final kind = map['kind'] as String? ?? 'literal';
    return switch (kind) {
      'literal' => ImportExpression.literal(map['value']),
      'column' => ImportExpression.column(map['name'] as String? ?? ''),
      'call' => ImportExpression.call(
        (map['name'] as String? ?? '').trim(),
        _listOfMaps(
          map['arguments'],
        ).map(ImportExpression.fromMap).toList(growable: false),
      ),
      _ => throw FormatException('Unsupported import expression kind: $kind.'),
    };
  }

  Object? _evaluateCall(
    Map<String, Object?> row, {
    List<String>? warnings,
    String? outputColumn,
  }) {
    final fn = name.toLowerCase();
    Object? arg(int index) => index < arguments.length
        ? arguments[index].evaluate(
            row,
            warnings: warnings,
            outputColumn: outputColumn,
          )
        : null;
    final values = <Object?>[
      for (final argument in arguments)
        argument.evaluate(row, warnings: warnings, outputColumn: outputColumn),
    ];
    switch (fn) {
      case 'add':
      case '+':
        return _numeric(values, (a, b) => a + b);
      case 'subtract':
      case '-':
        return _numeric(values, (a, b) => a - b);
      case 'multiply':
      case '*':
        return _numeric(values, (a, b) => a * b);
      case 'divide':
      case '/':
        final divisor = _asNum(arg(1));
        if (divisor == null || divisor == 0) {
          warnings?.add(_warning(outputColumn, 'division by zero'));
          return null;
        }
        final dividend = _asNum(arg(0));
        return dividend == null ? null : dividend / divisor;
      case 'modulo':
      case '%':
        final divisor = _asNum(arg(1));
        if (divisor == null || divisor == 0) {
          warnings?.add(_warning(outputColumn, 'modulo by zero'));
          return null;
        }
        final dividend = _asNum(arg(0));
        return dividend == null ? null : dividend % divisor;
      case 'concat':
        if (values.any((value) => value == null)) {
          return null;
        }
        return values.map((value) => '$value').join();
      case 'substr':
      case 'substring':
        final source = arg(0)?.toString();
        final start = _asInt(arg(1)) ?? 1;
        final length = _asInt(arg(2));
        if (source == null) {
          return null;
        }
        final startIndex = (start - 1).clamp(0, source.length);
        final endIndex = length == null
            ? source.length
            : (startIndex + length).clamp(startIndex, source.length);
        return source.substring(startIndex, endIndex);
      case 'upper':
        return arg(0)?.toString().toUpperCase();
      case 'lower':
        return arg(0)?.toString().toLowerCase();
      case 'trim':
        return arg(0)?.toString().trim();
      case 'coalesce':
        for (final value in values) {
          if (value != null) {
            return value;
          }
        }
        return null;
      case 'nullif':
        final first = arg(0);
        return _valuesEqual(first, arg(1)) ? null : first;
      case 'tointeger':
      case 'to_integer':
        return _convertInt(
          arg(0),
          warnings: warnings,
          outputColumn: outputColumn,
        );
      case 'toreal':
      case 'to_real':
        return _convertDouble(
          arg(0),
          warnings: warnings,
          outputColumn: outputColumn,
        );
      case 'totext':
      case 'to_text':
        return arg(0)?.toString();
      case 'if':
      case 'case':
        return _truthy(arg(0)) ? arg(1) : arg(2);
      case 'eq':
      case '=':
        return _valuesEqual(arg(0), arg(1));
      case 'ne':
      case '!=':
        return !_valuesEqual(arg(0), arg(1));
      case 'lt':
      case '<':
        return _compare(arg(0), arg(1)) < 0;
      case 'lte':
      case '<=':
        return _compare(arg(0), arg(1)) <= 0;
      case 'gt':
      case '>':
        return _compare(arg(0), arg(1)) > 0;
      case 'gte':
      case '>=':
        return _compare(arg(0), arg(1)) >= 0;
      case 'isnull':
      case 'is_null':
        return arg(0) == null;
      case 'isnotnull':
      case 'is_not_null':
        return arg(0) != null;
      case 'and':
        return values.every(_truthy);
      case 'or':
        return values.any(_truthy);
      case 'not':
        return !_truthy(arg(0));
      default:
        throw FormatException('Unsupported import expression call: $name.');
    }
  }
}

bool _matches(Object? left, ImportRowFilterOperator operator, Object? right) {
  return switch (operator) {
    ImportRowFilterOperator.equals => _valuesEqual(left, right),
    ImportRowFilterOperator.notEquals => !_valuesEqual(left, right),
    ImportRowFilterOperator.lessThan => _compare(left, right) < 0,
    ImportRowFilterOperator.lessThanOrEqual => _compare(left, right) <= 0,
    ImportRowFilterOperator.greaterThan => _compare(left, right) > 0,
    ImportRowFilterOperator.greaterThanOrEqual => _compare(left, right) >= 0,
    ImportRowFilterOperator.contains =>
      left != null && right != null && '$left'.contains('$right'),
    ImportRowFilterOperator.startsWith =>
      left != null && right != null && '$left'.startsWith('$right'),
    ImportRowFilterOperator.endsWith =>
      left != null && right != null && '$left'.endsWith('$right'),
    ImportRowFilterOperator.isNull => left == null,
    ImportRowFilterOperator.isNotNull => left != null,
  };
}

Object? _numeric(List<Object?> values, num Function(num a, num b) combine) {
  if (values.isEmpty) {
    return null;
  }
  var result = _asNum(values.first);
  if (result == null) {
    return null;
  }
  var accumulator = result;
  for (final value in values.skip(1)) {
    final next = _asNum(value);
    if (next == null) {
      return null;
    }
    accumulator = combine(accumulator, next);
  }
  return accumulator;
}

int _compare(Object? left, Object? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return -1;
  }
  if (right == null) {
    return 1;
  }
  final leftNum = _asNum(left);
  final rightNum = _asNum(right);
  if (leftNum != null && rightNum != null) {
    return leftNum.compareTo(rightNum);
  }
  return '$left'.compareTo('$right');
}

bool _valuesEqual(Object? left, Object? right) {
  final leftNum = _asNum(left);
  final rightNum = _asNum(right);
  if (leftNum != null && rightNum != null) {
    return leftNum == rightNum;
  }
  return left == right;
}

bool _truthy(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'false' && normalized != '0';
  }
  return true;
}

num? _asNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.trim());
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

int? _convertInt(
  Object? value, {
  List<String>? warnings,
  String? outputColumn,
}) {
  final converted = _asInt(value);
  if (converted == null && value != null) {
    warnings?.add(
      _warning(outputColumn, 'could not convert `$value` to integer'),
    );
  }
  return converted;
}

double? _convertDouble(
  Object? value, {
  List<String>? warnings,
  String? outputColumn,
}) {
  final converted = _asNum(value)?.toDouble();
  if (converted == null && value != null) {
    warnings?.add(_warning(outputColumn, 'could not convert `$value` to real'));
  }
  return converted;
}

String importDeduplicationKey(Map<String, Object?> row, List<String> columns) {
  return jsonEncode(<Object?>[for (final column in columns) row[column]]);
}

String _warning(String? column, String message) {
  return column == null ? message : '$column: $message';
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  return ((value as List?) ?? const <Object?>[])
      .whereType<Map<Object?, Object?>>()
      .map(_stringMap)
      .toList(growable: false);
}

Map<String, Object?>? _optionalMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map<Object?, Object?>) {
    return _stringMap(value);
  }
  return null;
}

Map<String, Object?> _requiredMap(Object? value) {
  final map = _optionalMap(value);
  if (map == null) {
    throw const FormatException('Expected import transform map.');
  }
  return map;
}

Map<String, Object?> _stringMap(Map<Object?, Object?> value) {
  return value.map((key, value) => MapEntry('$key', value));
}
