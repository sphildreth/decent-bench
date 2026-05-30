import 'dart:convert';
import 'dart:io';

import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:decent_bench/features/workspace/domain/data_quality_reports.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_report_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late DataQualityReportWriter writer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quality_report_test_');
    writer = const DataQualityReportWriter();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'writes Markdown report with private sample values redacted by default',
    () async {
      final output = p.join(tempDir.path, 'quality.md');

      await writer.writeReport(
        result: _resultWithSensitiveSample(),
        options: QualityReportOptions(
          format: QualityReportFormat.markdown,
          destinationPath: output,
          includeSampleValues: false,
        ),
      );

      final contents = await File(output).readAsString();
      expect(contents, contains('Data Quality Report'));
      expect(
        contents,
        contains('Raw failing row values are hidden by default'),
      );
      expect(contents, isNot(contains('Sensitive title')));
    },
  );

  test('writes machine-readable JSON report', () async {
    final output = p.join(tempDir.path, 'quality.json');

    await writer.writeReport(
      result: _resultWithSensitiveSample(),
      options: QualityReportOptions(
        format: QualityReportFormat.json,
        destinationPath: output,
        includeViolationDetailRows: true,
      ),
    );

    final json = jsonDecode(await File(output).readAsString()) as Map;
    expect(json['report_schema_version'], 1);
    expect(jsonEncode(json['quality_result']), contains('Sensitive title'));
  });
}

QualityRunResult _resultWithSensitiveSample() {
  return QualityRunResult(
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
    profileSummaries: const <TableQualitySummary>[
      TableQualitySummary(
        tableName: 'tasks',
        rowCount: 1,
        profileMode: QualityRunMode.full,
        sampleRowCount: null,
        columnSummaries: <ColumnQualitySummary>[],
        tableWarnings: <String>[],
      ),
    ],
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
            rowIdentity: <String, String>{'rowid': '1'},
            rowNumber: 1,
            valueDisplay: 'Sensitive title',
            message: 'Required value is missing.',
          ),
        ],
        detailsAvailable: true,
        detailQuerySql: null,
        detailStorePath: null,
      ),
    ],
    importReconciliation: null,
    duplicateSummaries: const <DuplicateSummary>[],
    errorMessage: null,
    warningMessages: const <String>[],
    detailStorePath: null,
  );
}
