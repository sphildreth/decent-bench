import 'dart:io';

import 'package:decent_bench/app/app.dart';
import 'package:decent_bench/app/logging/app_logger.dart';
import 'package:decent_bench/app/startup_launch_options.dart';
import 'package:archive/archive.dart';
import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import '../test/support/fakes.dart';

const _integrationTestTimeout = Timeout(Duration(minutes: 1));

WorkspaceController _createController({FakeWorkspaceGateway? gateway}) {
  return WorkspaceController(
    gateway: gateway ?? FakeWorkspaceGateway(),
    configStore: InMemoryConfigStore(),
    workspaceStateStore: InMemoryWorkspaceStateStore(),
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  WorkspaceController controller, {
  StartupLaunchOptions startupLaunchOptions = const StartupLaunchOptions(),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 1000);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    controller.dispose();
  });

  await tester.pumpWidget(
    DecentBenchApp(
      controller: controller,
      autoInitialize: false,
      logger: const NoOpAppLogger(),
      startupLaunchOptions: startupLaunchOptions,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() {
    messenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
      if (call.method == 'Menu.isPluginAvailable') {
        return false;
      }
      return null;
    });
  });

  tearDownAll(() {
    messenger.setMockMethodCallHandler(SystemChannels.menu, null);
  });

  group('Shell rendering', () {
    testWidgets('renders the desktop shell', (tester) async {
      final controller = _createController();

      await controller.initialize();
      await _pumpShell(tester, controller);

      expect(find.text('Schema Explorer'), findsOneWidget);
      expect(find.text('SQL Editor'), findsOneWidget);
      expect(find.text('Results Window'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Format'), findsOneWidget);
    }, timeout: _integrationTestTimeout);
  });

  group('Workspace operations', () {
    testWidgets(
      'opens a workspace and runs a query inside the shell',
      (tester) async {
        final controller = _createController();
        final tempDir = await Directory.systemTemp.createTemp(
          'decent-bench-it-',
        );
        final dbPath = p.join(tempDir.path, 'workspace.ddb');

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);
        controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');

        await _pumpShell(tester, controller);

        expect(find.text('tasks'), findsWidgets);

        await tester.tap(find.widgetWithText(FilledButton, 'Run'));
        await tester.pumpAndSettle();

        expect(find.text('Ship phase 1'), findsOneWidget);
        expect(find.textContaining('Workspace: workspace.ddb'), findsOneWidget);
      },
      timeout: _integrationTestTimeout,
    );

    testWidgets(
      'creates and switches between multiple editor tabs',
      (tester) async {
        final controller = _createController(
          gateway: _QualityIntegrationGateway(),
        );

        await controller.initialize();
        controller.createTab(sql: 'SELECT 1');
        controller.createTab(sql: 'SELECT 2');

        await _pumpShell(tester, controller);

        expect(find.textContaining('Query'), findsAtLeastNWidgets(3));
      },
      timeout: _integrationTestTimeout,
    );

    testWidgets(
      'opens preferences dialog from Options menu',
      (tester) async {
        final controller = _createController();

        await controller.initialize();
        await _pumpShell(tester, controller);

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
      },
      timeout: _integrationTestTimeout,
    );

    testWidgets(
      'shows quality dashboard results for an open workspace',
      (tester) async {
        final controller = _createController();
        final tempDir = await Directory.systemTemp.createTemp(
          'decent-bench-it-',
        );
        final dbPath = p.join(tempDir.path, 'workspace.ddb');

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);

        await _pumpShell(tester, controller);

        await tester.tap(find.text('Quality').first);
        await tester.pumpAndSettle();

        expect(find.text('No run'), findsOneWidget);
        expect(find.textContaining('Run a quality profile'), findsOneWidget);

        await controller.dataQuality.startRun();
        await tester.pump();

        expect(controller.dataQuality.currentRun?.status.name, 'completed');
        expect(find.text('Tables'), findsWidgets);
        expect(find.text('Rows'), findsWidgets);
      },
      timeout: _integrationTestTimeout,
    );
  });

  group('Import wizard launch', () {
    testWidgets(
      'launches the generic CSV import wizard from startup options',
      (tester) async {
        final controller = _createController();
        final tempDir = await Directory.systemTemp.createTemp(
          'decent-bench-it-',
        );
        final csvPath = p.join(tempDir.path, 'customers.csv');
        await File(csvPath).writeAsString('id,name\n1,Ada\n2,Lin\n');

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        await controller.initialize();
        await _pumpShell(
          tester,
          controller,
          startupLaunchOptions: StartupLaunchOptions(importSourcePath: csvPath),
        );

        expect(find.text('CSV Import Wizard'), findsOneWidget);
        expect(find.textContaining('Tables: 1'), findsOneWidget);
      },
      timeout: _integrationTestTimeout,
    );

    testWidgets(
      'launches archive chooser for ZIP imports from startup options',
      (tester) async {
        final controller = _createController();
        final tempDir = await Directory.systemTemp.createTemp(
          'decent-bench-it-',
        );
        final zipPath = p.join(tempDir.path, 'bundle.zip');
        final archive = Archive()
          ..addFile(
            ArchiveFile('customers.csv', 14, 'id,name\n1,Ada\n'.codeUnits),
          );
        await File(
          zipPath,
        ).writeAsBytes(ZipEncoder().encode(archive)!, flush: true);

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        await controller.initialize();
        await _pumpShell(
          tester,
          controller,
          startupLaunchOptions: StartupLaunchOptions(importSourcePath: zipPath),
        );

        expect(find.text('ZIP Wrapper Contents'), findsOneWidget);
        expect(find.textContaining('customers.csv'), findsOneWidget);
      },
      timeout: _integrationTestTimeout,
    );

    testWidgets(
      'launches JSON import wizard from startup options',
      (tester) async {
        final controller = _createController();
        final tempDir = await Directory.systemTemp.createTemp(
          'decent-bench-it-',
        );
        final jsonPath = p.join(tempDir.path, 'data.json');
        await File(
          jsonPath,
        ).writeAsString('[{"id": 1, "name": "Ada"}, {"id": 2, "name": "Lin"}]');

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        await controller.initialize();
        await _pumpShell(
          tester,
          controller,
          startupLaunchOptions: StartupLaunchOptions(
            importSourcePath: jsonPath,
          ),
        );

        expect(find.textContaining('Import Wizard'), findsOneWidget);
        expect(find.textContaining('Tables: 1'), findsOneWidget);
      },
      timeout: _integrationTestTimeout,
    );

    testWidgets(
      'launches XML import wizard from startup options',
      (tester) async {
        final controller = _createController();
        final tempDir = await Directory.systemTemp.createTemp(
          'decent-bench-it-',
        );
        final xmlPath = p.join(tempDir.path, 'catalog.xml');
        await File(xmlPath).writeAsString(
          '<?xml version="1.0"?>'
          '<catalog><item><id>1</id><name>Widget</name></item>'
          '<item><id>2</id><name>Gadget</name></item></catalog>',
        );

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        await controller.initialize();
        await _pumpShell(
          tester,
          controller,
          startupLaunchOptions: StartupLaunchOptions(importSourcePath: xmlPath),
        );

        expect(find.textContaining('Import Wizard'), findsOneWidget);
      },
      timeout: _integrationTestTimeout,
    );

    testWidgets(
      'launches HTML table import wizard from startup options',
      (tester) async {
        final controller = _createController();
        final tempDir = await Directory.systemTemp.createTemp(
          'decent-bench-it-',
        );
        final htmlPath = p.join(tempDir.path, 'report.html');
        await File(htmlPath).writeAsString(
          '<html><body><table><tr><th>Name</th><th>Age</th></tr>'
          '<tr><td>Alice</td><td>30</td></tr></table></body></html>',
        );

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        await controller.initialize();
        await _pumpShell(
          tester,
          controller,
          startupLaunchOptions: StartupLaunchOptions(
            importSourcePath: htmlPath,
          ),
        );

        expect(find.textContaining('Import Wizard'), findsOneWidget);
      },
      timeout: _integrationTestTimeout,
    );
  });
}

