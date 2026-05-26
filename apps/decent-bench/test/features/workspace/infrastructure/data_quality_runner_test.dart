import 'dart:io';

import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_repository.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  late Directory tempDir;
  late _QualityFakeGateway gateway;
  late DataQualityRunner runner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quality_runner_test_');
    gateway = _QualityFakeGateway();
    runner = DataQualityRunner(
      gateway: gateway,
      repository: DataQualityRepository(rootOverride: tempDir),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('profiles table columns and records validation failures', () async {
    final profile =
        QualityProfileDocument.empty(
          name: 'Required checks',
          now: DateTime.utc(2026, 5, 22),
        ).copyWith(
          profileId: 'profile-1',
          rules: const <ValidationRule>[
            ValidationRule(
              id: 'rule-1',
              name: 'Title required',
              description: '',
              enabled: true,
              severity: QualitySeverity.error,
              targetTable: 'tasks',
              targetColumn: 'title',
              ruleType: ValidationRuleType.required,
              params: <String, Object?>{
                'trim_strings': true,
                'treat_empty_string_as_null': true,
              },
            ),
          ],
        );

    final result = await runner.runQuality(
      request: QualityRunRequest(
        targetKind: QualityTargetKind.database,
        targetDatabasePath: '/tmp/workspace.ddb',
        targetTable: null,
        targetQueryId: null,
        targetQuerySql: null,
        profileId: profile.profileId,
        profilePath: null,
        mode: QualityRunMode.full,
        sampleRowLimit: 100,
        includeProfiling: true,
        includeValidation: true,
        includeImportReconciliation: false,
        includeDuplicateChecks: true,
        requestedAt: DateTime.utc(2026, 5, 22),
      ),
      schema: gateway.snapshot,
      profile: profile,
    );

    expect(result.status, QualityRunStatus.completed);
    expect(result.profileSummaries.single.tableName, 'tasks');
    expect(result.profileSummaries.single.columnSummaries, hasLength(2));
    expect(result.validationIssues, hasLength(1));
    expect(result.validationIssues.single.issueCode, 'required_value_missing');
    expect(result.errorIssueCount, 1);
    expect(result.schemaFingerprint, isNotEmpty);
  });

  test('supports paged violation rows from detail query SQL', () async {
    final issue = const ValidationIssueSummary(
      issueId: 'issue-1',
      ruleId: 'rule-1',
      ruleName: 'Title required',
      ruleType: 'required',
      severity: QualitySeverity.error,
      targetTable: 'tasks',
      targetColumn: 'title',
      issueCode: 'required_value_missing',
      message: 'Required value is missing.',
      failureCount: 1,
      sampleViolationRows: <ViolationRowReference>[],
      detailsAvailable: true,
      detailQuerySql:
          'SELECT rowid AS row_number, "title" AS value_display FROM "tasks" WHERE "title" IS NULL',
      detailStorePath: null,
    );

    final rows = await runner.loadViolationPage(
      databasePath: '/tmp/workspace.ddb',
      issue: issue,
      pageSize: 20,
      pageIndex: 0,
    );

    expect(rows, hasLength(1));
    expect(rows.single.rowNumber, 2);
  });

  test('profiles query result targets through a temporary table', () async {
    final result = await runner.runQuality(
      request: QualityRunRequest(
        targetKind: QualityTargetKind.queryResult,
        targetDatabasePath: '/tmp/workspace.ddb',
        targetTable: null,
        targetQueryId: 'saved-query-1',
        targetQuerySql: 'SELECT id, title FROM tasks',
        profileId: null,
        profilePath: null,
        mode: QualityRunMode.full,
        sampleRowLimit: 100,
        includeProfiling: true,
        includeValidation: false,
        includeImportReconciliation: false,
        includeDuplicateChecks: false,
        requestedAt: DateTime.utc(2026, 5, 22),
      ),
      schema: gateway.snapshot,
      profile: null,
    );

    expect(result.status, QualityRunStatus.completed);
    expect(result.targetKind, QualityTargetKind.queryResult);
    expect(result.profileSummaries.single.tableName, startsWith('__dbench_'));
    expect(result.profileSummaries.single.columnSummaries, hasLength(2));
    expect(
      gateway.executedSql.any((sql) => sql.contains('CREATE TEMP TABLE')),
      isTrue,
    );
    expect(
      gateway.executedSql.any((sql) => sql.contains('DROP TABLE IF EXISTS')),
      isTrue,
    );
  });

  test('plans every validation rule family', () {
    const planner = ValidationRulePlanner();

    final plannedByType = <ValidationRuleType, PlannedValidationRule>{
      for (final rule in _allRuleFamilyProfile().rules)
        rule.ruleType: planner.plan(rule),
    };

    expect(plannedByType.keys, unorderedEquals(ValidationRuleType.values));
    for (final type in ValidationRuleType.values) {
      final planned = plannedByType[type]!;
      if (type == ValidationRuleType.regex ||
          type == ValidationRuleType.nearDuplicateRows) {
        expect(planned.isolateBacked, isTrue);
        expect(planned.countSql, isNull);
        expect(planned.detailSql, isNull);
      } else {
        expect(planned.isolateBacked, isFalse);
        expect(planned.countSql, contains('failure_count'));
        expect(planned.detailSql, isNotEmpty);
      }
      expect(planned.issueCode, isNotEmpty);
      expect(planned.message, isNotEmpty);
    }
  });

  test(
    'records validation issues and duplicate summaries for every rule family',
    () async {
      final result = await runner.runQuality(
        request: QualityRunRequest(
          targetKind: QualityTargetKind.database,
          targetDatabasePath: '/tmp/workspace.ddb',
          targetTable: null,
          targetQueryId: null,
          targetQuerySql: null,
          profileId: 'all-rules',
          profilePath: null,
          mode: QualityRunMode.full,
          sampleRowLimit: 100,
          includeProfiling: false,
          includeValidation: true,
          includeImportReconciliation: false,
          includeDuplicateChecks: true,
          requestedAt: DateTime.utc(2026, 5, 22),
        ),
        schema: gateway.snapshot,
        profile: _allRuleFamilyProfile(),
      );

      expect(result.status, QualityRunStatus.completed);
      expect(
        result.validationIssues.map((issue) => issue.ruleType),
        unorderedEquals(
          ValidationRuleType.values.map((type) => type.wireName).toList(),
        ),
      );
      expect(
        result.validationIssues.map((issue) => issue.issueCode),
        containsAll(<String>[
          'required_value_missing',
          'unique_value_duplicated',
          'allowed_value_unmatched',
          'regex_unmatched',
          'numeric_value_out_of_range',
          'date_value_out_of_range',
          'string_length_out_of_range',
          'cross_column_predicate_failed',
          'referential_value_missing',
          'custom_sql_predicate_failed',
          'exact_duplicate_group',
          'near_duplicate_group',
        ]),
      );
      expect(result.duplicateSummaries, hasLength(2));
      expect(
        result.duplicateSummaries.map((summary) => summary.duplicateType),
        unorderedEquals(<String>[
          'exact_duplicate_rows',
          'near_duplicate_rows',
        ]),
      );
    },
  );

  test(
    'passes every validation rule family when checks find no failures',
    () async {
      final passingGateway = _PassingQualityFakeGateway();
      final passingRunner = DataQualityRunner(
        gateway: passingGateway,
        repository: DataQualityRepository(rootOverride: tempDir),
      );

      final result = await passingRunner.runQuality(
        request: QualityRunRequest(
          targetKind: QualityTargetKind.database,
          targetDatabasePath: '/tmp/workspace.ddb',
          targetTable: null,
          targetQueryId: null,
          targetQuerySql: null,
          profileId: 'all-rules',
          profilePath: null,
          mode: QualityRunMode.full,
          sampleRowLimit: 100,
          includeProfiling: false,
          includeValidation: true,
          includeImportReconciliation: false,
          includeDuplicateChecks: true,
          requestedAt: DateTime.utc(2026, 5, 22),
        ),
        schema: passingGateway.snapshot,
        profile: _allRuleFamilyProfile(),
      );

      expect(result.status, QualityRunStatus.completed);
      expect(result.validationIssues, isEmpty);
      expect(result.duplicateSummaries, isEmpty);
    },
  );

  test('isolate-backed rules write details that can be paged', () async {
    final result = await runner.runQuality(
      request: QualityRunRequest(
        targetKind: QualityTargetKind.database,
        targetDatabasePath: '/tmp/workspace.ddb',
        targetTable: null,
        targetQueryId: null,
        targetQuerySql: null,
        profileId: 'isolate-rules',
        profilePath: null,
        mode: QualityRunMode.full,
        sampleRowLimit: 100,
        includeProfiling: false,
        includeValidation: true,
        includeImportReconciliation: false,
        includeDuplicateChecks: true,
        requestedAt: DateTime.utc(2026, 5, 22),
      ),
      schema: gateway.snapshot,
      profile:
          QualityProfileDocument.empty(
            name: 'Isolate rules',
            now: DateTime.utc(2026, 5, 22),
          ).copyWith(
            profileId: 'isolate-rules',
            rules: <ValidationRule>[
              _rule(
                ValidationRuleType.regex,
                targetColumn: 'title',
                params: const <String, Object?>{
                  'pattern': r'^OK$',
                  'case_sensitive': true,
                  'allow_null': false,
                },
              ),
              _rule(
                ValidationRuleType.nearDuplicateRows,
                params: const <String, Object?>{
                  'columns': <String>['title'],
                  'similarity': 'normalized_levenshtein',
                  'threshold': 0.7,
                  'candidate_limit': 100,
                  'blocking_columns': <String>[],
                  'trim_strings': true,
                  'case_sensitive': false,
                },
              ),
            ],
          ),
    );

    expect(result.validationIssues, hasLength(2));
    for (final issue in result.validationIssues) {
      expect(issue.detailStorePath, isNotNull);
      final page = await runner.loadViolationPage(
        databasePath: '/tmp/workspace.ddb',
        issue: issue,
        pageSize: 1,
        pageIndex: 0,
      );
      expect(page, hasLength(1));
    }
  });

  test('returns cancelled result when cancellation is requested', () async {
    final token = DataQualityCancellationToken()..cancel();

    final result = await runner.runQuality(
      request: QualityRunRequest(
        targetKind: QualityTargetKind.database,
        targetDatabasePath: '/tmp/workspace.ddb',
        targetTable: null,
        targetQueryId: null,
        targetQuerySql: null,
        profileId: null,
        profilePath: null,
        mode: QualityRunMode.full,
        sampleRowLimit: 100,
        includeProfiling: true,
        includeValidation: false,
        includeImportReconciliation: false,
        includeDuplicateChecks: false,
        requestedAt: DateTime.utc(2026, 5, 22),
      ),
      schema: gateway.snapshot,
      profile: null,
      cancellationToken: token,
    );

    expect(result.status, QualityRunStatus.cancelled);
    expect(result.errorMessage, 'Quality run cancelled.');
  });
}

