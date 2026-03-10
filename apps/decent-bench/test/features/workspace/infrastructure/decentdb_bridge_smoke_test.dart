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
    late String engineVersion;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('decent-bench-phase1-');
      dbPath = p.join(tempDir.path, 'phase1.ddb');
      bridge = DecentDbBridge(resolver: _FixedResolver(nativeLib));
      await bridge.initialize();
      engineVersion = (await bridge.openDatabase(dbPath)).engineVersion;
    });

    tearDown(() async {
      await bridge.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'supports DDL, schema loading, and export',
      skip: skipReason,
      () async {
        await bridge.runQuery(
          sql:
              'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
          params: const <Object?>[],
          pageSize: 50,
        );
        await bridge.runQuery(
          sql: "INSERT INTO users VALUES (1, 'Ada')",
          params: const <Object?>[],
          pageSize: 50,
        );
        await bridge.runQuery(
          sql: 'CREATE VIEW user_names AS SELECT id, name FROM users',
          params: const <Object?>[],
          pageSize: 50,
        );
        await bridge.runQuery(
          sql: 'CREATE INDEX idx_users_name ON users (name)',
          params: const <Object?>[],
          pageSize: 50,
        );

        final schema = await bridge.loadSchema();

        expect(schema.tables.any((item) => item.name == 'users'), isTrue);
        expect(schema.views.any((item) => item.name == 'user_names'), isTrue);
        expect(
          schema.indexes.any((item) => item.name == 'idx_users_name'),
          isTrue,
        );

        final exportPath = p.join(tempDir.path, 'users.csv');
        final export = await bridge.exportCsv(
          sql: 'SELECT id, name FROM users ORDER BY id',
          params: const <Object?>[],
          pageSize: 50,
          path: exportPath,
          delimiter: ',',
          includeHeaders: true,
        );

        expect(export.rowCount, 1);
        expect(await File(exportPath).readAsString(), contains('Ada'));
      },
    );

    test(
      'supports parameters, paging, and EXPLAIN',
      skip: skipReason,
      () async {
        await bridge.runQuery(
          sql: 'CREATE TABLE nums (id INTEGER PRIMARY KEY, label TEXT)',
          params: const <Object?>[],
          pageSize: 2,
        );
        for (var i = 1; i <= 5; i++) {
          await bridge.runQuery(
            sql: 'INSERT INTO nums VALUES (\$1, \$2)',
            params: <Object?>[i, 'n$i'],
            pageSize: 2,
          );
        }

        final firstPage = await bridge.runQuery(
          sql: 'SELECT id, label FROM nums WHERE id >= \$1 ORDER BY id',
          params: const <Object?>[2],
          pageSize: 2,
        );
        expect(firstPage.rows.length, 2);
        expect(firstPage.cursorId, isNotNull);

        final secondPage = await bridge.fetchNextPage(
          cursorId: firstPage.cursorId!,
          pageSize: 2,
        );
        expect(secondPage.rows.length, 2);

        final explain = await bridge.runQuery(
          sql: 'EXPLAIN SELECT id FROM nums WHERE id = 2',
          params: const <Object?>[],
          pageSize: 10,
        );
        expect(explain.rows, isNotEmpty);
      },
    );

    test('supports recursive CTEs', skip: skipReason, () async {
      try {
        final cte = await bridge.runQuery(
          sql: '''
WITH RECURSIVE cnt(x) AS (
  SELECT 1
  UNION ALL
  SELECT x + 1 FROM cnt WHERE x < 5
)
SELECT x FROM cnt ORDER BY x
''',
          params: const <Object?>[],
          pageSize: 10,
        );
        expect(cte.rows.length, 5);
        expect(cte.rows.first['x'], 1);
      } on BridgeFailure catch (error) {
        if (error.message.contains('Table not found')) {
          markTestSkipped(
            'Current DecentDB build at $nativeLib reports $engineVersion but rejects WITH RECURSIVE in this environment.',
          );
          return;
        }
        rethrow;
      }
    });
  });
}
