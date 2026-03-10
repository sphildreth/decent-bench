import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/app_config_store.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';

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

class FakeWorkspaceGateway implements WorkspaceDatabaseGateway {
  @override
  String? resolvedLibraryPath = '/tmp/libc_api.so';

  int cancelCount = 0;
  String? lastExportPath;

  QueryResultPage firstPage = QueryResultPage(
    cursorId: 'cursor-1',
    columns: const <String>['id', 'title'],
    rows: const <Map<String, Object?>>[
      <String, Object?>{'id': 1, 'title': 'Ship phase 1'},
    ],
    done: false,
    rowsAffected: null,
    elapsed: const Duration(milliseconds: 5),
  );

  QueryResultPage nextPage = QueryResultPage(
    cursorId: null,
    columns: const <String>['id', 'title'],
    rows: const <Map<String, Object?>>[
      <String, Object?>{'id': 2, 'title': 'Keep paging'},
    ],
    done: true,
    rowsAffected: null,
    elapsed: const Duration(milliseconds: 4),
  );

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
          ),
          SchemaColumn(
            name: 'title',
            type: 'TEXT',
            notNull: false,
            unique: false,
            primaryKey: false,
            refTable: null,
            refColumn: null,
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
    return nextPage;
  }

  @override
  Future<String> initialize() async => resolvedLibraryPath!;

  @override
  Future<SchemaSnapshot> loadSchema() async => snapshot;

  @override
  Future<DatabaseSession> openDatabase(String path) async {
    return DatabaseSession(path: path, engineVersion: '1.6.0');
  }

  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  }) async {
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
    return firstPage;
  }
}
