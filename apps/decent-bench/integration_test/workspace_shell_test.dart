import 'dart:io';

import 'package:decent_bench/app/app.dart';
import 'package:decent_bench/app/logging/app_logger.dart';
import 'package:decent_bench/app/startup_launch_options.dart';
import 'package:archive/archive.dart';
import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Shell rendering', () {
    testWidgets('renders the desktop shell', (tester) async {
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
        DecentBenchApp(
          controller: controller,
          autoInitialize: false,
          logger: const NoOpAppLogger(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schema Explorer'), findsOneWidget);
      expect(find.text('SQL Editor'), findsOneWidget);
      expect(find.text('Results Window'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Format'), findsOneWidget);
    });
  });

  group('Workspace operations', () {
    testWidgets('opens a workspace and runs a query inside the shell', (
      tester,
    ) async {
      final controller = WorkspaceController(
        gateway: FakeWorkspaceGateway(),
        configStore: InMemoryConfigStore(),
        workspaceStateStore: InMemoryWorkspaceStateStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp('decent-bench-it-');
      final dbPath = p.join(tempDir.path, 'workspace.ddb');

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
      await controller.openDatabase(dbPath, createIfMissing: true);
      controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');

      await tester.pumpWidget(
        DecentBenchApp(
          controller: controller,
          autoInitialize: false,
          logger: const NoOpAppLogger(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('tasks'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();

      expect(find.text('Ship phase 1'), findsOneWidget);
      expect(find.textContaining('Workspace: workspace.ddb'), findsOneWidget);
    });

    testWidgets('creates and switches between multiple editor tabs', (
      tester,
    ) async {
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
      controller.createTab(sql: 'SELECT 1');
      controller.createTab(sql: 'SELECT 2');

      await tester.pumpWidget(
        DecentBenchApp(
          controller: controller,
          autoInitialize: false,
          logger: const NoOpAppLogger(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Query'), findsAtLeastNWidgets(3));
    });

    testWidgets('opens preferences dialog from Options menu', (tester) async {
      final controller = WorkspaceController(
        gateway: FakeWorkspaceGateway(),
        configStore: InMemoryConfigStore(),
        workspaceStateStore: InMemoryWorkspaceStateStore(),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        messenger.setMockMethodCallHandler(SystemChannels.menu, null);
        controller.dispose();
      });

      messenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
        if (call.method == 'Menu.isPluginAvailable') {
          return false;
        }
        return null;
      });

      await controller.initialize();
      await tester.pumpWidget(
        DecentBenchApp(
          controller: controller,
          autoInitialize: false,
          logger: const NoOpAppLogger(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tools'), findsOneWidget);

      await tester.tap(find.text('Tools'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.widgetWithText(MenuItemButton, 'Options / Preferences'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(MenuItemButton, 'Options / Preferences'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Options / Preferences'), findsOneWidget);
      expect(find.textContaining('Theme'), findsWidgets);
      expect(find.textContaining('Editor'), findsWidgets);
    });
  });

  group('Import wizard launch', () {
    testWidgets('launches the generic CSV import wizard from startup options', (
      tester,
    ) async {
      final controller = WorkspaceController(
        gateway: FakeWorkspaceGateway(),
        configStore: InMemoryConfigStore(),
        workspaceStateStore: InMemoryWorkspaceStateStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp('decent-bench-it-');
      final csvPath = p.join(tempDir.path, 'customers.csv');
      await File(csvPath).writeAsString('id,name\n1,Ada\n2,Lin\n');

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
        DecentBenchApp(
          controller: controller,
          autoInitialize: false,
          logger: const NoOpAppLogger(),
          startupLaunchOptions: StartupLaunchOptions(
            importSourcePath: csvPath,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CSV Import Wizard'), findsOneWidget);
      expect(find.textContaining('Tables: 1'), findsOneWidget);
    });

    testWidgets(
      'launches archive chooser for ZIP imports from startup options',
      (tester) async {
        final controller = WorkspaceController(
          gateway: FakeWorkspaceGateway(),
          configStore: InMemoryConfigStore(),
          workspaceStateStore: InMemoryWorkspaceStateStore(),
        );
        final tempDir = await Directory.systemTemp.createTemp(
          'decent-bench-it-',
        );
        final zipPath = p.join(tempDir.path, 'bundle.zip');
        final archive = Archive()
          ..addFile(
            ArchiveFile(
              'customers.csv',
              14,
              'id,name\n1,Ada\n'.codeUnits,
            ),
          );
        await File(zipPath).writeAsBytes(
          ZipEncoder().encode(archive)!,
          flush: true,
        );

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
          DecentBenchApp(
            controller: controller,
            autoInitialize: false,
            logger: const NoOpAppLogger(),
            startupLaunchOptions: StartupLaunchOptions(
              importSourcePath: zipPath,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ZIP Wrapper Contents'), findsOneWidget);
        expect(find.textContaining('customers.csv'), findsOneWidget);
      },
    );

    testWidgets('launches JSON import wizard from startup options', (
      tester,
    ) async {
      final controller = WorkspaceController(
        gateway: FakeWorkspaceGateway(),
        configStore: InMemoryConfigStore(),
        workspaceStateStore: InMemoryWorkspaceStateStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp('decent-bench-it-');
      final jsonPath = p.join(tempDir.path, 'data.json');
      await File(jsonPath).writeAsString(
        '[{"id": 1, "name": "Ada"}, {"id": 2, "name": "Lin"}]',
      );

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
        DecentBenchApp(
          controller: controller,
          autoInitialize: false,
          logger: const NoOpAppLogger(),
          startupLaunchOptions: StartupLaunchOptions(
            importSourcePath: jsonPath,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Import Wizard'), findsOneWidget);
      expect(find.textContaining('Tables: 1'), findsOneWidget);
    });

    testWidgets('launches XML import wizard from startup options', (
      tester,
    ) async {
      final controller = WorkspaceController(
        gateway: FakeWorkspaceGateway(),
        configStore: InMemoryConfigStore(),
        workspaceStateStore: InMemoryWorkspaceStateStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp('decent-bench-it-');
      final xmlPath = p.join(tempDir.path, 'catalog.xml');
      await File(xmlPath).writeAsString(
        '<?xml version="1.0"?>'
        '<catalog><item><id>1</id><name>Widget</name></item>'
        '<item><id>2</id><name>Gadget</name></item></catalog>',
      );

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
        DecentBenchApp(
          controller: controller,
          autoInitialize: false,
          logger: const NoOpAppLogger(),
          startupLaunchOptions: StartupLaunchOptions(
            importSourcePath: xmlPath,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Import Wizard'), findsOneWidget);
    });

    testWidgets('launches HTML table import wizard from startup options', (
      tester,
    ) async {
      final controller = WorkspaceController(
        gateway: FakeWorkspaceGateway(),
        configStore: InMemoryConfigStore(),
        workspaceStateStore: InMemoryWorkspaceStateStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp('decent-bench-it-');
      final htmlPath = p.join(tempDir.path, 'report.html');
      await File(htmlPath).writeAsString(
        '<html><body><table><tr><th>Name</th><th>Age</th></tr>'
        '<tr><td>Alice</td><td>30</td></tr></table></body></html>',
      );

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
        DecentBenchApp(
          controller: controller,
          autoInitialize: false,
          logger: const NoOpAppLogger(),
          startupLaunchOptions: StartupLaunchOptions(
            importSourcePath: htmlPath,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Import Wizard'), findsOneWidget);
    });
  });
}
