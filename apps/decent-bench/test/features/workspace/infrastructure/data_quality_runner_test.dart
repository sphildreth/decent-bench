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

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  }) async {
    lastRunQuerySql = sql;
    final normalized = sql.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.contains('COUNT(*) AS failure_count')) {
      return _page(
        columns: const <String>['failure_count'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'failure_count': 1},
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
