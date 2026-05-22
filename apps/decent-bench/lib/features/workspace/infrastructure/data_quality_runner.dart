import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../domain/data_quality_models.dart';
import '../domain/workspace_models.dart';
import 'data_quality_repository.dart';
import 'decentdb_bridge.dart';

typedef DataQualityProgressCallback =
    void Function(DataQualityProgress progress);

class DataQualityProgress {
  const DataQualityProgress({
    required this.phase,
    this.currentTable,
    this.currentRule,
    this.rowsScanned,
    this.cancellable = true,
  });

  final String phase;
  final String? currentTable;
  final String? currentRule;
  final int? rowsScanned;
  final bool cancellable;
}

class DataQualityCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw const DataQualityCancelledException();
    }
  }
}

class DataQualityCancelledException implements Exception {
  const DataQualityCancelledException();

  @override
  String toString() => 'Quality run cancelled.';
}

class DataQualitySqlPlanner {
  const DataQualitySqlPlanner();

  String quoteIdentifier(String identifier) {
    return '"${identifier.replaceAll('"', '""')}"';
  }

  String tableSource({
    required String tableName,
    required QualityRunMode mode,
    required int sampleRowLimit,
  }) {
    final table = quoteIdentifier(tableName);
    if (mode == QualityRunMode.sampled) {
      return '(SELECT * FROM $table LIMIT $sampleRowLimit)';
    }
    return table;
  }

  String rowCountSql({
    required String tableName,
    required QualityRunMode mode,
    required int sampleRowLimit,
  }) {
    return 'SELECT COUNT(*) AS row_count FROM ${tableSource(tableName: tableName, mode: mode, sampleRowLimit: sampleRowLimit)}';
  }

  String columnAggregateSql({
    required String tableName,
    required String columnName,
    required QualityRunMode mode,
    required int sampleRowLimit,
  }) {
    final source = tableSource(
      tableName: tableName,
      mode: mode,
      sampleRowLimit: sampleRowLimit,
    );
    final column = quoteIdentifier(columnName);
    return '''
SELECT
  COUNT(*) AS row_count,
  SUM(CASE WHEN $column IS NULL THEN 1 ELSE 0 END) AS null_count,
  SUM(CASE WHEN $column IS NOT NULL THEN 1 ELSE 0 END) AS non_null_count,
  SUM(CASE WHEN $column IS NOT NULL AND TRIM(CAST($column AS TEXT)) = '' THEN 1 ELSE 0 END) AS empty_string_count,
  COUNT(DISTINCT $column) AS distinct_count,
  MIN($column) AS min_value,
  MAX($column) AS max_value,
  AVG(CAST($column AS REAL)) AS mean_value,
  MIN(LENGTH(CAST($column AS TEXT))) AS min_length,
  MAX(LENGTH(CAST($column AS TEXT))) AS max_length
FROM $source
''';
  }

  String topValuesSql({
    required String tableName,
    required String columnName,
    required QualityRunMode mode,
    required int sampleRowLimit,
    int limit = 10,
  }) {
    final source = tableSource(
      tableName: tableName,
      mode: mode,
      sampleRowLimit: sampleRowLimit,
    );
    final column = quoteIdentifier(columnName);
    return '''
SELECT CAST($column AS TEXT) AS value_display, COUNT(*) AS value_count
FROM $source
GROUP BY $column
ORDER BY value_count DESC, value_display ASC
LIMIT $limit
''';
  }

  String sortedValuesSql({
    required String tableName,
    required String columnName,
    required QualityRunMode mode,
    required int sampleRowLimit,
    int hardLimit = 50000,
  }) {
    final source = tableSource(
      tableName: tableName,
      mode: mode,
      sampleRowLimit: math.min(sampleRowLimit, hardLimit),
    );
    final column = quoteIdentifier(columnName);
    return '''
SELECT $column AS value
FROM $source
WHERE $column IS NOT NULL
ORDER BY $column
LIMIT $hardLimit
''';
  }
}

class ValidationRulePlanner {
  const ValidationRulePlanner({
    this.sqlPlanner = const DataQualitySqlPlanner(),
  });

  final DataQualitySqlPlanner sqlPlanner;

  PlannedValidationRule plan(ValidationRule rule) {
    final table = sqlPlanner.quoteIdentifier(rule.targetTable);
    final column = rule.targetColumn == null
        ? null
        : sqlPlanner.quoteIdentifier(rule.targetColumn!);
    return switch (rule.ruleType) {
      ValidationRuleType.required => _required(rule, table, column!),
      ValidationRuleType.unique => _unique(rule, table),
      ValidationRuleType.allowedValues => _allowedValues(rule, table, column!),
      ValidationRuleType.numericRange => _numericRange(rule, table, column!),
      ValidationRuleType.dateRange => _dateRange(rule, table, column!),
      ValidationRuleType.stringLength => _stringLength(rule, table, column!),
      ValidationRuleType.crossColumn => _predicate(
        rule,
        table,
        rule.params['sql_expression'] as String? ?? '1',
        'cross_column_predicate_failed',
      ),
      ValidationRuleType.referential => _referential(rule, table),
      ValidationRuleType.customSqlPredicate => _predicate(
        rule,
        table,
        rule.params['predicate_sql'] as String? ?? '1',
        'custom_sql_predicate_failed',
      ),
      ValidationRuleType.exactDuplicateRows => _unique(
        rule,
        table,
        issueCode: 'exact_duplicate_group',
      ),
      ValidationRuleType.regex || ValidationRuleType.nearDuplicateRows =>
        PlannedValidationRule.isolate(rule),
    };
  }

  PlannedValidationRule _required(
    ValidationRule rule,
    String table,
    String column,
  ) {
    final trim = rule.params['trim_strings'] as bool? ?? true;
    final emptyAsNull =
        rule.params['treat_empty_string_as_null'] as bool? ?? true;
    final valueExpr = trim
        ? 'TRIM(CAST($column AS TEXT))'
        : 'CAST($column AS TEXT)';
    final where = emptyAsNull
        ? '$column IS NULL OR $valueExpr = \'\''
        : '$column IS NULL';
    return PlannedValidationRule.sql(
      rule,
      issueCode: 'required_value_missing',
      countSql: 'SELECT COUNT(*) AS failure_count FROM $table WHERE $where',
      detailSql:
          'SELECT rowid AS row_number, $column AS value_display FROM $table WHERE $where',
      message: 'Required value is missing.',
    );
  }

