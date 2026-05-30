import 'dart:io';

import 'package:decent_bench/features/workspace/application/data_quality_controller.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_repository.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_runner.dart';
import 'package:decent_bench/features/workspace/presentation/quality/data_quality_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quality_dashboard_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('constructs dashboard with an attached quality controller', () async {
    final gateway = FakeWorkspaceGateway();
    final controller = DataQualityController(
      runner: DataQualityRunner(gateway: gateway),
      repository: DataQualityRepository(rootOverride: tempDir),
    );
    await controller.attachWorkspace(
      databasePath: '/tmp/workspace.ddb',
      schema: gateway.snapshot,
    );

    final dashboard = DataQualityDashboard(
      controller: controller,
      onExportReport: () {},
    );

    expect(dashboard.controller, same(controller));
    expect(controller.hasDatabase, isTrue);
    expect(controller.currentRun, isNull);
  });
}
