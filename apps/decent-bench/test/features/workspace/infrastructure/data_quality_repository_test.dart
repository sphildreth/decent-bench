import 'dart:io';

import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late DataQualityRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quality_repository_test_');
    repository = DataQualityRepository(rootOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves profiles and default profile pointer', () async {
    final profile = QualityProfileDocument.empty(
      name: 'Default quality',
      now: DateTime.utc(2026, 5, 22),
    ).copyWith(profileId: 'profile-1');

    await repository.saveProfile(
      databasePath: '/tmp/workspace.ddb',
      profile: profile,
    );
    await repository.setDefaultProfile(
      databasePath: '/tmp/workspace.ddb',
      profileId: profile.profileId,
    );

    final profiles = await repository.loadProfiles('/tmp/workspace.ddb');
    final defaultProfile = await repository.loadDefaultProfile(
      '/tmp/workspace.ddb',
    );

    expect(profiles, hasLength(1));
    expect(profiles.single.profileId, 'profile-1');
    expect(defaultProfile?.profileId, 'profile-1');
  });

  test('stores violation detail rows as paged JSONL', () async {
    await repository.saveViolationDetails(
      databasePath: '/tmp/workspace.ddb',
      runId: 'run-1',
      issueId: 'issue-1',
      rows: const <ViolationRowReference>[
        ViolationRowReference(
          rowIdentity: <String, String>{'rowid': '1'},
          rowNumber: 1,
          valueDisplay: 'a',
          message: 'failed',
        ),
        ViolationRowReference(
          rowIdentity: <String, String>{'rowid': '2'},
          rowNumber: 2,
          valueDisplay: 'b',
          message: 'failed',
        ),
      ],
    );

    final page = await repository.loadViolationPage(
      databasePath: '/tmp/workspace.ddb',
      runId: 'run-1',
      issueId: 'issue-1',
      pageSize: 1,
      pageIndex: 1,
    );

    expect(page, hasLength(1));
    expect(page.single.rowNumber, 2);
    expect(page.single.valueDisplay, 'b');
  });

  test('returns latest import reconciliation for target table', () async {
    await repository.saveImportReconciliation(
      databasePath: '/tmp/workspace.ddb',
      reconciliation: ImportReconciliationSummary(
        importJobId: 'old',
        sourcePathDisplay: '/tmp/old.csv',
        sourceFormat: 'CSV',
        sourceFingerprint: null,
        startedAt: DateTime.utc(2026, 5, 21),
        completedAt: DateTime.utc(2026, 5, 21),
        tableMappings: const <ImportTableReconciliation>[
          ImportTableReconciliation(
            sourceName: 'tasks',
            targetTable: 'tasks',
            sourceRowCount: 1,
            importedRowCount: 1,
            skippedRowCount: 0,
            rejectedRowCount: 0,
            transformedRowCount: 0,
            typeCoercionFailureCount: 0,
            warningCount: 0,
          ),
        ],
        warningCount: 0,
        warningsByTable: const <String, int>{},
        warningsByCode: const <String, int>{},
      ),
    );
    await repository.saveImportReconciliation(
      databasePath: '/tmp/workspace.ddb',
      reconciliation: ImportReconciliationSummary(
        importJobId: 'new',
        sourcePathDisplay: '/tmp/new.csv',
        sourceFormat: 'CSV',
        sourceFingerprint: null,
        startedAt: DateTime.utc(2026, 5, 22),
        completedAt: DateTime.utc(2026, 5, 22),
        tableMappings: const <ImportTableReconciliation>[
          ImportTableReconciliation(
            sourceName: 'tasks',
            targetTable: 'tasks',
            sourceRowCount: 2,
            importedRowCount: 2,
            skippedRowCount: 0,
            rejectedRowCount: 0,
            transformedRowCount: 0,
            typeCoercionFailureCount: 0,
            warningCount: 0,
          ),
        ],
        warningCount: 0,
        warningsByTable: const <String, int>{},
        warningsByCode: const <String, int>{},
      ),
    );

    final latest = await repository.loadLatestImportReconciliation(
      databasePath: '/tmp/workspace.ddb',
      tableName: 'tasks',
    );

    expect(latest?.importJobId, 'new');
  });
}