class _QualityIntegrationGateway extends FakeWorkspaceGateway {
  final List<String> executedSql = <String>[];

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  }) async {
    lastRunQuerySql = sql;
    lastRunQueryParams = <Object?>[...params];
    executedSql.add(sql);
    final normalized = sql.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.contains('COUNT(*) AS failure_count')) {
      return _page(
        columns: const <String>['failure_count'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'failure_count': 0},
        ],
      );
    }
    if (normalized.contains('COUNT(*) AS row_count')) {
      return _page(
        columns: const <String>['row_count'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'row_count': 2},
        ],
      );
    }
    if (normalized.contains('SUM(CASE')) {
      final isTitle = normalized.contains('"title"');
      return _page(
        columns: const <String>[
          'row_count',
          'null_count',
          'non_null_count',
          'empty_string_count',
          'distinct_count',
          'min_value',
          'max_value',
          'mean_value',
          'min_length',
          'max_length',
        ],
        rows: <Map<String, Object?>>[
          <String, Object?>{
            'row_count': 2,
            'null_count': 0,
            'non_null_count': 2,
            'empty_string_count': 0,
            'distinct_count': isTitle ? 1 : 2,
            'min_value': isTitle ? 'Ship phase 1' : 1,
            'max_value': isTitle ? 'Ship phase 1' : 2,
            'mean_value': isTitle ? null : 1.5,
            'min_length': isTitle ? 12 : 1,
            'max_length': isTitle ? 12 : 1,
          },
        ],
      );
    }
    if (normalized.contains('GROUP BY')) {
      return _page(
        columns: const <String>['value_display', 'value_count'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'value_display': 'Ship phase 1', 'value_count': 2},
        ],
      );
    }
    if (normalized.contains('SELECT "id" AS value')) {
      return _page(
        columns: const <String>['value'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'value': 1},
          <String, Object?>{'value': 2},
        ],
      );
    }
    return super.runQuery(sql: sql, params: params, pageSize: pageSize);
  }

  QueryResultPage _page({
    required List<String> columns,
    required List<Map<String, Object?>> rows,
  }) {
    return QueryResultPage(
      cursorId: null,
      columns: columns,
      rows: rows,
      done: true,
      rowsAffected: null,
      elapsed: const Duration(milliseconds: 1),
    );
  }
}
