import '../domain/import_module_manifest.dart';
import 'import_module_catalog.dart';

final ImportModuleCatalog builtinImportModuleCatalog = ImportModuleCatalog(
  builtinImportModules,
);

final List<ImportModuleManifest> builtinImportModules = <ImportModuleManifest>[
  _module(
    id: 'decentdb',
    legacyFormatKey: 'decentDb',
    kind: ImportModuleKind.directOpen,
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'DecentDB',
    family: ImportModuleFamily.database,
    summary: 'Open an existing DecentDB workspace directly.',
    description: 'Direct-open module for existing `.ddb` files.',
    extensions: <String>['.ddb'],
    implementation: ImportModuleImplementation.directOpen,
    adapterId: 'direct_open_decentdb',
    adapterKind: ImportModuleAdapterKind.dartBuiltin,
    capabilities: _capabilities(importFull: true),
    actions: _actions(<String>['open_database']),
  ),
  _module(
    id: 'csv',
    legacyFormatKey: 'csv',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'CSV',
    family: ImportModuleFamily.delimitedText,
    summary: 'Delimited text import with comma defaults.',
    description:
        'Delimited text import with header, delimiter, quoting, preview, '
        'transforms, and type overrides.',
    extensions: <String>['.csv'],
    implementation: ImportModuleImplementation.genericWizard,
    adapterId: 'generic_delimited',
    adapterKind: ImportModuleAdapterKind.dartGeneric,
    capabilities: _genericSingleTableCapabilities,
    options: _delimitedOptions(delimiter: ','),
    typeMappings: _sampledTextTypeMappings,
  ),
  _module(
    id: 'tsv',
    legacyFormatKey: 'tsv',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'TSV',
    family: ImportModuleFamily.delimitedText,
    summary: 'Tab-delimited text import.',
    description: 'Tab-delimited import using the generic text pipeline.',
    extensions: <String>['.tsv'],
    implementation: ImportModuleImplementation.genericWizard,
    adapterId: 'generic_delimited',
    adapterKind: ImportModuleAdapterKind.dartGeneric,
    capabilities: _genericSingleTableCapabilities,
    options: _delimitedOptions(delimiter: '\t'),
    typeMappings: _sampledTextTypeMappings,
  ),
  _module(
    id: 'generic_delimited',
    legacyFormatKey: 'genericDelimited',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'Generic Delimited Text',
    family: ImportModuleFamily.delimitedText,
    summary: 'Custom-delimited text import.',
    description: 'Custom-delimited import for CSV-like text exports and logs.',
    extensions: <String>['.txt', '.dat', '.log', '.psv'],
    implementation: ImportModuleImplementation.genericWizard,
    adapterId: 'generic_delimited',
    adapterKind: ImportModuleAdapterKind.dartGeneric,
    note: 'Use delimiter and malformed-row options to adapt messy exports.',
    capabilities: _genericSingleTableCapabilities,
    options: _delimitedOptions(delimiter: ','),
    typeMappings: _sampledTextTypeMappings,
  ),
  _module(
    id: 'fixed_width',
    legacyFormatKey: 'fixedWidth',
    status: ImportModuleStatus.planned,
    priority: ImportModulePriority.p1,
    name: 'Fixed-width Text',
    family: ImportModuleFamily.delimitedText,
    summary: 'Legacy fixed-width line parsing.',
    description: 'Planned importer for fixed-width text records.',
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    note: 'Recognized in the roadmap, but not implemented yet.',
    limitations: _unavailableLimitations(
      'fixed_width.not_implemented',
      'Column-boundary editing is not implemented yet.',
    ),
  ),
  _module(
    id: 'xlsx',
    legacyFormatKey: 'xlsx',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'Excel (.xlsx)',
    family: ImportModuleFamily.spreadsheet,
    summary: 'Excel workbook import.',
    description:
        'Existing Excel import wizard with sheet selection and transforms.',
    extensions: <String>['.xlsx'],
    implementation: ImportModuleImplementation.dedicatedWizard,
    adapterId: 'legacy_excel',
    adapterKind: ImportModuleAdapterKind.legacyWizard,
    capabilities: _multiTableCapabilities,
  ),
  _module(
    id: 'xls',
    legacyFormatKey: 'xls',
    status: ImportModuleStatus.partial,
    priority: ImportModulePriority.p1,
    name: 'Excel (.xls)',
    family: ImportModuleFamily.spreadsheet,
    summary: 'Legacy Excel workbook import.',
    description: 'Legacy Excel import using the existing workbook path.',
    extensions: <String>['.xls'],
    implementation: ImportModuleImplementation.dedicatedWizard,
    adapterId: 'legacy_excel',
    adapterKind: ImportModuleAdapterKind.legacyWizard,
    note:
        'Legacy workbooks depend on the current conversion/normalization '
        'path and surface warnings.',
    capabilities: _multiTableCapabilities,
    limitations: _unavailableLimitations(
      'xls.legacy_conversion',
      'Legacy workbook conversion can surface runtime warnings.',
    ),
  ),
  _module(
    id: 'ods',
    legacyFormatKey: 'ods',
    status: ImportModuleStatus.planned,
    priority: ImportModulePriority.p1,
    name: 'OpenDocument Spreadsheet',
    family: ImportModuleFamily.spreadsheet,
    summary: 'LibreOffice/OpenOffice spreadsheet import.',
    description: 'Planned importer for `.ods` workbooks.',
    extensions: <String>['.ods'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'ods.not_implemented',
      'ODS workbook parsing has not been implemented yet.',
    ),
  ),
  _module(
    id: 'json',
    legacyFormatKey: 'json',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'JSON',
    family: ImportModuleFamily.structuredDocument,
    summary: 'Structured JSON import.',
    description: 'Structured JSON import with flatten or normalize strategies.',
    extensions: <String>['.json'],
    implementation: ImportModuleImplementation.genericWizard,
    adapterId: 'generic_structured',
    adapterKind: ImportModuleAdapterKind.dartGeneric,
    capabilities: _genericStructuredCapabilities,
    options: _structuredOptions(defaultStrategy: 'normalize'),
    typeMappings: _structuredTypeMappings,
  ),
  _module(
    id: 'ndjson',
    legacyFormatKey: 'ndjson',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'NDJSON / JSONL',
    family: ImportModuleFamily.structuredDocument,
    summary: 'Line-oriented JSON import.',
    description:
        'Line-oriented JSON import with schema drift handling and '
        'relational preview.',
    extensions: <String>['.ndjson', '.jsonl'],
    implementation: ImportModuleImplementation.genericWizard,
    adapterId: 'generic_structured',
    adapterKind: ImportModuleAdapterKind.dartGeneric,
    capabilities: _genericStructuredCapabilities,
    options: _structuredOptions(defaultStrategy: 'flatten'),
    typeMappings: _structuredTypeMappings,
  ),
  _module(
    id: 'xml',
    legacyFormatKey: 'xml',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'XML',
    family: ImportModuleFamily.structuredDocument,
    summary: 'Structured XML import.',
    description:
        'XML import with flatten or parent-child normalization strategies.',
    extensions: <String>['.xml'],
    implementation: ImportModuleImplementation.genericWizard,
    adapterId: 'generic_structured',
    adapterKind: ImportModuleAdapterKind.dartGeneric,
    capabilities: _genericStructuredCapabilities,
    options: _structuredOptions(defaultStrategy: 'flatten'),
    typeMappings: _structuredTypeMappings,
  ),
  _module(
    id: 'yaml',
    legacyFormatKey: 'yaml',
    status: ImportModuleStatus.investigate,
    priority: ImportModulePriority.p2,
    name: 'YAML',
    family: ImportModuleFamily.structuredDocument,
    summary: 'Structured YAML import.',
    description: 'Investigate YAML import for record-oriented documents.',
    extensions: <String>['.yaml', '.yml'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'yaml.not_implemented',
      'YAML parsing is not implemented and arbitrary config is not '
          'always tabular.',
    ),
  ),
  _module(
    id: 'toml',
    legacyFormatKey: 'toml',
    status: ImportModuleStatus.deferred,
    priority: ImportModulePriority.p3,
    name: 'TOML',
    family: ImportModuleFamily.structuredDocument,
    summary: 'Config-oriented TOML import.',
    description: 'Deferred TOML import for key/value or record data.',
    extensions: <String>['.toml'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'toml.low_tabular_fit',
      'TOML usually represents configuration rather than row sets.',
    ),
  ),
  _module(
    id: 'html_table',
    legacyFormatKey: 'htmlTable',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'HTML Tables',
    family: ImportModuleFamily.webMarkup,
    summary: 'HTML table extraction.',
    description:
        'HTML table extraction with table selection, header inference, '
        'and metadata hints.',
    extensions: <String>['.html', '.htm'],
    implementation: ImportModuleImplementation.genericWizard,
    adapterId: 'generic_html_table',
    adapterKind: ImportModuleAdapterKind.dartGeneric,
    capabilities: _genericStructuredCapabilities,
    options: _htmlOptions,
    typeMappings: _sampledTextTypeMappings,
  ),
  _module(
    id: 'markdown_table',
    legacyFormatKey: 'markdownTable',
    status: ImportModuleStatus.investigate,
    priority: ImportModulePriority.p2,
    name: 'Markdown Tables',
    family: ImportModuleFamily.webMarkup,
    summary: 'Markdown table import.',
    description: 'Investigate Markdown table extraction from `.md` files.',
    extensions: <String>['.md'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'markdown_table.not_implemented',
      'Markdown table parsing is not implemented yet.',
    ),
  ),
  _module(
    id: 'sqlite',
    legacyFormatKey: 'sqlite',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'SQLite',
    family: ImportModuleFamily.database,
    summary: 'SQLite database import.',
    description: 'Existing SQLite import wizard and background worker path.',
    extensions: <String>['.db', '.sqlite', '.sqlite3'],
    implementation: ImportModuleImplementation.dedicatedWizard,
    adapterId: 'legacy_sqlite',
    adapterKind: ImportModuleAdapterKind.legacyWizard,
    capabilities: _multiTableCapabilities,
    typeMappings: _databaseTypeMappings,
    checks: <ImportModuleCheck>[
      const ImportModuleCheck(
        id: 'sqlite.signature',
        name: 'SQLite Signature',
        description:
            'Warn when a SQLite-like extension does not have the SQLite header.',
        defaultEnabled: true,
      ),
    ],
  ),
  _module(
    id: 'duckdb',
    legacyFormatKey: 'duckdb',
    status: ImportModuleStatus.planned,
    priority: ImportModulePriority.p1,
    name: 'DuckDB',
    family: ImportModuleFamily.database,
    summary: 'DuckDB file import.',
    description: 'Planned DuckDB file importer.',
    extensions: <String>['.duckdb'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'duckdb.not_implemented',
      'DuckDB file reading and type mapping are not implemented yet.',
    ),
  ),
  _module(
    id: 'access',
    legacyFormatKey: 'access',
    status: ImportModuleStatus.investigate,
    priority: ImportModulePriority.p2,
    name: 'Microsoft Access',
    family: ImportModuleFamily.legacyBusiness,
    summary: 'Access database import.',
    description: 'Investigate Access database import.',
    extensions: <String>['.mdb', '.accdb'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'access.driver_dependency',
      'Cross-platform Access drivers and licensing need review.',
    ),
  ),
  _module(
    id: 'dbf',
    legacyFormatKey: 'dbf',
    status: ImportModuleStatus.investigate,
    priority: ImportModulePriority.p2,
    name: 'DBF / FoxPro',
    family: ImportModuleFamily.legacyBusiness,
    summary: 'Legacy DBF database import.',
    description: 'Investigate DBF/FoxPro import.',
    extensions: <String>['.dbf'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'dbf.encoding_memo_review',
      'Code page, memo-file, and deleted-row handling need review.',
    ),
  ),
  _module(
    id: 'ms_sql_bak',
    legacyFormatKey: 'msSqlBak',
    status: ImportModuleStatus.investigate,
    priority: ImportModulePriority.p2,
    name: 'MS SQL Server Backup',
    family: ImportModuleFamily.databaseDump,
    summary: 'Container-assisted SQL Server backup import.',
    description:
        'Container-assisted MS SQL backup import is recognized but not '
        'implemented.',
    extensions: <String>['.bak'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'ms_sql_bak.container_dependency',
      'SQL Server restore tooling and licensing need review.',
    ),
  ),
  _module(
    id: 'sql_dump',
    legacyFormatKey: 'sqlDump',
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'SQL Dump',
    family: ImportModuleFamily.databaseDump,
    summary: 'MVP-lite SQL dump import.',
    description: 'Existing SQL dump wizard for the MVP-lite parser scope.',
    extensions: <String>['.sql'],
    implementation: ImportModuleImplementation.dedicatedWizard,
    adapterId: 'legacy_sql_dump',
    adapterKind: ImportModuleAdapterKind.legacyWizard,
    capabilities: _multiTableCapabilities,
    typeMappings: _databaseTypeMappings,
  ),
  _module(
    id: 'postgres_plain_dump',
    legacyFormatKey: 'postgresPlainDump',
    status: ImportModuleStatus.planned,
    priority: ImportModulePriority.p1,
    name: 'PostgreSQL Plain SQL Dump',
    family: ImportModuleFamily.databaseDump,
    summary: 'PostgreSQL plain dump expansion.',
    description: 'Broader plain SQL dump import beyond current MVP-lite scope.',
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'postgres_plain_dump.copy_not_implemented',
      'PostgreSQL COPY and dialect expansion are not implemented yet.',
    ),
  ),
  _module(
    id: 'parquet',
    legacyFormatKey: 'parquet',
    status: ImportModuleStatus.planned,
    priority: ImportModulePriority.p1,
    name: 'Parquet',
    family: ImportModuleFamily.analytical,
    summary: 'Columnar Parquet import.',
    description: 'Planned columnar Parquet import.',
    extensions: <String>['.parquet'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'parquet.reader_dependency',
      'An Apache-compatible Parquet reader decision is required.',
    ),
  ),
  _module(
    id: 'json_log_stream',
    legacyFormatKey: 'jsonLogStream',
    status: ImportModuleStatus.planned,
    priority: ImportModulePriority.p1,
    name: 'JSON Log Stream',
    family: ImportModuleFamily.logsEvents,
    summary: 'Operational log ingestion built on NDJSON support.',
    description: 'Planned log-focused workflow over JSON line streams.',
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'json_log_stream.template_not_implemented',
      'Timestamp extraction and log templates are not implemented yet.',
    ),
  ),
  _module(
    id: 'delimited_log',
    legacyFormatKey: 'delimitedLog',
    status: ImportModuleStatus.investigate,
    priority: ImportModulePriority.p2,
    name: 'Delimited Log File',
    family: ImportModuleFamily.logsEvents,
    summary: 'Template-based delimited log import.',
    description: 'Investigate delimited log templates.',
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'delimited_log.template_not_implemented',
      'Template parsing and timestamp rules are not implemented yet.',
    ),
  ),
  _module(
    id: 'zip_archive',
    legacyFormatKey: 'zipArchive',
    kind: ImportModuleKind.wrapper,
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'ZIP Wrapper',
    family: ImportModuleFamily.compressedArchive,
    summary: 'ZIP archive wrapper.',
    description:
        'Archive wrapper that discovers supported inner files and routes '
        'them into the normal import flow.',
    extensions: <String>['.zip'],
    implementation: ImportModuleImplementation.wrapper,
    adapterId: 'zip_wrapper',
    adapterKind: ImportModuleAdapterKind.wrapper,
    capabilities: _wrapperCapabilities,
    actions: _actions(<String>['inspect_archive', 'extract_inner_source']),
  ),
  _module(
    id: 'gzip_archive',
    legacyFormatKey: 'gzipArchive',
    kind: ImportModuleKind.wrapper,
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'GZip Wrapper',
    family: ImportModuleFamily.compressedArchive,
    summary: 'GZip and tar+gzip wrapper.',
    description:
        'Single-file wrapper that unwraps supported CSV/JSON/NDJSON/XML/'
        'HTML/SQL/Excel/SQLite files.',
    extensions: <String>['.tar.gz', '.gz', '.tgz'],
    implementation: ImportModuleImplementation.wrapper,
    adapterId: 'gzip_wrapper',
    adapterKind: ImportModuleAdapterKind.wrapper,
    capabilities: _wrapperCapabilities,
    actions: _actions(<String>['inspect_archive', 'extract_inner_source']),
  ),
  _module(
    id: 'bzip2_archive',
    legacyFormatKey: 'bzip2Archive',
    kind: ImportModuleKind.wrapper,
    status: ImportModuleStatus.complete,
    priority: ImportModulePriority.p0,
    name: 'BZip2 / Tar+BZip2 Wrapper',
    family: ImportModuleFamily.compressedArchive,
    summary: 'BZip2 and tar+bzip2 wrapper.',
    description:
        'BZip2 wrapper for single-file decompression and tar+bzip2 '
        'archive extraction.',
    extensions: <String>['.tar.bz2', '.bz2', '.tbz2'],
    implementation: ImportModuleImplementation.wrapper,
    adapterId: 'bzip2_wrapper',
    adapterKind: ImportModuleAdapterKind.wrapper,
    capabilities: _wrapperCapabilities,
    actions: _actions(<String>['inspect_archive', 'extract_inner_source']),
  ),
  _module(
    id: 'xz_archive',
    legacyFormatKey: 'xzArchive',
    kind: ImportModuleKind.wrapper,
    status: ImportModuleStatus.investigate,
    priority: ImportModulePriority.p2,
    name: 'XZ Wrapper',
    family: ImportModuleFamily.compressedArchive,
    summary: 'XZ compressed wrapper support.',
    description: 'Investigate XZ and tar+xz wrapper support.',
    extensions: <String>['.tar.xz', '.xz'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'xz_archive.not_implemented',
      'Cross-platform XZ extraction is not implemented yet.',
    ),
  ),
  _module(
    id: 'clipboard_table',
    legacyFormatKey: 'clipboardTable',
    status: ImportModuleStatus.investigate,
    priority: ImportModulePriority.p1,
    name: 'Clipboard Table',
    family: ImportModuleFamily.webMarkup,
    summary: 'Clipboard HTML/pasted table capture.',
    description: 'Investigate pasted table import.',
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'clipboard_table.not_implemented',
      'Clipboard capture is not implemented yet.',
    ),
  ),
  _module(
    id: 'pdf_tables',
    legacyFormatKey: 'pdfTables',
    status: ImportModuleStatus.deferred,
    priority: ImportModulePriority.p3,
    name: 'PDF Tables',
    family: ImportModuleFamily.webMarkup,
    summary: 'PDF table extraction.',
    description: 'Deferred PDF table extraction.',
    extensions: <String>['.pdf'],
    implementation: ImportModuleImplementation.recognizedUnsupported,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    limitations: _unavailableLimitations(
      'pdf_tables.quality_deferred',
      'PDF extraction quality and correction UX are not good enough yet.',
    ),
  ),
  _module(
    id: 'unknown',
    legacyFormatKey: 'unknown',
    status: ImportModuleStatus.notStarted,
    priority: ImportModulePriority.none,
    name: 'Unknown',
    family: ImportModuleFamily.other,
    summary: 'Unknown or unsupported source.',
    description: 'Fallback module for unknown or unsupported sources.',
    implementation: ImportModuleImplementation.unknown,
    adapterId: 'none',
    adapterKind: ImportModuleAdapterKind.none,
    actions: _actions(<String>['show_unknown_source_message']),
  ),
];

