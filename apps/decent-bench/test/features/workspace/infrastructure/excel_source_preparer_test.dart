import 'dart:io';

import 'package:archive/archive.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/excel_source_preparer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('prepareExcelWorkbookSource', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('decent-bench-excel-prep-');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns original path for non-xls files with no warnings', () {
      final xlsxPath = p.join(tempDir.path, 'test.xlsx');
      File(xlsxPath).writeAsBytesSync(_minimalXlsx());

      final result = prepareExcelWorkbookSource(xlsxPath);

      expect(result.resolvedPath, xlsxPath);
      expect(result.warnings, isEmpty);
      result.dispose();
    });

    test('throws BridgeFailure for missing .xls file', () {
      final missingPath = p.join(tempDir.path, 'missing.xls');

      expect(
        () => prepareExcelWorkbookSource(missingPath),
        throwsA(isA<BridgeFailure>()),
      );
    });
  });

  group('normalizeExcelWorkbookSource', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('decent-bench-excel-norm-');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('normalizes xlsx with prefixed namespace elements', () {
      final rawBytes = _xlsxWithPrefixedNamespaces();
      final xlsxPath = p.join(tempDir.path, 'prefixed.xlsx');
      File(xlsxPath).writeAsBytesSync(rawBytes);

      final result = normalizeExcelWorkbookSource(xlsxPath);

      expect(result.resolvedPath, isNot(equals(xlsxPath)));
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('normalized'));

      final normalizedBytes = File(result.resolvedPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(normalizedBytes);
      final sheetEntry = archive.files.firstWhere(
        (f) => f.name.contains('sheet'),
      );
      final sheetContent = String.fromCharCodes(
        sheetEntry.content as List<int>,
      );
      expect(sheetContent, isNot(contains('x:')));

      result.dispose();
    });

    test('creates a temporary file that dispose cleans up', () {
      final rawBytes = _minimalXlsx();
      final xlsxPath = p.join(tempDir.path, 'disposable.xlsx');
      File(xlsxPath).writeAsBytesSync(rawBytes);

      final result = normalizeExcelWorkbookSource(xlsxPath);
      expect(File(result.resolvedPath).existsSync(), isTrue);

      result.dispose();
      expect(File(result.resolvedPath).existsSync(), isFalse);
    });

    test('throws BridgeFailure for missing file', () {
      expect(
        () =>
            normalizeExcelWorkbookSource(p.join(tempDir.path, 'missing.xlsx')),
        throwsA(isA<BridgeFailure>()),
      );
    });
  });
}

List<int> _minimalXlsx() {
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        '[Content_Types].xml',
        '<?xml version="1.0"?>'.length,
        '<?xml version="1.0"?>'.codeUnits,
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/workbook.xml',
        '<workbook/>'.length,
        '<workbook/>'.codeUnits,
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/worksheets/sheet1.xml',
        '<worksheet/>'.length,
        '<worksheet/>'.codeUnits,
      ),
    );
  return ZipEncoder().encode(archive)!;
}

List<int> _xlsxWithPrefixedNamespaces() {
  final sheetContent =
      '<?xml version="1.0"?>'
      '<x:worksheet xmlns:x="http://example.com">'
      '<x:sheetData/>'
      '</x:worksheet>';
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        '[Content_Types].xml',
        '<?xml version="1.0"?>'.length,
        '<?xml version="1.0"?>'.codeUnits,
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/workbook.xml',
        '<workbook/>'.length,
        '<workbook/>'.codeUnits,
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/worksheets/sheet1.xml',
        sheetContent.length,
        sheetContent.codeUnits,
      ),
    );
  return ZipEncoder().encode(archive)!;
}
