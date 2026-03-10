import 'dart:io';

import 'package:decent_bench/app/app.dart';
import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import '../test/support/fakes.dart';

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField labeled $label',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the phase 2 workspace shell', (tester) async {
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: InMemoryConfigStore(),
      workspaceStateStore: InMemoryWorkspaceStateStore(),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      controller.dispose();
    });
    await controller.initialize();

    await tester.pumpWidget(
      DecentBenchApp(controller: controller, autoInitialize: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Decent Bench'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Schema'), findsOneWidget);
    expect(find.text('SQL Workspace'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('New Tab'), findsOneWidget);
  });

  testWidgets('creates a workspace, uses multiple tabs, and exports CSV', (
    tester,
  ) async {
    final gateway = FakeWorkspaceGateway();
    final controller = WorkspaceController(
      gateway: gateway,
      configStore: InMemoryConfigStore(),
      workspaceStateStore: InMemoryWorkspaceStateStore(),
    );
    final tempDir = await Directory.systemTemp.createTemp('decent-bench-it-');
    final dbPath = p.join(tempDir.path, 'phase2.ddb');
    final exportPath = p.join(tempDir.path, 'phase2.csv');

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      controller.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    await controller.initialize();

    await tester.pumpWidget(
      DecentBenchApp(controller: controller, autoInitialize: false),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_fieldWithLabel('Database path'), dbPath);
    final createNewButton = find.widgetWithText(FilledButton, 'Create New');
    await tester.ensureVisible(createNewButton);
    await tester.tap(createNewButton);
    await tester.pumpAndSettle();

    expect(find.text('tasks'), findsWidgets);
    expect(find.text('active_tasks'), findsWidgets);

    await tester.tap(find.text('active_tasks').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('CREATE VIEW active_tasks'), findsOneWidget);

    await tester.enterText(
      _fieldWithLabel('SQL'),
      'SELECT id, title FROM tasks ORDER BY id',
    );
    final runSqlButton = find.widgetWithText(FilledButton, 'Run SQL');
    await tester.ensureVisible(runSqlButton);
    await tester.tap(runSqlButton);
    await tester.pumpAndSettle();
    expect(find.text('Ship phase 1'), findsOneWidget);

    final newTabButton = find.widgetWithText(FilledButton, 'New Tab');
    await tester.ensureVisible(newTabButton);
    await tester.tap(newTabButton);
    await tester.pumpAndSettle();
    expect(find.text('Query 2'), findsOneWidget);
    expect(controller.activeTab.title, 'Query 2');

    controller.updateActiveSql('SELECT id, name FROM projects ORDER BY id');
    await tester.pumpAndSettle();
    await tester.ensureVisible(runSqlButton);
    await tester.tap(runSqlButton);
    await tester.pumpAndSettle();
    expect(controller.activeTab.resultRows.single['name'], 'Phase 2');

    await tester.tap(find.text('Query 1'));
    await tester.pumpAndSettle();
    expect(find.text('Ship phase 1'), findsOneWidget);

    await tester.tap(find.text('Load next page'));
    await tester.pumpAndSettle();
    expect(find.text('Keep paging'), findsOneWidget);

    await tester.enterText(_fieldWithLabel('CSV export path'), exportPath);
    final exportButton = find.widgetWithText(FilledButton, 'Export CSV');
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(gateway.lastExportPath, exportPath);
    expect(find.textContaining('Exported 2 rows to'), findsOneWidget);
  });
}