QualityProfileDocument _allRuleFamilyProfile() {
  return QualityProfileDocument.empty(
    name: 'All rule families',
    now: DateTime.utc(2026, 5, 22),
  ).copyWith(
    profileId: 'all-rules',
    rules: <ValidationRule>[
      _rule(
        ValidationRuleType.required,
        targetColumn: 'title',
        params: const <String, Object?>{
          'trim_strings': true,
          'treat_empty_string_as_null': true,
        },
      ),
      _rule(
        ValidationRuleType.unique,
        targetColumn: 'id',
        params: const <String, Object?>{
          'columns': <String>['id'],
          'ignore_nulls': true,
          'trim_strings': false,
        },
      ),
      _rule(
        ValidationRuleType.allowedValues,
        targetColumn: 'title',
        params: const <String, Object?>{
          'values': <String>['Ship'],
          'case_sensitive': true,
          'trim_strings': true,
          'allow_null': true,
        },
      ),
      _rule(
        ValidationRuleType.regex,
        targetColumn: 'title',
        params: const <String, Object?>{
          'pattern': r'^OK$',
          'case_sensitive': true,
          'allow_null': false,
        },
      ),
      _rule(
        ValidationRuleType.numericRange,
        targetColumn: 'id',
        params: const <String, Object?>{
          'min': 10,
          'max': 20,
          'inclusive_min': true,
          'inclusive_max': true,
          'allow_null': true,
        },
      ),
      _rule(
        ValidationRuleType.dateRange,
        targetColumn: 'title',
        params: const <String, Object?>{
          'min': '2026-01-01',
          'max': '2026-12-31',
          'inclusive_min': true,
          'inclusive_max': true,
          'allow_null': true,
        },
      ),
      _rule(
        ValidationRuleType.stringLength,
        targetColumn: 'title',
        params: const <String, Object?>{
          'min_length': 10,
          'max_length': 20,
          'trim_strings': true,
          'allow_null': true,
        },
      ),
      _rule(
        ValidationRuleType.crossColumn,
        params: const <String, Object?>{
          'sql_expression': '"id" > 0',
          'referenced_columns': <String>['id'],
        },
      ),
      _rule(
        ValidationRuleType.referential,
        targetColumn: 'id',
        params: const <String, Object?>{
          'source_columns': <String>['id'],
          'reference_table': 'projects',
          'reference_columns': <String>['id'],
          'ignore_nulls': true,
        },
      ),
      _rule(
        ValidationRuleType.customSqlPredicate,
        params: const <String, Object?>{
          'predicate_sql': 'LENGTH("title") > 0',
          'referenced_columns': <String>['title'],
        },
      ),
      _rule(
        ValidationRuleType.exactDuplicateRows,
        params: const <String, Object?>{
          'columns': <String>['title'],
          'ignore_nulls': true,
          'trim_strings': true,
        },
      ),
      _rule(
        ValidationRuleType.nearDuplicateRows,
        params: const <String, Object?>{
          'columns': <String>['title'],
          'similarity': 'normalized_levenshtein',
          'threshold': 0.7,
          'candidate_limit': 100,
          'blocking_columns': <String>['title'],
          'trim_strings': true,
          'case_sensitive': false,
        },
      ),
    ],
  );
}

