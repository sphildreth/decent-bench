import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/sqlite_import_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('tryParseSqliteTimestampValue', () {
    test(
      'parses ISO timestamps with more than 6 fractional digits and offsets',
      () {
        final parsed = tryParseSqliteTimestampValue(
          '2024-12-30T10:02:04.901481207-06:00',
        );

        expect(parsed?.toIso8601String(), '2024-12-30T16:02:04.901481Z');
      },
    );

    test(
      'parses space-separated timestamps with more than 6 fractional digits',
      () {
        final parsed = tryParseSqliteTimestampValue(
          '2025-01-01 11:00:42.24883752-06:00',
        );

        expect(parsed?.toIso8601String(), '2025-01-01T17:00:42.248837Z');
      },
    );

    test('returns null for non-temporal text', () {
      expect(tryParseSqliteTimestampValue('not-a-timestamp'), isNull);
    });
  });

  group('inspectSqliteSourceFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'decent-bench-sqlite-inspect-',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'keeps text when timestamp-like samples miss later empty string values',
      () {
        final sourcePath = p.join(tempDir.path, 'sparse-dates.sqlite');
        final database = sqlite.sqlite3.open(sourcePath);
        try {
          database.execute('''
CREATE TABLE events (
  id INTEGER PRIMARY KEY,
  release_date TEXT NOT NULL
)
''');
          for (var index = 1; index <= 64; index++) {
            database.execute(
              "INSERT INTO events VALUES ($index, '2026-03-10')",
            );
          }
          database.execute("INSERT INTO events VALUES (65, '')");
        } finally {
          database.close();
        }

        final inspection = inspectSqliteSourceFile(sourcePath);
        final column = inspection.tables.single.columns.singleWhere(
          (candidate) => candidate.sourceName == 'release_date',
        );

        expect(column.targetType, 'TEXT');
      },
    );
  });
}
