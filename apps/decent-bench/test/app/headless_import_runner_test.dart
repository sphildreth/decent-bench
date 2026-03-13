import 'dart:convert';
import 'dart:io';

import 'package:decent_bench/app/headless_import_runner.dart';
import 'package:decent_bench/app/startup_launch_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'decent-bench-headless-import-test-',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('imports a CSV fixture headlessly and emits a JSON summary', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final targetPath = p.join(tempDir.path, 'customers_basic.ddb');
    final sourcePath = p.normalize(
      p.join(
        Directory.current.path,
        '..',
        '..',
        'test-data',
        'text_seperated_values',
        'customers_basic.csv',
      ),
    );

    final exitCode = await runHeadlessImportCli(
      HeadlessImportCliOptions(
        sourcePath: sourcePath,
        targetPath: targetPath,
        silent: true,
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(stdoutLines, isNotEmpty);

    final report = jsonDecode(stdoutLines.last) as Map<String, Object?>;
    final databaseTables = (report['database_tables'] as List<dynamic>)
        .cast<Map<String, Object?>>();

    expect(report['format_key'], 'csv');
    expect(report['target_path'], targetPath);
    expect(report['imported_tables'], isNotEmpty);
    expect(databaseTables, hasLength(1));
    expect(databaseTables.single['row_count'], greaterThan(0));
    expect(File(targetPath).existsSync(), isTrue);
  });

  test(
    'imports a SQLite fixture headlessly and emits a JSON summary',
    () async {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      final targetPath = p.join(tempDir.path, 'sample_app.ddb');
      final sourcePath = p.normalize(
        p.join(
          Directory.current.path,
          '..',
          '..',
          'test-data',
          'sql_related',
          'sample_app.sqlite',
        ),
      );

      final exitCode = await runHeadlessImportCli(
        HeadlessImportCliOptions(
          sourcePath: sourcePath,
          targetPath: targetPath,
          silent: true,
        ),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(stdoutLines, isNotEmpty);

      final report = jsonDecode(stdoutLines.last) as Map<String, Object?>;
      final databaseTables = (report['database_tables'] as List<dynamic>)
          .cast<Map<String, Object?>>();

      expect(report['format_key'], 'sqlite');
      expect(report['imported_tables'], isNotEmpty);
      expect(databaseTables, isNotEmpty);
      expect(File(targetPath).existsSync(), isTrue);
    },
  );

  test('imports an Excel fixture headlessly and emits a JSON summary', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final targetPath = p.join(tempDir.path, 'basic_contacts.ddb');
    final sourcePath = p.normalize(
      p.join(
        Directory.current.path,
        '..',
        '..',
        'test-data',
        'excel',
        'basic_contacts.xlsx',
      ),
    );

    final exitCode = await runHeadlessImportCli(
      HeadlessImportCliOptions(
        sourcePath: sourcePath,
        targetPath: targetPath,
        silent: true,
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(stdoutLines, isNotEmpty);

    final report = jsonDecode(stdoutLines.last) as Map<String, Object?>;
    final warnings = (report['warnings'] as List<dynamic>).cast<String>();

    expect(report['format_key'], 'xlsx');
    expect(report['imported_tables'], isNotEmpty);
    expect(
      warnings.join('\n'),
      contains('temporary `.xlsx` rewrite'),
    );
    expect(File(targetPath).existsSync(), isTrue);
  });

  test('rejects plan files until plan execution is implemented', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final targetPath = p.join(tempDir.path, 'customers_basic.ddb');
    final sourcePath = p.normalize(
      p.join(
        Directory.current.path,
        '..',
        '..',
        'test-data',
        'text_seperated_values',
        'customers_basic.csv',
      ),
    );

    final exitCode = await runHeadlessImportCli(
      HeadlessImportCliOptions(
        sourcePath: sourcePath,
        targetPath: targetPath,
        planPath: p.join(tempDir.path, 'import-plan.json'),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 2);
    expect(stdoutLines, isEmpty);
    expect(
      stderrLines.join('\n'),
      contains('Headless import plan execution is not implemented yet'),
    );
  });
}
