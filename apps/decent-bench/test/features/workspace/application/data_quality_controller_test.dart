import 'dart:io';

import 'package:decent_bench/features/workspace/application/data_quality_controller.dart';
import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
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
}