const ImportModuleCapabilities _genericSingleTableCapabilities =
    ImportModuleCapabilities(
      inspectSchema: true,
      previewRows: true,
      importFull: true,
      supportsCancellation: true,
      supportsRejectedRows: true,
      canExportRecipe: true,
    );

const ImportModuleCapabilities _genericStructuredCapabilities =
    ImportModuleCapabilities(
      inspectSchema: true,
      previewRows: true,
      importFull: true,
      supportsMultipleTables: true,
      supportsCancellation: true,
      supportsRejectedRows: true,
      canExportRecipe: true,
    );

const ImportModuleCapabilities _multiTableCapabilities =
    ImportModuleCapabilities(
      inspectSchema: true,
      previewRows: true,
      importFull: true,
      importSelectedTables: true,
      supportsMultipleTables: true,
      supportsCancellation: true,
      preservesLogicalTypes: true,
      canExportRecipe: true,
    );

const ImportModuleCapabilities _wrapperCapabilities = ImportModuleCapabilities(
  inspectSchema: true,
  previewRows: false,
  importFull: false,
  supportsArchives: true,
  supportsCancellation: true,
);

ImportModuleCapabilities _capabilities({bool importFull = false}) {
  return ImportModuleCapabilities(importFull: importFull);
}

List<ImportModuleOption> _delimitedOptions({required String delimiter}) {
  return <ImportModuleOption>[
    const ImportModuleOption(
      id: 'header_row',
      label: 'Header Row',
      type: ImportModuleOptionType.boolean,
      defaultValue: true,
      required: true,
    ),
    ImportModuleOption(
      id: 'delimiter',
      label: 'Delimiter',
      type: ImportModuleOptionType.string,
      defaultValue: delimiter,
      required: true,
    ),
    const ImportModuleOption(
      id: 'quote_character',
      label: 'Quote Character',
      type: ImportModuleOptionType.string,
      defaultValue: '"',
      required: true,
    ),
    const ImportModuleOption(
      id: 'escape_character',
      label: 'Escape Character',
      type: ImportModuleOptionType.string,
      defaultValue: '"',
      required: true,
    ),
    const ImportModuleOption(
      id: 'encoding',
      label: 'Encoding',
      type: ImportModuleOptionType.enumeration,
      defaultValue: 'auto',
      allowedValues: <String>['auto', 'utf8', 'latin1'],
      required: true,
    ),
    const ImportModuleOption(
      id: 'malformed_row_strategy',
      label: 'Malformed Row Strategy',
      type: ImportModuleOptionType.enumeration,
      defaultValue: 'padOrTruncate',
      allowedValues: <String>['padOrTruncate', 'skipRow'],
      required: true,
    ),
  ];
}

