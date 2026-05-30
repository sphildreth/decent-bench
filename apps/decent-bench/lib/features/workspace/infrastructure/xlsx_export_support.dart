import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../domain/workspace_models.dart';

Future<ExcelExportResult> writeRowsToXlsx({
  required String path,
  required List<String> columns,
  required Stream<List<Object?>> rows,
  required bool includeHeaders,
  String sheetName = 'Results',
}) async {
  if (columns.isEmpty) {
    throw const BridgeFailure(
      'The current statement does not produce rows and cannot be exported.',
    );
  }

  final destination = File(path);
  await destination.parent.create(recursive: true);
  final tempDir = await Directory.systemTemp.createTemp('decent_bench_xlsx_');
  try {
    await _writeStaticWorkbookParts(tempDir, sheetName: sheetName);
    final sheetPath = p.join(tempDir.path, 'xl', 'worksheets', 'sheet1.xml');
    final sheetFile = File(sheetPath);
    await sheetFile.parent.create(recursive: true);

    var rowIndex = 1;
    var rowCount = 0;
    final sink = sheetFile.openWrite();
    try {
      sink.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      sink.writeln(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      );
      sink.writeln('<sheetData>');
      if (includeHeaders) {
        _writeSheetRow(sink, rowIndex++, columns);
      }
      await for (final row in rows) {
        _writeSheetRow(sink, rowIndex++, row);
        rowCount++;
      }
      sink.writeln('</sheetData>');
      sink.writeln('</worksheet>');
    } finally {
      await sink.flush();
      await sink.close();
    }

    await _zipWorkbook(tempDir, destination.path);
    return ExcelExportResult(rowCount: rowCount, path: destination.path);
  } finally {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<void> _writeStaticWorkbookParts(
  Directory root, {
  required String sheetName,
}) async {
  final files = <String, String>{
    '[Content_Types].xml': '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>
''',
    '_rels/.rels': '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
''',
    'xl/workbook.xml':
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${_xmlAttribute(sheetName)}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
''',
    'xl/_rels/workbook.xml.rels': '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>
''',
  };

  for (final entry in files.entries) {
    final file = File(p.joinAll(<String>[root.path, ...entry.key.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value.trimLeft());
  }
}

Future<void> _zipWorkbook(Directory root, String path) async {
  final encoder = ZipFileEncoder();
  encoder.create(path, level: Deflate.BEST_SPEED);
  try {
    for (final relativePath in const <String>[
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels',
      'xl/worksheets/sheet1.xml',
    ]) {
      await encoder.addFile(
        File(p.joinAll(<String>[root.path, ...relativePath.split('/')])),
        relativePath,
      );
    }
  } finally {
    await encoder.close();
  }
}

void _writeSheetRow(IOSink sink, int rowIndex, List<Object?> values) {
  sink.write('<row r="$rowIndex">');
  for (var index = 0; index < values.length; index++) {
    final ref = '${_columnName(index + 1)}$rowIndex';
    _writeCell(sink, ref, values[index]);
  }
  sink.writeln('</row>');
}

void _writeCell(IOSink sink, String ref, Object? value) {
  if (value == null) {
    sink.write('<c r="$ref"/>');
    return;
  }
  if (value is bool) {
    sink.write('<c r="$ref" t="b"><v>${value ? 1 : 0}</v></c>');
    return;
  }
  if (value is num && value.isFinite) {
    sink.write('<c r="$ref"><v>$value</v></c>');
    return;
  }
  sink.write(
    '<c r="$ref" t="inlineStr"><is><t>${_xmlText('$value')}</t></is></c>',
  );
}

String _columnName(int oneBasedIndex) {
  var value = oneBasedIndex;
  final chars = <int>[];
  while (value > 0) {
    value--;
    chars.insert(0, 65 + (value % 26));
    value ~/= 26;
  }
  return String.fromCharCodes(chars);
}

String _xmlText(String value) {
  return _sanitizeXml(
    value,
  ).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}

String _xmlAttribute(String value) {
  return _xmlText(value).replaceAll('"', '&quot;');
}

String _sanitizeXml(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune == 0x09 ||
        rune == 0x0A ||
        rune == 0x0D ||
        rune >= 0x20 && rune <= 0xD7FF ||
        rune >= 0xE000 && rune <= 0xFFFD ||
        rune >= 0x10000 && rune <= 0x10FFFF) {
      buffer.writeCharCode(rune);
    } else {
      buffer.write('\uFFFD');
    }
  }
  return buffer.toString();
}
