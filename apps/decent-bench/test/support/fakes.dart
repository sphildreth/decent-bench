import 'dart:io';

import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_state.dart';
import 'package:decent_bench/features/workspace/infrastructure/app_config_store.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';
import 'package:decent_bench/features/workspace/infrastructure/workspace_state_store.dart';

class InMemoryConfigStore implements WorkspaceConfigStore {
  InMemoryConfigStore([AppConfig? config])
    : _config = config ?? AppConfig.defaults();

  AppConfig _config;

  @override
  Future<AppConfig> load() async => _config;

  @override
  Future<void> save(AppConfig config) async {
    _config = config;
  }
}

class InMemoryWorkspaceStateStore implements WorkspaceStateStore {
  final Map<String, PersistedWorkspaceState> _states =
      <String, PersistedWorkspaceState>{};

  @override
  Future<void> clear(String databasePath) async {
    _states.remove(databasePath);
  }

  @override
  Future<PersistedWorkspaceState?> load(String databasePath) async {
    return _states[databasePath];
  }

  @override
  Future<void> save(String databasePath, PersistedWorkspaceState state) async {
    _states[databasePath] = state;
  }
}

class FakeWorkspaceGateway implements WorkspaceDatabaseGateway {
  @override
  String? resolvedLibraryPath = '/tmp/libc_api.so';

  int cancelCount = 0;
  String? lastExportPath;

  SchemaSnapshot snapshot = SchemaSnapshot(
    objects: <SchemaObjectSummary>[
      SchemaObjectSummary(
        name: 'tasks',
        kind: SchemaObjectKind.table,
        columns: const <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: 'INTEGER',
            notNull: true,
            unique: true,
            primaryKey: true,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
          SchemaColumn(
            name: 'title',
            type: 'TEXT',
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
        ],
      ),
      SchemaObjectSummary(
        name: 'active_tasks',
        kind: SchemaObjectKind.view,
        ddl: 'CREATE VIEW active_tasks AS SELECT id, title FROM tasks;',
        columns: const <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: 'ANY',
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
            refOnDelete: null,
            refOnUpdate: null,
          ),
          SchemaColumn(
            name: 'title',
            type: 'ANY',
            notNull: false,
            unique: false,
            primaryKey: false,
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
        name: 'idx_tasks_title',
        table: 'tasks',
        columns: <String>['title'],
        unique: false,
        kind: 'btree',
      ),
    ],
    loadedAt: DateTime(2026, 3, 9),
  );

  @override
  Future<void> cancelQuery(String cursorId) async {
    cancelCount++;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<CsvExportResult> exportCsv({
    required String sql,
    required List<Object?> params,
    required int pageSize,
    required String path,
    required String delimiter,
    required bool includeHeaders,
  }) async {
    lastExportPath = path;
    return CsvExportResult(rowCount: 2, path: path);
  }

  @override
  Future<QueryResultPage> fetchNextPage({
    required String cursorId,
    required int pageSize,
  }) async {
    return switch (cursorId) {
      'cursor-projects' => QueryResultPage(
        cursorId: null,
        columns: const <String>['id', 'name'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'id': 11, 'name': 'Keep testing'},
        ],
        done: true,
        rowsAffected: null,
        elapsed: const Duration(milliseconds: 4),
      ),
      _ => QueryResultPage(
        cursorId: null,
        columns: const <String>['id', 'title'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'id': 2, 'title': 'Keep paging'},
        ],
        done: true,
        rowsAffected: null,
        elapsed: const Duration(milliseconds: 4),
      ),
    };
  }

  @override
  Future<String> initialize() async => resolvedLibraryPath!;

  @override
  Future<SchemaSnapshot> loadSchema() async => snapshot;

  @override
  Future<DatabaseSession> openDatabase(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('');
    }
    return DatabaseSession(path: path, engineVersion: '1.6.1');
  }

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  }) async {
    if (sql.toUpperCase().contains('BROKEN')) {
      throw const BridgeFailure('syntax error near BROKEN', code: 'ERR_SQL');
    }
    if (sql.toUpperCase().startsWith('CREATE')) {
      return QueryResultPage(
        cursorId: null,
        columns: const <String>[],
        rows: const <Map<String, Object?>>[],
        done: true,
        rowsAffected: 0,
        elapsed: const Duration(milliseconds: 2),
      );
    }
    if (sql.toLowerCase().contains('projects')) {
      return QueryResultPage(
        cursorId: 'cursor-projects',
        columns: const <String>['id', 'name'],
        rows: const <Map<String, Object?>>[
          <String, Object?>{'id': 10, 'name': 'Phase 3'},
        ],
        done: false,
        rowsAffected: null,
        elapsed: const Duration(milliseconds: 5),
      );
    }
    return QueryResultPage(
      cursorId: 'cursor-1',
      columns: const <String>['id', 'title'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'title': 'Ship phase 1'},
      ],
      done: false,
      rowsAffected: null,
      elapsed: const Duration(milliseconds: 5),
    );
  }
}