ValidationRule _rule(
  ValidationRuleType type, {
  String? targetColumn,
  Map<String, Object?> params = const <String, Object?>{},
}) {
  return ValidationRule(
    id: '${type.wireName}-rule',
    name: '${type.wireName} rule',
    description: '',
    enabled: true,
    severity: QualitySeverity.error,
    targetTable: 'tasks',
    targetColumn: targetColumn,
    ruleType: type,
    params: params,
  );
}

class _QualityFakeGateway extends FakeWorkspaceGateway {
  _QualityFakeGateway() {
    snapshot = SchemaSnapshot(
      objects: <SchemaObjectSummary>[snapshot.objectNamed('tasks')!],
      indexes: const <IndexSummary>[],
      triggers: const <TriggerSummary>[],
      loadedAt: DateTime.utc(2026, 5, 22),
    );
  }

  final List<String> executedSql = <String>[];

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    Duration? timeout,
  }) async {
    lastRunQuerySql = sql;
    executedSql.add(sql);
    final normalized = sql.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.contains('CREATE TEMP TABLE') ||
        normalized.contains('DROP TABLE IF EXISTS')) {
      return _page(
        columns: const <String>[],
        rows: const <Map<String, Object?>>[],
      );
    }
    if (normalized.contains('SELECT * FROM "__dbench_quality_query_')) {
      return _page(
        columns: const <String>['id', 'title'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'id': 1, 'title': 'Ship'},
        ],
      );
    }
    if (normalized.contains('COUNT(*) AS failure_count')) {
      return _page(
        columns: const <String>['failure_count'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'failure_count': 1},
        ],
      );
    }
    if (normalized.contains(
      'SELECT rowid AS row_number, "title" FROM "tasks" LIMIT',
    )) {
      return _page(
        columns: const <String>['row_number', 'title'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'row_number': 1, 'title': 'Jon'},
          <String, Object?>{'row_number': 2, 'title': 'John'},
        ],
      );
    }
    if (normalized.contains(
          'SELECT rowid AS row_number, "title" AS value_display FROM "tasks"',
        ) &&
        !normalized.contains('IS NULL')) {
      return _page(
        columns: const <String>['row_number', 'value_display'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'row_number': 3, 'value_display': 'BAD'},
        ],
      );
    }
    if (normalized.contains('row_number') &&
        normalized.contains('value_display')) {
      return _page(
        columns: const <String>['row_number', 'value_display'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'row_number': 2, 'value_display': null},
        ],
      );
    }
    if (normalized.contains('COUNT(*) AS row_count')) {
      return _page(
        columns: const <String>['row_count'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'row_count': 2},
        ],
      );
    }
    if (normalized.contains('SUM(CASE')) {
      final isTitle = normalized.contains('"title"');
      return _page(
        columns: const <String>[
          'row_count',
          'null_count',
          'non_null_count',
          'empty_string_count',
          'distinct_count',
          'min_value',
          'max_value',
          'mean_value',
          'min_length',
          'max_length',
        ],
        rows: <Map<String, Object?>>[
          <String, Object?>{
            'row_count': 2,
            'null_count': isTitle ? 1 : 0,
            'non_null_count': isTitle ? 1 : 2,
            'empty_string_count': 0,
            'distinct_count': isTitle ? 1 : 2,
            'min_value': isTitle ? 'Ship' : 1,
            'max_value': isTitle ? 'Ship' : 2,
            'mean_value': isTitle ? null : 1.5,
            'min_length': isTitle ? 4 : 1,
            'max_length': isTitle ? 4 : 1,
          },
        ],
      );
    }
    if (normalized.contains('GROUP BY')) {
      return _page(
        columns: const <String>['value_display', 'value_count'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'value_display': 'Ship', 'value_count': 1},
        ],
      );
    }
    if (normalized.contains('SELECT "id" AS value')) {
      return _page(
        columns: const <String>['value'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'value': 1},
          <String, Object?>{'value': 2},
        ],
      );
    }
    return _page(
      columns: const <String>[],
      rows: const <Map<String, Object?>>[],
    );
  }

  QueryResultPage _page({
    required List<String> columns,
    required List<Map<String, Object?>> rows,
  }) {
    return QueryResultPage(
      cursorId: null,
      columns: columns,
      rows: rows,
      done: true,
      rowsAffected: null,
      elapsed: const Duration(milliseconds: 1),
    );
  }
}

class _PassingQualityFakeGateway extends _QualityFakeGateway {
  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    Duration? timeout,
  }) async {
    final normalized = sql.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.contains('COUNT(*) AS failure_count')) {
      return _page(
        columns: const <String>['failure_count'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'failure_count': 0},
        ],
      );
    }
    if (normalized.contains(
      'SELECT rowid AS row_number, "title" AS value_display FROM "tasks"',
    )) {
      return _page(
        columns: const <String>['row_number', 'value_display'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'row_number': 1, 'value_display': 'OK'},
        ],
      );
    }
    if (normalized.contains(
      'SELECT rowid AS row_number, "title" FROM "tasks" LIMIT',
    )) {
      return _page(
        columns: const <String>['row_number', 'title'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'row_number': 1, 'title': 'Alpha'},
          <String, Object?>{'row_number': 2, 'title': 'Omega'},
        ],
      );
    }
    return super.runQuery(sql: sql, params: params, pageSize: pageSize);
  }
}