List<ImportModuleOption> _structuredOptions({required String defaultStrategy}) {
  return <ImportModuleOption>[
    ImportModuleOption(
      id: 'structured_strategy',
      label: 'Structured Mapping Strategy',
      type: ImportModuleOptionType.enumeration,
      defaultValue: defaultStrategy,
      allowedValues: const <String>['flatten', 'normalize'],
      required: true,
    ),
  ];
}

const List<ImportModuleOption> _htmlOptions = <ImportModuleOption>[
  ImportModuleOption(
    id: 'preserve_html_metadata',
    label: 'Preserve HTML Metadata',
    type: ImportModuleOptionType.boolean,
    defaultValue: true,
    required: true,
  ),
];

const List<ImportModuleTypeMapping> _sampledTextTypeMappings =
    <ImportModuleTypeMapping>[
      ImportModuleTypeMapping(
        sourceType: 'text',
        targetType: 'TEXT/INTEGER/REAL/BOOLEAN/DATE/TIMESTAMP',
        fidelity: ImportModuleTypeFidelity.coerced,
        notes:
            'Text files do not carry native types; DecentDB types are inferred '
            'from samples and can be overridden.',
      ),
    ];

const List<ImportModuleTypeMapping> _structuredTypeMappings =
    <ImportModuleTypeMapping>[
      ImportModuleTypeMapping(
        sourceType: 'json_xml_scalar',
        targetType: 'TEXT/INTEGER/REAL/BOOLEAN/DATE/TIMESTAMP',
        fidelity: ImportModuleTypeFidelity.coerced,
        notes:
            'Structured scalars are inferred from sampled values and can be '
            'flattened or normalized into DecentDB tables.',
      ),
    ];