  PlannedValidationRule _unique(
    ValidationRule rule,
    String table, {
    String issueCode = 'unique_value_duplicated',
  }) {
    final columns = _ruleColumns(rule);
    final quoted = columns.map(sqlPlanner.quoteIdentifier).toList();
    final keyExprs = (rule.params['trim_strings'] as bool? ?? false)
        ? quoted.map((column) => 'TRIM(CAST($column AS TEXT))').toList()
        : quoted;
    final nullFilter = (rule.params['ignore_nulls'] as bool? ?? true)
        ? 'WHERE ${quoted.map((column) => '$column IS NOT NULL').join(' AND ')}'
        : '';
    final keyList = keyExprs.join(', ');
    final grouped =
        'SELECT $keyList, COUNT(*) AS duplicate_count FROM $table $nullFilter GROUP BY $keyList HAVING COUNT(*) > 1';
    return PlannedValidationRule.sql(
      rule,
      issueCode: issueCode,
      countSql:
          'SELECT COUNT(*) AS failure_count FROM ($grouped) duplicate_groups',
      detailSql: grouped,
      message: issueCode == 'exact_duplicate_group'
          ? 'Exact duplicate row group found.'
          : 'Unique key is duplicated.',
    );
  }

  PlannedValidationRule _allowedValues(
    ValidationRule rule,
    String table,
    String column,
  ) {
    final values = ((rule.params['values'] as List?) ?? const <Object?>[])
        .map((item) => "'${'$item'.replaceAll("'", "''")}'")
        .join(', ');
    final allowNull = rule.params['allow_null'] as bool? ?? true;
    final trim = rule.params['trim_strings'] as bool? ?? true;
    final caseSensitive = rule.params['case_sensitive'] as bool? ?? true;
    var valueExpr = trim
        ? 'TRIM(CAST($column AS TEXT))'
        : 'CAST($column AS TEXT)';
    var allowedExpr = values;
    if (!caseSensitive) {
      valueExpr = 'LOWER($valueExpr)';
      allowedExpr = ((rule.params['values'] as List?) ?? const <Object?>[])
          .map((item) => "'${'$item'.toLowerCase().replaceAll("'", "''")}'")
          .join(', ');
    }
    final where =
        '${allowNull ? '$column IS NOT NULL AND ' : ''}$valueExpr NOT IN ($allowedExpr)';
    return PlannedValidationRule.sql(
      rule,
      issueCode: 'allowed_value_unmatched',
      countSql: 'SELECT COUNT(*) AS failure_count FROM $table WHERE $where',
      detailSql:
          'SELECT rowid AS row_number, $column AS value_display FROM $table WHERE $where',
      message: 'Value is not in the allowed set.',
    );
  }

  PlannedValidationRule _numericRange(
    ValidationRule rule,
    String table,
    String column,
  ) {
    final clauses = <String>[];
    final min = rule.params['min'];
    final max = rule.params['max'];
    if (min != null) {
      clauses.add(
        'CAST($column AS REAL) ${(rule.params['inclusive_min'] as bool? ?? true) ? '<' : '<='} $min',
      );
    }
    if (max != null) {
      clauses.add(
        'CAST($column AS REAL) ${(rule.params['inclusive_max'] as bool? ?? true) ? '>' : '>='} $max',
      );
    }
    final allowNull = rule.params['allow_null'] as bool? ?? true;
    final where =
        '${allowNull ? '$column IS NOT NULL AND ' : ''}(${clauses.join(' OR ')})';
    return PlannedValidationRule.sql(
      rule,
      issueCode: 'numeric_value_out_of_range',
      countSql: 'SELECT COUNT(*) AS failure_count FROM $table WHERE $where',
      detailSql:
          'SELECT rowid AS row_number, $column AS value_display FROM $table WHERE $where',
      message: 'Numeric value is outside the configured range.',
    );
  }

  PlannedValidationRule _dateRange(
    ValidationRule rule,
    String table,
    String column,
  ) {
    final clauses = <String>[];
    final min = rule.params['min'];
    final max = rule.params['max'];
    if (min != null) {
      clauses.add(
        'CAST($column AS TEXT) ${(rule.params['inclusive_min'] as bool? ?? true) ? '<' : '<='} \'${'$min'.replaceAll("'", "''")}\'',
      );
    }
    if (max != null) {
      clauses.add(
        'CAST($column AS TEXT) ${(rule.params['inclusive_max'] as bool? ?? true) ? '>' : '>='} \'${'$max'.replaceAll("'", "''")}\'',
      );
    }
    final allowNull = rule.params['allow_null'] as bool? ?? true;
    final where =
        '${allowNull ? '$column IS NOT NULL AND ' : ''}(${clauses.join(' OR ')})';
    return PlannedValidationRule.sql(
      rule,
      issueCode: 'date_value_out_of_range',
      countSql: 'SELECT COUNT(*) AS failure_count FROM $table WHERE $where',
      detailSql:
          'SELECT rowid AS row_number, $column AS value_display FROM $table WHERE $where',
      message: 'Date/time value is outside the configured range.',
    );
  }

  PlannedValidationRule _stringLength(
    ValidationRule rule,
    String table,
    String column,
  ) {
    final trim = rule.params['trim_strings'] as bool? ?? false;
    final expr = trim
        ? 'LENGTH(TRIM(CAST($column AS TEXT)))'
        : 'LENGTH(CAST($column AS TEXT))';
    final clauses = <String>[];
    final min = rule.params['min_length'];
    final max = rule.params['max_length'];
    if (min != null) {
      clauses.add('$expr < $min');
    }
    if (max != null) {
      clauses.add('$expr > $max');
    }
    final allowNull = rule.params['allow_null'] as bool? ?? true;
    final where =
        '${allowNull ? '$column IS NOT NULL AND ' : ''}(${clauses.join(' OR ')})';
    return PlannedValidationRule.sql(
      rule,
      issueCode: 'string_length_out_of_range',
      countSql: 'SELECT COUNT(*) AS failure_count FROM $table WHERE $where',
      detailSql:
          'SELECT rowid AS row_number, $column AS value_display FROM $table WHERE $where',
      message: 'String length is outside the configured range.',
    );
  }

  PlannedValidationRule _predicate(
    ValidationRule rule,
    String table,
    String predicate,
    String issueCode,
  ) {
    final where = 'NOT ($predicate) OR ($predicate) IS NULL';
    return PlannedValidationRule.sql(
      rule,
      issueCode: issueCode,
      countSql: 'SELECT COUNT(*) AS failure_count FROM $table WHERE $where',
      detailSql: 'SELECT rowid AS row_number FROM $table WHERE $where',
      message: 'SQL predicate failed.',
    );
  }

  PlannedValidationRule _referential(ValidationRule rule, String table) {
    final sourceColumns =
        ((rule.params['source_columns'] as List?) ?? const <Object?>[])
            .map((item) => '$item')
            .toList();
    final referenceColumns =
        ((rule.params['reference_columns'] as List?) ?? const <Object?>[])
            .map((item) => '$item')
            .toList();
    final referenceTable = sqlPlanner.quoteIdentifier(
      rule.params['reference_table'] as String? ?? '',
    );
    final joinClauses = <String>[];
    for (var index = 0; index < sourceColumns.length; index++) {
      joinClauses.add(
        'src.${sqlPlanner.quoteIdentifier(sourceColumns[index])} = ref.${sqlPlanner.quoteIdentifier(referenceColumns[index])}',
      );
    }
    final nullFilter = (rule.params['ignore_nulls'] as bool? ?? true)
        ? 'AND ${sourceColumns.map((column) => 'src.${sqlPlanner.quoteIdentifier(column)} IS NOT NULL').join(' AND ')}'
        : '';
    final where =
        'ref.${sqlPlanner.quoteIdentifier(referenceColumns.first)} IS NULL $nullFilter';
    return PlannedValidationRule.sql(
      rule,
      issueCode: 'referential_value_missing',
      countSql:
          'SELECT COUNT(*) AS failure_count FROM $table src LEFT JOIN $referenceTable ref ON ${joinClauses.join(' AND ')} WHERE $where',
      detailSql:
          'SELECT src.rowid AS row_number FROM $table src LEFT JOIN $referenceTable ref ON ${joinClauses.join(' AND ')} WHERE $where',
      message: 'Referenced row is missing.',
    );
  }

  List<String> _ruleColumns(ValidationRule rule) {
    final columns = ((rule.params['columns'] as List?) ?? const <Object?>[])
        .map((item) => '$item')
        .where((item) => item.trim().isNotEmpty)
        .toList();
    if (columns.isNotEmpty) {
      return columns;
    }
    return <String>[if (rule.targetColumn != null) rule.targetColumn!];
  }
}

class PlannedValidationRule {
  const PlannedValidationRule._({
    required this.rule,
    required this.issueCode,
    required this.message,
    this.countSql,
    this.detailSql,
    this.isolateBacked = false,
  });

  factory PlannedValidationRule.sql(
    ValidationRule rule, {
    required String issueCode,
    required String countSql,
    required String detailSql,
    required String message,
  }) {
    return PlannedValidationRule._(
      rule: rule,
      issueCode: issueCode,
      countSql: countSql,
      detailSql: detailSql,
      message: message,
    );
  }

  factory PlannedValidationRule.isolate(ValidationRule rule) {
    return PlannedValidationRule._(
      rule: rule,
      issueCode: rule.ruleType == ValidationRuleType.regex
          ? 'regex_unmatched'
          : 'near_duplicate_group',
      message: rule.ruleType == ValidationRuleType.regex
          ? 'Value does not match the configured regex.'
          : 'Near-duplicate candidate group found.',
      isolateBacked: true,
    );
  }

  final ValidationRule rule;
  final String issueCode;
  final String message;
  final String? countSql;
  final String? detailSql;
  final bool isolateBacked;
}

class DataQualityRunner {
  DataQualityRunner({
    required WorkspaceDatabaseGateway gateway,
    DataQualityRepository? repository,
    this.sqlPlanner = const DataQualitySqlPlanner(),
    this.rulePlanner = const ValidationRulePlanner(),
  }) : _gateway = gateway,
       _repository = repository ?? DataQualityRepository();

  final WorkspaceDatabaseGateway _gateway;
  final DataQualityRepository _repository;
  final DataQualitySqlPlanner sqlPlanner;
  final ValidationRulePlanner rulePlanner;

  Future<QualityRunResult> runQuality({
    required QualityRunRequest request,
    required SchemaSnapshot schema,
    QualityProfileDocument? profile,
    DataQualityProgressCallback? onProgress,
    DataQualityCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? DataQualityCancellationToken();
    final started = DateTime.now().toUtc();
    final runId = generateQualityUuid();
    String? temporaryQueryTableName;
    try {
      _validateOrThrow(request.validate(), 'quality run request');
      if (profile != null) {
        _validateOrThrow(profile.validate(), 'quality profile');
      }
      final queryResultTable = request.targetKind == QualityTargetKind.queryResult
          ? await _materializeQueryResultTarget(runId: runId, request: request)
          : null;
      temporaryQueryTableName = queryResultTable?.name;
      final targetTables = queryResultTable == null
          ? _targetTables(request, schema)
          : <SchemaObjectSummary>[queryResultTable];
      final profileSummaries = <TableQualitySummary>[];
      final issues = <ValidationIssueSummary>[];
      final duplicateSummaries = <DuplicateSummary>[];
      ImportReconciliationSummary? reconciliation;

      if (request.includeProfiling) {
        for (final table in targetTables) {
          token.throwIfCancelled();
          onProgress?.call(
            DataQualityProgress(phase: 'Profiling', currentTable: table.name),
          );
          profileSummaries.add(
            await runProfiling(
              table: table,
              mode: request.mode,
              sampleRowLimit: request.sampleRowLimit,
              token: token,
            ),
          );
        }
      }

      if (request.includeValidation && profile != null) {
        for (final rule in profile.rules.where((rule) => rule.enabled)) {
          if (!targetTables.any((table) => table.name == rule.targetTable)) {
            continue;
          }
          token.throwIfCancelled();
          onProgress?.call(
            DataQualityProgress(
              phase: 'Validating',
              currentTable: rule.targetTable,
              currentRule: rule.name,
            ),
          );
          final issue = await _runRule(
            runId: runId,
            databasePath: request.targetDatabasePath,
            rule: rule,
            includeSampleValues: false,
            token: token,
          );
          if (issue != null) {
            issues.add(issue);
            if (rule.ruleType == ValidationRuleType.exactDuplicateRows ||
                rule.ruleType == ValidationRuleType.nearDuplicateRows) {
              duplicateSummaries.add(
                DuplicateSummary(
                  summaryId: generateQualityUuid(),
                  ruleId: rule.id,
                  targetTable: rule.targetTable,
                  columns:
                      ((rule.params['columns'] as List?) ?? const <Object?>[])
                          .map((item) => '$item')
                          .toList(),
                  duplicateType: rule.ruleType.wireName,
                  groupCount: issue.failureCount,
                  rowCount: issue.failureCount,
                  candidateLimit: rule.params['candidate_limit'] as int?,
                  detailsAvailable: issue.detailsAvailable,
                  detailStorePath: issue.detailStorePath,
                ),
              );
            }
          }
        }
      }

      if (request.includeImportReconciliation) {
        reconciliation = await _repository.loadLatestImportReconciliation(
          databasePath: request.targetDatabasePath,
          tableName: request.targetTable,
        );
      }

      onProgress?.call(const DataQualityProgress(phase: 'Fingerprinting'));
      final dataFingerprints = <QualityDataFingerprint>[];
      for (final table in targetTables) {
        dataFingerprints.add(
          await computeDataFingerprint(
            table: table,
            mode: request.mode,
            sampleRowLimit: request.sampleRowLimit,
          ),
        );
      }

      return QualityRunResult(
        runId: runId,
        profileId: profile?.profileId ?? request.profileId,
        targetKind: request.targetKind,
        targetLabel: _targetLabel(request),
        databasePath: request.targetDatabasePath,
        startedAt: started,
        completedAt: DateTime.now().toUtc(),
        status: QualityRunStatus.completed,
        mode: request.mode,
        sampleRowLimit: request.mode == QualityRunMode.sampled
            ? request.sampleRowLimit
            : null,
        schemaFingerprint: computeSchemaFingerprint(schema),
        schemaFingerprintAlgorithm: 'schema-json-sha256-v1',
        dataFingerprints: dataFingerprints,
        profileSummaries: profileSummaries,
        validationIssues: issues,
        importReconciliation: reconciliation,
        duplicateSummaries: duplicateSummaries,
        errorMessage: null,
        warningMessages: <String>[
          if (request.mode == QualityRunMode.sampled)
            'Quality run used sampled mode with ${request.sampleRowLimit} rows per table.',
        ],
        detailStorePath: null,
      );
    } on DataQualityCancelledException {
      return QualityRunResult(
        runId: runId,
        profileId: profile?.profileId ?? request.profileId,
        targetKind: request.targetKind,
        targetLabel: _targetLabel(request),
        databasePath: request.targetDatabasePath,
        startedAt: started,
        completedAt: DateTime.now().toUtc(),
        status: QualityRunStatus.cancelled,
        mode: request.mode,
        sampleRowLimit: request.mode == QualityRunMode.sampled
            ? request.sampleRowLimit
            : null,
        schemaFingerprint: computeSchemaFingerprint(schema),
        schemaFingerprintAlgorithm: 'schema-json-sha256-v1',
        dataFingerprints: const <QualityDataFingerprint>[],
        profileSummaries: const <TableQualitySummary>[],
        validationIssues: const <ValidationIssueSummary>[],
        importReconciliation: null,
        duplicateSummaries: const <DuplicateSummary>[],
        errorMessage: 'Quality run cancelled.',
        warningMessages: const <String>[],
        detailStorePath: null,
      );
    } catch (error) {
      return QualityRunResult(
        runId: runId,
        profileId: profile?.profileId ?? request.profileId,
        targetKind: request.targetKind,
        targetLabel: _targetLabel(request),
        databasePath: request.targetDatabasePath,
        startedAt: started,
        completedAt: DateTime.now().toUtc(),
        status: QualityRunStatus.failed,
        mode: request.mode,
        sampleRowLimit: request.mode == QualityRunMode.sampled
            ? request.sampleRowLimit
            : null,
        schemaFingerprint: computeSchemaFingerprint(schema),
        schemaFingerprintAlgorithm: 'schema-json-sha256-v1',
        dataFingerprints: const <QualityDataFingerprint>[],
        profileSummaries: const <TableQualitySummary>[],
        validationIssues: const <ValidationIssueSummary>[],
        importReconciliation: null,
        duplicateSummaries: const <DuplicateSummary>[],
        errorMessage: '$error',
        warningMessages: const <String>[],
        detailStorePath: null,
      );
    } finally {
      if (temporaryQueryTableName != null) {
        await _dropTemporaryQueryTarget(temporaryQueryTableName);
      }
    }
  }

  Future<TableQualitySummary> runProfiling({
    required SchemaObjectSummary table,
    required QualityRunMode mode,
    required int sampleRowLimit,
    DataQualityCancellationToken? token,
  }) async {
    final rowCount = await _scalarInt(
      sqlPlanner.rowCountSql(
        tableName: table.name,
        mode: QualityRunMode.full,
        sampleRowLimit: sampleRowLimit,
      ),
      'row_count',
    );
    final sampleCount = mode == QualityRunMode.sampled
        ? math.min(rowCount, sampleRowLimit)
        : null;
    final columns = <ColumnQualitySummary>[];
    final tableWarnings = <String>[];
    for (final column in table.columns) {
      token?.throwIfCancelled();
      try {
        columns.add(
          await _profileColumn(
            table: table,
            column: column,
            rowCount: rowCount,
            mode: mode,
            sampleRowLimit: sampleRowLimit,
          ),
        );
      } catch (error) {
        tableWarnings.add('Column ${column.name}: $error');
      }
    }
    return TableQualitySummary(
      tableName: table.name,
      rowCount: rowCount,
      profileMode: mode,
      sampleRowCount: sampleCount,
      columnSummaries: columns,
      tableWarnings: tableWarnings,
    );
  }

  Future<QualityDataFingerprint> computeDataFingerprint({
    required SchemaObjectSummary table,
    required QualityRunMode mode,
    required int sampleRowLimit,
  }) async {
    final rowCount = await _scalarInt(
      sqlPlanner.rowCountSql(
        tableName: table.name,
        mode: QualityRunMode.full,
        sampleRowLimit: sampleRowLimit,
      ),
      'row_count',
    );
    final columnPayload = <Map<String, Object?>>[];
    for (final column in table.columns) {
      try {
        final aggregate = await _firstRow(
          sqlPlanner.columnAggregateSql(
            tableName: table.name,
            columnName: column.name,
            mode: mode,
            sampleRowLimit: sampleRowLimit,
          ),
        );
        columnPayload.add(<String, Object?>{
          'name': column.name,
          'type': column.type,
          'null_count': aggregate['null_count'],
          'non_null_count': aggregate['non_null_count'],
          'distinct_count': aggregate['distinct_count'],
          'min': aggregate['min_value']?.toString(),
          'max': aggregate['max_value']?.toString(),
        });
      } catch (_) {
        columnPayload.add(<String, Object?>{
          'name': column.name,
          'type': column.type,
          'warning': 'fingerprint_metric_failed',
        });
      }
    }
    final payload = jsonEncode(<String, Object?>{
      'table': table.name,
      'row_count': rowCount,
      'columns': columnPayload,
    });
    return QualityDataFingerprint(
      tableName: table.name,
      rowCount: rowCount,
      contentFingerprint: sha256.convert(utf8.encode(payload)).toString(),
      contentFingerprintAlgorithm: 'aggregate-json-sha256-v1',
      computedAt: DateTime.now().toUtc(),
    );
  }

  String computeSchemaFingerprint(SchemaSnapshot schema) {
    final payload = <Map<String, Object?>>[
      for (final table in schema.tables)
        <String, Object?>{
          'name': table.name,
          'columns': <Map<String, Object?>>[
            for (final column in table.columns)
              <String, Object?>{
                'name': column.name,
                'type': column.type,
                'not_null': column.notNull,
                'unique': column.unique,
                'primary_key': column.primaryKey,
                'ref_table': column.refTable,
                'ref_column': column.refColumn,
              },
          ],
        },
    ];
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  Future<ColumnQualitySummary> _profileColumn({
    required SchemaObjectSummary table,
    required SchemaColumn column,
    required int rowCount,
    required QualityRunMode mode,
    required int sampleRowLimit,
  }) async {
    final aggregate = await _firstRow(
      sqlPlanner.columnAggregateSql(
        tableName: table.name,
        columnName: column.name,
        mode: mode,
        sampleRowLimit: sampleRowLimit,
      ),
    );
    final effectiveRowCount = _asInt(aggregate['row_count']);
    final nullCount = _asInt(aggregate['null_count']);
    final emptyStringCount = _asInt(aggregate['empty_string_count']);
    final nonNullCount = _asInt(aggregate['non_null_count']);
    final distinctCount = _asInt(aggregate['distinct_count']);
    final topValues = await _topValues(
      tableName: table.name,
      columnName: column.name,
      mode: mode,
      sampleRowLimit: sampleRowLimit,
      rowCount: effectiveRowCount,
    );
    final numericValues = _isNumericType(column.type)
        ? await _numericSortedValues(
            tableName: table.name,
            columnName: column.name,
            mode: mode,
            sampleRowLimit: sampleRowLimit,
          )
        : const <double>[];
    final outlier = numericValues.length >= 4
        ? _buildOutlierSummary(numericValues)
        : null;
    return ColumnQualitySummary(
      columnName: column.name,
      typeName: column.type,
      nativeTypeFamily: describeNativeType(typeName: column.type).familyLabel,
      rowCount: rowCount,
      sampleRowCount: mode == QualityRunMode.sampled ? effectiveRowCount : null,
      nullCount: nullCount,
      nullPercent: _percent(nullCount, effectiveRowCount),
      emptyStringCount: emptyStringCount,
      emptyStringPercent: _percent(emptyStringCount, effectiveRowCount),
      nonNullCount: nonNullCount,
      distinctCount: distinctCount,
      distinctPercent: _percent(distinctCount, effectiveRowCount),
      minValueDisplay: aggregate['min_value']?.toString(),
      maxValueDisplay: aggregate['max_value']?.toString(),
      meanValueDisplay: aggregate['mean_value']?.toString(),
      medianValueDisplay: numericValues.isEmpty
          ? null
          : _median(numericValues).toStringAsFixed(3),
      stddevValueDisplay: numericValues.length < 2
          ? null
          : _stddev(numericValues).toStringAsFixed(3),
      minLength: _nullableInt(aggregate['min_length']),
      maxLength: _nullableInt(aggregate['max_length']),
      topValues: topValues,
      histogramBuckets: _buildHistogram(numericValues),
      malformedTemporalCount: _isTemporalType(column.type)
          ? await _malformedTemporalCount(
              tableName: table.name,
              columnName: column.name,
              mode: mode,
              sampleRowLimit: sampleRowLimit,
            )
          : 0,
      potentialKey:
          effectiveRowCount > 0 &&
          nullCount == 0 &&
          distinctCount == effectiveRowCount,
      outlierSummary: outlier,
      warnings: <String>[
        if (mode == QualityRunMode.sampled)
          'Metric computed from first $sampleRowLimit rows.',
        if (numericValues.length >= 50000)
          'Median and IQR used the bounded sorted-value cap.',
      ],
    );
  }

  Future<List<QualityValueFrequency>> _topValues({
    required String tableName,
    required String columnName,
    required QualityRunMode mode,
    required int sampleRowLimit,
    required int rowCount,
  }) async {
    final page = await _gateway.runQuery(
      sql: sqlPlanner.topValuesSql(
        tableName: tableName,
        columnName: columnName,
        mode: mode,
        sampleRowLimit: sampleRowLimit,
      ),
      params: const <Object?>[],
      pageSize: 10,
    );
    return <QualityValueFrequency>[
      for (final row in page.rows.take(10))
        QualityValueFrequency(
          valueDisplay: row['value_display']?.toString() ?? '<null>',
          count: _asInt(row['value_count']),
          percent: _percent(_asInt(row['value_count']), rowCount),
        ),
    ];
  }

  Future<List<double>> _numericSortedValues({
    required String tableName,
    required String columnName,
    required QualityRunMode mode,
    required int sampleRowLimit,
  }) async {
    final page = await _gateway.runQuery(
      sql: sqlPlanner.sortedValuesSql(
        tableName: tableName,
        columnName: columnName,
        mode: mode,
        sampleRowLimit: sampleRowLimit,
      ),
      params: const <Object?>[],
      pageSize: 50000,
    );
    return <double>[
      for (final row in page.rows)
        if (double.tryParse('${row['value']}') != null)
          double.parse('${row['value']}'),
    ]..sort();
  }

  Future<int> _malformedTemporalCount({
    required String tableName,
    required String columnName,
    required QualityRunMode mode,
    required int sampleRowLimit,
  }) async {
    final source = sqlPlanner.tableSource(
      tableName: tableName,
      mode: mode,
      sampleRowLimit: sampleRowLimit,
    );
    final column = sqlPlanner.quoteIdentifier(columnName);
    final page = await _gateway.runQuery(
      sql: 'SELECT $column AS value FROM $source WHERE $column IS NOT NULL',
      params: const <Object?>[],
      pageSize: sampleRowLimit,
    );
    return page.rows
        .where((row) => DateTime.tryParse('${row['value']}') == null)
        .length;
  }

  Future<ValidationIssueSummary?> _runRule({
    required String runId,
    required String databasePath,
    required ValidationRule rule,
    required bool includeSampleValues,
    required DataQualityCancellationToken token,
  }) async {
    final planned = rulePlanner.plan(rule);
    if (planned.isolateBacked) {
      return _runIsolateRule(
        runId: runId,
        databasePath: databasePath,
        planned: planned,
        includeSampleValues: includeSampleValues,
        token: token,
      );
    }
    final count = await _scalarInt(planned.countSql!, 'failure_count');
    if (count == 0) {
      return null;
    }
    final samplePage = await _gateway.runQuery(
      sql: '${planned.detailSql!} LIMIT 5',
      params: const <Object?>[],
      pageSize: 5,
    );
    final sampleRows = _sampleRows(
      samplePage.rows,
      includeSampleValues: includeSampleValues,
      message: planned.message,
    );
    return ValidationIssueSummary(
      issueId: generateQualityUuid(),
      ruleId: rule.id,
      ruleName: rule.name,
      ruleType: rule.ruleType.wireName,
      severity: rule.severity,
      targetTable: rule.targetTable,
      targetColumn: rule.targetColumn,
      issueCode: planned.issueCode,
      message: planned.message,
      failureCount: count,
      sampleViolationRows: sampleRows,
      detailsAvailable: true,
      detailQuerySql: planned.detailSql,
      detailStorePath: null,
    );
  }

  Future<ValidationIssueSummary?> _runIsolateRule({
    required String runId,
    required String databasePath,
    required PlannedValidationRule planned,
    required bool includeSampleValues,
    required DataQualityCancellationToken token,
  }) async {
    final rule = planned.rule;
    if (rule.ruleType == ValidationRuleType.regex) {
      final column = sqlPlanner.quoteIdentifier(rule.targetColumn!);
      final table = sqlPlanner.quoteIdentifier(rule.targetTable);
      final allowNull = rule.params['allow_null'] as bool? ?? true;
      final page = await _gateway.runQuery(
        sql:
            'SELECT rowid AS row_number, $column AS value_display FROM $table ${allowNull ? 'WHERE $column IS NOT NULL' : ''}',
        params: const <Object?>[],
        pageSize: 50000,
      );
      token.throwIfCancelled();
      final failingMaps = await Isolate.run(
        () => _findRegexViolationRows(
          rows: page.rows,
          pattern: rule.params['pattern'] as String? ?? '.*',
          caseSensitive: rule.params['case_sensitive'] as bool? ?? true,
          allowNull: allowNull,
          includeSampleValues: includeSampleValues,
          message: planned.message,
        ),
      );
      final failing = failingMaps
          .map(ViolationRowReference.fromJson)
          .toList(growable: false);
      if (failing.isEmpty) {
        return null;
      }
      final issueId = generateQualityUuid();
      await _repository.saveViolationDetails(
        databasePath: databasePath,
        runId: runId,
        issueId: issueId,
        rows: failing,
      );
      return ValidationIssueSummary(
        issueId: issueId,
        ruleId: rule.id,
        ruleName: rule.name,
        ruleType: rule.ruleType.wireName,
        severity: rule.severity,
        targetTable: rule.targetTable,
        targetColumn: rule.targetColumn,
        issueCode: planned.issueCode,
        message: planned.message,
        failureCount: failing.length,
        sampleViolationRows: failing.take(5).toList(),
        detailsAvailable: true,
        detailQuerySql: null,
        detailStorePath: _repository
            .violationDetailsFile(
              databasePath: databasePath,
              runId: runId,
              issueId: issueId,
            )
            .path,
      );
    }
    return _runNearDuplicateRule(
      runId: runId,
      databasePath: databasePath,
      planned: planned,
      includeSampleValues: includeSampleValues,
      token: token,
    );
  }

  Future<ValidationIssueSummary?> _runNearDuplicateRule({
    required String runId,
    required String databasePath,
    required PlannedValidationRule planned,
    required bool includeSampleValues,
    required DataQualityCancellationToken token,
  }) async {
    final rule = planned.rule;
    final columns = ((rule.params['columns'] as List?) ?? const <Object?>[])
        .map((item) => '$item')
        .toList();
    final candidateLimit = rule.params['candidate_limit'] as int? ?? 1000;
    final threshold = (rule.params['threshold'] as num?)?.toDouble() ?? 0.9;
    final table = sqlPlanner.quoteIdentifier(rule.targetTable);
    final selectColumns = columns.map(sqlPlanner.quoteIdentifier).join(', ');
    final page = await _gateway.runQuery(
      sql:
          'SELECT rowid AS row_number, $selectColumns FROM $table LIMIT $candidateLimit',
      params: const <Object?>[],
      pageSize: candidateLimit,
    );
    token.throwIfCancelled();
    final rows = page.rows;
    final failingMaps = await Isolate.run(
      () => _findNearDuplicateViolationRows(
        rows: rows,
        columns: columns,
        similarity: rule.params['similarity'],
        threshold: threshold,
        includeSampleValues: includeSampleValues,
        message: planned.message,
      ),
    );
    final failing = failingMaps
        .map(ViolationRowReference.fromJson)
        .toList(growable: false);
    if (failing.isEmpty) {
      return null;
    }
    final issueId = generateQualityUuid();
    await _repository.saveViolationDetails(
      databasePath: databasePath,
      runId: runId,
      issueId: issueId,
      rows: failing,
    );
    return ValidationIssueSummary(
      issueId: issueId,
      ruleId: rule.id,
      ruleName: rule.name,
      ruleType: rule.ruleType.wireName,
      severity: rule.severity,
      targetTable: rule.targetTable,
      targetColumn: rule.targetColumn,
      issueCode: planned.issueCode,
      message: 'Bounded near-duplicate scan found matching candidates.',
      failureCount: failing.length,
      sampleViolationRows: failing.take(5).toList(),
      detailsAvailable: true,
      detailQuerySql: null,
      detailStorePath: _repository
          .violationDetailsFile(
            databasePath: databasePath,
            runId: runId,
            issueId: issueId,
          )
          .path,
    );
  }

  Future<List<ViolationRowReference>> loadViolationPage({
    required String databasePath,
    required ValidationIssueSummary issue,
    required int pageSize,
    required int pageIndex,
  }) async {
    if (issue.detailQuerySql != null) {
      final page = await _gateway.runQuery(
        sql:
            '${issue.detailQuerySql!} LIMIT $pageSize OFFSET ${pageSize * pageIndex}',
        params: const <Object?>[],
        pageSize: pageSize,
      );
      return _sampleRows(
        page.rows,
        includeSampleValues: false,
        message: issue.message,
      );
    }
    return _repository.loadViolationPage(
      databasePath: databasePath,
      runId: _runIdFromDetailPath(issue.detailStorePath),
      issueId: issue.issueId,
      pageSize: pageSize,
      pageIndex: pageIndex,
    );
  }

  List<SchemaObjectSummary> _targetTables(
    QualityRunRequest request,
    SchemaSnapshot schema,
  ) {
    if (request.targetKind == QualityTargetKind.table) {
      final table = schema.objectNamed(request.targetTable ?? '');
      return table == null
          ? const <SchemaObjectSummary>[]
          : <SchemaObjectSummary>[table];
    }
    return schema.tables;
  }

  Future<SchemaObjectSummary> _materializeQueryResultTarget({
    required String runId,
    required QualityRunRequest request,
  }) async {
    final querySql = request.targetQuerySql?.trim();
    if (querySql == null || querySql.isEmpty) {
      throw const FormatException('Query result quality target requires SQL.');
    }
    final tableName = '__dbench_quality_query_${runId.replaceAll('-', '_')}';
    final table = sqlPlanner.quoteIdentifier(tableName);
    await _gateway.runQuery(
      sql: 'CREATE TEMP TABLE $table AS SELECT * FROM ($querySql) quality_source',
      params: const <Object?>[],
      pageSize: 1,
    );
    final preview = await _gateway.runQuery(
      sql: 'SELECT * FROM $table LIMIT 1',
      params: const <Object?>[],
      pageSize: 1,
    );
    return SchemaObjectSummary(
      name: tableName,
      kind: SchemaObjectKind.table,
      temporary: true,
      columns: <SchemaColumn>[
        for (final column in preview.columns)
          SchemaColumn(
            name: column,
            type: 'TEXT',
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
      ],
    );
  }

  Future<void> _dropTemporaryQueryTarget(String tableName) async {
    try {
      await _gateway.runQuery(
        sql: 'DROP TABLE IF EXISTS ${sqlPlanner.quoteIdentifier(tableName)}',
        params: const <Object?>[],
        pageSize: 1,
      );
    } catch (_) {
      // Temporary quality targets are best-effort cleanup only.
    }
  }

  String _targetLabel(QualityRunRequest request) {
    return switch (request.targetKind) {
      QualityTargetKind.database => 'Database',
      QualityTargetKind.table => request.targetTable ?? 'Table',
      QualityTargetKind.queryResult => request.targetQueryId ?? 'Query result',
    };
  }

  Future<Map<String, Object?>> _firstRow(String sql) async {
    final page = await _gateway.runQuery(
      sql: sql,
      params: const <Object?>[],
      pageSize: 1,
    );
    return page.rows.isEmpty ? const <String, Object?>{} : page.rows.first;
  }

  Future<int> _scalarInt(String sql, String columnName) async {
    final row = await _firstRow(sql);
    return _asInt(row[columnName]);
  }
}

void _validateOrThrow(List<DataQualityValidationError> errors, String label) {
  if (errors.isEmpty) {
    return;
  }
  throw FormatException(
    'Invalid $label: ${errors.map((error) => error.toString()).join('; ')}',
  );
}

List<ViolationRowReference> _sampleRows(
  List<Map<String, Object?>> rows, {
  required bool includeSampleValues,
  required String message,
}) {
  return <ViolationRowReference>[
    for (final row in rows)
      ViolationRowReference(
        rowIdentity: <String, String>{
          if (row['row_number'] != null) 'rowid': '${row['row_number']}',
          for (final entry in row.entries.take(3))
            if (entry.key != 'value_display' && entry.value != null)
              entry.key: '${entry.value}',
        },
        rowNumber: _nullableInt(row['row_number']),
        valueDisplay: includeSampleValues
            ? row['value_display']?.toString()
            : null,
        message: message,
      ),
  ];
}

double _percent(int count, int total) => total <= 0 ? 0 : count * 100 / total;

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _asInt(value);
}

bool _isNumericType(String typeName) {
  final normalized = typeName.toLowerCase();
  return normalized.contains('int') ||
      normalized.contains('real') ||
      normalized.contains('double') ||
      normalized.contains('float') ||
      normalized.contains('numeric') ||
      normalized.contains('decimal');
}

bool _isTemporalType(String typeName) {
  final normalized = typeName.toLowerCase();
  return normalized.contains('date') ||
      normalized.contains('time') ||
      normalized.contains('timestamp');
}

double _median(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  final middle = values.length ~/ 2;
  if (values.length.isOdd) {
    return values[middle];
  }
  return (values[middle - 1] + values[middle]) / 2;
}

double _stddev(List<double> values) {
  if (values.length < 2) {
    return 0;
  }
  final mean = values.reduce((left, right) => left + right) / values.length;
  final variance =
      values
          .map((value) => math.pow(value - mean, 2).toDouble())
          .reduce((left, right) => left + right) /
      (values.length - 1);
  return math.sqrt(variance);
}

OutlierSummary? _buildOutlierSummary(List<double> sortedValues) {
  if (sortedValues.length < 4) {
    return null;
  }
  final q1 = _median(sortedValues.take(sortedValues.length ~/ 2).toList());
  final q3 = _median(
    sortedValues.skip((sortedValues.length + 1) ~/ 2).toList(),
  );
  final iqr = q3 - q1;
  final lower = q1 - 1.5 * iqr;
  final upper = q3 + 1.5 * iqr;
  final count = sortedValues
      .where((value) => value < lower || value > upper)
      .length;
  return OutlierSummary(
    method: OutlierMethod.iqr,
    lowerFenceDisplay: lower.toStringAsFixed(3),
    upperFenceDisplay: upper.toStringAsFixed(3),
    outlierCount: count,
    outlierPercent: _percent(count, sortedValues.length),
  );
}

List<QualityHistogramBucket> _buildHistogram(List<double> sortedValues) {
  if (sortedValues.isEmpty) {
    return const <QualityHistogramBucket>[];
  }
  final min = sortedValues.first;
  final max = sortedValues.last;
  if (min == max) {
    return <QualityHistogramBucket>[
      QualityHistogramBucket(
        label: min.toStringAsFixed(3),
        lowerBoundDisplay: min.toStringAsFixed(3),
        upperBoundDisplay: max.toStringAsFixed(3),
        count: sortedValues.length,
        percent: 100,
      ),
    ];
  }
  const bucketCount = 10;
  final width = (max - min) / bucketCount;
  final buckets = List<int>.filled(bucketCount, 0);
  for (final value in sortedValues) {
    final index = value == max
        ? bucketCount - 1
        : ((value - min) / width).floor().clamp(0, bucketCount - 1);
    buckets[index]++;
  }
  return <QualityHistogramBucket>[
    for (var index = 0; index < buckets.length; index++)
      QualityHistogramBucket(
        label:
            '${(min + index * width).toStringAsFixed(2)}-${(min + (index + 1) * width).toStringAsFixed(2)}',
        lowerBoundDisplay: (min + index * width).toStringAsFixed(3),
        upperBoundDisplay: (min + (index + 1) * width).toStringAsFixed(3),
        count: buckets[index],
        percent: _percent(buckets[index], sortedValues.length),
      ),
  ];
}

double Function(String, String) _parseSimilarity(Object? value) {
  if (value == 'token_sort_ratio') {
    return _tokenSortRatio;
  }
  return _normalizedLevenshtein;
}

List<Map<String, Object?>> _findRegexViolationRows({
  required List<Map<String, Object?>> rows,
  required String pattern,
  required bool caseSensitive,
  required bool allowNull,
  required bool includeSampleValues,
  required String message,
}) {
  final regex = RegExp(pattern, caseSensitive: caseSensitive);
  return <Map<String, Object?>>[
    for (final row in rows)
      if (_regexRowFails(row, regex: regex, allowNull: allowNull))
        ViolationRowReference(
          rowIdentity: <String, String>{'rowid': '${row['row_number']}'},
          rowNumber: _nullableInt(row['row_number']),
          valueDisplay: includeSampleValues
              ? row['value_display']?.toString()
              : null,
          message: message,
        ).toJson(),
  ];
}

bool _regexRowFails(
  Map<String, Object?> row, {
  required RegExp regex,
  required bool allowNull,
}) {
  final value = row['value_display'];
  if (value == null && allowNull) {
    return false;
  }
  return value == null || !regex.hasMatch('$value');
}

List<Map<String, Object?>> _findNearDuplicateViolationRows({
  required List<Map<String, Object?>> rows,
  required List<String> columns,
  required Object? similarity,
  required double threshold,
  required bool includeSampleValues,
  required String message,
}) {
  final failing = <Map<String, Object?>>[];
  final scorer = _parseSimilarity(similarity);
  for (var leftIndex = 0; leftIndex < rows.length; leftIndex++) {
    for (var rightIndex = leftIndex + 1; rightIndex < rows.length; rightIndex++) {
      final left = columns
          .map((column) => '${rows[leftIndex][column] ?? ''}')
          .join(' ');
      final right = columns
          .map((column) => '${rows[rightIndex][column] ?? ''}')
          .join(' ');
      final score = scorer(left, right);
      if (score >= threshold) {
        failing.add(
          ViolationRowReference(
            rowIdentity: <String, String>{
              'left_rowid': '${rows[leftIndex]['row_number']}',
              'right_rowid': '${rows[rightIndex]['row_number']}',
            },
            rowNumber: _nullableInt(rows[leftIndex]['row_number']),
            valueDisplay: includeSampleValues
                ? '$left ~ $right (${score.toStringAsFixed(3)})'
                : null,
            message: message,
          ).toJson(),
        );
      }
    }
  }
  return failing;
}

double _tokenSortRatio(String left, String right) {
  final sortedLeft = left.toLowerCase().split(RegExp(r'\s+'))..sort();
  final sortedRight = right.toLowerCase().split(RegExp(r'\s+'))..sort();
  return _normalizedLevenshtein(sortedLeft.join(' '), sortedRight.join(' '));
}

double _normalizedLevenshtein(String left, String right) {
  if (left == right) {
    return 1;
  }
  final maxLength = math.max(left.length, right.length);
  if (maxLength == 0) {
    return 1;
  }
  final distance = _levenshtein(left.toLowerCase(), right.toLowerCase());
  return 1 - distance / maxLength;
}

int _levenshtein(String left, String right) {
  final previous = List<int>.generate(right.length + 1, (index) => index);
  final current = List<int>.filled(right.length + 1, 0);
  for (var i = 0; i < left.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < right.length; j++) {
      final cost = left.codeUnitAt(i) == right.codeUnitAt(j) ? 0 : 1;
      current[j + 1] = math.min(
        math.min(current[j] + 1, previous[j + 1] + 1),
        previous[j] + cost,
      );
    }
    previous.setAll(0, current);
  }
  return previous[right.length];
}

String _runIdFromDetailPath(String? path) {
  if (path == null || path.trim().isEmpty) {
    return '';
  }
  final parts = path.split(RegExp(r'[/\\]'));
  final violationsIndex = parts.lastIndexOf('violations');
  if (violationsIndex > 0) {
    return parts[violationsIndex - 1];
  }
  return '';
}
