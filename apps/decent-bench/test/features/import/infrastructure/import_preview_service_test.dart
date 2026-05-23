import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/infrastructure/import_format_registry.dart';
import 'package:decent_bench/features/import/infrastructure/import_execution_service.dart';
import 'package:decent_bench/features/import/infrastructure/import_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late ImportPreviewService service;
  late ImportExecutionService executionService;
  late Directory tempDir;
  final registry = ImportFormatRegistry.instance;

  String resolveHtmlFixturePath(String filename) {
    final candidates = <String>[
      p.normalize(
        p.join(
          Directory.current.path,
          '..',
          '..',
          'test-data',
          'html',
          filename,
        ),
      ),
      p.normalize(
        p.join(Directory.current.path, 'test-data', 'html', filename),
      ),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    throw StateError(
      'Could not locate test-data/html/$filename from ${Directory.current.path}',
    );
  }

  String resolveJsonFixturePath(String filename) {
    final candidates = <String>[
      p.normalize(
        p.join(
          Directory.current.path,
          '..',
          '..',
          'test-data',
          'json',
          filename,
        ),
      ),
      p.normalize(
        p.join(Directory.current.path, 'test-data', 'json', filename),
      ),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    throw StateError(
      'Could not locate test-data/json/$filename from ${Directory.current.path}',
    );
  }

  String resolveXmlFixturePath(String filename) {
    final candidates = <String>[
      p.normalize(
        p.join(
          Directory.current.path,
          '..',
          '..',
          'test-data',
          'xml',
          filename,
        ),
      ),
      p.normalize(p.join(Directory.current.path, 'test-data', 'xml', filename)),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    throw StateError(
      'Could not locate test-data/xml/$filename from ${Directory.current.path}',
    );
  }

  setUp(() async {
    service = ImportPreviewService();
    executionService = ImportExecutionService();
    tempDir = await Directory.systemTemp.createTemp(
      'decent-bench-preview-test-',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('parses delimited files with inferred types', () async {
    final file = File(p.join(tempDir.path, 'people.csv'))
      ..writeAsStringSync('id,name,active\n1,Ada,true\n2,Lin,false\n');

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.csv),
      options: const GenericImportOptions(),
    );

    expect(inspection.tables, hasLength(1));
    expect(
      inspection.tables.single.columns.map((column) => column.targetType),
      <String>['INTEGER', 'TEXT', 'BOOLEAN'],
    );
  });

  test('parses custom-escaped delimited values', () async {
    final file = File(p.join(tempDir.path, 'quoted.txt'))
      ..writeAsStringSync('id|note\n1|"Ada said \\"hi\\""\n');

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.genericDelimited),
      options: const GenericImportOptions(
        delimiter: '|',
        quoteCharacter: '"',
        escapeCharacter: '\\',
      ),
    );

    expect(
      inspection.tables.single.previewRows.single['note'],
      'Ada said "hi"',
    );
  });

  test('normalizes JSON arrays into child tables', () async {
    final file = File(p.join(tempDir.path, 'orders.json'))
      ..writeAsStringSync(
        '{"customer":{"id":1,"name":"Ada"},"orders":[{"item":"Keyboard"},{"item":"Mouse"}]}',
      );

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.json),
      options: const GenericImportOptions(
        structuredStrategy: StructuredImportStrategy.normalize,
      ),
    );

    expect(inspection.tables.length, greaterThan(1));
    expect(
      inspection.tables.any(
        (table) =>
            table.columns.any((column) => column.sourceName == 'parent_id'),
      ),
      isTrue,
    );
  });

  test('JSON defaults to normalized relational imports', () {
    final options = defaultGenericImportOptionsFor(ImportFormatKey.json);

    expect(options.structuredStrategy, StructuredImportStrategy.normalize);
  });

  test(
    'normalizes nested JSON fixtures into parent and child tables',
    () async {
      final inspection = await service.inspect(
        sourcePath: resolveJsonFixturePath('nested_orders.json'),
        format: registry.forKey(ImportFormatKey.json),
        options: defaultGenericImportOptionsFor(ImportFormatKey.json),
      );

      expect(
        inspection.tables.map((table) => table.targetName),
        containsAll(<String>[
          'nested_orders',
          'nested_orders_orders',
          'nested_orders_orders_items',
        ]),
      );

      final orders = inspection.tables.firstWhere(
        (table) => table.targetName == 'nested_orders_orders',
      );
      final items = inspection.tables.firstWhere(
        (table) => table.targetName == 'nested_orders_orders_items',
      );

      expect(orders.rowCount, 2);
      expect(items.rowCount, 3);
      expect(
        orders.columns.map((column) => column.sourceName),
        containsAll(<String>['_import_id', 'parent_id', 'order_id']),
      );
      expect(
        items.columns.map((column) => column.sourceName),
        containsAll(<String>['_import_id', 'parent_id', 'sku']),
      );
    },
  );

  test('flattens NDJSON into one table', () async {
    final file = File(p.join(tempDir.path, 'events.jsonl'))
      ..writeAsStringSync('{"id":1,"kind":"start"}\n{"id":2,"kind":"stop"}\n');

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.ndjson),
      options: const GenericImportOptions(),
    );

    expect(inspection.tables, hasLength(1));
    expect(inspection.tables.single.rowCount, 2);
  });

  test('parses fixed-width text with inferred boundaries', () async {
    final file = File(p.join(tempDir.path, 'employees.fwf'))
      ..writeAsStringSync(
        'ID  NAME        TOTAL\n'
        '1   Ada Lovelace 42.5\n'
        '2   Lin          10\n',
      );

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.fixedWidth),
      options: const GenericImportOptions(),
    );

    expect(inspection.tables.single.columns.map((c) => c.sourceName), <String>[
      'ID',
      'NAME',
      'TOTAL',
    ]);
    expect(inspection.tables.single.previewRows.first['NAME'], 'Ada Lovelace');
  });

  test('extracts timestamp metadata from JSON log streams', () async {
    final file = File(p.join(tempDir.path, 'events.log'))
      ..writeAsStringSync(
        '{"timestamp":"2026-05-23T12:00:00Z","level":"info","message":"started","request":{"id":"r1"}}\n',
      );

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.jsonLogStream),
      options: const GenericImportOptions(),
    );

    expect(inspection.tables.single.previewRows.single['_source_line'], 1);
    expect(
      inspection.tables.single.previewRows.single['_event_timestamp'],
      '2026-05-23T12:00:00.000Z',
    );
    expect(inspection.tables.single.previewRows.single['request__id'], 'r1');
  });

  test('parses IIS W3C log templates', () async {
    final file = File(p.join(tempDir.path, 'access.log'))
      ..writeAsStringSync(
        '#Version: 1.0\n'
        '#Fields: date time cs-method cs-uri-stem sc-status\n'
        '2026-05-23 12:00:00 GET /index.html 200\n',
      );

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.delimitedLog),
      options: const GenericImportOptions(),
    );

    expect(inspection.tables.single.previewRows.single['cs_method'], 'GET');
    expect(
      inspection.tables.single.previewRows.single['_event_timestamp'],
      '2026-05-23T12:00:00Z',
    );
  });

  test('maps HAR entries into linked tables', () async {
    final file = File(p.join(tempDir.path, 'capture.har'))
      ..writeAsStringSync('''
{
  "log": {
    "version": "1.2",
    "creator": {"name": "test", "version": "1"},
    "entries": [
      {
        "startedDateTime": "2026-05-23T12:00:00Z",
        "time": 12,
        "request": {
          "method": "GET",
          "url": "https://example.test/",
          "httpVersion": "HTTP/1.1",
          "headers": [{"name": "Accept", "value": "*/*"}]
        },
        "response": {
          "status": 200,
          "statusText": "OK",
          "httpVersion": "HTTP/1.1",
          "headers": [{"name": "Content-Type", "value": "text/html"}],
          "content": {"size": 5, "mimeType": "text/html"},
          "bodySize": 5,
          "headersSize": 20
        },
        "timings": {"wait": 10, "receive": 2}
      }
    ]
  }
}
''');

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.har),
      options: const GenericImportOptions(),
    );

    expect(
      inspection.tables.map((table) => table.sourceId),
      containsAll(<String>['requests', 'responses', 'timings', 'headers']),
    );
    final requests = inspection.tables.firstWhere(
      (table) => table.sourceId == 'requests',
    );
    expect(requests.previewRows.single['method'], 'GET');
  });

  test('normalizes XML repeated elements into related tables', () async {
    final file = File(p.join(tempDir.path, 'catalog.xml'))
      ..writeAsStringSync(
        '<catalog><customer id="1"><name>Ada</name><orders><order><item>Keyboard</item></order><order><item>Mouse</item></order></orders></customer></catalog>',
      );

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.xml),
      options: const GenericImportOptions(
        structuredStrategy: StructuredImportStrategy.normalize,
      ),
    );

    expect(inspection.tables.length, greaterThan(1));
    expect(
      inspection.tables.any((table) => table.targetName.contains('orders')),
      isTrue,
    );
  });

  test(
    'projects repeated XML root elements into one record table by default',
    () async {
      final inspection = await service.inspect(
        sourcePath: resolveXmlFixturePath('07_large_dataset.xml'),
        format: registry.forKey(ImportFormatKey.xml),
        options: defaultGenericImportOptionsFor(ImportFormatKey.xml),
      );

      expect(inspection.tables, hasLength(1));
      final table = inspection.tables.single;
      expect(table.targetName, 'records');
      expect(table.rowCount, 10000);
      expect(
        table.columns.map((column) => column.sourceName),
        containsAll(<String>[
          'attr_id',
          'uuid',
          'value',
          'status',
          'metadata__source',
          'metadata__retry_count',
        ]),
      );
      expect(table.previewRows.first, containsPair('attr_id', '1'));
      expect(
        table.previewRows.first,
        containsPair('metadata__source', 'system_1'),
      );
    },
  );

  test(
    'routes SpreadsheetML worksheets through a strict XML adapter',
    () async {
      final file = File(p.join(tempDir.path, 'workbook.xml'))
        ..writeAsStringSync('''
<?xml version="1.0"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
  <Worksheet ss:Name="Sales">
    <Table>
      <Row>
        <Cell><Data ss:Type="String">id</Data></Cell>
        <Cell><Data ss:Type="String">amount</Data></Cell>
      </Row>
      <Row>
        <Cell><Data ss:Type="Number">1</Data></Cell>
        <Cell ss:Formula="=1+2"><Data ss:Type="Number">3</Data></Cell>
      </Row>
    </Table>
  </Worksheet>
</Workbook>
''');

      final inspection = await service.inspect(
        sourcePath: file.path,
        format: registry.forKey(ImportFormatKey.spreadsheetMl),
        options: const GenericImportOptions(),
      );

      expect(inspection.tables.single.targetName, 'Sales');
      expect(inspection.tables.single.previewRows.single['amount'], 3);
      expect(inspection.warnings.join('\n'), contains('formula cells'));
    },
  );

  test('extracts ODS worksheet rows from content.xml', () async {
    final contentXml = utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
  <office:body>
    <office:spreadsheet>
      <table:table table:name="Sheet A">
        <table:table-row>
          <table:table-cell office:value-type="string"><text:p>id</text:p></table:table-cell>
          <table:table-cell office:value-type="string"><text:p>active</text:p></table:table-cell>
        </table:table-row>
        <table:table-row>
          <table:table-cell office:value-type="float" office:value="1"><text:p>1</text:p></table:table-cell>
          <table:table-cell office:value-type="boolean" office:boolean-value="true"><text:p>true</text:p></table:table-cell>
        </table:table-row>
      </table:table>
    </office:spreadsheet>
  </office:body>
</office:document-content>
''');
    final archive = Archive()
      ..addFile(ArchiveFile('content.xml', contentXml.length, contentXml));
    final file = File(p.join(tempDir.path, 'workbook.ods'))
      ..writeAsBytesSync(ZipEncoder().encode(archive)!, flush: true);

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.ods),
      options: const GenericImportOptions(),
    );

    expect(inspection.tables.single.targetName, 'Sheet_A');
    expect(inspection.tables.single.previewRows.single['id'], 1);
    expect(inspection.tables.single.previewRows.single['active'], isTrue);
  });

  test('extracts multiple HTML tables', () async {
    final file = File(p.join(tempDir.path, 'tables.html'))
      ..writeAsStringSync('''
        <html>
          <body>
            <table id="customers"><caption>Customers</caption><tr><th>id</th><th>name</th></tr><tr><td>1</td><td>Ada</td></tr></table>
            <table><tr><th>kind</th><th>count</th></tr><tr><td>open</td><td>2</td></tr></table>
          </body>
        </html>
      ''');

    final inspection = await service.inspect(
      sourcePath: file.path,
      format: registry.forKey(ImportFormatKey.htmlTable),
      options: const GenericImportOptions(),
    );

    expect(inspection.tables, hasLength(2));
    expect(inspection.tables.first.targetName, contains('Customers'));
    expect(inspection.tables.every((table) => table.selected), isTrue);
  });

  test(
    'parses Markdown pipe tables and preserves warning row numbers',
    () async {
      final file = File(p.join(tempDir.path, 'tables.md'))
        ..writeAsStringSync(
          [
            '# Heading',
            '',
            'Intro prose with | pipes but no table.',
            '',
            '```text',
            '| ignored | table |',
            '| --- | --- |',
            '| nope | nope |',
            '```',
            '',
            '| name | note | count |',
            '| --- | :---: | ---: |',
            '| Ada | has escaped \\| pipe | 1 |',
            '| Lin | trailing pipe | 2 |',
            '| Ragged only one cell |',
            '',
            'More prose with | pipes but no separator.',
            '',
            '| city | status |',
            '| --- | --- |',
            '| Austin | open |',
          ].join('\n'),
        );

      final inspection = await service.inspect(
        sourcePath: file.path,
        format: registry.forKey(ImportFormatKey.markdownTable),
        options: const GenericImportOptions(),
      );

      expect(inspection.tables, hasLength(2));
      expect(inspection.tables.first.rowCount, 3);
      expect(
        inspection.tables.first.previewRows[0]['note'],
        'has escaped | pipe',
      );
      expect(
        inspection.tables.first.warnings.join('\n'),
        contains('Source row 15: Markdown table row had 1 cell; expected 3.'),
      );
      expect(
        inspection.tables.first.warnings.join('\n'),
        contains(
          'Missing cells are imported as null and extra cells are truncated.',
        ),
      );
      expect(inspection.warnings.join('\n'), isNot(contains('Source row 7:')));

      final request = GenericImportRequest(
        jobId: 'markdown-preview-test',
        sourcePath: file.path,
        targetPath: p.join(tempDir.path, 'tables.ddb'),
        importIntoExistingTarget: false,
        replaceExistingTarget: true,
        formatKey: ImportFormatKey.markdownTable,
        options: const GenericImportOptions(),
        tables: inspection.tables,
      );
      final materialized = executionService.materializeRequest(request);

      expect(materialized.tables, hasLength(2));
      expect(materialized.tables.first.rows, hasLength(3));
      expect(materialized.tables.first.rows[0]['note'], 'has escaped | pipe');
      expect(
        materialized.tables.first.warnings.join('\n'),
        contains('Source row 15: Markdown table row had 1 cell; expected 3.'),
      );
    },
  );

  test('rejects Markdown documents without any pipe tables', () async {
    final file = File(p.join(tempDir.path, 'notes.md'))
      ..writeAsStringSync(
        [
          '# Notes',
          '',
          'Plain prose.',
          '',
          '- list item',
          '',
          '```',
          '| not | a | table |',
          '```',
        ].join('\n'),
      );

    expect(
      () => service.inspect(
        sourcePath: file.path,
        format: registry.forKey(ImportFormatKey.markdownTable),
        options: const GenericImportOptions(),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('No Markdown tables found'),
        ),
      ),
    );
  });

  test(
    'keeps every detected table selected for checked-in HTML fixtures',
    () async {
      final inspection = await service.inspect(
        sourcePath: resolveHtmlFixturePath('report_tables.html'),
        format: registry.forKey(ImportFormatKey.htmlTable),
        options: const GenericImportOptions(),
      );

      expect(inspection.tables, hasLength(2));
      expect(inspection.tables.every((table) => table.selected), isTrue);
    },
  );
}
