import 'dart:convert';
import 'dart:io';

import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/sql_dump_import_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('inspectSqlDumpSourceFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('decent-bench-sql-dump-');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    String writeDump(String content, {String encoding = 'utf8'}) {
      final path = p.join(tempDir.path, 'dump.sql');
      if (encoding == 'latin1') {
        File(path).writeAsBytesSync(latin1.encode(content));
      } else {
        File(path).writeAsStringSync(content);
      }
      return path;
    }

    test('parses a simple CREATE TABLE + INSERT', () {
      final path = writeDump('''
CREATE TABLE users (
  id INT NOT NULL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(255)
);

INSERT INTO users (id, name, email) VALUES (1, 'Ada', 'ada@example.com');
INSERT INTO users (id, name, email) VALUES (2, 'Lin', NULL);
''');

      final inspection = inspectSqlDumpSourceFile(path, encoding: 'auto');

      expect(inspection.tables, hasLength(1));
      expect(inspection.tables.first.sourceName, 'users');
      expect(inspection.tables.first.columns, hasLength(3));
      expect(inspection.tables.first.columns[0].sourceName, 'id');
      expect(inspection.tables.first.columns[0].inferredTargetType, 'INTEGER');
      expect(inspection.tables.first.columns[1].sourceName, 'name');
      expect(inspection.tables.first.columns[1].inferredTargetType, 'TEXT');
      expect(inspection.tables.first.rowCount, 2);
      expect(inspection.tables.first.previewRows, hasLength(2));
      expect(inspection.tables.first.previewRows[0]['name'], 'Ada');
      expect(inspection.tables.first.previewRows[1]['email'], isNull);
      expect(inspection.resolvedEncoding, 'utf8');
      expect(inspection.warnings, isEmpty);
    });

    test('skips unsupported SET statements with warnings', () {
      final path = writeDump('''
SET NAMES utf8mb4;
CREATE TABLE items (id INT PRIMARY KEY, label TEXT);
INSERT INTO items VALUES (10, 'widget');
LOCK TABLES items WRITE;
UNLOCK TABLES;
''');

      final inspection = inspectSqlDumpSourceFile(path, encoding: 'auto');

      expect(inspection.tables, hasLength(1));
      expect(inspection.skippedStatements.length, greaterThanOrEqualTo(2));
      expect(inspection.warnings.any((w) => w.contains('SET')), isTrue);
    });

    test('handles backtick-quoted identifiers', () {
      final path = writeDump('''
CREATE TABLE `my table` (
  `col 1` INT,
  `col 2` TEXT
);
INSERT INTO `my table` (`col 1`, `col 2`) VALUES (42, 'hello');
''');

      final inspection = inspectSqlDumpSourceFile(path, encoding: 'auto');

      expect(inspection.tables, hasLength(1));
      expect(inspection.tables.first.sourceName, 'my table');
      expect(inspection.tables.first.columns[0].sourceName, 'col 1');
      expect(inspection.tables.first.previewRows.first['col 1'], 42);
    });

    test('handles multiple tables', () {
      final path = writeDump('''
CREATE TABLE orders (id INT PRIMARY KEY, total DECIMAL(10,2));
CREATE TABLE line_items (id INT PRIMARY KEY, order_id INT, product TEXT);
INSERT INTO orders VALUES (1, 99.99);
INSERT INTO line_items VALUES (1, 1, 'book');
''');

      final inspection = inspectSqlDumpSourceFile(path, encoding: 'auto');

      expect(inspection.tables, hasLength(2));
      expect(inspection.tables[0].sourceName, 'orders');
      expect(inspection.tables[1].sourceName, 'line_items');
      expect(inspection.totalStatements, 4);
    });

    test('handles Latin1 encoding', () {
      final content = '''
CREATE TABLE items (id INT PRIMARY KEY, label TEXT);
INSERT INTO items VALUES (1, 'caf\xe9');
''';
      final path = writeDump(content, encoding: 'latin1');

      final inspection = inspectSqlDumpSourceFile(path, encoding: 'latin1');

      expect(inspection.resolvedEncoding, 'latin1');
      expect(inspection.tables.first.previewRows.first['label'], 'caf\xe9');
    });

    test('auto-detect falls back to Latin1 for non-UTF8 content', () {
      final bytes = <int>[
        ...utf8.encode('CREATE TABLE t (id INT);\nINSERT INTO t VALUES (1);\n'),
        0xe9,
      ];
      final path = p.join(tempDir.path, 'bad_utf8.sql');
      File(path).writeAsBytesSync(bytes);

      final inspection = inspectSqlDumpSourceFile(path, encoding: 'auto');

      expect(inspection.resolvedEncoding, 'latin1');
      expect(inspection.warnings, isNotEmpty);
    });

    test('throws for missing file', () {
      expect(
        () =>
            inspectSqlDumpSourceFile('/nonexistent/path.sql', encoding: 'auto'),
        throwsA(isA<BridgeFailure>()),
      );
    });
  });

  group('mapMySqlDeclaredTypeToDecentDb', () {
    test('maps INT to INTEGER', () {
      expect(mapMySqlDeclaredTypeToDecentDb('INT'), 'INTEGER');
    });

    test('maps BIGINT to INTEGER', () {
      expect(mapMySqlDeclaredTypeToDecentDb('BIGINT'), 'INTEGER');
    });

    test('maps VARCHAR(255) to TEXT', () {
      expect(mapMySqlDeclaredTypeToDecentDb('VARCHAR(255)'), 'TEXT');
    });

    test('maps DOUBLE to FLOAT64', () {
      expect(mapMySqlDeclaredTypeToDecentDb('DOUBLE'), 'FLOAT64');
    });

    test('maps DECIMAL(10,2) to DECIMAL(10,2)', () {
      expect(mapMySqlDeclaredTypeToDecentDb('DECIMAL(10,2)'), 'DECIMAL(10,2)');
    });

    test('maps BOOLEAN to BOOLEAN', () {
      expect(mapMySqlDeclaredTypeToDecentDb('BOOLEAN'), 'BOOLEAN');
    });

    test('maps TINYINT(1) to BOOLEAN', () {
      expect(mapMySqlDeclaredTypeToDecentDb('TINYINT(1)'), 'BOOLEAN');
    });

    test('maps BLOB to BLOB', () {
      expect(mapMySqlDeclaredTypeToDecentDb('BLOB'), 'BLOB');
    });

    test('maps DATETIME to TIMESTAMP', () {
      expect(mapMySqlDeclaredTypeToDecentDb('DATETIME'), 'TIMESTAMP');
    });

    test('maps empty string to TEXT', () {
      expect(mapMySqlDeclaredTypeToDecentDb(''), 'TEXT');
    });

    test('maps CHAR(36) to UUID', () {
      expect(mapMySqlDeclaredTypeToDecentDb('CHAR(36)'), 'UUID');
    });

    test('maps DECIMAL without precision to DECIMAL(18,6)', () {
      expect(mapMySqlDeclaredTypeToDecentDb('DECIMAL'), 'DECIMAL(18,6)');
    });

    test('maps DecentDB v2.5 semantic dump types conservatively', () {
      expect(mapMySqlDeclaredTypeToDecentDb("ENUM('draft','paid')"), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('INET'), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('IPADDR'), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('CIDR'), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('TIME'), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('INTERVAL DAY TO SECOND'), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('MACADDR'), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('MACADDR8'), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('GEOMETRY'), 'TEXT');
      expect(mapMySqlDeclaredTypeToDecentDb('GEOGRAPHY'), 'TEXT');
    });
  });

  group('materializeSqlDumpSourceFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'decent-bench-sql-dump-mat-',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('materializes selected tables with rows', () {
      final path = p.join(tempDir.path, 'dump.sql');
      File(path).writeAsStringSync('''
CREATE TABLE users (id INT, name TEXT);
INSERT INTO users VALUES (1, 'Ada');
INSERT INTO users VALUES (2, 'Lin');
''');

      final inspection = inspectSqlDumpSourceFile(path, encoding: 'auto');
      final result = materializeSqlDumpSourceFile(
        path,
        encoding: 'auto',
        tables: inspection.tables,
      );

      expect(result.tables, hasLength(1));
      expect(result.tables.first.sourceName, 'users');
      expect(result.tables.first.rows, hasLength(2));
      expect(result.tables.first.rows[0]['id'], 1);
      expect(result.tables.first.rows[0]['name'], 'Ada');
    });

    test('materializes only selected tables', () {
      final path = p.join(tempDir.path, 'dump.sql');
      File(path).writeAsStringSync('''
CREATE TABLE a (id INT);
CREATE TABLE b (id INT);
INSERT INTO a VALUES (1);
INSERT INTO b VALUES (2);
''');

      final inspection = inspectSqlDumpSourceFile(path, encoding: 'auto');
      final onlyB = inspection.tables
          .where((t) => t.sourceName == 'b')
          .toList();

      final result = materializeSqlDumpSourceFile(
        path,
        encoding: 'auto',
        tables: onlyB,
      );

      expect(result.tables, hasLength(1));
      expect(result.tables.first.sourceName, 'b');
      expect(result.tables.first.rows, hasLength(1));
    });
  });
}
