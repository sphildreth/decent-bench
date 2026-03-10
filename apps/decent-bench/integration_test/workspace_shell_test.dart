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

  testWidgets('renders the phase 1 workspace shell', (tester) async {
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: InMemoryConfigStore(),
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
    expect(find.text('SQL Editor'), findsOneWidget);
    expect(find.text('Paged Results'), findsOneWidget);
    expect(find.text('Run SQL'), findsOneWidget);
    expect(find.text('Open Existing'), findsOneWidget);
  });

  testWidgets(
    'creates a workspace, runs a query, pages results, and exports CSV',
    (tester) async {
      final gateway = FakeWorkspaceGateway();
      final controller = WorkspaceController(
        gateway: gateway,
        configStore: InMemoryConfigStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp('decent-bench-it-');
      final dbPath = p.join(tempDir.path, 'phase1.ddb');
      final exportPath = p.join(tempDir.path, 'phase1.csv');

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
      await tester.tap(find.text('Create New'));
      await tester.pumpAndSettle();

      expect(find.text('tasks'), findsOneWidget);

      await tester.tap(find.text('tasks'));
      await tester.pumpAndSettle();

      expect(find.text('id'), findsOneWidget);
      expect(find.text('title'), findsOneWidget);

      await tester.enterText(
        _fieldWithLabel('SQL'),
        'SELECT id, title FROM tasks ORDER BY id',
      );
      await tester.tap(find.text('Run SQL'));
      await tester.pumpAndSettle();

      expect(find.text('Ship phase 1'), findsOneWidget);

      await tester.tap(find.text('Load next page'));
      await tester.pumpAndSettle();

      expect(find.text('Keep paging'), findsOneWidget);

      await tester.enterText(_fieldWithLabel('CSV export path'), exportPath);
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();

      expect(gateway.lastExportPath, exportPath);
      expect(find.textContaining('Exported 2 rows to'), findsOneWidget);
    },
  );
}
