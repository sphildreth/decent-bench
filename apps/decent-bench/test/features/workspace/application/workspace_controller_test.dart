import 'dart:io';

import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  test('initialize loads config and native library path', () async {
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: InMemoryConfigStore(),
      workspaceStateStore: InMemoryWorkspaceStateStore(),
    );

    await controller.initialize();

    expect(controller.nativeLibraryPath, '/tmp/libc_api.so');
    expect(controller.workspaceMessage, 'Ready.');
    expect(controller.tabs, hasLength(1));
  });

  test('openDatabase refreshes schema and stores recent files', () async {
    final dbPath =
        '${Directory.systemTemp.path}/workbench-${DateTime.now().microsecondsSinceEpoch}.ddb';
    final store = InMemoryConfigStore();
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: store,
      workspaceStateStore: InMemoryWorkspaceStateStore(),
    );
    await controller.initialize();

    await controller.openDatabase(dbPath, createIfMissing: true);

    expect(controller.databasePath, dbPath);
    expect(controller.engineVersion, '1.6.1');
    expect(controller.schema.tables.single.name, 'tasks');
    expect(controller.schema.views.single.name, 'active_tasks');
    expect((await store.load()).recentFiles, contains(dbPath));
  });

  test('tabs own independent query state and results', () async {
    final dbPath =
        '${Directory.systemTemp.path}/workbench-${DateTime.now().microsecondsSinceEpoch}.ddb';
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: InMemoryConfigStore(),
      workspaceStateStore: InMemoryWorkspaceStateStore(),
    );
    await controller.initialize();
    await controller.openDatabase(dbPath, createIfMissing: true);

    controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
    await controller.runActiveTab();
    expect(controller.activeTab.resultRows.single['title'], 'Ship phase 1');
    expect(controller.activeTab.phase, QueryPhase.running);

    controller.createTab();
    controller.updateActiveSql('SELECT id, name FROM projects ORDER BY id');
    await controller.runActiveTab();
    expect(controller.activeTab.resultRows.single['name'], 'Phase 2');
    expect(controller.activeTab.phase, QueryPhase.running);

    final secondTabId = controller.activeTabId;
    controller.previousTab();

    expect(controller.activeTab.sql, 'SELECT id, title FROM tasks ORDER BY id');
    expect(controller.activeTab.resultRows.single['title'], 'Ship phase 1');
    expect(controller.tabs, hasLength(2));

    controller.selectTab(secondTabId);
    await controller.fetchNextPage();
    expect(controller.activeTab.phase, QueryPhase.completed);
    expect(controller.activeTab.resultRows.last['name'], 'Keep testing');

    await controller.cancelTabQuery(controller.tabs.first.id);
    controller.selectTab(controller.tabs.first.id);
    expect(controller.activeTab.phase, QueryPhase.cancelled);
    expect(controller.activeTab.isResultPartial, isTrue);
  });

  test('reopening the same database restores persisted tab drafts', () async {
    final dbPath =
        '${Directory.systemTemp.path}/workbench-${DateTime.now().microsecondsSinceEpoch}.ddb';
    final configStore = InMemoryConfigStore();
    final workspaceStateStore = InMemoryWorkspaceStateStore();

    final firstController = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: configStore,
      workspaceStateStore: workspaceStateStore,
    );
    await firstController.initialize();
    await firstController.openDatabase(dbPath, createIfMissing: true);
    firstController.updateActiveSql('SELECT * FROM tasks WHERE id = \$1');
    firstController.updateActiveParameterJson('[1]');
    firstController.createTab();
    firstController.updateActiveSql('SELECT * FROM projects ORDER BY id');
    firstController.updateActiveExportPath('/tmp/projects.csv');
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final secondController = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: configStore,
      workspaceStateStore: workspaceStateStore,
    );
    await secondController.initialize();
    await secondController.openDatabase(dbPath, createIfMissing: false);

    expect(secondController.tabs, hasLength(2));
    expect(
      secondController.activeTab.sql,
      'SELECT * FROM projects ORDER BY id',
    );
    expect(secondController.activeTab.exportPath, '/tmp/projects.csv');
    secondController.previousTab();
    expect(secondController.activeTab.parameterJson, '[1]');
  });
}
