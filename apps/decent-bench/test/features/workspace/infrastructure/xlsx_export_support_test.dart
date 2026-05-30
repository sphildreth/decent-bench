import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:decent_bench/features/workspace/infrastructure/xlsx_export_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('writeRowsToXlsx', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('xlsx-export-test-');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('writes an Office Open XML workbook with headers and rows', () async {
      final path = p.join(tempDir.path, 'results.xlsx');

      final result = await writeRowsToXlsx(
        path: path,
        columns: const <String>['id', 'name', 'active'],
        rows: Stream<List<Object?>>.fromIterable(const <List<Object?>>[
          <Object?>[1, 'Ada & Co', true],
          <Object?>[2, '<Grace>', false],
        ]),
        includeHeaders: true,
      );

      expect(result.rowCount, 2);
      expect(result.path, path);
      final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
      expect(archive.findFile('[Content_Types].xml'), isNotNull);
      expect(archive.findFile('xl/workbook.xml'), isNotNull);
      final sheet = _archiveText(archive.findFile('xl/worksheets/sheet1.xml')!);
      expect(sheet, contains('<c r="A1" t="inlineStr"'));
      expect(sheet, contains('<t>id</t>'));
      expect(sheet, contains('<c r="A2"><v>1</v></c>'));
      expect(sheet, contains('<t>Ada &amp; Co</t>'));
      expect(sheet, contains('<t>&lt;Grace&gt;</t>'));
      expect(sheet, contains('<c r="C3" t="b"><v>0</v></c>'));
    });

    test('omits header row when requested', () async {
      final path = p.join(tempDir.path, 'no-headers.xlsx');

      await writeRowsToXlsx(
        path: path,
        columns: const <String>['id'],
        rows: Stream<List<Object?>>.fromIterable(const <List<Object?>>[
          <Object?>[7],
        ]),
        includeHeaders: false,
      );

      final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
      final sheet = _archiveText(archive.findFile('xl/worksheets/sheet1.xml')!);
      expect(sheet, isNot(contains('<t>id</t>')));
      expect(sheet, contains('<c r="A1"><v>7</v></c>'));
    });
  });
}

String _archiveText(ArchiveFile file) {
  return utf8.decode(file.content as List<int>);
}
