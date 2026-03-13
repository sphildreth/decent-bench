import 'package:decent_bench/features/import/domain/import_models.dart';

class GenericImportFixtureEntry {
  const GenericImportFixtureEntry({
    required this.relativePath,
    required this.formatKey,
    this.options,
    this.extractWrappedSource = false,
    this.expectedTableNames,
    this.expectedRowCountsByTable = const <String, int>{},
    this.requiredColumnsByTable = const <String, List<String>>{},
    this.expectedColumnTypesByTable = const <String, Map<String, String>>{},
  });

  final String relativePath;
  final ImportFormatKey formatKey;
  final GenericImportOptions? options;
  final bool extractWrappedSource;
  final List<String>? expectedTableNames;
  final Map<String, int> expectedRowCountsByTable;
  final Map<String, List<String>> requiredColumnsByTable;
  final Map<String, Map<String, String>> expectedColumnTypesByTable;
}

class GenericInspectionFixtureEntry {
  const GenericInspectionFixtureEntry({
    required this.relativePath,
    required this.formatKey,
    this.options,
    this.extractWrappedSource = false,
    required this.expectedTableCount,
    required this.expectedSelectedTableCount,
    this.expectedWarningSubstrings = const <String>[],
  });

  final String relativePath;
  final ImportFormatKey formatKey;
  final GenericImportOptions? options;
  final bool extractWrappedSource;
  final int expectedTableCount;
  final int expectedSelectedTableCount;
  final List<String> expectedWarningSubstrings;
}

class SqliteImportFixtureEntry {
  const SqliteImportFixtureEntry({
    required this.relativePath,
    this.expectedTableNames,
    this.expectedRowCountsByTable = const <String, int>{},
    this.expectedColumnTypesByTable = const <String, Map<String, String>>{},
  });

  final String relativePath;
  final List<String>? expectedTableNames;
  final Map<String, int> expectedRowCountsByTable;
  final Map<String, Map<String, String>> expectedColumnTypesByTable;
}

class SqliteInspectionFixtureEntry {
  const SqliteInspectionFixtureEntry({
    required this.relativePath,
    this.expectedDetectionWarningSubstrings = const <String>[],
    this.expectedTableCount,
  });

  final String relativePath;
  final List<String> expectedDetectionWarningSubstrings;
  final int? expectedTableCount;
}

class ExcelImportFixtureEntry {
  const ExcelImportFixtureEntry({
    required this.relativePath,
    this.headerRow = true,
  });

  final String relativePath;
  final bool headerRow;
}

class SqlDumpImportFixtureEntry {
  const SqlDumpImportFixtureEntry({
    required this.relativePath,
    this.encoding = 'auto',
    this.extractWrappedSource = false,
    this.requireSkippedStatements = false,
  });

  final String relativePath;
  final String encoding;
  final bool extractWrappedSource;
  final bool requireSkippedStatements;
}

class DetectionFixtureEntry {
  const DetectionFixtureEntry({
    required this.relativePath,
    required this.expectedFormatKey,
    required this.expectedSupportState,
    required this.expectedImplementationKind,
    this.expectedWarningSubstrings = const <String>[],
    this.expectedArchiveCandidateKeys = const <ImportFormatKey>[],
  });

  final String relativePath;
  final ImportFormatKey expectedFormatKey;
  final ImportSupportState expectedSupportState;
  final ImportImplementationKind expectedImplementationKind;
  final List<String> expectedWarningSubstrings;
  final List<ImportFormatKey> expectedArchiveCandidateKeys;
}

const List<String> _allTypesMediumTableNames = <String>[
  'basic_types',
  'bool_types',
  'datetime_types',
  'enum_types',
  'null_handling',
  'numeric_edge_cases',
  'text_types',
];

const Map<String, int> _allTypesMediumRowCounts = <String, int>{
  'basic_types': 100,
  'bool_types': 50,
  'datetime_types': 50,
  'text_types': 50,
  'numeric_edge_cases': 50,
  'null_handling': 50,
  'enum_types': 50,
};