const List<ImportModuleTypeMapping> _databaseTypeMappings =
    <ImportModuleTypeMapping>[
      ImportModuleTypeMapping(
        sourceType: 'database_column',
        targetType: 'DecentDB column type',
        fidelity: ImportModuleTypeFidelity.losslessWithMetadata,
        notes:
            'Database import paths map source column declarations into '
            'DecentDB-compatible target types and retain import metadata.',
      ),
    ];

List<ImportModuleAction> _actions(List<String> ids) {
  return <ImportModuleAction>[
    for (final id in ids)
      ImportModuleAction(id: id, label: _labelForAction(id), required: true),
  ];
}

List<ImportModuleLimitation> _unavailableLimitations(
  String id,
  String message,
) {
  return <ImportModuleLimitation>[
    ImportModuleLimitation(id: id, severity: 'info', message: message),
  ];
}

ImportModuleManifest _module({
  required String id,
  required String legacyFormatKey,
  ImportModuleKind kind = ImportModuleKind.source,
  required ImportModuleStatus status,
  required ImportModulePriority priority,
  required String name,
  required ImportModuleFamily family,
  required String summary,
  required String description,
  List<String> extensions = const <String>[],
  required ImportModuleImplementation implementation,
  required String adapterId,
  required ImportModuleAdapterKind adapterKind,
  String? note,
  ImportModuleCapabilities capabilities = const ImportModuleCapabilities(),
  List<ImportModuleOption> options = const <ImportModuleOption>[],
  List<ImportModuleAction>? actions,
  List<ImportModuleTypeMapping> typeMappings =
      const <ImportModuleTypeMapping>[],
  List<ImportModuleCheck> checks = const <ImportModuleCheck>[],
  List<ImportModuleLimitation> limitations = const <ImportModuleLimitation>[],
}) {
  return ImportModuleManifest(
    schemaVersion: 1,
    id: id,
    kind: kind,
    status: status,
    priority: priority,
    legacyFormatKey: legacyFormatKey,
    name: name,
    family: family,
    summary: summary,
    description: description,
    note: note,
    detection: ImportModuleDetection(
      extensions: extensions,
      priority: _detectionPriorityFor(status, implementation),
    ),
    support: ImportModuleSupport(implementation: implementation),
    capabilities: capabilities,
    adapter: ImportModuleAdapterRef(
      id: adapterId,
      kind: adapterKind,
      protocol: 'dart_import_adapter_v1',
    ),
    actions:
        actions ?? _actions(_defaultActionIdsFor(implementation, adapterKind)),
    options: options,
    typeMappings: typeMappings,
    checks: checks,
    limitations: limitations,
    documentation: const ImportModuleDocumentation(
      helpTopic: 'importing-data',
      formatDocs: 'README.md',
      fixtureNotes: 'fixtures/README.md',
    ),
    fixtures: <ImportModuleFixture>[
      ImportModuleFixture(
        id: '${id}_smoke',
        path: 'fixtures/README.md',
        purpose: 'Module fixture contract and generation notes.',
        expectedTables: const <String>[],
        expectedWarnings: const <String>[],
        generated: true,
      ),
    ],
  );
}

