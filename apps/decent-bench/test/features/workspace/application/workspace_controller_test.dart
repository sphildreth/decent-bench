import 'dart:io';

import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/excel_import_models.dart';
import 'package:decent_bench/features/workspace/domain/sql_dump_import_models.dart';
import 'package:decent_bench/features/workspace/domain/sqlite_import_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

WorkspaceController _createController({
  FakeWorkspaceGateway? gateway,
  InMemoryConfigStore? configStore,
  InMemoryWorkspaceStateStore? workspaceStateStore,
  InMemorySavedQueryLibraryStore? savedQueryLibraryStore,
  RecordingAppLogger? logger,
}) {
  return WorkspaceController(
    gateway: gateway ?? FakeWorkspaceGateway(),
    configStore: configStore ?? InMemoryConfigStore(),
    workspaceStateStore: workspaceStateStore ?? InMemoryWorkspaceStateStore(),
    savedQueryLibraryStore:
        savedQueryLibraryStore ?? InMemorySavedQueryLibraryStore(),
    logger: logger,
  );
}

String _tempDbPath() {
  return '${Directory.systemTemp.path}/workbench-${DateTime.now().microsecondsSinceEpoch}.ddb';
}

Future<File> _createTempDbFile() async {
  final path = _tempDbPath();
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString('');
  addTearDown(() async {
    if (await file.exists()) {
      await file.delete();
    }
  });
  return file;
}

class _TrackingWorkspaceGateway extends FakeWorkspaceGateway {
  _TrackingWorkspaceGateway({required this.queryContract});

  final QueryContract queryContract;

  int runQueryCallCount = 0;
  List<Object?>? lastRunParams;
  final List<List<Object?>> runQueryParamsHistory = <List<Object?>>[];

  @override
  Future<QueryContract> describeQueryContract(String sql) async {
    lastDescribedQuerySql = sql;
    return queryContract;
  }

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  }) async {
    runQueryCallCount += 1;
    lastRunParams = <Object?>[...params];
    runQueryParamsHistory.add(<Object?>[...params]);
    return super.runQuery(sql: sql, params: params, pageSize: pageSize);
  }
}

QueryContract _makeQueryContract({
  List<QueryParameterContract> parameters = const <QueryParameterContract>[],
}) {
  return QueryContract(
    contractVersion: 1,
    sql: 'query',
    statementKind: 'query',
    readOnly: true,
    schemaCookie: 1,
    tempSchemaCookie: 0,
    schemaFingerprint: 'fingerprint',
    parameters: parameters,
    resultColumns: const <QueryResultColumnContract>[],
    diagnostics: const <String>[],
  );
}

