import 'package:decent_bench/app/app.dart';
import 'package:decent_bench/app/logging/app_logger.dart';
import 'package:decent_bench/app/startup_launch_options.dart';
import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_shell_preferences.dart';
import 'package:decent_bench/features/workspace/infrastructure/app_lifecycle_service.dart';
import 'package:decent_bench/features/workspace/infrastructure/shortcut_config_service.dart';
import 'package:decent_bench/features/workspace/presentation/preferences_dialog.dart';
import 'package:decent_bench/features/workspace/presentation/shell/results_pane.dart';
import 'package:decent_bench/features/workspace/presentation/shell/schema_explorer_pane.dart';
import 'package:decent_bench/features/workspace/presentation/shell/status_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void _configureDesktopViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 1000);
}

WorkspaceController _createController({
  FakeWorkspaceGateway? gateway,
  InMemoryConfigStore? configStore,
  InMemoryWorkspaceStateStore? workspaceStateStore,
}) {
  return WorkspaceController(
    gateway: gateway ?? FakeWorkspaceGateway(),
    configStore: configStore ?? InMemoryConfigStore(),
    workspaceStateStore: workspaceStateStore ?? InMemoryWorkspaceStateStore(),
    savedQueryLibraryStore: InMemorySavedQueryLibraryStore(),
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  WorkspaceController controller, {
  StartupLaunchOptions startupLaunchOptions = const StartupLaunchOptions(),
  AppLifecycleService? appLifecycleService,
}) async {
  _configureDesktopViewport(tester);
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
      startupLaunchOptions: startupLaunchOptions,
      appLifecycleService:
          appLifecycleService ?? const FlutterAppLifecycleService(),
    ),
  );
}