const Map<String, Map<String, String>> _allTypesMediumColumnTypes =
    <String, Map<String, String>>{
      'basic_types': <String, String>{
        'tinyint_col': 'INTEGER',
        'float_col': 'FLOAT64',
        'numeric_col': 'DECIMAL(10,2)',
        'date_col': 'TIMESTAMP',
        'time_col': 'TIMESTAMP',
        'datetime_col': 'TIMESTAMP',
        'timestamp_col': 'TIMESTAMP',
        'bool_col': 'BOOLEAN',
        'blob_col': 'BLOB',
        'uuid_col': 'UUID',
      },
      'bool_types': <String, String>{
        'bool_as_int': 'BOOLEAN',
        'bool_as_text': 'BOOLEAN',
        'bool_as_char': 'BOOLEAN',
      },
      'datetime_types': <String, String>{
        'iso_date': 'TIMESTAMP',
        'us_date': 'TIMESTAMP',
        'eu_date': 'TIMESTAMP',
        'iso_datetime': 'TIMESTAMP',
        'unix_timestamp': 'TIMESTAMP',
        'epoch_millis': 'TIMESTAMP',
        'natural_language': 'TEXT',
      },
      'numeric_edge_cases': <String, String>{
        'zero': 'INTEGER',
        'negative_zero': 'FLOAT64',
        'infinity': 'FLOAT64',
        'nan': 'FLOAT64',
      },
      'text_types': <String, String>{
        'unicode': 'TEXT',
        'emoji': 'TEXT',
        'json': 'TEXT',
        'xml': 'TEXT',
      },
    };

const List<String> _htmlDataTypesTestTableNames = <String>[
  'basic_types',
  'bool_types',
  'datetime_types',
  'text_types',
  'numeric_edge_cases',
  'null_handling',
  'enum_types',
];

const Map<String, int> _htmlDataTypesTestRowCounts = <String, int>{
  'basic_types': 5,
  'bool_types': 10,
  'datetime_types': 8,
  'text_types': 6,
  'numeric_edge_cases': 5,
  'null_handling': 8,
  'enum_types': 10,
};

const Map<String, Map<String, String>> _htmlDataTypesTestColumnTypes =
    <String, Map<String, String>>{
      'basic_types': <String, String>{
        'id': 'INTEGER',
        'tinyint_col': 'INTEGER',
        'float_col': 'FLOAT64',
        'real_col': 'FLOAT64',
        'double_col': 'FLOAT64',
        'numeric_col': 'DECIMAL(18,6)',
        'decimal_col': 'DECIMAL(18,6)',
        'date_col': 'TIMESTAMP',
        'time_col': 'TIMESTAMP',
        'datetime_col': 'TIMESTAMP',
        'timestamp_col': 'TIMESTAMP',
        'bool_col': 'BOOLEAN',
        'json_col': 'TEXT',
        'uuid_col': 'UUID',
      },
      'bool_types': <String, String>{
        'bool_as_int': 'BOOLEAN',
        'bool_as_text': 'TEXT',
        'bool_as_char': 'TEXT',
        'bool_as_word': 'TEXT',
      },
      'datetime_types': <String, String>{
        'iso_date': 'TIMESTAMP',
        'us_date': 'TIMESTAMP',
        'eu_date': 'TIMESTAMP',
        'iso_datetime': 'TIMESTAMP',
        'unix_timestamp': 'TIMESTAMP',
        'epoch_millis': 'TIMESTAMP',
        'natural_language': 'TEXT',
      },
      'text_types': <String, String>{
        'unicode': 'TEXT',
        'emoji': 'TEXT',
        'html': 'TEXT',
        'json': 'TEXT',
        'xml': 'TEXT',
        'base64': 'TEXT',
      },
      'numeric_edge_cases': <String, String>{
        'zero': 'INTEGER',
        'negative_zero': 'FLOAT64',
        'positive': 'FLOAT64',
        'negative': 'FLOAT64',
        'very_small': 'FLOAT64',
        'very_large': 'FLOAT64',
        'infinity': 'FLOAT64',
        'minus_infinity': 'FLOAT64',
        'nan': 'FLOAT64',
      },
      'null_handling': <String, String>{
        'null_int': 'INTEGER',
        'null_real': 'FLOAT64',
        'null_text': 'TEXT',
        'empty_vs_null': 'TEXT',
      },
      'enum_types': <String, String>{
        'status': 'TEXT',
        'priority': 'TEXT',
        'category': 'TEXT',
        'role': 'TEXT',
      },
    };

