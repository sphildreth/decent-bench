import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/excel_import_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  String fixturePath(String relativePath) {
    return p.normalize(
      p.join(Directory.current.path, '..', '..', relativePath),
    );
  }

  test('normalizes prefixed OOXML workbooks before inspection', () {
    final sourcePath = fixturePath('test-data/excel/basic_contacts.xlsx');

    final inspection = inspectExcelSourceFile(sourcePath, headerRow: true);

    expect(inspection.sheets, isNotEmpty);
    expect(
      inspection.warnings.join('\n'),
      contains('temporary `.xlsx` rewrite'),
    );

    final materialized = materializeExcelImportSourceFile(
      sourcePath: sourcePath,
      headerRow: true,
      sheets: inspection.sheets,
    );

    expect(materialized.tables, isNotEmpty);
    expect(materialized.tables.first.rows, isNotEmpty);
    expect(
      materialized.warnings.join('\n'),
      contains('temporary `.xlsx` rewrite'),
    );
  });
}
