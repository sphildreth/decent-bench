import 'dart:io';

import 'package:archive/archive.dart';
import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/infrastructure/import_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late ImportDetectionService service;
  late Directory tempDir;

  setUp(() async {
    service = ImportDetectionService();
    tempDir = await Directory.systemTemp.createTemp(
      'decent-bench-detect-test-',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('detects CSV as a supported generic import', () async {
    final file = File(p.join(tempDir.path, 'records.csv'))
      ..writeAsStringSync('id,name\n1,Ada\n2,Lin');

    final result = await service.detect(file.path);

    expect(result.format.key, ImportFormatKey.csv);
    expect(result.format.launchesGenericWizard, isTrue);
    expect(result.warnings, isEmpty);
  });

  test('detects ZIP wrapper candidates', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('customers.csv', 14, 'id,name\n1,Ada\n'.codeUnits))
      ..addFile(ArchiveFile('snapshot.json', 11, '[{"id":1}]'.codeUnits))
      ..addFile(ArchiveFile('notes.bin', 3, <int>[1, 2, 3]));
    final zipBytes = ZipEncoder().encode(archive)!;
    final file = File(p.join(tempDir.path, 'bundle.zip'))
      ..writeAsBytesSync(zipBytes, flush: true);

    final result = await service.detect(file.path);

    expect(result.format.key, ImportFormatKey.zipArchive);
    expect(result.archiveCandidates, hasLength(2));
    expect(
      result.archiveCandidates.map((candidate) => candidate.innerFormatKey),
      containsAll(<ImportFormatKey>[ImportFormatKey.csv, ImportFormatKey.json]),
    );
  });

  test('detects GZip wrapper candidate from inner filename', () async {
    final bytes = GZipEncoder().encode('id,name\n1,Ada\n'.codeUnits)!;
    final file = File(p.join(tempDir.path, 'customers.csv.gz'))
      ..writeAsBytesSync(bytes, flush: true);

    final result = await service.detect(file.path);

    expect(result.format.key, ImportFormatKey.gzipArchive);
    expect(result.archiveCandidates, hasLength(1));
    expect(result.archiveCandidates.single.innerFormatKey, ImportFormatKey.csv);
  });

  test('detects ODS as a supported generic spreadsheet import', () async {
    final file = File(p.join(tempDir.path, 'report.ods'))
      ..writeAsStringSync('');

    final result = await service.detect(file.path);

    expect(result.format.key, ImportFormatKey.ods);
    expect(result.format.launchesGenericWizard, isTrue);
    expect(result.format.supportState, ImportSupportState.complete);
  });

  test('keeps connector expansion formats explicit but unavailable', () async {
    final cases = <String, ImportSupportState>{
      'warehouse.duckdb': ImportSupportState.planned,
      'analytics.parquet': ImportSupportState.investigate,
      'legacy.dbf': ImportSupportState.investigate,
      'report.pdf': ImportSupportState.deferred,
    };

    for (final entry in cases.entries) {
      final file = File(p.join(tempDir.path, entry.key))..writeAsStringSync('');

      final result = await service.detect(file.path);

      expect(result.format.isRecognizedButUnavailable, isTrue);
      expect(result.format.supportState, entry.value);
    }
  });

  test('routes XML SpreadsheetML signatures before generic XML', () async {
    final file = File(p.join(tempDir.path, 'workbook.xml'))
      ..writeAsStringSync('''
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
  <Worksheet ss:Name="Sheet1"><Table /></Worksheet>
</Workbook>
''');

    final result = await service.detect(file.path);

    expect(result.format.key, ImportFormatKey.spreadsheetMl);
    expect(result.format.launchesGenericWizard, isTrue);
  });

  test('routes JSON and W3C log content before generic .log import', () async {
    final jsonLog = File(p.join(tempDir.path, 'app.log'))
      ..writeAsStringSync(
        '{"timestamp":"2026-05-23T12:00:00Z","level":"info","message":"ok"}\n',
      );
    final w3cLog = File(p.join(tempDir.path, 'access.log'))
      ..writeAsStringSync(
        '#Fields: date time cs-method cs-uri-stem sc-status\n'
        '2026-05-23 12:00:00 GET / 200\n',
      );

    expect(
      (await service.detect(jsonLog.path)).format.key,
      ImportFormatKey.jsonLogStream,
    );
    expect(
      (await service.detect(w3cLog.path)).format.key,
      ImportFormatKey.delimitedLog,
    );
  });

  test(
    'routes fixed-width .txt content before generic delimited import',
    () async {
      final file = File(p.join(tempDir.path, 'employees.txt'))
        ..writeAsStringSync('ID  NAME        TOTAL\n1   Ada         42\n');

      final result = await service.detect(file.path);

      expect(result.format.key, ImportFormatKey.fixedWidth);
      expect(result.format.launchesGenericWizard, isTrue);
    },
  );

  test('detects and extracts XZ single-file wrapper candidates', () async {
    final bytes = XZEncoder().encode('id,name\n1,Ada\n'.codeUnits);
    final file = File(p.join(tempDir.path, 'customers.csv.xz'))
      ..writeAsBytesSync(bytes, flush: true);

    final result = await service.detect(file.path);
    expect(result.format.key, ImportFormatKey.xzArchive);
    expect(result.archiveCandidates.single.innerFormatKey, ImportFormatKey.csv);

    final extracted = await service.extractArchiveCandidate(
      archivePath: file.path,
      wrapperKey: ImportFormatKey.xzArchive,
      candidate: result.archiveCandidates.single,
    );
    expect(File(extracted).readAsStringSync(), 'id,name\n1,Ada\n');
  });
}