List<String> _defaultActionIdsFor(
  ImportModuleImplementation implementation,
  ImportModuleAdapterKind adapterKind,
) {
  if (adapterKind == ImportModuleAdapterKind.wrapper) {
    return <String>['inspect_archive', 'extract_inner_source'];
  }
  return switch (implementation) {
    ImportModuleImplementation.directOpen => <String>['open_database'],
    ImportModuleImplementation.genericWizard => <String>[
      'inspect_schema',
      'preview_rows',
      'import_full',
    ],
    ImportModuleImplementation.dedicatedWizard => <String>[
      'inspect_schema',
      'preview_rows',
      'import_selected_tables',
    ],
    ImportModuleImplementation.wrapper => <String>[
      'inspect_archive',
      'extract_inner_source',
    ],
    ImportModuleImplementation.recognizedUnsupported => <String>[
      'recognize_source',
    ],
    ImportModuleImplementation.workerBacked => <String>[
      'inspect_schema',
      'preview_rows',
      'import_full',
    ],
    ImportModuleImplementation.unknown => <String>[
      'show_unknown_source_message',
    ],
  };
}

int _detectionPriorityFor(
  ImportModuleStatus status,
  ImportModuleImplementation implementation,
) {
  if (implementation == ImportModuleImplementation.unknown) {
    return -1;
  }
  return switch (status) {
    ImportModuleStatus.complete => 100,
    ImportModuleStatus.partial => 90,
    ImportModuleStatus.planned => 60,
    ImportModuleStatus.investigate => 40,
    ImportModuleStatus.deferred => 20,
    ImportModuleStatus.candidate => 10,
    ImportModuleStatus.notStarted => 0,
  };
}

String _labelForAction(String id) {
  return switch (id) {
    'open_database' => 'Open Database',
    'inspect_schema' => 'Inspect Source',
    'preview_rows' => 'Preview Rows',
    'import_full' => 'Import',
    'import_selected_tables' => 'Import Selected Tables',
    'inspect_archive' => 'Inspect Archive',
    'extract_inner_source' => 'Extract Inner Source',
    'recognize_source' => 'Recognize Source',
    'show_unknown_source_message' => 'Show Unknown Source Message',
    _ => id,
  };
}
