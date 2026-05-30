import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quality profile TOML round trips validation rules', () {
    final now = DateTime.utc(2026, 5, 22, 12);
    final profile = QualityProfileDocument(
      configVersion: QualityProfileDocument.currentConfigVersion,
      profileId: 'profile-1',
      name: 'Default checks',
      description: 'Import quality checks',
      createdAt: now,
      updatedAt: now,
      defaultMode: QualityRunMode.sampled,
      sampleRowLimit: 250,
      includeImportReconciliation: true,
      includeDuplicateChecks: true,
      duplicateCandidateLimit: 1000,
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

    final parsed = QualityProfileDocument.fromToml(profile.toToml());

    expect(parsed, profile);
    expect(parsed.validate(), isEmpty);
  });

  test('validation catches unsafe custom SQL and missing rule parameters', () {
    final profile =
        QualityProfileDocument.empty(
          name: 'Broken',
          now: DateTime.utc(2026, 5, 22),
        ).copyWith(
          profileId: 'profile-1',
          rules: const <ValidationRule>[
            ValidationRule(
              id: 'rule-1',
              name: 'Unsafe',
              description: '',
              enabled: true,
              severity: QualitySeverity.error,
              targetTable: 'tasks',
              targetColumn: null,
              ruleType: ValidationRuleType.customSqlPredicate,
              params: <String, Object?>{
                'predicate_sql': '1; DROP TABLE tasks',
                'referenced_columns': <String>['title'],
              },
            ),
            ValidationRule(
              id: 'rule-2',
              name: 'Range',
              description: '',
              enabled: true,
              severity: QualitySeverity.warning,
              targetTable: 'tasks',
              targetColumn: 'id',
              ruleType: ValidationRuleType.numericRange,
              params: <String, Object?>{},
            ),
          ],
        );

    final errors = profile.validate().map((error) => error.toString());

    expect(errors, contains(contains('params.predicate_sql')));
    expect(errors, contains(contains('Numeric range requires min or max')));
  });

  test('redacted quality result hides sample violation values', () {
    final result = QualityRunResult(
      runId: 'run-1',
      profileId: 'profile-1',
      targetKind: QualityTargetKind.table,
      targetLabel: 'tasks',
      databasePath: '/tmp/workspace.ddb',
      startedAt: DateTime.utc(2026, 5, 22),
      completedAt: DateTime.utc(2026, 5, 22, 0, 1),
      status: QualityRunStatus.completed,
      mode: QualityRunMode.full,
      sampleRowLimit: null,
      schemaFingerprint: 'abc',
      schemaFingerprintAlgorithm: 'test',
      dataFingerprints: const <QualityDataFingerprint>[],
      profileSummaries: const <TableQualitySummary>[],
      validationIssues: const <ValidationIssueSummary>[
        ValidationIssueSummary(
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
          sampleViolationRows: <ViolationRowReference>[
            ViolationRowReference(
              rowIdentity: <String, String>{'rowid': '3'},
              rowNumber: 3,
              valueDisplay: 'Sensitive title',
              message: 'Required value is missing.',
            ),
          ],
          detailsAvailable: true,
          detailQuerySql: 'SELECT rowid FROM tasks',
          detailStorePath: null,
        ),
      ],
      importReconciliation: null,
      duplicateSummaries: const <DuplicateSummary>[],
      errorMessage: null,
      warningMessages: const <String>[],
      detailStorePath: null,
    );

    final redacted = result.redactedForReport();

    expect(
      redacted.validationIssues.single.sampleViolationRows.single.valueDisplay,
      isNull,
    );
  });
}
