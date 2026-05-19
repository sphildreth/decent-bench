import 'dart:convert';
import 'dart:io';

import 'package:decent_bench/app/headless_import_runner.dart';
import 'package:decent_bench/app/startup_launch_options.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_native_release_asset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Only attempt a network download when explicitly requested via env var.
    // In offline or local developer environments the native library is expected
    // to be pre-installed (e.g. via the CI workflow or the tool/stage_decentdb_native.dart
    // script). Set DECENT_BENCH_DOWNLOAD_NATIVE=1 to enable the download.
    final downloadNative =
        Platform.environment['DECENT_BENCH_DOWNLOAD_NATIVE'] == '1';
    if (downloadNative) {
      await DecentDbNativeReleaseAsset.ensureAvailableForCurrentProject(
        startPath: Directory.current.path,
      );
    }
  });

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

  test(
    'imports an Excel fixture headlessly and emits a JSON summary',
    () async {
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
      expect(warnings.join('\n'), contains('temporary `.xlsx` rewrite'));
      expect(File(targetPath).existsSync(), isTrue);
    },
  );

  test('loads a profile document for headless plan execution', () async {
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
    final profilePath = p.join(tempDir.path, 'import-profile.json');
    await File(profilePath).writeAsString(
      jsonEncode(<String, Object?>{
        'config_version': 1,
        'import': <String, Object?>{
          'name': 'Customers CSV',
          'source_format': 'csv',
          'header_row': true,
          'native_type_mappings': <String, Object?>{'email': 'TEXT'},
        },
        'exports': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'csv-default',
            'name': 'CSV Default',
            'format': 'csv',
            'include_headers': true,
          },
        ],
      }),
    );

    final exitCode = await runHeadlessImportCli(
      HeadlessImportCliOptions(
        sourcePath: sourcePath,
        targetPath: targetPath,
        planPath: profilePath,
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stdoutLines, isNotEmpty);
    expect(
      stderrLines.join('\n'),
      contains('Using import profile: Customers CSV'),
    );
    final report = jsonDecode(stdoutLines.last) as Map<String, Object?>;
    expect(report['format_key'], 'csv');
  });

  test('rejects invalid profile documents', () async {
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
    final profilePath = p.join(tempDir.path, 'bad-profile.json');
    await File(
      profilePath,
    ).writeAsString(jsonEncode(<String, Object?>{'config_version': 99}));

    final exitCode = await runHeadlessImportCli(
      HeadlessImportCliOptions(
        sourcePath: sourcePath,
        targetPath: targetPath,
        planPath: profilePath,
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 2);
    expect(stdoutLines, isEmpty);
    expect(stderrLines.join('\n'), contains('Invalid import/export profile'));
  });
}
