import 'dart:io';

import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';
import 'package:decent_bench/features/workspace/infrastructure/native_library_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FixedResolver extends NativeLibraryResolver {
  _FixedResolver(this.path);

  final String path;

  @override
  Future<String> resolve() async => path;
}

void main() {
  const defaultNativeLib = '/home/steven/source/decentdb/build/libc_api.so';
  final nativeLib =
      Platform.environment['DECENTDB_NATIVE_LIB'] ?? defaultNativeLib;
  final nativeLibExists = File(nativeLib).existsSync();
  final skipReason = nativeLibExists
      ? null
      : 'Expected DecentDB native library at $nativeLib';

  group('DecentDbBridge smoke tests', () {
    late DecentDbBridge bridge;
    late Directory tempDir;
    late String dbPath;

    Future<QueryResultPage> runQuery(
      String sql, {
      List<Object?> params = const <Object?>[],
      int pageSize = 64,
    }) {
      return bridge.runQuery(sql: sql, params: params, pageSize: pageSize);
    }

    Future<void> exec(
      String sql, {
      List<Object?> params = const <Object?>[],
    }) async {
      await runQuery(sql, params: params);
    }

    Future<List<Map<String, Object?>>> queryAllRows(
      String sql, {
      List<Object?> params = const <Object?>[],
      int pageSize = 64,
    }) async {
      final firstPage = await runQuery(sql, params: params, pageSize: pageSize);
      final rows = <Map<String, Object?>>[...firstPage.rows];
      var cursorId = firstPage.cursorId;

      while (cursorId != null) {
        final nextPage = await bridge.fetchNextPage(
          cursorId: cursorId,
          pageSize: pageSize,
        );
        rows.addAll(nextPage.rows);
        cursorId = nextPage.cursorId;
      }

      return rows;
    }

    Future<void> expectBridgeFailure(
      Future<Object?> Function() action, {
      String? containsMessage,
    }) async {
      await expectLater(
        action,
        throwsA(
          isA<BridgeFailure>().having(
            (error) => error.message,
            'message',
            containsMessage == null ? isNotEmpty : contains(containsMessage),
          ),
        ),
      );
    }

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('decent-bench-phase1-');
      dbPath = p.join(tempDir.path, 'phase1.ddb');
      bridge = DecentDbBridge(resolver: _FixedResolver(nativeLib));
      await bridge.initialize();
      await bridge.openDatabase(dbPath);
    });

    tearDown(() async {
      await bridge.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('supports CSV export from query results', skip: skipReason, () async {
      await exec(
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
      );
      await exec("INSERT INTO users VALUES (1, 'Ada')");
      await exec("INSERT INTO users VALUES (2, 'Grace')");

      final exportPath = p.join(tempDir.path, 'users.csv');
      final export = await bridge.exportCsv(
        sql: 'SELECT id, name FROM users ORDER BY id',
        params: const <Object?>[],
        pageSize: 1,
        path: exportPath,
        delimiter: ',',
        includeHeaders: true,
      );

      expect(export.rowCount, 2);
      expect(
        await File(exportPath).readAsString(),
        allOf(contains('id,name'), contains('Ada'), contains('Grace')),
      );
    });

    test('supports parameters and paged cursors', skip: skipReason, () async {
      await exec('CREATE TABLE nums (id INTEGER PRIMARY KEY, label TEXT)');
      for (var i = 1; i <= 5; i++) {
        await exec(
          'INSERT INTO nums VALUES (\$1, \$2)',
          params: <Object?>[i, 'n$i'],
        );
      }

      final firstPage = await runQuery(
        'SELECT id, label FROM nums WHERE id >= \$1 ORDER BY id',
        params: const <Object?>[2],
        pageSize: 2,
      );

      expect(firstPage.rows.length, 2);
      expect(firstPage.rows.first['id'], 2);
      expect(firstPage.rows.last['id'], 3);
      expect(firstPage.cursorId, isNotNull);

      final rows = <Map<String, Object?>>[...firstPage.rows];
      var cursorId = firstPage.cursorId;
      while (cursorId != null) {
        final nextPage = await bridge.fetchNextPage(
          cursorId: cursorId,
          pageSize: 2,
        );
        rows.addAll(nextPage.rows);
        cursorId = nextPage.cursorId;
      }

      expect(
        rows.map((row) => row['id']),
        orderedEquals(<Object?>[2, 3, 4, 5]),
      );
      expect(
        rows.map((row) => row['label']),
        orderedEquals(<Object?>['n2', 'n3', 'n4', 'n5']),
      );
    });

    test('supports views and indexes', skip: skipReason, () async {
      await exec(
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
      );
      await exec("INSERT INTO users VALUES (1, 'Ada')");
      await exec("INSERT INTO users VALUES (2, 'Grace')");
      await exec('CREATE VIEW user_names AS SELECT id, name FROM users');
      await exec('CREATE INDEX idx_users_name ON users (name)');

      final viewRows = await queryAllRows(
        'SELECT id, name FROM user_names ORDER BY id',
      );
      final schema = await bridge.loadSchema();

      expect(viewRows.length, 2);
      expect(viewRows.first['name'], 'Ada');
      expect(schema.tables.any((item) => item.name == 'users'), isTrue);
      expect(schema.views.any((item) => item.name == 'user_names'), isTrue);
      expect(
        schema.indexes.any((item) => item.name == 'idx_users_name'),
        isTrue,
      );
    });

    test(
      'supports recursive CTEs and cursor cancellation',
      skip: skipReason,
      () async {
        const recursiveSql = '''
WITH RECURSIVE cnt(x) AS (
  SELECT 1
  UNION ALL
  SELECT x + 1 FROM cnt WHERE x < 5
)
SELECT x FROM cnt
''';

        final firstPage = await runQuery(recursiveSql, pageSize: 2);
        expect(
          firstPage.rows.map((row) => row['x']),
          orderedEquals(<Object?>[1, 2]),
        );
        expect(firstPage.cursorId, isNotNull);

        await bridge.cancelQuery(firstPage.cursorId!);
        await expectBridgeFailure(
          () =>
              bridge.fetchNextPage(cursorId: firstPage.cursorId!, pageSize: 2),
          containsMessage: 'Query cursor is no longer available.',
        );

        final rows = await queryAllRows(recursiveSql, pageSize: 10);
        expect(
          rows.map((row) => row['x']),
          orderedEquals(<Object?>[1, 2, 3, 4, 5]),
        );
      },
    );

    test(
      'supports constraints and generated stored columns',
      skip: skipReason,
      () async {
        await exec('''
CREATE TABLE line_items (
  id INTEGER PRIMARY KEY,
  sku TEXT NOT NULL UNIQUE,
  price REAL NOT NULL CHECK (price > 0),
  qty INTEGER NOT NULL CHECK (qty > 0),
  status TEXT DEFAULT 'active',
  total REAL GENERATED ALWAYS AS (price * qty) STORED
)
''');

        await exec(
          'INSERT INTO line_items (id, sku, price, qty) VALUES (1, \$1, \$2, \$3)',
          params: const <Object?>['A-1', 9.5, 2],
        );

        final rows = await queryAllRows(
          'SELECT sku, status, total FROM line_items WHERE id = 1',
        );
        expect(rows.single['sku'], 'A-1');
        expect(rows.single['status'], 'active');
        expect(rows.single['total'], closeTo(19.0, 0.0001));

        await expectBridgeFailure(
          () => exec(
            'INSERT INTO line_items (id, sku, price, qty) VALUES (2, \$1, \$2, \$3)',
            params: const <Object?>['A-1', 5.0, 1],
          ),
        );
        await expectBridgeFailure(
          () => exec(
            'INSERT INTO line_items (id, sku, price, qty) VALUES (3, \$1, \$2, \$3)',
            params: const <Object?>['B-2', 5.0, 0],
          ),
        );

        await bridge.openDatabase(dbPath);
        final reopenedRows = await queryAllRows(
          'SELECT total FROM line_items WHERE id = 1',
        );
        expect(reopenedRows.single['total'], closeTo(19.0, 0.0001));
      },
    );

    test('supports window and aggregate functions', skip: skipReason, () async {
      await exec(
        'CREATE TABLE payroll (id INTEGER PRIMARY KEY, dept TEXT, employee TEXT, salary INTEGER)',
      );
      await exec("INSERT INTO payroll VALUES (1, 'eng', 'Ada', 120)");
      await exec("INSERT INTO payroll VALUES (2, 'eng', 'Grace', 110)");
      await exec("INSERT INTO payroll VALUES (3, 'ops', 'Linus', 90)");
      await exec("INSERT INTO payroll VALUES (4, 'ops', 'Ken', 80)");

      final rankedRows = await queryAllRows('''
SELECT dept, employee, salary, ROW_NUMBER() OVER (
  PARTITION BY dept
  ORDER BY salary DESC
) AS rn
FROM payroll
ORDER BY dept, rn
''');
      final aggregateRows = await queryAllRows('''
SELECT dept, COUNT(*) AS members, SUM(salary) AS total_salary
FROM payroll
GROUP BY dept
ORDER BY dept
''');

      expect(rankedRows.first['employee'], 'Ada');
      expect(rankedRows.first['rn'], 1);
      expect(rankedRows[2]['employee'], 'Linus');
      expect(rankedRows[2]['rn'], 1);
      expect(aggregateRows.first['dept'], 'eng');
      expect(aggregateRows.first['members'], 2);
      expect(aggregateRows.first['total_salary'], 230);
      expect(aggregateRows.last['dept'], 'ops');
      expect(aggregateRows.last['total_salary'], 170);
    });

    test('supports JSON table-valued functions', skip: skipReason, () async {
      final eachRows = await queryAllRows(
        '''SELECT key, value, type FROM json_each('{"name":"Alice","age":30}') ORDER BY key''',
      );
      final treeRows = await queryAllRows(
        '''SELECT key, value, type, path FROM json_tree('{"a":1,"b":[2,3]}')''',
      );

      final ageRow = eachRows.firstWhere((row) => row['key'] == 'age');
      final nameRow = eachRows.firstWhere((row) => row['key'] == 'name');

      expect(eachRows.length, 2);
      expect(ageRow['type'], 'number');
      expect(ageRow['value'].toString(), '30');
      expect(nameRow['type'], 'string');
      expect(nameRow['value'].toString(), contains('Alice'));
      expect(
        treeRows.any(
          (row) => row['type'] == 'object' && row['path'].toString() == r'$',
        ),
        isTrue,
      );
      expect(
        treeRows.any(
          (row) =>
              row['key'] == 'a' &&
              row['type'] == 'number' &&
              row['path'].toString() == r'$.a',
        ),
        isTrue,
      );
    });

    test('supports transactions and savepoints', skip: skipReason, () async {
      await exec('CREATE TABLE txn_events (id INTEGER PRIMARY KEY, note TEXT)');
      await exec('BEGIN');
      await exec("INSERT INTO txn_events VALUES (1, 'kept')");
      await exec('SAVEPOINT sp1');
      await exec("INSERT INTO txn_events VALUES (2, 'rolled-back')");
      await exec('ROLLBACK TO SAVEPOINT sp1');
      await exec('COMMIT');

      final rows = await queryAllRows(
        'SELECT id, note FROM txn_events ORDER BY id',
      );
      expect(rows.length, 1);
      expect(rows.single['id'], 1);
      expect(rows.single['note'], 'kept');
    });

    test('supports row triggers', skip: skipReason, () async {
      await exec(
        'CREATE TABLE events (id INTEGER PRIMARY KEY, label TEXT NOT NULL)',
      );
      await exec('CREATE TABLE audit (tag TEXT)');
      await exec(
        "CREATE TRIGGER events_ins_audit AFTER INSERT ON events FOR EACH ROW EXECUTE FUNCTION decentdb_exec_sql('INSERT INTO audit(tag) VALUES (''I'')')",
      );
      await exec("INSERT INTO events VALUES (1, 'launch')");

      final auditRows = await queryAllRows('SELECT tag FROM audit');
      expect(auditRows.single['tag'], 'I');
    });

    test('supports temp tables and temp views', skip: skipReason, () async {
      await exec('CREATE TEMP TABLE temp_results (id INTEGER, value TEXT)');
      await exec("INSERT INTO temp_results VALUES (1, 'ephemeral')");
      await exec(
        'CREATE TEMP VIEW temp_summary AS SELECT value FROM temp_results',
      );

      final tempRows = await queryAllRows('SELECT value FROM temp_summary');
      expect(tempRows.single['value'], 'ephemeral');

      await bridge.openDatabase(dbPath);
      await expectBridgeFailure(
        () => queryAllRows('SELECT value FROM temp_summary'),
      );
    });

    test('supports planner introspection', skip: skipReason, () async {
      await exec(
        'CREATE TABLE explain_items (id INTEGER PRIMARY KEY, score INTEGER)',
      );
      await exec('INSERT INTO explain_items VALUES (1, 10)');
      await exec('INSERT INTO explain_items VALUES (2, 20)');

      final explainRows = await queryAllRows(
        'EXPLAIN SELECT id FROM explain_items WHERE score > 10',
      );
      final analyzeRows = await queryAllRows(
        'EXPLAIN ANALYZE SELECT id FROM explain_items WHERE score > 10',
      );

      expect(explainRows, isNotEmpty);
      expect(analyzeRows, isNotEmpty);
      expect(explainRows.first.keys, contains('query_plan'));
      expect(analyzeRows.first.keys, contains('query_plan'));
    });

    test('supports statistics collection', skip: skipReason, () async {
      await exec('CREATE TABLE stats_items (id INTEGER PRIMARY KEY, grp TEXT)');
      await exec("INSERT INTO stats_items VALUES (1, 'a')");
      await exec("INSERT INTO stats_items VALUES (2, 'a')");
      await exec("INSERT INTO stats_items VALUES (3, 'b')");
      await exec('CREATE INDEX idx_stats_grp ON stats_items (grp)');

      await exec('ANALYZE stats_items');

      final rows = await queryAllRows(
        "SELECT COUNT(*) AS row_count FROM stats_items WHERE grp = 'a'",
      );
      expect(rows.single['row_count'], 2);
    });
  });
}