void main() {
  group('Initialization', () {
    test('initialize loads config and native library path', () async {
      final controller = _createController();
      await controller.initialize();

      expect(controller.nativeLibraryPath, '/tmp/libdecentdb.so');
      expect(controller.workspaceMessage, 'Ready.');
      expect(controller.tabs, hasLength(1));
    });

    test(
      'initialize reopens the most recent workspace when it still exists',
      () async {
        final file = await _createTempDbFile();
        final config = AppConfig.defaults().copyWith(
          recentFiles: <String>[file.path],
        );
        final controller = _createController(
          configStore: InMemoryConfigStore(config),
        );

        await controller.initialize();

        expect(controller.databasePath, file.path);
        expect(controller.engineVersion, '1.6.1');
        expect(controller.schema.tables.single.name, 'tasks');
        expect(controller.workspaceError, isNull);
      },
    );

    test(
      'initialize reruns the most recent saved query when reopening the last workspace',
      () async {
        final file = await _createTempDbFile();
        final config = AppConfig.defaults().copyWith(
          recentFiles: <String>[file.path],
        );
        final workspaceStateStore = InMemoryWorkspaceStateStore();
        await workspaceStateStore.save(
          file.path,
          PersistedWorkspaceState(
            schemaVersion: PersistedWorkspaceState.currentSchemaVersion,
            activeTabId: 'query-tab-1',
            tabs: <WorkspaceTabDraft>[
              WorkspaceTabDraft(
                id: 'query-tab-1',
                title: 'Query 1',
                sql: 'SELECT 1;',
                parameterJson: '',
                exportPath: '',
                queryHistory: <QueryHistoryEntry>[
                  QueryHistoryEntry(
                    sql: 'SELECT id, title FROM tasks ORDER BY id',
                    parameterJson: '',
                    ranAt: DateTime(2026, 3, 10, 9, 30),
                    outcome: QueryHistoryOutcome.completed,
                    elapsed: const Duration(milliseconds: 12),
                    rowsLoaded: 2,
                    rowsAffected: null,
                  ),
                ],
              ),
            ],
          ),
        );
        final controller = _createController(
          configStore: InMemoryConfigStore(config),
          workspaceStateStore: workspaceStateStore,
        );

        await controller.initialize();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.databasePath, file.path);
        expect(
          controller.activeTab.sql,
          'SELECT id, title FROM tasks ORDER BY id',
        );
        expect(controller.activeTab.resultRows.single['title'], 'Ship phase 1');
        expect(controller.activeTab.phase, QueryPhase.completed);
      },
    );

    test(
      'initialize runs a first-table preview query when reopening a workspace without query history',
      () async {
        final file = await _createTempDbFile();
        final controller = _createController(
          configStore: InMemoryConfigStore(
            AppConfig.defaults().copyWith(recentFiles: <String>[file.path]),
          ),
        );

        await controller.initialize();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.databasePath, file.path);
        expect(controller.activeTab.sql, startsWith('SELECT *'));
        expect(controller.activeTab.sql, contains('FROM "tasks"'));
        expect(controller.activeTab.resultRows.single['title'], 'Ship phase 1');
        expect(controller.activeTab.executionPlan.isLoading, isFalse);
        expect(
          controller.activeTab.executionPlan.rows.single['query_plan'],
          contains('SCAN tasks'),
        );
      },
    );

    test(
      'initialize ignores failed history entries and falls back to a preview query',
      () async {
        final file = await _createTempDbFile();
        final workspaceStateStore = InMemoryWorkspaceStateStore();
        await workspaceStateStore.save(
          file.path,
          PersistedWorkspaceState(
            schemaVersion: PersistedWorkspaceState.currentSchemaVersion,
            activeTabId: 'query-tab-1',
            tabs: <WorkspaceTabDraft>[
              WorkspaceTabDraft(
                id: 'query-tab-1',
                title: 'Query 1',
                sql: 'ANALYZE albums;',
                parameterJson: '',
                exportPath: '',
                queryHistory: <QueryHistoryEntry>[
                  QueryHistoryEntry(
                    sql: 'ANALYZE albums;',
                    parameterJson: '',
                    ranAt: DateTime(2026, 3, 10, 17, 34),
                    outcome: QueryHistoryOutcome.failed,
                    elapsed: Duration.zero,
                    rowsLoaded: 0,
                    rowsAffected: null,
                    errorMessage: 'syntax error near albums',
                  ),
                ],
              ),
            ],
          ),
        );
        final controller = _createController(
          configStore: InMemoryConfigStore(
            AppConfig.defaults().copyWith(recentFiles: <String>[file.path]),
          ),
          workspaceStateStore: workspaceStateStore,
        );

        await controller.initialize();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.activeTab.sql, startsWith('SELECT *'));
        expect(controller.activeTab.sql, contains('FROM "tasks"'));
        expect(controller.activeTab.phase, QueryPhase.completed);
        expect(controller.activeTab.resultRows.single['title'], 'Ship phase 1');
      },
    );

    test(
      'initialize skips a newer non-restorable completed query and falls back to a preview query',
      () async {
        final file = await _createTempDbFile();
        final workspaceStateStore = InMemoryWorkspaceStateStore();
        await workspaceStateStore.save(
          file.path,
          PersistedWorkspaceState(
            schemaVersion: PersistedWorkspaceState.currentSchemaVersion,
            activeTabId: 'query-tab-1',
            tabs: <WorkspaceTabDraft>[
              WorkspaceTabDraft(
                id: 'query-tab-1',
                title: 'Query 1',
                sql: 'CREATE TABLE archived_tasks (id INTEGER);',
                parameterJson: '',
                exportPath: '',
                queryHistory: <QueryHistoryEntry>[
                  QueryHistoryEntry(
                    sql: 'SELECT id, title FROM tasks ORDER BY id',
                    parameterJson: '',
                    ranAt: DateTime(2026, 3, 10, 9, 30),
                    outcome: QueryHistoryOutcome.completed,
                    elapsed: const Duration(milliseconds: 12),
                    rowsLoaded: 2,
                    rowsAffected: null,
                  ),
                  QueryHistoryEntry(
                    sql: 'CREATE TABLE archived_tasks (id INTEGER);',
                    parameterJson: '',
                    ranAt: DateTime(2026, 3, 10, 9, 31),
                    outcome: QueryHistoryOutcome.completed,
                    elapsed: const Duration(milliseconds: 3),
                    rowsLoaded: 0,
                    rowsAffected: 0,
                  ),
                ],
              ),
            ],
          ),
        );
        final controller = _createController(
          configStore: InMemoryConfigStore(
            AppConfig.defaults().copyWith(recentFiles: <String>[file.path]),
          ),
          workspaceStateStore: workspaceStateStore,
        );

        await controller.initialize();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.databasePath, file.path);
        expect(controller.activeTab.sql, startsWith('SELECT *'));
        expect(controller.activeTab.sql, contains('FROM "tasks"'));
        expect(
          controller.activeTab.sql,
          isNot('SELECT id, title FROM tasks ORDER BY id'),
        );
        expect(controller.activeTab.phase, QueryPhase.completed);
        expect(controller.activeTab.resultRows.single['title'], 'Ship phase 1');
      },
    );

    test(
      'initialize falls back to the sample shell when the last workspace is missing',
      () async {
        final missingPath =
            '${Directory.systemTemp.path}/missing-${DateTime.now().microsecondsSinceEpoch}.ddb';
        final config = AppConfig.defaults().copyWith(
          recentFiles: <String>[missingPath],
        );
        final controller = _createController(
          configStore: InMemoryConfigStore(config),
        );

        await controller.initialize();

        expect(controller.databasePath, isNull);
        expect(controller.workspaceError, isNull);
        expect(controller.workspaceMessage, 'Ready.');
        expect(controller.schema.tables, isEmpty);
      },
    );

    test(
      'initialize removes the last workspace from startup restore after an open failure',
      () async {
        final file = await _createTempDbFile();
        final logger = RecordingAppLogger();
        final configStore = InMemoryConfigStore(
          AppConfig.defaults().copyWith(recentFiles: <String>[file.path]),
        );
        final gateway = FakeWorkspaceGateway()
          ..openDatabaseError = const BridgeFailure(
            'database corruption: unsupported database format version 3 on page 1; expected 8',
            code: 'corruption',
          );
        final controller = _createController(
          gateway: gateway,
          logger: logger,
          configStore: configStore,
        );

        await controller.initialize();

        expect(controller.databasePath, isNull);
        expect(controller.workspaceError, isNull);
        expect(
          controller.workspaceMessage,
          'Ready. Could not reopen ${file.uri.pathSegments.last} automatically.',
        );
        expect((await configStore.load()).recentFiles, isEmpty);
        expect(
          logger.entries.any(
            (entry) =>
                entry.operation == 'startup_restore' &&
                entry.level == LogVerbosity.warning,
          ),
          isTrue,
        );
      },
    );

    test('clearActiveTabHistory removes only the active tab history', () async {
      final dbPath = _tempDbPath();
      final controller = _createController();

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);
      controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
      await controller.runActiveTab();
      await controller.fetchNextPage();
      controller.createTab(sql: 'SELECT id, name FROM projects ORDER BY id');
      await controller.runActiveTab();
      await controller.fetchNextPage();

      expect(controller.queryHistory, hasLength(2));
      controller.clearActiveTabHistory();

      expect(controller.activeTab.queryHistory, isEmpty);
      controller.previousTab();
      expect(controller.activeTab.queryHistory, hasLength(1));
    });
  });

  group('Database operations', () {
    test('openDatabase refreshes schema and stores recent files', () async {
      final dbPath = _tempDbPath();
      final store = InMemoryConfigStore();
      final controller = _createController(configStore: store);
      await controller.initialize();

      await controller.openDatabase(dbPath, createIfMissing: true);

      expect(controller.databasePath, dbPath);
      expect(controller.engineVersion, '1.6.1');
      expect(controller.schema.tables.single.name, 'tasks');
      expect(controller.schema.views.single.name, 'active_tasks');
      expect((await store.load()).recentFiles, contains(dbPath));
    });

    test(
      'openLogDatabase opens the configured application log database',
      () async {
        final logPath =
            '${Directory.systemTemp.path}/decent-bench-log-${DateTime.now().microsecondsSinceEpoch}.ddb';
        final file = File(logPath);
        await file.parent.create(recursive: true);
        await file.writeAsString('');

        addTearDown(() async {
          if (await file.exists()) {
            await file.delete();
          }
        });

        final controller = _createController(logger: _FixedPathLogger(logPath));
        await controller.initialize();

        await controller.openLogDatabase();

        expect(controller.databasePath, logPath);
        expect(controller.engineVersion, '1.6.1');
        expect(controller.workspaceError, isNull);
      },
    );
  });

  group('Branch and snapshot workflow', () {
    test(
      'openDatabase records unavailable native branch APIs without failing the workspace',
      () async {
        final dbPath = _tempDbPath();
        final controller = _createController();

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);

        expect(controller.databasePath, dbPath);
        expect(controller.workspaceError, isNull);
        expect(controller.canUseNativeBranchWorkflow, isFalse);
        expect(
          controller.branchState.nativeBranchApiUnavailableReason,
          contains('public Dart binding API'),
        );
      },
    );

    test('loads branch state and routes dry-run/apply operations', () async {
      final dbPath = _tempDbPath();
      final gateway = FakeWorkspaceGateway()
        ..branchApiAvailable = true
        ..branches = const <WorkspaceBranchInfo>[
          WorkspaceBranchInfo(name: 'main', isCurrent: true),
          WorkspaceBranchInfo(name: 'experiment', parentRef: 'main'),
        ]
        ..snapshots = const <WorkspaceSnapshotInfo>[
          WorkspaceSnapshotInfo(
            name: 'baseline',
            ref: 'snapshot:baseline',
            branch: 'main',
          ),
        ]
        ..branchDiffResult = const WorkspaceBranchDiff(
          leftRef: 'main',
          rightRef: 'experiment',
          rows: <WorkspaceBranchDiffRow>[
            WorkspaceBranchDiffRow(
              tableName: 'tasks',
              operation: 'modified',
              primaryKey: '1',
            ),
          ],
          addedRows: 0,
          modifiedRows: 1,
          removedRows: 0,
        );
      final controller = _createController(gateway: gateway);

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);

      expect(controller.canUseNativeBranchWorkflow, isTrue);
      expect(controller.branchState.currentBranch, 'main');
      expect(controller.branchState.branches, hasLength(2));
      expect(controller.branchState.snapshots.single.name, 'baseline');

      await controller.createSnapshot('before_edit');
      await controller.createBranch(
        branchName: 'scratch',
        fromRef: 'snapshot:baseline',
      );
      final diff = await controller.previewBranchDiff(
        leftRef: 'main',
        rightRef: 'scratch',
      );
      await controller.previewRestoreBranch(
        branchName: 'scratch',
        targetRef: 'main',
      );
      await controller.applyRestoreBranch(
        branchName: 'scratch',
        targetRef: 'main',
      );
      await controller.previewMergeBranch(
        sourceBranch: 'scratch',
        targetBranch: 'main',
      );

      expect(gateway.lastCreatedSnapshotName, startsWith('pre_restore_'));
      expect(gateway.lastCreatedBranchName, 'scratch');
      expect(gateway.lastCreatedBranchFromRef, 'snapshot:baseline');
      expect(gateway.lastBranchDiffLeftRef, 'main');
      expect(gateway.lastBranchDiffRightRef, 'scratch');
      expect(diff?.totalChanges, 1);
      expect(gateway.lastRestoreBranchName, 'scratch');
      expect(gateway.lastRestoreTargetRef, 'main');
      expect(gateway.lastRestoreDryRun, isFalse);
      expect(gateway.lastMergeSourceBranch, 'scratch');
      expect(gateway.lastMergeTargetBranch, 'main');
      expect(gateway.lastMergeDryRun, isTrue);
      expect(controller.lastBranchDiff?.totalChanges, 1);
    });
  });

  group('Configuration', () {
    test(
      'applyAppConfig persists and reloads TOML-backed preferences',
      () async {
        final store = InMemoryConfigStore();
        final controller = _createController(configStore: store);
        await controller.initialize();

        final updatedConfig = controller.config.copyWith(
          defaultPageSize: 250,
          csvDelimiter: ';',
          csvIncludeHeaders: false,
          editorSettings: const EditorSettings(
            autocompleteEnabled: false,
            autocompleteMaxSuggestions: 18,
            formatUppercaseKeywords: false,
            indentSpaces: 4,
            showLineNumbers: true,
          ),
          shortcutBindings: <String, String>{
            ...controller.config.shortcutBindings,
            'tools_run_query': 'Ctrl+Shift+Enter',
          },
          snippets: const <SqlSnippet>[
            SqlSnippet(
              id: 'custom',
              name: 'Custom',
              trigger: 'custom',
              description: 'Custom snippet',
              body: 'SELECT * FROM custom_table;',
            ),
          ],
        );

        final saved = await controller.applyAppConfig(updatedConfig);

        expect(saved, isTrue);
        expect((await store.load()).defaultPageSize, 250);
        expect((await store.load()).csvDelimiter, ';');

        controller.config = AppConfig.defaults();
        await controller.reloadConfig();

        expect(controller.config.defaultPageSize, 250);
        expect(controller.config.csvIncludeHeaders, isFalse);
        expect(
          controller.config.shortcutBindings['tools_run_query'],
          'Ctrl+Shift+Enter',
        );
        expect(controller.config.snippets.single.trigger, 'custom');
      },
    );
  });

  group('Multi-tab behavior', () {
    test('tabs own independent query state and results', () async {
      final dbPath = _tempDbPath();
      final controller = _createController();
      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);

      controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
      await controller.runActiveTab();
      expect(controller.activeTab.resultRows.single['title'], 'Ship phase 1');
      expect(controller.activeTab.phase, QueryPhase.completed);
      expect(controller.canRunActiveTab, isTrue);
      expect(controller.canCancelActiveTab, isFalse);

      controller.createTab();
      controller.updateActiveSql('SELECT id, name FROM projects ORDER BY id');
      await controller.runActiveTab();
      expect(controller.activeTab.resultRows.single['name'], 'Phase 3');
      expect(controller.activeTab.phase, QueryPhase.completed);
      expect(controller.canRunActiveTab, isTrue);
      expect(controller.canCancelActiveTab, isFalse);

      final secondTabId = controller.activeTabId;
      controller.previousTab();

      expect(
        controller.activeTab.sql,
        'SELECT id, title FROM tasks ORDER BY id',
      );
      expect(controller.activeTab.resultRows.single['title'], 'Ship phase 1');
      expect(controller.tabs, hasLength(2));

      controller.selectTab(secondTabId);
      await controller.fetchNextPage();
      expect(controller.activeTab.phase, QueryPhase.completed);
      expect(controller.activeTab.resultRows.last['name'], 'Keep testing');

      await controller.cancelTabQuery(controller.tabs.first.id);
      controller.selectTab(controller.tabs.first.id);
      expect(controller.activeTab.phase, QueryPhase.completed);
      expect(controller.activeTab.isResultPartial, isFalse);
      expect(controller.activeTab.hasMoreRows, isTrue);
    });

    test('reopening the same database restores persisted tab drafts', () async {
      final dbPath = _tempDbPath();
      final configStore = InMemoryConfigStore();
      final workspaceStateStore = InMemoryWorkspaceStateStore();

      final firstController = _createController(
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
      await configStore.save(
        (await configStore.load()).copyWith(recentFiles: const <String>[]),
      );

      final secondController = _createController(
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

    test(
      'reopening the same database restores per-tab query and message history',
      () async {
        final dbPath = _tempDbPath();
        final configStore = InMemoryConfigStore();
        final workspaceStateStore = InMemoryWorkspaceStateStore();

        final firstController = _createController(
          configStore: configStore,
          workspaceStateStore: workspaceStateStore,
        );
        await firstController.initialize();
        await firstController.openDatabase(dbPath, createIfMissing: true);
        firstController.updateActiveSql(
          'SELECT id, title FROM tasks ORDER BY id',
        );
        await firstController.runActiveTab();
        await firstController.fetchNextPage();
        await Future<void>.delayed(const Duration(milliseconds: 450));
        await configStore.save(
          (await configStore.load()).copyWith(recentFiles: const <String>[]),
        );

        final secondController = _createController(
          configStore: configStore,
          workspaceStateStore: workspaceStateStore,
        );
        await secondController.initialize();
        await secondController.openDatabase(dbPath, createIfMissing: false);

        expect(secondController.activeTab.queryHistory, hasLength(1));
        expect(
          secondController.activeTab.queryHistory.single.outcome,
          QueryHistoryOutcome.completed,
        );
        expect(secondController.activeTab.messageHistory, isNotEmpty);
      },
    );
  });

  group('Query execution', () {
    test('exports the active query as Excel', () async {
      final gateway = FakeWorkspaceGateway();
      final controller = _createController(gateway: gateway);
      await controller.initialize();
      await controller.openDatabase(_tempDbPath(), createIfMissing: true);
      controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
      await controller.runActiveTab();

      await controller.exportCurrentQueryAsExcel(
        path: '/tmp/tasks.xlsx',
        includeHeaders: false,
      );

      expect(gateway.lastExportPath, '/tmp/tasks.xlsx');
      expect(gateway.lastExcelIncludeHeaders, isFalse);
      expect(controller.activeTab.error, isNull);
      expect(
        controller.activeTab.statusMessage,
        'Exported 2 rows to /tmp/tasks.xlsx.',
      );
    });

    test('runTab stores query contracts before executing SQL', () async {
      final dbPath = _tempDbPath();
      final gateway = FakeWorkspaceGateway();
      final controller = _createController(gateway: gateway);

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);
      controller.updateActiveSql('SELECT id, title FROM tasks WHERE id = \$1');
      controller.updateActiveParameterJson('[1]');
      await controller.runActiveTab();

      expect(gateway.lastDescribedQuerySql, contains(r'$1'));
      expect(gateway.lastRunQuerySql, contains(r'$1'));
      expect(controller.activeTab.queryContract, isNotNull);
      expect(controller.activeTab.parameterContracts.single.name, r'$1');
      expect(
        controller.activeTab.resultContractForColumn('title')?.typeName,
        'TEXT',
      );
      expect(
        controller.activeTab.queryContract?.schemaFingerprint,
        gateway.toolingMetadata.schemaFingerprint,
      );
    });

    test(
      'tableEditabilityForTab identifies editable table result sets',
      () async {
        final dbPath = _tempDbPath();
        final controller = _createController();

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);
        controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
        await controller.runActiveTab();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final editability = controller.tableEditabilityForTab();

        expect(editability.isEditable, isTrue);
        expect(editability.tableName, 'tasks');
        expect(editability.primaryKeyColumn, 'id');
        expect(editability.primaryKeyResultColumn, 'id');
        expect(editability.canEditColumn('title'), isTrue);
        expect(editability.canEditColumn('id'), isFalse);
        expect(editability.canDeleteRows, isTrue);
      },
    );

    test(
      'updateResultCell commits parameterized updates by primary key',
      () async {
        final dbPath = _tempDbPath();
        final gateway = FakeWorkspaceGateway();
        final controller = _createController(gateway: gateway);

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);
        controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
        await controller.runActiveTab();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final result = await controller.updateResultCell(
          rowIndex: 0,
          columnName: 'title',
          value: 'Ship phase 2',
        );

        expect(result.success, isTrue);
        expect(
          gateway.lastRunQuerySql,
          'UPDATE "tasks" SET "title" = \$1 WHERE "id" = \$2',
        );
        expect(gateway.lastRunQueryParams, <Object?>['Ship phase 2', 1]);
        expect(controller.activeTab.resultRows.single['title'], 'Ship phase 2');
      },
    );

    test('updateResultCell rejects read-only result columns', () async {
      final dbPath = _tempDbPath();
      final gateway = FakeWorkspaceGateway();
      final controller = _createController(gateway: gateway);

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);
      controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
      await controller.runActiveTab();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final previousSql = gateway.lastRunQuerySql;

      final result = await controller.updateResultCell(
        rowIndex: 0,
        columnName: 'id',
        value: 2,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('primary key'));
      expect(gateway.lastRunQuerySql, previousSql);
    });

    test('insertResultRow commits parameterized inserts', () async {
      final dbPath = _tempDbPath();
      final gateway = FakeWorkspaceGateway();
      final controller = _createController(gateway: gateway);

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);
      controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
      await controller.runActiveTab();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final result = await controller.insertResultRow(
        values: const <String, Object?>{'id': 2, 'title': 'Ship phase 2'},
      );

      expect(result.success, isTrue);
      expect(
        gateway.lastRunQuerySql,
        'INSERT INTO "tasks" ("id", "title") VALUES (\$1, \$2)',
      );
      expect(gateway.lastRunQueryParams, <Object?>[2, 'Ship phase 2']);
      expect(controller.activeTab.resultRows, hasLength(2));
      expect(controller.activeTab.resultRows.last, <String, Object?>{
        'id': 2,
        'title': 'Ship phase 2',
      });
    });

    test(
      'insertResultRow validates required values before execution',
      () async {
        final dbPath = _tempDbPath();
        final gateway = FakeWorkspaceGateway();
        final controller = _createController(gateway: gateway);

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);
        controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
        await controller.runActiveTab();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final previousSql = gateway.lastRunQuerySql;

        final result = await controller.insertResultRow(
          values: const <String, Object?>{'id': 2},
        );

        expect(result.success, isFalse);
        expect(result.message, 'title is required.');
        expect(gateway.lastRunQuerySql, previousSql);
      },
    );

    test(
      'deleteResultRow commits parameterized deletes by primary key',
      () async {
        final dbPath = _tempDbPath();
        final gateway = FakeWorkspaceGateway();
        final controller = _createController(gateway: gateway);

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);
        controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
        await controller.runActiveTab();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final result = await controller.deleteResultRow(rowIndex: 0);

        expect(result.success, isTrue);
        expect(gateway.lastRunQuerySql, 'DELETE FROM "tasks" WHERE "id" = \$1');
        expect(gateway.lastRunQueryParams, <Object?>[1]);
        expect(controller.activeTab.resultRows, isEmpty);
      },
    );

    test(
      'runTab validates parameter count before execution using the query contract',
      () async {
        final dbPath = _tempDbPath();
        final gateway = _TrackingWorkspaceGateway(
          queryContract: _makeQueryContract(
            parameters: const <QueryParameterContract>[
              QueryParameterContract(
                position: 1,
                name: r'$1',
                typeName: 'INT64',
                nullable: false,
                source: 'catalog_column',
                sourceTable: 'tasks',
                sourceColumn: 'id',
                diagnostics: <String>[],
              ),
              QueryParameterContract(
                position: 2,
                name: r'$2',
                typeName: 'TEXT',
                nullable: false,
                source: 'catalog_column',
                sourceTable: 'tasks',
                sourceColumn: 'title',
                diagnostics: <String>[],
              ),
            ],
          ),
        );
        final controller = _createController(gateway: gateway);

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);
        controller.updateActiveSql(
          'SELECT id FROM tasks WHERE id = \$1 AND title = \$2',
        );
        controller.updateActiveParameterJson('[1]');
        await controller.runActiveTab();

        expect(gateway.runQueryCallCount, 0);
        expect(controller.activeTab.phase, QueryPhase.failed);
        expect(
          controller.activeTab.error?.message,
          contains('This query expects 2 parameters'),
        );
        expect(controller.activeTab.queryContract, isNotNull);
        expect(controller.activeTab.queryContract?.parameters, hasLength(2));
      },
    );

    test('runTab validates non-nullable parameters before execution', () async {
      final dbPath = _tempDbPath();
      final gateway = _TrackingWorkspaceGateway(
        queryContract: _makeQueryContract(
          parameters: const <QueryParameterContract>[
            QueryParameterContract(
              position: 1,
              name: r'$1',
              typeName: 'INT64',
              nullable: false,
              source: 'catalog_column',
              sourceTable: 'tasks',
              sourceColumn: 'id',
              diagnostics: <String>[],
            ),
          ],
        ),
      );
      final controller = _createController(gateway: gateway);

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);
      controller.updateActiveSql('SELECT id FROM tasks WHERE id = \$1');
      controller.updateActiveParameterJson('[null]');
      await controller.runActiveTab();

      expect(gateway.runQueryCallCount, 0);
      expect(controller.activeTab.phase, QueryPhase.failed);
      expect(
        controller.activeTab.error?.message,
        contains('Required parameters missing values: \$1.'),
      );
    });

    test('runTab reruns with updated JSON parameter values', () async {
      final dbPath = _tempDbPath();
      final gateway = _TrackingWorkspaceGateway(
        queryContract: _makeQueryContract(
          parameters: const <QueryParameterContract>[
            QueryParameterContract(
              position: 1,
              name: r'$1',
              typeName: 'INT64',
              nullable: false,
              source: 'catalog_column',
              sourceTable: 'tasks',
              sourceColumn: 'id',
              diagnostics: <String>[],
            ),
          ],
        ),
      );
      final controller = _createController(gateway: gateway);

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);
      controller.updateActiveSql('SELECT id FROM tasks WHERE id = \$1');
      controller.updateActiveParameterJson('[1]');
      await controller.runActiveTab();
      expect(gateway.lastRunParams, <Object?>[1]);

      controller.updateActiveParameterJson('[2]');
      await controller.runActiveTab();
      expect(gateway.lastRunParams, <Object?>[2]);
      expect(gateway.runQueryCallCount, 4);
      expect(gateway.runQueryParamsHistory, <List<Object?>>[
        const <Object?>[1],
        const <Object?>[1],
        const <Object?>[2],
        const <Object?>[2],
      ]);
    });

    test(
      'runTab stops before execution when query contract decoding fails',
      () async {
        final dbPath = _tempDbPath();
        final gateway = FakeWorkspaceGateway()
          ..queryContractError = const BridgeFailure(
            'syntax error near BROKEN',
            code: 'ERR_SQL',
          );
        final controller = _createController(gateway: gateway);

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);
        controller.updateActiveSql('SELECT BROKEN');
        await controller.runActiveTab();

        expect(gateway.lastDescribedQuerySql, 'SELECT BROKEN');
        expect(gateway.lastRunQuerySql, isNull);
        expect(controller.activeTab.phase, QueryPhase.failed);
        expect(controller.activeTab.error?.message, contains('BROKEN'));
        expect(controller.activeTab.queryContract, isNull);
      },
    );

    test('runTab captures execution plan rows from EXPLAIN output', () async {
      final dbPath = _tempDbPath();
      final controller = _createController();
      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);

      controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
      await controller.runActiveTab();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.activeTab.executionPlan.isLoading, isFalse);
      expect(controller.activeTab.executionPlan.columns, <String>[
        'query_plan',
      ]);
      expect(
        controller.activeTab.executionPlan.rows.single['query_plan'],
        contains('SCAN tasks'),
      );
    });

    test(
      'runTab skips execution plans for statements that do not return rows',
      () async {
        final dbPath = _tempDbPath();
        final gateway = FakeWorkspaceGateway();
        final controller = _createController(gateway: gateway);
        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);

        controller.updateActiveSql(
          'CREATE TABLE sample_items (id INTEGER PRIMARY KEY)',
        );
        await controller.runActiveTab();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          gateway.lastRunQuerySql,
          'CREATE TABLE sample_items (id INTEGER PRIMARY KEY)',
        );
        expect(controller.activeTab.executionPlan.isLoading, isFalse);
        expect(controller.activeTab.executionPlan.hasData, isFalse);
        expect(
          controller.activeTab.executionPlan.errorMessage,
          'Execution plan is only available for statements that return rows.',
        );
      },
    );

    test(
      'runActiveSql executes selected SQL without overwriting the tab draft',
      () async {
        final dbPath = _tempDbPath();
        final gateway = FakeWorkspaceGateway();
        final controller = _createController(gateway: gateway);
        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);

        controller.updateActiveSql(
          'SELECT id, title FROM tasks ORDER BY id;\nSELECT id, name FROM projects ORDER BY id;',
        );

        await controller.runActiveSql(
          'SELECT id, name FROM projects ORDER BY id',
        );

        expect(
          controller.activeTab.sql,
          'SELECT id, title FROM tasks ORDER BY id;\nSELECT id, name FROM projects ORDER BY id;',
        );
        expect(
          controller.activeTab.lastSql,
          'SELECT id, name FROM projects ORDER BY id',
        );
        expect(controller.activeTab.resultRows.single['name'], 'Phase 3');
        expect(
          gateway.lastRunQuerySql,
          'EXPLAIN SELECT id, name FROM projects ORDER BY id',
        );
      },
    );

    test('runActiveTab records query timing log entries', () async {
      final dbPath = _tempDbPath();
      final logger = RecordingAppLogger();
      final config = AppConfig.defaults().copyWith(
        logging: const LoggingSettings(verbosity: LogVerbosity.debug),
      );
      final controller = _createController(
        configStore: InMemoryConfigStore(config),
        logger: logger,
      );
      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);

      controller.updateActiveSql('SELECT id, title FROM tasks ORDER BY id');
      await controller.runActiveTab();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final timingEntry = logger.entries.lastWhere(
        (entry) => entry.operation == 'query.first_page',
      );
      expect(timingEntry.category, 'query');
      expect(timingEntry.databasePath, dbPath);
      expect(timingEntry.sql, 'SELECT id, title FROM tasks ORDER BY id');
      expect(timingEntry.rowCount, 1);
      expect(timingEntry.elapsedNanos, greaterThan(0));
    });

    test('runActiveTab trims per-tab history to configured depth', () async {
      final dbPath = _tempDbPath();
      final configStore = InMemoryConfigStore(
        AppConfig.defaults().copyWith(queryHistoryLimit: 2),
      );
      final controller = _createController(configStore: configStore);

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);

      controller.updateActiveSql('CREATE TABLE sample_1 (id INTEGER)');
      await controller.runActiveTab();
      controller.updateActiveSql('CREATE TABLE sample_2 (id INTEGER)');
      await controller.runActiveTab();
      controller.updateActiveSql('CREATE TABLE sample_3 (id INTEGER)');
      await controller.runActiveTab();

      expect(controller.activeTab.queryHistory, hasLength(2));
      expect(controller.activeTab.queryHistory.first.sql, contains('sample_2'));
      expect(controller.activeTab.queryHistory.last.sql, contains('sample_3'));
    });
  });

  group('Saved queries', () {
    test(
      'saveActiveQuery persists contract metadata and can load into a tab',
      () async {
        final dbPath = _tempDbPath();
        final store = InMemorySavedQueryLibraryStore();
        final controller = _createController(savedQueryLibraryStore: store);

        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);
        controller.updateActiveSql(
          'SELECT id, title FROM tasks WHERE id = \$1',
        );
        controller.updateActiveParameterJson('[1]');
        await controller.runActiveTab();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final saved = await controller.saveActiveQuery(
          name: 'Task lookup',
          folder: 'ops',
          tags: const <String>['tasks'],
        );

        expect(saved, isNotNull);
        expect(controller.savedQueries.single.name, 'Task lookup');
        expect(controller.savedQueries.single.queryContract, isNotNull);
        expect(
          (await store.load(dbPath)).queries.single.schemaFingerprint,
          isNotEmpty,
        );

        controller.createTab();
        controller.loadSavedQuery(saved!.id);

        expect(
          controller.activeTab.sql,
          'SELECT id, title FROM tasks WHERE id = \$1',
        );
        expect(controller.activeTab.parameterJson, '[1]');
        expect(
          controller.activeTab.queryContract?.parameters.single.name,
          r'$1',
        );
      },
    );

    test('deleteSavedQuery removes it from the persisted library', () async {
      final dbPath = _tempDbPath();
      final store = InMemorySavedQueryLibraryStore();
      final controller = _createController(savedQueryLibraryStore: store);

      await controller.initialize();
      await controller.openDatabase(dbPath, createIfMissing: true);
      final saved = await controller.saveActiveQuery(name: 'Ready check');

      await controller.deleteSavedQuery(saved!.id);

      expect(controller.savedQueries, isEmpty);
      expect((await store.load(dbPath)).queries, isEmpty);
    });
  });

  group('Error handling', () {
    test(
      'runActiveSql maps syntax failures back to the selected statement location',
      () async {
        final dbPath = _tempDbPath();
        final controller = _createController();
        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);

        const sql =
            'SELECT id, title FROM tasks;\nBROKEN SELECT * FROM projects;';
        controller.updateActiveSql(sql);

        await controller.runActiveSql(
          'BROKEN SELECT * FROM projects;',
          bufferStartOffset: sql.indexOf('BROKEN'),
          description: 'statement',
        );

        expect(controller.activeTab.phase, QueryPhase.failed);
        expect(controller.activeTab.error, isNotNull);
        expect(controller.activeTab.error!.location, isNotNull);
        expect(controller.activeTab.error!.location!.line, 2);
        expect(controller.activeTab.error!.location!.column, 1);
      },
    );

    test(
      'runActiveTab preserves line and column offsets after leading whitespace',
      () async {
        final dbPath = _tempDbPath();
        final controller = _createController();
        await controller.initialize();
        await controller.openDatabase(dbPath, createIfMissing: true);

        controller.updateActiveSql('\n  BROKEN SELECT * FROM tasks;');

        await controller.runActiveTab();

        expect(controller.activeTab.phase, QueryPhase.failed);
        expect(controller.activeTab.error, isNotNull);
        expect(controller.activeTab.error!.location, isNotNull);
        expect(controller.activeTab.error!.location!.line, 2);
        expect(controller.activeTab.error!.location!.column, 3);
      },
    );
  });

  group('Import - target path', () {
    test(
      'import workflows suggest new DecentDB targets beside the source file',
      () async {
        final controller = _createController();
        await controller.initialize();

        controller.beginExcelImport(sourcePath: '/tmp/imports/source.xlsx');
        expect(
          controller.excelImportSession?.targetPath,
          '/tmp/imports/source.ddb',
        );

        controller.beginSqlDumpImport(sourcePath: '/tmp/imports/source.sql');
        expect(
          controller.sqlDumpImportSession?.targetPath,
          '/tmp/imports/source.ddb',
        );

        controller.beginSqliteImport(sourcePath: '/tmp/imports/source.sqlite');
        expect(
          controller.sqliteImportSession?.targetPath,
          '/tmp/imports/source.ddb',
        );
      },
    );
  });

  group('Import - Excel', () {
    test(
      'excel import inspection loads sheets, previews, and import summary',
      () async {
        final gateway = FakeWorkspaceGateway();
        final logger = RecordingAppLogger();
        final config = AppConfig.defaults().copyWith(
          logging: const LoggingSettings(verbosity: LogVerbosity.debug),
        );
        final controller = _createController(
          gateway: gateway,
          configStore: InMemoryConfigStore(config),
          logger: logger,
        );
        await controller.initialize();

        controller.beginExcelImport();
        await controller.loadExcelImportSource('/tmp/phase5-source.xlsx');

        final session = controller.excelImportSession;
        expect(session, isNotNull);
        expect(session!.phase, ExcelImportJobPhase.ready);
        expect(
          session.sheets.map((sheet) => sheet.sourceName),
          contains('people'),
        );
        expect(session.focusedSheetDraft?.previewRows.first['name'], 'Ada');

        controller.setExcelImportStep(ExcelImportWizardStep.transforms);
        controller.renameExcelImportSheet('people', 'imported_people');
        controller.renameExcelImportColumn('people', 1, 'display_name');
        await controller.runExcelImport();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(gateway.lastExcelImportRequest, isNotNull);
        expect(
          gateway.lastExcelImportRequest!.selectedSheets.first.targetName,
          'imported_people',
        );
        expect(
          controller.excelImportSession?.phase,
          ExcelImportJobPhase.completed,
        );
        expect(
          controller.excelImportSession?.summary?.importedTables,
          contains('imported_people'),
        );
        final excelSummary = controller.excelImportSession!.summary!;
        final completionEntry = logger.entries.lastWhere(
          (entry) => entry.operation == 'run_excel_import',
        );
        final completionDetails = completionEntry.details!;
        expect(completionEntry.category, 'import.excel');
        expect(completionEntry.rowCount, excelSummary.totalRowsCopied);
        expect(completionEntry.elapsedNanos, greaterThan(0));
        expect(completionEntry.databasePath, endsWith('.ddb'));
        expect(
          completionDetails['total_rows_copied'],
          excelSummary.totalRowsCopied,
        );
        expect(
          completionDetails['rows_copied_by_table'],
          excelSummary.rowsCopiedByTable,
        );
        final warningEntry = logger.entries.lastWhere(
          (entry) => entry.operation == 'run_excel_import_warnings',
        );
        final warningDetails = warningEntry.details!;
        expect(warningEntry.level, LogVerbosity.warning);
        expect(warningDetails['warning_count'], 1);
        expect(
          warningDetails['warnings'],
          contains('Workbook formulas are imported as formula text.'),
        );
      },
    );

    test('excel import cancellation updates session state', () async {
      final gateway = FakeWorkspaceGateway()..holdExcelImportOpen = true;
      final controller = _createController(gateway: gateway);
      await controller.initialize();
      controller.beginExcelImport();
      await controller.loadExcelImportSource('/tmp/phase5-cancel.xlsx');

      await controller.runExcelImport();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.excelImportSession?.phase, ExcelImportJobPhase.running);

      final jobId = controller.excelImportSession?.jobId;
      await controller.cancelExcelImport();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gateway.lastCancelledImportJobId, jobId);
      expect(
        controller.excelImportSession?.phase,
        ExcelImportJobPhase.cancelled,
      );
      expect(controller.excelImportSession?.summary?.rolledBack, isTrue);
    });

    test(
      'excel import failure updates session state and workspace error',
      () async {
        final gateway = FakeWorkspaceGateway()..failNextExcelImport = true;
        final controller = _createController(gateway: gateway);
        await controller.initialize();
        controller.beginExcelImport();
        await controller.loadExcelImportSource('/tmp/phase5-failure.xlsx');

        await controller.runExcelImport();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          controller.excelImportSession?.step,
          ExcelImportWizardStep.summary,
        );
        expect(
          controller.excelImportSession?.phase,
          ExcelImportJobPhase.failed,
        );
        expect(
          controller.excelImportSession?.error,
          'Excel import failed in the fake gateway.',
        );
        expect(
          controller.workspaceError,
          'Excel import failed in the fake gateway.',
        );
        expect(controller.workspaceMessage, isNull);
      },
    );
  });

  group('Import - SQLite', () {
    test(
      'sqlite import inspection loads tables, previews, and import summary',
      () async {
        final gateway = FakeWorkspaceGateway();
        final logger = RecordingAppLogger();
        final config = AppConfig.defaults().copyWith(
          logging: const LoggingSettings(verbosity: LogVerbosity.debug),
        );
        final controller = _createController(
          gateway: gateway,
          configStore: InMemoryConfigStore(config),
          logger: logger,
        );
        await controller.initialize();

        controller.beginSqliteImport();
        await controller.loadSqliteImportSource('/tmp/phase4-source.sqlite');

        final session = controller.sqliteImportSession;
        expect(session, isNotNull);
        expect(session!.phase, SqliteImportJobPhase.ready);
        expect(
          session.tables.map((table) => table.sourceName),
          contains('users'),
        );
        expect(session.focusedTableDraft?.previewLoaded, isTrue);
        expect(
          session.focusedTableDraft?.previewRows.first['name'],
          anyOf('Ada', isNull),
        );

        controller.setSqliteImportStep(SqliteImportWizardStep.transforms);
        controller.renameSqliteImportTable('users', 'imported_users');
        controller.renameSqliteImportColumn('users', 'name', 'display_name');
        await controller.runSqliteImport();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(gateway.lastSqliteImportRequest, isNotNull);
        expect(
          gateway.lastSqliteImportRequest!.selectedTables.first.targetName,
          'imported_users',
        );
        expect(
          controller.sqliteImportSession?.phase,
          SqliteImportJobPhase.completed,
        );
        expect(
          controller.sqliteImportSession?.summary?.importedTables,
          contains('imported_users'),
        );
        final sqliteSummary = controller.sqliteImportSession!.summary!;
        final completionEntry = logger.entries.lastWhere(
          (entry) => entry.operation == 'run_sqlite_import',
        );
        final completionDetails = completionEntry.details!;
        expect(completionEntry.category, 'import.sqlite');
        expect(completionEntry.rowCount, sqliteSummary.totalRowsCopied);
        expect(completionEntry.elapsedNanos, greaterThan(0));
        expect(
          completionDetails['total_rows_copied'],
          sqliteSummary.totalRowsCopied,
        );
        expect(
          completionDetails['index_count'],
          sqliteSummary.indexesCreated.length,
        );
        expect(
          completionDetails['skipped_item_count'],
          sqliteSummary.skippedItems.length,
        );
        expect(
          completionDetails['rows_copied_by_table'],
          sqliteSummary.rowsCopiedByTable,
        );
        final warningEntry = logger.entries.lastWhere(
          (entry) => entry.operation == 'run_sqlite_import_warnings',
        );
        final warningDetails = warningEntry.details!;
        expect(warningEntry.level, LogVerbosity.warning);
        expect(warningDetails['warning_count'], greaterThan(0));
      },
    );

    test('sqlite import cancellation updates session state', () async {
      final gateway = FakeWorkspaceGateway()..holdImportOpen = true;
      final controller = _createController(gateway: gateway);
      await controller.initialize();
      controller.beginSqliteImport();
      await controller.loadSqliteImportSource('/tmp/phase4-cancel.sqlite');

      await controller.runSqliteImport();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        controller.sqliteImportSession?.phase,
        SqliteImportJobPhase.running,
      );

      final jobId = controller.sqliteImportSession?.jobId;
      await controller.cancelSqliteImport();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gateway.lastCancelledImportJobId, jobId);
      expect(
        controller.sqliteImportSession?.phase,
        SqliteImportJobPhase.cancelled,
      );
      expect(controller.sqliteImportSession?.summary?.rolledBack, isTrue);
    });

    test(
      'sqlite import failure updates session state and workspace error',
      () async {
        final gateway = FakeWorkspaceGateway()..failNextImport = true;
        final controller = _createController(gateway: gateway);
        await controller.initialize();
        controller.beginSqliteImport();
        await controller.loadSqliteImportSource('/tmp/phase4-failure.sqlite');

        await controller.runSqliteImport();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          controller.sqliteImportSession?.step,
          SqliteImportWizardStep.summary,
        );
        expect(
          controller.sqliteImportSession?.phase,
          SqliteImportJobPhase.failed,
        );
        expect(
          controller.sqliteImportSession?.error,
          'SQLite import failed in the fake gateway.',
        );
        expect(
          controller.workspaceError,
          'SQLite import failed in the fake gateway.',
        );
        expect(controller.workspaceMessage, isNull);
      },
    );
  });

  group('Import - SQL dump', () {
    test(
      'sql dump import inspection loads parsed tables, warnings, and import summary',
      () async {
        final gateway = FakeWorkspaceGateway();
        final logger = RecordingAppLogger();
        final config = AppConfig.defaults().copyWith(
          logging: const LoggingSettings(verbosity: LogVerbosity.debug),
        );
        final controller = _createController(
          gateway: gateway,
          configStore: InMemoryConfigStore(config),
          logger: logger,
        );
        await controller.initialize();

        controller.beginSqlDumpImport();
        await controller.loadSqlDumpImportSource('/tmp/phase6-source.sql');

        final session = controller.sqlDumpImportSession;
        expect(session, isNotNull);
        expect(session!.phase, SqlDumpImportJobPhase.ready);
        expect(
          session.tables.map((table) => table.sourceName),
          contains('people'),
        );
        expect(session.warnings, isNotEmpty);
        expect(session.skippedStatementCount, greaterThan(0));
        expect(session.focusedTableDraft?.previewRows.first['name'], 'Ada');

        controller.setSqlDumpImportStep(SqlDumpImportWizardStep.transforms);
        controller.renameSqlDumpImportTable('people', 'imported_people');
        controller.renameSqlDumpImportColumn('people', 1, 'display_name');
        await controller.runSqlDumpImport();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(gateway.lastSqlDumpImportRequest, isNotNull);
        expect(
          gateway.lastSqlDumpImportRequest!.selectedTables.first.targetName,
          'imported_people',
        );
        expect(
          gateway
              .lastSqlDumpImportRequest!
              .selectedTables
              .first
              .columns[1]
              .targetName,
          'display_name',
        );
        expect(
          controller.sqlDumpImportSession?.phase,
          SqlDumpImportJobPhase.completed,
        );
        expect(
          controller.sqlDumpImportSession?.summary?.importedTables,
          contains('imported_people'),
        );
        final sqlDumpSummary = controller.sqlDumpImportSession!.summary!;
        final completionEntry = logger.entries.lastWhere(
          (entry) => entry.operation == 'run_sql_dump_import',
        );
        final completionDetails = completionEntry.details!;
        expect(completionEntry.category, 'import.sql_dump');
        expect(completionEntry.rowCount, sqlDumpSummary.totalRowsCopied);
        expect(completionEntry.elapsedNanos, greaterThan(0));
        expect(
          completionDetails['total_rows_copied'],
          sqlDumpSummary.totalRowsCopied,
        );
        expect(
          completionDetails['skipped_statement_count'],
          sqlDumpSummary.skippedStatementCount,
        );
        expect(
          completionDetails['rows_copied_by_table'],
          sqlDumpSummary.rowsCopiedByTable,
        );
        final warningEntry = logger.entries.lastWhere(
          (entry) => entry.operation == 'run_sql_dump_import_warnings',
        );
        final warningDetails = warningEntry.details!;
        expect(warningEntry.level, LogVerbosity.warning);
        expect(warningDetails['warning_count'], greaterThan(0));
      },
    );

    test('sql dump import cancellation updates session state', () async {
      final gateway = FakeWorkspaceGateway()..holdSqlDumpImportOpen = true;
      final controller = _createController(gateway: gateway);
      await controller.initialize();
      controller.beginSqlDumpImport();
      await controller.loadSqlDumpImportSource('/tmp/phase6-cancel.sql');

      await controller.runSqlDumpImport();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        controller.sqlDumpImportSession?.phase,
        SqlDumpImportJobPhase.running,
      );

      final jobId = controller.sqlDumpImportSession?.jobId;
      await controller.cancelSqlDumpImport();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gateway.lastCancelledImportJobId, jobId);
      expect(
        controller.sqlDumpImportSession?.phase,
        SqlDumpImportJobPhase.cancelled,
      );
      expect(controller.sqlDumpImportSession?.summary?.rolledBack, isTrue);
    });

    test(
      'sql dump import failure updates session state and workspace error',
      () async {
        final gateway = FakeWorkspaceGateway()..failNextSqlDumpImport = true;
        final controller = _createController(gateway: gateway);
        await controller.initialize();
        controller.beginSqlDumpImport();
        await controller.loadSqlDumpImportSource('/tmp/phase6-failure.sql');

        await controller.runSqlDumpImport();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          controller.sqlDumpImportSession?.step,
          SqlDumpImportWizardStep.summary,
        );
        expect(
          controller.sqlDumpImportSession?.phase,
          SqlDumpImportJobPhase.failed,
        );
        expect(
          controller.sqlDumpImportSession?.error,
          'SQL dump import failed in the fake gateway.',
        );
        expect(
          controller.workspaceError,
          'SQL dump import failed in the fake gateway.',
        );
        expect(controller.workspaceMessage, isNull);
      },
    );
  });
}

class _FixedPathLogger extends RecordingAppLogger {
  _FixedPathLogger(this._logDatabasePath);

  final String _logDatabasePath;

  @override
  String get logDatabasePath => _logDatabasePath;
}