const List<GenericImportFixtureEntry> genericImportRoundTripFixtures =
    <GenericImportFixtureEntry>[
      GenericImportFixtureEntry(
        relativePath: 'test-data/text_seperated_values/customers_basic.csv',
        formatKey: ImportFormatKey.csv,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/text_seperated_values/customers_basic.csv.gz',
        formatKey: ImportFormatKey.csv,
        extractWrappedSource: true,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/text_seperated_values/products.tsv',
        formatKey: ImportFormatKey.tsv,
        options: GenericImportOptions(delimiter: '\t'),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/text_seperated_values/orders_pipe.psv',
        formatKey: ImportFormatKey.genericDelimited,
        options: GenericImportOptions(delimiter: '|'),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/01_basic_flat.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/02_mixed_types.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/02_sparse_objects.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/03_simple_nested.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/04_nested_arrays.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/05_complex_relational.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/06_large_array.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/07_large_dataset.ndjson',
        formatKey: ImportFormatKey.ndjson,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/08_wide_objects.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/09_foreign_keys.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/02_empty_object.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/events.ndjson',
        formatKey: ImportFormatKey.ndjson,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/json/nested_orders.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/01_basic_flat.xml',
        formatKey: ImportFormatKey.xml,
        expectedTableNames: <String>['employees'],
        expectedRowCountsByTable: <String, int>{'employees': 3},
        requiredColumnsByTable: <String, List<String>>{
          'employees': <String>['id', 'name', 'role'],
        },
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/02_attributes.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/03_edge_cases.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/03_empty.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/04_mixed_content.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/05_deeply_nested.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/06_namespaces.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/07_large_dataset.xml',
        formatKey: ImportFormatKey.xml,
        expectedTableNames: <String>['records'],
        expectedRowCountsByTable: <String, int>{'records': 10000},
        requiredColumnsByTable: <String, List<String>>{
          'records': <String>[
            'attr_id',
            'uuid',
            'value',
            'status',
            'metadata__source',
            'metadata__retry_count',
          ],
        },
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/08_wide_elements.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/09_cdata.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/xml/catalog.xml',
        formatKey: ImportFormatKey.xml,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/01_single_basic.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/02_empty_and_edge.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/03_large_table.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/04_wide_table.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/05_multiple_tables.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/06_complex_spans.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/07_no_headers_messy.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/08_nested_tables.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/09_data_types_test.html',
        formatKey: ImportFormatKey.htmlTable,
        expectedTableNames: _htmlDataTypesTestTableNames,
        expectedRowCountsByTable: _htmlDataTypesTestRowCounts,
        requiredColumnsByTable: <String, List<String>>{
          'basic_types': <String>[
            'date_col',
            'time_col',
            'datetime_col',
            'timestamp_col',
            'bool_col',
            'uuid_col',
          ],
          'bool_types': <String>[
            'bool_as_int',
            'bool_as_text',
            'bool_as_char',
            'bool_as_word',
          ],
          'datetime_types': <String>[
            'iso_date',
            'us_date',
            'eu_date',
            'unix_timestamp',
            'epoch_millis',
          ],
          'numeric_edge_cases': <String>[
            'zero',
            'negative_zero',
            'infinity',
            'minus_infinity',
            'nan',
          ],
          'null_handling': <String>['null_int', 'null_real', 'empty_vs_null'],
        },
        expectedColumnTypesByTable: _htmlDataTypesTestColumnTypes,
      ),
      GenericImportFixtureEntry(
        relativePath: 'test-data/html/report_tables.html',
        formatKey: ImportFormatKey.htmlTable,
      ),
    ];

const List<GenericInspectionFixtureEntry> genericInspectionFixtures =
    <GenericInspectionFixtureEntry>[
      GenericInspectionFixtureEntry(
        relativePath: 'test-data/json/02_empty_array.json',
        formatKey: ImportFormatKey.json,
        options: GenericImportOptions(
          structuredStrategy: StructuredImportStrategy.normalize,
        ),
        expectedTableCount: 0,
        expectedSelectedTableCount: 0,
      ),
    ];

const List<SqliteImportFixtureEntry> sqliteImportRoundTripFixtures =
    <SqliteImportFixtureEntry>[
      SqliteImportFixtureEntry(
        relativePath: 'test-data/sql_related/sample_app.sqlite',
      ),
      SqliteImportFixtureEntry(
        relativePath: 'test-data/sqlite/02_datatypes.sqlite',
      ),
      SqliteImportFixtureEntry(
        relativePath: 'test-data/sqlite/03_large_table.sqlite',
      ),
      SqliteImportFixtureEntry(
        relativePath: 'test-data/sqlite/04_many_tables.sqlite',
      ),
      SqliteImportFixtureEntry(
        relativePath: 'test-data/sqlite/05_wide_table.sqlite',
      ),
      SqliteImportFixtureEntry(
        relativePath: 'test-data/sqlite/06_complex_relations.sqlite',
      ),
      SqliteImportFixtureEntry(
        relativePath: 'test-data/sqlite/07_all_types_medium.sqlite',
        expectedTableNames: _allTypesMediumTableNames,
        expectedRowCountsByTable: _allTypesMediumRowCounts,
        expectedColumnTypesByTable: _allTypesMediumColumnTypes,
      ),
    ];