void main() {
  group('Shell rendering', () {
    testWidgets('renders the desktop shell with classic panes', (tester) async {
      final controller = _createController();
      await _pumpShell(tester, controller);
      await tester.pumpAndSettle();

      expect(find.text('File'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Schema Explorer'), findsOneWidget);
      expect(find.text('Properties / Details'), findsOneWidget);
      expect(find.text('SQL Editor'), findsOneWidget);
      expect(find.text('Results Window'), findsOneWidget);
      expect(find.textContaining('Workspace:'), findsOneWidget);
      expect(find.text('Export path'), findsNothing);
      expect(find.text('Export CSV'), findsNothing);
      expect(tester.getSize(find.byType(StatusBar)).width, 1600);
      expect(
        find.widgetWithText(OutlinedButton, 'Import SQLite...'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'New Query Tab'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Manage'), findsNothing);

      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      expect(find.text('Manage Snippets'), findsOneWidget);
      expect(find.text('Database Statistics'), findsOneWidget);
    });
  });

  group('Configuration and shortcuts', () {
    testWidgets('loads shortcut labels from TOML-backed config into the menu', (
      tester,
    ) async {
      final config = AppConfig.defaults().copyWith(
        shortcutBindings: <String, String>{
          ...AppConfig.defaultShortcutBindings(),
          'file_exit': 'Ctrl+Shift+Q',
        },
      );
      final controller = _createController(
        configStore: InMemoryConfigStore(config),
      );
      await _pumpShell(tester, controller);
      await tester.pumpAndSettle();

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();

      expect(find.text('Exit'), findsOneWidget);
      expect(find.text('Ctrl+Shift+Q'), findsOneWidget);
    });

    testWidgets('File Exit requests an application shutdown', (tester) async {
      final lifecycle = FakeAppLifecycleService();
      final controller = _createController();
      await _pumpShell(tester, controller, appLifecycleService: lifecycle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(lifecycle.requestedExit, isTrue);
    });

    testWidgets('editor line numbers respect the configuration toggle', (
      tester,
    ) async {
      final config = AppConfig.defaults().copyWith(
        editorSettings: AppConfig.defaults().editorSettings.copyWith(
          showLineNumbers: false,
        ),
      );
      final controller = _createController(
        configStore: InMemoryConfigStore(config),
      );
      await _pumpShell(tester, controller);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('sql_editor.gutter')),
        findsNothing,
      );
    });
  });

  group('Import wizards', () {
    testWidgets('toolbar import entry opens the SQLite wizard', (tester) async {
      final controller = _createController();
      await _pumpShell(tester, controller);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Import SQLite...'));
      await tester.pumpAndSettle();

      expect(find.text('SQLite Import Wizard'), findsOneWidget);
    });

    testWidgets('startup --import opens the matching import wizard', (
      tester,
    ) async {
      final controller = _createController();
      await _pumpShell(
        tester,
        controller,
        startupLaunchOptions: const StartupLaunchOptions(
          importSourcePath: '/tmp/source.xlsx',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excel Import Wizard'), findsOneWidget);
    });
  });

  group('Schema explorer', () {
    testWidgets('reports a table node on secondary tap', (tester) async {
      String? shownNodeId;
      Offset? shownPosition;

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: SchemaExplorerPane(
                schema: FakeWorkspaceGateway().snapshot,
                databasePath: '/tmp/schema-menu.ddb',
                selectedNodeId: null,
                onSelectNode: (_) {},
                onShowNodeMenu: (nodeId, position) {
                  shownNodeId = nodeId;
                  shownPosition = position;
                },
                onRefresh: () {},
                isLoading: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tasksFinder = find.text('tasks').first;
      await tester.tapAt(
        tester.getCenter(tasksFinder),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(shownNodeId, 'table:tasks');
      expect(shownPosition, isNotNull);
    });

    testWidgets('shows child totals for tables and views', (tester) async {
      final schema = FakeWorkspaceGateway().snapshot;

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: SchemaExplorerPane(
                schema: schema,
                databasePath: '/tmp/schema-counts.ddb',
                selectedNodeId: null,
                onSelectNode: (_) {},
                onShowNodeMenu: (_, _) {},
                onRefresh: () {},
                isLoading: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tasksBranch = find.byKey(
        const PageStorageKey<String>('table:tasks'),
      );
      final tasksRect = tester.getRect(tasksBranch);
      await tester.tapAt(
        Offset(tasksRect.right - 20, tasksRect.top + (tasksRect.height / 2)),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('schema.count.folder:tasks:columns'),
          ),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('schema.count.folder:tasks:indexes'),
          ),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('schema.count.folder:tasks:constraints'),
          ),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('schema.count.folder:tasks:triggers'),
          ),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      final viewBranch = find.byKey(
        const PageStorageKey<String>('view:active_tasks'),
      );
      await tester.ensureVisible(viewBranch);
      final viewRect = tester.getRect(viewBranch);
      await tester.tapAt(
        Offset(viewRect.right - 20, viewRect.top + (viewRect.height / 2)),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('schema.count.folder:active_tasks:columns'),
          ),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('schema.count.folder:active_tasks:indexes'),
          ),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('schema.count.folder:active_tasks:triggers'),
          ),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows branch, temp, generated, and native type metadata', (
      tester,
    ) async {
      final schema = SchemaSnapshot(
        objects: const <SchemaObjectSummary>[
          SchemaObjectSummary(
            name: 'geo_points',
            kind: SchemaObjectKind.table,
            temporary: true,
            ddl:
                'CREATE TEMP TABLE geo_points (id INT64 PRIMARY KEY, shape GEOMETRY, status ENUM);',
            checks: <SchemaCheckConstraint>[
              SchemaCheckConstraint(
                name: 'shape_valid',
                exprSql: 'shape IS NOT NULL',
              ),
            ],
            columns: <SchemaColumn>[
              SchemaColumn(
                name: 'id',
                type: 'INT64',
                notNull: true,
                unique: true,
                primaryKey: true,
                refTable: null,
                refColumn: null,
                refOnDelete: null,
                refOnUpdate: null,
              ),
              SchemaColumn(
                name: 'shape',
                type: 'GEOMETRY',
                notNull: true,
                unique: false,
                primaryKey: false,
                refTable: null,
                refColumn: null,
                refOnDelete: null,
                refOnUpdate: null,
              ),
              SchemaColumn(
                name: 'status',
                type: "ENUM('open','closed')",
                notNull: false,
                unique: false,
                primaryKey: false,
                defaultExpr: "'open'",
                refTable: null,
                refColumn: null,
                refOnDelete: null,
                refOnUpdate: null,
              ),
              SchemaColumn(
                name: 'shape_hash',
                type: 'TEXT',
                notNull: false,
                unique: false,
                primaryKey: false,
                generatedExpr: 'lower(hex(shape))',
                generatedStored: true,
                refTable: null,
                refColumn: null,
                refOnDelete: null,
                refOnUpdate: null,
              ),
            ],
          ),
        ],
        indexes: const <IndexSummary>[
          IndexSummary(
            name: 'idx_geo_points_shape',
            table: 'geo_points',
            columns: <String>['shape'],
            unique: false,
            kind: 'rtree',
            temporary: true,
          ),
        ],
        triggers: const <TriggerSummary>[
          TriggerSummary(
            name: 'geo_points_ai',
            targetName: 'geo_points',
            targetKind: 'table',
            timing: 'after',
            events: <String>['insert'],
            eventsMask: 1,
            forEachRow: true,
            temporary: true,
            actionSql: 'SELECT 1',
            ddl:
                'CREATE TEMP TRIGGER geo_points_ai AFTER INSERT ON geo_points BEGIN SELECT 1; END;',
          ),
        ],
        loadedAt: DateTime(2026, 5, 19),
      );
      final metadata = ToolingMetadata(
        metadataVersion: 1,
        engineVersion: '2.5.2',
        databaseFormatVersion: 8,
        schemaCookie: 12,
        tempSchemaCookie: 2,
        schemaFingerprint:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        schemaFingerprintAlgorithm: 'sha256:decentdb-tooling-schema-v1',
        columnTypeMetadata: const <ToolingColumnTypeMetadata>[
          ToolingColumnTypeMetadata(
            tableName: 'geo_points',
            columnName: 'shape',
            columnType: 'GEOMETRY',
            typeInfo: ToolingTypeInfo(
              typeName: 'GEOMETRY',
              valueKind: 'geometry',
              cValueTag: 9,
              spatial: ToolingSpatialTypeInfo(
                subtype: 'POINT',
                dimensions: 'XY',
                srid: 4326,
              ),
            ),
          ),
          ToolingColumnTypeMetadata(
            tableName: 'geo_points',
            columnName: 'status',
            columnType: "ENUM('open','closed')",
            typeInfo: ToolingTypeInfo(
              typeName: "ENUM('open','closed')",
              valueKind: 'enum',
              cValueTag: 10,
            ),
          ),
        ],
        capabilities: const ToolingCapabilities(
          queryContractVersion: 1,
          queryDescribe: true,
          deterministicJson: true,
        ),
      );

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: SchemaExplorerPane(
                schema: schema,
                databasePath: '/tmp/schema-rich.ddb',
                toolingMetadata: metadata,
                branchLabel: 'analysis',
                selectedNodeId: null,
                onSelectNode: (_) {},
                onShowNodeMenu: (_, _) {},
                onRefresh: () {},
                isLoading: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Engine 2.5.2'), findsOneWidget);
      expect(find.text('Branch analysis'), findsOneWidget);
      expect(find.text('Schema abcdef012345'), findsOneWidget);
      expect(find.text('Temporary'), findsOneWidget);
      expect(find.textContaining('geo_points  TEMP'), findsOneWidget);

      final indexSection = find.byKey(
        const PageStorageKey<String>('section:indexes'),
      );
      final indexRect = tester.getRect(indexSection);
      await tester.tapAt(
        Offset(indexRect.right - 20, indexRect.top + (indexRect.height / 2)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('idx_geo_points_shape'), findsOneWidget);

      final triggerSection = find.byKey(
        const PageStorageKey<String>('section:triggers'),
      );
      final triggerRect = tester.getRect(triggerSection);
      await tester.tapAt(
        Offset(
          triggerRect.right - 20,
          triggerRect.top + (triggerRect.height / 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('geo_points_ai'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('schema.filter')),
        'srid 4326',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('geo_points  TEMP'), findsOneWidget);
      expect(find.textContaining('POINT XY SRID 4326'), findsOneWidget);
      expect(find.textContaining('labels open, closed'), findsOneWidget);
      expect(find.textContaining('GENERATED STORED'), findsOneWidget);
      expect(find.text('No matching indexes'), findsOneWidget);
    });

    testWidgets('double click toggles a branch row', (tester) async {
      final schema = FakeWorkspaceGateway().snapshot;

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: SchemaExplorerPane(
                schema: schema,
                databasePath: '/tmp/schema-double-click.ddb',
                selectedNodeId: null,
                onSelectNode: (_) {},
                onShowNodeMenu: (_, _) {},
                onRefresh: () {},
                isLoading: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const columnsCountKey = ValueKey<String>(
        'schema.count.folder:tasks:columns',
      );
      expect(find.byKey(columnsCountKey), findsNothing);

      final tasksBranch = find.byKey(
        const PageStorageKey<String>('table:tasks'),
      );
      final tasksRect = tester.getRect(tasksBranch);
      final branchPoint = Offset(
        tasksRect.left + 24,
        tasksRect.top + (tasksRect.height / 2),
      );

      await tester.tapAt(branchPoint);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(branchPoint);
      await tester.pumpAndSettle();

      expect(find.byKey(columnsCountKey), findsOneWidget);

      final expandedTasksRect = tester.getRect(tasksBranch);
      final collapsePoint = Offset(
        expandedTasksRect.left + 24,
        expandedTasksRect.top + 20,
      );

      await tester.tapAt(collapsePoint);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(collapsePoint);
      await tester.pumpAndSettle();

      expect(find.byKey(columnsCountKey), findsNothing);
    });

    testWidgets('empty schemas do not render sample schema placeholders', (
      tester,
    ) async {
      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchemaExplorerPane(
              schema: SchemaSnapshot.empty(),
              databasePath: '/tmp/artistSearchEngine.ddb',
              selectedNodeId: 'database',
              onSelectNode: (_) {},
              onShowNodeMenu: (_, _) {},
              onRefresh: () {},
              isLoading: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('customers'), findsNothing);
      expect(find.text('orders'), findsNothing);
      expect(find.text('active_orders'), findsNothing);
    });
  });

  group('Results grid', () {
    testWidgets('execution plan tab renders EXPLAIN rows', (tester) async {
      final verticalScrollController = ScrollController();
      final horizontalScrollController = ScrollController();
      final tab = QueryTabState.initial(id: 'query-tab-1', title: 'Query 1')
          .copyWith(
            executionPlan: const QueryExecutionPlanState(
              columns: <String>['query_plan'],
              rows: <Map<String, Object?>>[
                <String, Object?>{
                  'query_plan':
                      'SCAN tasks USING COVERING INDEX idx_tasks_title',
                },
              ],
              isLoading: false,
            ),
          );

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        verticalScrollController.dispose();
        horizontalScrollController.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200,
                height: 600,
                child: Material(
                  child: ResultsPane(
                    activeTab: tab,
                    activeResultsTab: ResultsPaneTab.executionPlan,
                    verticalScrollController: verticalScrollController,
                    horizontalScrollController: horizontalScrollController,
                    interactionState: const ResultsGridInteractionState(),
                    onResultsTabChanged: (_) {},
                    onLoadNextPage: () {},
                    onSelectCell: (_, _) {},
                    onShowCellMenu: (_, _, _) {},
                    onSelectRow: (_) {},
                    onTogglePinnedColumn: (_) {},
                    onShowColumnStatistics: (_) {},
                    usePlaceholderContent: false,
                    tableEditabilityLabel: 'Read-only results',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('SCAN tasks'), findsOneWidget);
      expect(find.text('SCAN'), findsOneWidget);
      expect(find.text('table tasks'), findsOneWidget);
      expect(find.text('index idx_tasks_title'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Copy Raw Plan'), findsOneWidget);
    });

    testWidgets('columns resize by dragging the header handle', (tester) async {
      final verticalScrollController = ScrollController();
      final horizontalScrollController = ScrollController();
      final tab = QueryTabState.initial(id: 'query-tab-1', title: 'Query 1')
          .copyWith(
            lastSql: 'SELECT id, name FROM customers',
            resultColumns: const <String>['id', 'name'],
            resultRows: const <Map<String, Object?>>[
              <String, Object?>{'id': 1, 'name': 'Ada'},
              <String, Object?>{'id': 2, 'name': 'Lin'},
            ],
          );

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        verticalScrollController.dispose();
        horizontalScrollController.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200,
                height: 600,
                child: Material(
                  child: ResultsPane(
                    activeTab: tab,
                    activeResultsTab: ResultsPaneTab.results,
                    verticalScrollController: verticalScrollController,
                    horizontalScrollController: horizontalScrollController,
                    interactionState: const ResultsGridInteractionState(),
                    onResultsTabChanged: (_) {},
                    onLoadNextPage: () {},
                    onSelectCell: (_, _) {},
                    onShowCellMenu: (_, _, _) {},
                    onSelectRow: (_) {},
                    onTogglePinnedColumn: (_) {},
                    onShowColumnStatistics: (_) {},
                    usePlaceholderContent: false,
                    tableEditabilityLabel: 'Read-only results',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final headerFinder = find.byKey(
        const ValueKey<String>('results.header.name'),
      );
      final resizeHandleFinder = find.byKey(
        const ValueKey<String>('results.resize.name'),
      );

      final initialWidth = tester.getSize(headerFinder).width;
      await tester.drag(resizeHandleFinder, const Offset(72, 0));
      await tester.pump();

      final expandedWidth = tester.getSize(headerFinder).width;
      expect(expandedWidth, greaterThan(initialWidth));

      await tester.drag(resizeHandleFinder, const Offset(-500, 0));
      await tester.pump();

      final shrunkWidth = tester.getSize(headerFinder).width;
      expect(shrunkWidth, lessThan(expandedWidth));
      expect(shrunkWidth, greaterThanOrEqualTo(96));
    });

    testWidgets('chart tab renders loaded numeric results', (tester) async {
      final verticalScrollController = ScrollController();
      final horizontalScrollController = ScrollController();
      final tab = QueryTabState.initial(id: 'tab-1', title: 'Query 1').copyWith(
        resultColumns: const <String>['region', 'total'],
        resultRows: const <Map<String, Object?>>[
          <String, Object?>{'region': 'North', 'total': 12.5},
          <String, Object?>{'region': 'South', 'total': 7.5},
        ],
      );

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        verticalScrollController.dispose();
        horizontalScrollController.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200,
                height: 600,
                child: Material(
                  child: ResultsPane(
                    activeTab: tab,
                    activeResultsTab: ResultsPaneTab.chart,
                    verticalScrollController: verticalScrollController,
                    horizontalScrollController: horizontalScrollController,
                    interactionState: const ResultsGridInteractionState(),
                    onResultsTabChanged: (_) {},
                    onLoadNextPage: () {},
                    onSelectCell: (_, _) {},
                    onShowCellMenu: (_, _, _) {},
                    onSelectRow: (_) {},
                    onTogglePinnedColumn: (_) {},
                    onShowColumnStatistics: (_) {},
                    usePlaceholderContent: false,
                    tableEditabilityLabel: 'Read-only results',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bar'), findsOneWidget);
      expect(find.text('Line'), findsOneWidget);
      expect(find.text('X: region'), findsOneWidget);
      expect(find.text('Y: total'), findsOneWidget);
      expect(find.text('2 plotted points'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Export PNG'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('empty state avoids overflow in short panels', (tester) async {
      final verticalScrollController = ScrollController();
      final horizontalScrollController = ScrollController();
      final tab = QueryTabState.initial(id: 'tab-1', title: 'Query 1').copyWith(
        lastSql: 'SELECT * FROM tasks',
        statusMessage:
            'Ready. Execute a query to capture elapsed time, row counts, and warnings.',
      );
      final previousOnError = FlutterError.onError;
      FlutterErrorDetails? overflowError;

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        verticalScrollController.dispose();
        horizontalScrollController.dispose();
        FlutterError.onError = previousOnError;
      });
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('RenderFlex overflowed')) {
          overflowError = details;
        }
        previousOnError?.call(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200,
                height: 140,
                child: Material(
                  child: ResultsPane(
                    activeTab: tab,
                    activeResultsTab: ResultsPaneTab.results,
                    verticalScrollController: verticalScrollController,
                    horizontalScrollController: horizontalScrollController,
                    interactionState: const ResultsGridInteractionState(),
                    onResultsTabChanged: (_) {},
                    onLoadNextPage: () {},
                    onSelectCell: (_, _) {},
                    onShowCellMenu: (_, _, _) {},
                    onSelectRow: (_) {},
                    onTogglePinnedColumn: (_) {},
                    onShowColumnStatistics: (_) {},
                    usePlaceholderContent: false,
                    tableEditabilityLabel: 'Read-only results',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(overflowError, isNull);
      expect(find.text('Query returned no rows.'), findsOneWidget);
    });
  });

  group('Preferences dialog', () {
    testWidgets('previews theme changes without persisting until save', (
      tester,
    ) async {
      Future<void> settleUi() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }

      final initialConfig = AppConfig.defaults();
      AppConfig? savedConfig;
      String? previewedThemeId;

      _configureDesktopViewport(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PreferencesDialog(
            initialConfig: initialConfig,
            configFilePath: '/tmp/config.toml',
            shortcutConfigService: const ShortcutConfigService(),
            createSnippetId: () => 'snippet-1',
            availableThemesById: const <String, String>{
              'classic-dark': 'Classic Dark',
              'classic-light': 'Classic Light',
            },
            resolvedThemesDirectory: '/tmp/themes',
            onPreviewTheme: (themeId) async {
              previewedThemeId = themeId;
            },
            onSave: (config) async {
              savedConfig = config;
              return null;
            },
          ),
        ),
      );
      await settleUi();

      await tester.tap(
        find.byKey(const ValueKey<String>('preferences.active_theme')),
      );
      await settleUi();
      await tester.tap(find.text('Classic Light').last);
      await settleUi();

      expect(previewedThemeId, 'classic-light');
      expect(savedConfig, isNull);
      expect(initialConfig.appearance.activeTheme, 'classic-dark');
    });
  });
}
