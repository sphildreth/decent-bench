import 'dart:async';
import 'dart:io';

import 'package:decent_bench/features/workspace/application/data_quality_controller.dart';
import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_repository.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  late Directory tempDir;
  late FakeWorkspaceGateway gateway;
  late DataQualityController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quality_controller_test_');
    gateway = FakeWorkspaceGateway();
    controller = DataQualityController(
      runner: DataQualityRunner(gateway: gateway),
      repository: DataQualityRepository(rootOverride: tempDir),
    );
  });

  tearDown(() async {
    controller.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('attachWorkspace creates an in-memory default profile', () async {
    await controller.attachWorkspace(
      databasePath: '/tmp/workspace.ddb',
      schema: gateway.snapshot,
    );

    expect(controller.hasDatabase, isTrue);
    expect(controller.currentProfile?.name, 'Default Import Quality');
    expect(controller.currentProfile?.rules, isNotEmpty);
    expect(controller.freshness, QualityFreshnessStatus.noRun);
  });

  test('saveProfile persists and selects the profile', () async {
    await controller.attachWorkspace(
      databasePath: '/tmp/workspace.ddb',
      schema: gateway.snapshot,
    );
    final profile = QualityProfileDocument.empty(
      name: 'Team profile',
      now: DateTime.utc(2026, 5, 22),
    ).copyWith(profileId: 'profile-1');

    await controller.saveProfile(profile);

    expect(controller.currentProfile?.profileId, 'profile-1');
    expect(
      controller.profiles.map((item) => item.profileId),
      contains('profile-1'),
    );
  });

  test('startRun clears cancellable state after completion', () async {
    final runner = _CompletingQualityRunner();
    final qualityController = DataQualityController(
      runner: runner,
      repository: DataQualityRepository(rootOverride: tempDir),
    );
    addTearDown(qualityController.dispose);
    await qualityController.attachWorkspace(
      databasePath: '/tmp/workspace.ddb',
      schema: runner.gateway.snapshot,
    );

    final runFuture = qualityController.startRun();
    await runner.started.future;

    expect(qualityController.isRunning, isTrue);
    expect(qualityController.canCancelRun, isTrue);

    runner.complete();
    final result = await runFuture;

    expect(result?.status, QualityRunStatus.completed);
    expect(qualityController.currentRun?.status, QualityRunStatus.completed);
    expect(qualityController.isRunning, isFalse);
    expect(qualityController.canCancelRun, isFalse);
    expect(qualityController.progress, isNull);
  });

  test('stale displayed running result is not cancellable', () async {
    await controller.attachWorkspace(
      databasePath: '/tmp/workspace.ddb',
      schema: gateway.snapshot,
    );
    controller.currentRun = _qualityRun(status: QualityRunStatus.running);

    expect(controller.isRunning, isFalse);
    expect(controller.canCancelRun, isFalse);
    expect(
      controller.computeFreshness(controller.currentRun),
      QualityFreshnessStatus.stale,
    );
  });
}

class _CompletingQualityRunner extends DataQualityRunner {
  _CompletingQualityRunner() : this._(FakeWorkspaceGateway());

  _CompletingQualityRunner._(this.gateway) : super(gateway: gateway);

  final FakeWorkspaceGateway gateway;
  final Completer<void> started = Completer<void>();
  final Completer<QualityRunResult> _completion = Completer<QualityRunResult>();

  void complete() {
    _completion.complete(_qualityRun(status: QualityRunStatus.completed));
  }

  @override
  Future<QualityRunResult> runQuality({
    required QualityRunRequest request,
    required SchemaSnapshot schema,
    QualityProfileDocument? profile,
    DataQualityProgressCallback? onProgress,
    DataQualityCancellationToken? cancellationToken,
  }) {
    onProgress?.call(const DataQualityProgress(phase: 'Profiling'));
    if (!started.isCompleted) {
      started.complete();
    }
    return _completion.future;
  }

  @override
  String computeSchemaFingerprint(SchemaSnapshot schema) => 'schema-1';
}

QualityRunResult _qualityRun({required QualityRunStatus status}) {
  return QualityRunResult(
    runId: 'run-1',
    profileId: 'profile-1',
    targetKind: QualityTargetKind.database,
    targetLabel: 'Database',
    databasePath: '/tmp/workspace.ddb',
    startedAt: DateTime.utc(2026, 5, 22, 12),
    completedAt: status == QualityRunStatus.running
        ? null
        : DateTime.utc(2026, 5, 22, 12, 1),
    status: status,
    mode: QualityRunMode.full,
    sampleRowLimit: null,
    schemaFingerprint: 'schema-1',
    schemaFingerprintAlgorithm: 'schema-json-sha256-v1',
    dataFingerprints: const <QualityDataFingerprint>[],
    profileSummaries: const <TableQualitySummary>[],
    validationIssues: const <ValidationIssueSummary>[],
    importReconciliation: null,
    duplicateSummaries: const <DuplicateSummary>[],
    errorMessage: null,
    warningMessages: const <String>[],
    detailStorePath: null,
  );
}
