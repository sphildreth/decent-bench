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
    );

    await controller.initialize();

    expect(controller.nativeLibraryPath, '/tmp/libc_api.so');
    expect(controller.lastStatus, 'Ready.');
  });

  test('openDatabase refreshes schema and stores recent files', () async {
    final dbPath =
        '${Directory.systemTemp.path}/workbench-${DateTime.now().microsecondsSinceEpoch}.ddb';
    final store = InMemoryConfigStore();
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: store,
    );
    await controller.initialize();

    await controller.openDatabase(dbPath, createIfMissing: true);

    expect(controller.databasePath, dbPath);
    expect(controller.engineVersion, '1.6.0');
    expect(controller.schema.tables.single.name, 'tasks');
    expect((await store.load()).recentFiles, contains(dbPath));
  });

  test(
    'runSql, fetchNextPage, export, and cancel update controller state',
    () async {
      final gateway = FakeWorkspaceGateway();
      final dbPath =
          '${Directory.systemTemp.path}/workbench-${DateTime.now().microsecondsSinceEpoch}.ddb';
      final controller = WorkspaceController(
        gateway: gateway,
        configStore: InMemoryConfigStore(),
      );
      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);

      await controller.runSql(
        sql: 'SELECT * FROM tasks ORDER BY id',
        parameterJson: '[1]',
      );

      expect(controller.resultRows.length, 1);
      expect(controller.hasMoreRows, isTrue);
      expect(controller.queryPhase, QueryPhase.running);

      await controller.fetchNextPage();

      expect(controller.resultRows.length, 2);
      expect(controller.hasMoreRows, isFalse);
      expect(controller.queryPhase, QueryPhase.completed);

      await controller.exportCurrentQuery('/tmp/export.csv');

      expect(gateway.lastExportPath, '/tmp/export.csv');

      await controller.runSql(sql: 'SELECT * FROM tasks', parameterJson: '[]');
      await controller.cancelActiveQuery();

      expect(controller.queryPhase, QueryPhase.cancelled);
      expect(gateway.cancelCount, greaterThan(0));
    },
  );
}