const List<SqliteInspectionFixtureEntry> sqliteInspectionFixtures =
    <SqliteInspectionFixtureEntry>[
      SqliteInspectionFixtureEntry(
        relativePath: 'test-data/sqlite/01_empty.sqlite',
        expectedDetectionWarningSubstrings: <String>[
          'header does not match the SQLite signature',
        ],
        expectedTableCount: 0,
      ),
    ];

const List<ExcelImportFixtureEntry>
excelImportRoundTripFixtures = <ExcelImportFixtureEntry>[
  ExcelImportFixtureEntry(relativePath: 'test-data/excel/basic_contacts.xlsx'),
  ExcelImportFixtureEntry(
    relativePath: 'test-data/excel/cross_sheet_calculations.xlsx',
  ),
  ExcelImportFixtureEntry(
    relativePath: 'test-data/excel/inventory_pricing_complex.xlsx',
  ),
  ExcelImportFixtureEntry(relativePath: 'test-data/excel/legacy_contacts.xls'),
  ExcelImportFixtureEntry(
    relativePath: 'test-data/excel/legacy_multi_sheet.xls',
  ),
  ExcelImportFixtureEntry(relativePath: 'test-data/excel/legacy_sales.xls'),
  ExcelImportFixtureEntry(relativePath: 'test-data/excel/sales_orders.xlsx'),
  ExcelImportFixtureEntry(
    relativePath: 'test-data/excel/sensor_timeseries.xlsx',
  ),
  ExcelImportFixtureEntry(
    relativePath: 'test-data/excel/wide_sparse_dataset.xlsx',
  ),
  ExcelImportFixtureEntry(
    relativePath: 'test-data/excel/workbook_formulas.xlsx',
  ),
  ExcelImportFixtureEntry(relativePath: 'test-data/excel/workbook_simple.xlsx'),
];

const List<SqlDumpImportFixtureEntry> sqlDumpImportRoundTripFixtures =
    <SqlDumpImportFixtureEntry>[
      SqlDumpImportFixtureEntry(
        relativePath: 'test-data/sql_related/schema_seed.sql',
      ),
      SqlDumpImportFixtureEntry(
        relativePath: 'test-data/sql_related/mysql_export.sql',
      ),
      SqlDumpImportFixtureEntry(
        relativePath: 'test-data/sql_related/mysql_export.sql.gz',
        extractWrappedSource: true,
      ),
      SqlDumpImportFixtureEntry(
        relativePath: 'test-data/sql_related/mariadb_export.sql',
      ),
      SqlDumpImportFixtureEntry(
        relativePath: 'test-data/sql_related/mariadb_export.sql.gz',
        extractWrappedSource: true,
      ),
      SqlDumpImportFixtureEntry(
        relativePath: 'test-data/sql_related/postgresql_plain_export.sql',
        requireSkippedStatements: true,
      ),
      SqlDumpImportFixtureEntry(
        relativePath: 'test-data/sql_related/postgresql_plain_export.sql.gz',
        extractWrappedSource: true,
        requireSkippedStatements: true,
      ),
    ];

const List<DetectionFixtureEntry> detectionFixtures = <DetectionFixtureEntry>[
  DetectionFixtureEntry(
    relativePath: 'test-data/text_seperated_values/employees_fixed_width.txt',
    expectedFormatKey: ImportFormatKey.genericDelimited,
    expectedSupportState: ImportSupportState.complete,
    expectedImplementationKind: ImportImplementationKind.genericWizard,
  ),
  DetectionFixtureEntry(
    relativePath: 'test-data/sql_related/mysql_mock_export.bak',
    expectedFormatKey: ImportFormatKey.unknown,
    expectedSupportState: ImportSupportState.notStarted,
    expectedImplementationKind: ImportImplementationKind.unknown,
  ),
  DetectionFixtureEntry(
    relativePath: 'test-data/sql_related/mariadb_mock_export.bak',
    expectedFormatKey: ImportFormatKey.unknown,
    expectedSupportState: ImportSupportState.notStarted,
    expectedImplementationKind: ImportImplementationKind.unknown,
  ),
  DetectionFixtureEntry(
    relativePath: 'test-data/sql_related/postgresql_mock_binary.dump',
    expectedFormatKey: ImportFormatKey.unknown,
    expectedSupportState: ImportSupportState.notStarted,
    expectedImplementationKind: ImportImplementationKind.unknown,
  ),
  DetectionFixtureEntry(
    relativePath: 'test-data/sql_related/postgresql_mock_custom.backup',
    expectedFormatKey: ImportFormatKey.unknown,
    expectedSupportState: ImportSupportState.notStarted,
    expectedImplementationKind: ImportImplementationKind.unknown,
  ),
];
