import 'dart:io';

import 'package:archive/archive.dart';
import 'package:decent_bench/features/import/application/import_manager.dart';
import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/infrastructure/import_format_registry.dart';
import 'package:decent_bench/features/import_modules/domain/import_module_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late ImportManager manager;
  late ImportFormatRegistry registry;
  late Directory tempDir;

  setUp(() {
    registry = ImportFormatRegistry.instance;
    manager = ImportManager(registry: registry);
    tempDir = Directory.systemTemp.createTempSync('import-manager-test-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ImportFormatDefinition formatByKey(ImportFormatKey key) {
    return registry.forKey(key);
  }

  group('moduleForDetection', () {
    test('returns module by moduleId when it exists in the catalog', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/data.csv',
        format: formatByKey(ImportFormatKey.csv),
        warnings: const <String>[],
        moduleId: 'csv',
      );

      final module = manager.moduleForDetection(detection);

      expect(module.id, 'csv');
      expect(module.name, 'CSV');
    });

    test(
      'returns module by format key when moduleId matches a different format',
      () {
        final detection = ImportDetectionResult(
          sourcePath: '/tmp/data.xlsx',
          format: formatByKey(ImportFormatKey.xlsx),
          warnings: const <String>[],
          moduleId: 'csv',
        );

        final module = manager.moduleForDetection(detection);

        expect(module.id, 'csv');
      },
    );

    test('returns module by format key when moduleId is null', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/data.json',
        format: formatByKey(ImportFormatKey.json),
        warnings: const <String>[],
      );

      final module = manager.moduleForDetection(detection);

      expect(module.legacyFormatKey, 'json');
    });

    test('falls back to format key when moduleId is not in catalog', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/data.csv',
        format: formatByKey(ImportFormatKey.csv),
        warnings: const <String>[],
        moduleId: 'nonexistent_module_id',
      );

      final module = manager.moduleForDetection(detection);

      expect(module.legacyFormatKey, 'csv');
    });

    test('resolves DecentDB direct-open module via moduleId', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/workspace.ddb',
        format: formatByKey(ImportFormatKey.decentDb),
        warnings: const <String>[],
        moduleId: 'decentdb',
      );

      final module = manager.moduleForDetection(detection);

      expect(module.id, 'decentdb');
      expect(module.support.implementation,
          ImportModuleImplementation.directOpen);
    });

    test('resolves ZIP archive module via format key fallback', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/bundle.zip',
        format: formatByKey(ImportFormatKey.zipArchive),
        warnings: const <String>[],
      );

      final module = manager.moduleForDetection(detection);

      expect(module.legacyFormatKey, 'zipArchive');
    });

    test('resolves unknown format via format key fallback', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/mystery.xyz',
        format: formatByKey(ImportFormatKey.unknown),
        warnings: const <String>[],
      );

      final module = manager.moduleForDetection(detection);

      expect(module.legacyFormatKey, 'unknown');
    });

    test('resolves ODS spreadsheet module via format key fallback', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/report.ods',
        format: formatByKey(ImportFormatKey.ods),
        warnings: const <String>[],
      );

      final module = manager.moduleForDetection(detection);

      expect(module.legacyFormatKey, 'ods');
      expect(module.name, contains('OpenDocument'));
    });

    test('resolves SQLite module via format key fallback', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/data.sqlite',
        format: formatByKey(ImportFormatKey.sqlite),
        warnings: const <String>[],
      );

      final module = manager.moduleForDetection(detection);

      expect(module.legacyFormatKey, 'sqlite');
    });

    test('resolves TSV module via format key fallback', () {
      final detection = ImportDetectionResult(
        sourcePath: '/tmp/data.tsv',
        format: formatByKey(ImportFormatKey.tsv),
        warnings: const <String>[],
      );

      final module = manager.moduleForDetection(detection);

      expect(module.legacyFormatKey, 'tsv');
      expect(module.name, 'TSV');
    });
  });

  group('detectSource', () {
    test('detects CSV file format', () async {
      final file = File(p.join(tempDir.path, 'records.csv'))
        ..writeAsStringSync('id,name\n1,Ada\n2,Lin');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.csv);
      expect(result.warnings, isEmpty);
      expect(result.sourcePath, file.path);
    });

    test('detects JSON file format', () async {
      final file = File(p.join(tempDir.path, 'data.json'))
        ..writeAsStringSync('[{"id": 1}]');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.json);
      expect(result.warnings, isEmpty);
    });

    test('detects SQLite file format', () async {
      final file = File(p.join(tempDir.path, 'data.sqlite'))
        ..writeAsStringSync('not-a-real-sqlite-header');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.sqlite);
      expect(result.warnings, contains(isA<String>()));
    });

    test('detects TSV file format', () async {
      final file = File(p.join(tempDir.path, 'data.tsv'))
        ..writeAsStringSync('id\tname\n1\tAda');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.tsv);
      expect(result.warnings, isEmpty);
    });

    test('detects XML SpreadsheetML before generic XML', () async {
      final file = File(p.join(tempDir.path, 'workbook.xml'))
        ..writeAsStringSync('''
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
  xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
  <Worksheet ss:Name="Sheet1">
    <Table>
      <Row><Cell><Data ss:Type="String">Hello</Data></Cell></Row>
    </Table>
  </Worksheet>
</Workbook>''');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.spreadsheetMl);
    });

    test('detects ZIP archive with candidates', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('data.csv', 14, 'id,name\n1,Ada\n'.codeUnits))
        ..addFile(
            ArchiveFile('report.json', 11, '[{"id":1}]'.codeUnits));
      final zipBytes = ZipEncoder().encode(archive)!;
      final file = File(p.join(tempDir.path, 'bundle.zip'))
        ..writeAsBytesSync(zipBytes, flush: true);

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.zipArchive);
      expect(result.archiveCandidates, hasLength(2));
    });

    test('detects GZip archive with inner candidate', () async {
      final bytes = GZipEncoder().encode('id,name\n1,Ada\n'.codeUnits)!;
      final file = File(p.join(tempDir.path, 'customers.csv.gz'))
        ..writeAsBytesSync(bytes, flush: true);

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.gzipArchive);
      expect(result.archiveCandidates, hasLength(1));
      expect(
        result.archiveCandidates.single.innerFormatKey,
        ImportFormatKey.csv,
      );
    });

    test('detects ODS spreadsheet', () async {
      final file = File(p.join(tempDir.path, 'report.ods'))
        ..writeAsStringSync('');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.ods);
      expect(result.format.launchesGenericWizard, isTrue);
    });

    test('detects YAML format', () async {
      final file = File(p.join(tempDir.path, 'config.yaml'))
        ..writeAsStringSync('key: value\n');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.yaml);
    });

    test('detects TOML format', () async {
      final file = File(p.join(tempDir.path, 'config.toml'))
        ..writeAsStringSync('[section]\nkey = "value"\n');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.toml);
    });

    test('detects unrecognized extension as unknown', () async {
      final file = File(p.join(tempDir.path, 'mystery.xyz'))
        ..writeAsStringSync('hello');

      final result = await manager.detectSource(file.path);

      expect(result.format.key, ImportFormatKey.unknown);
    });

    test('populates moduleId in detection result', () async {
      final file = File(p.join(tempDir.path, 'data.csv'))
        ..writeAsStringSync('id,name\n1,Ada');

      final result = await manager.detectSource(file.path);

      expect(result.moduleId, isNotNull);
      expect(result.moduleId, isNotEmpty);
    });
  });

  group('extractArchiveCandidate', () {
    test('extracts a CSV entry from a ZIP archive', () async {
      final archive = Archive()
        ..addFile(
            ArchiveFile('data.csv', 14, 'id,name\n1,Ada\n'.codeUnits))
        ..addFile(
            ArchiveFile('notes.txt', 6, 'hello'.codeUnits));
      final zipBytes = ZipEncoder().encode(archive)!;
      final archiveFile = File(p.join(tempDir.path, 'bundle.zip'))
        ..writeAsBytesSync(zipBytes, flush: true);

      final candidate = ImportArchiveCandidate(
        entryPath: 'data.csv',
        displayName: 'data.csv',
        innerFormatKey: ImportFormatKey.csv,
        innerFormatLabel: 'CSV',
        supportState: ImportSupportState.complete,
      );

      final extractedPath = await manager.extractArchiveCandidate(
        archivePath: archiveFile.path,
        wrapperKey: ImportFormatKey.zipArchive,
        candidate: candidate,
      );

      expect(extractedPath, endsWith('data.csv'));
      final extracted = File(extractedPath);
      expect(extracted.existsSync(), isTrue);
      expect(extracted.readAsStringSync(), 'id,name\n1,Ada\n');
    });

    test('extracts a JSON entry from a ZIP archive', () async {
      final archive = Archive()
        ..addFile(
            ArchiveFile('records.json', 11, '[{"id":1}]'.codeUnits));
      final zipBytes = ZipEncoder().encode(archive)!;
      final archiveFile = File(p.join(tempDir.path, 'data.zip'))
        ..writeAsBytesSync(zipBytes, flush: true);

      final candidate = ImportArchiveCandidate(
        entryPath: 'records.json',
        displayName: 'records.json',
        innerFormatKey: ImportFormatKey.json,
        innerFormatLabel: 'JSON',
        supportState: ImportSupportState.complete,
      );

      final extractedPath = await manager.extractArchiveCandidate(
        archivePath: archiveFile.path,
        wrapperKey: ImportFormatKey.zipArchive,
        candidate: candidate,
      );

      expect(extractedPath, endsWith('records.json'));
      final extracted = File(extractedPath);
      expect(extracted.readAsStringSync(), '[{"id":1}]');
    });

    test('extracts a single file from GZip archive', () async {
      final originalContent = 'id,name\n1,Ada\n2,Lin\n';
      final bytes =
          GZipEncoder().encode(originalContent.codeUnits)!;
      final archiveFile = File(p.join(tempDir.path, 'data.csv.gz'))
        ..writeAsBytesSync(bytes, flush: true);

      final candidate = ImportArchiveCandidate(
        entryPath: 'data.csv',
        displayName: 'data.csv',
        innerFormatKey: ImportFormatKey.csv,
        innerFormatLabel: 'CSV',
        supportState: ImportSupportState.complete,
      );

      final extractedPath = await manager.extractArchiveCandidate(
        archivePath: archiveFile.path,
        wrapperKey: ImportFormatKey.gzipArchive,
        candidate: candidate,
      );

      final extracted = File(extractedPath);
      expect(extracted.existsSync(), isTrue);
      expect(extracted.readAsStringSync(), originalContent);
    });

    test('throws when ZIP entry is missing', () async {
      final archive = Archive()
        ..addFile(
            ArchiveFile('other.txt', 5, 'hello'.codeUnits));
      final zipBytes = ZipEncoder().encode(archive)!;
      final archiveFile = File(p.join(tempDir.path, 'bundle.zip'))
        ..writeAsBytesSync(zipBytes, flush: true);

      final candidate = ImportArchiveCandidate(
        entryPath: 'missing.csv',
        displayName: 'missing.csv',
        innerFormatKey: ImportFormatKey.csv,
        innerFormatLabel: 'CSV',
        supportState: ImportSupportState.complete,
      );

      expect(
        () => manager.extractArchiveCandidate(
          archivePath: archiveFile.path,
          wrapperKey: ImportFormatKey.zipArchive,
          candidate: candidate,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('constructor defaults', () {
    test('uses singleton registry when none provided', () {
      final defaultManager = ImportManager();

      expect(defaultManager.registry, ImportFormatRegistry.instance);
    });

    test('uses provided registry when given', () {
      final customRegistry = ImportFormatRegistry.instance;
      final customManager = ImportManager(registry: customRegistry);

      expect(customManager.registry, customRegistry);
    });
  });
}
