# Importing Data

Imports bring data from another file into a DecentDB database. The importer
guides you through the source file, destination table names, column names, and
type choices.

This page lists formats that this build can actually open or import. If a
format is not listed under supported sources, treat it as unsupported in the
app.

## Supported sources

- **DecentDB**: `.ddb` files open directly instead of going through import.
- **Clipboard Table**: explicit paste/import action for tabular clipboard text
  or HTML tables
- **CSV**: `.csv`
- **TSV**: `.tsv`
- **Generic Delimited Text**: `.txt`, `.dat`, `.log`, and `.psv`
- **Fixed-width Text**: `.fwf`, plus fixed-width-looking `.txt` and `.dat`
  files
- **JSON**: `.json`
- **NDJSON / JSONL**: `.ndjson` and `.jsonl`
- **JSON Log Stream**: `.jsonl`, `.ndjson`, and log-like `.log` files with
  per-line JSON objects
- **XML**: `.xml`
- **SpreadsheetML / Excel XML Spreadsheet**: `.xml` files with strict
  SpreadsheetML signatures
- **HTML Tables**: `.html` and `.htm`
- **Markdown Tables**: `.md` pipe tables
- **Excel (.xlsx)**: `.xlsx`
- **Excel (.xls)**: `.xls` through the legacy conversion path, which may show warnings
- **OpenDocument Spreadsheet**: `.ods`
- **SQLite**: `.db`, `.sqlite`, and `.sqlite3`
- **SQL Dump**: `.sql` files with common MySQL/MariaDB statements and
  PostgreSQL plain dump patterns including `COPY FROM stdin`
- **PostgreSQL Plain SQL Dump**: PostgreSQL dialect expansion for `.sql`
  plain dumps
- **Web and App Logs**: common Apache, Nginx, IIS W3C, and structured app log
  templates in `.log` or `.txt` files
- **Delimited Log File**: template-driven structured logs such as IIS W3C,
  Apache/Nginx access logs, and key=value app logs
- **HAR**: `.har` browser HTTP archive exports
- **ZIP Wrapper**: `.zip` archives when they contain a supported inner file
- **GZip Wrapper**: `.gz`, `.tgz`, and `.tar.gz` when they contain a supported inner file
- **BZip2 / Tar+BZip2 Wrapper**: `.bz2`, `.tbz2`, and `.tar.bz2` when they contain a supported inner file
- **XZ Wrapper**: `.xz`, `.txz`, and `.tar.xz` when they contain a
  supported inner file

You can start an import from the **Import** menu, toolbar import buttons, or drag and drop.

## Clipboard import

Use clipboard table import when you copied tabular data from a spreadsheet,
browser page, document, or terminal. Decent Bench only reads the clipboard after
you choose the import command. It never monitors clipboard contents
continuously, and HTML clipboard content is sanitized before preview.

## Delimited, fixed-width, JSON, XML, Markdown, and HTML import

Use the generic import wizard for delimited text, fixed-width text, structured
documents, Markdown pipe tables, and HTML tables. The wizard previews detected
tables, lets you rename columns and tables, and lets you override DecentDB
target types before import.

For delimited text, review the delimiter, header row, quoting, encoding, and
malformed-row behavior. For fixed-width text, review inferred column
boundaries. For JSON, NDJSON, XML, SpreadsheetML, Markdown, and HTML, review
how nested, repeated, or multi-table structure maps to DecentDB tables.

## Excel import

Use Excel import when a workbook is the source of truth. The wizard helps you choose the sheet and review column names before loading data.

Tips:

- Put headers in the first row when possible.
- Remove summary rows or notes before importing if they are not data.
- If a column mixes text and numbers, choose the type that preserves the values you care about.

## SQLite import

Use SQLite import when you already have a local database file. The wizard reads source tables and creates matching DecentDB tables.

This is useful when another app exports SQLite or when you want to move lightweight data into DecentDB.

## SQL dump import

Use SQL dump import for common MariaDB, MySQL, and PostgreSQL plain `.sql`
files. Decent Bench supports the practical table, insert, and PostgreSQL
`COPY FROM stdin` patterns used by many dumps, but a dump that uses advanced
server features may need cleanup first.

## Log and HAR import

Use log imports for JSON log streams, IIS W3C logs, common web access logs, and
simple app log templates. The importer preserves source fields where possible
and adds timestamp metadata when it can detect a timestamp reliably.

HAR imports split browser HTTP archives into conservative linked tables for
requests, timings, headers, and responses so large payload bodies are not
treated as first-class table data by default.

## Archive wrappers

Archive imports are wrappers, not data formats. Decent Bench inspects supported
archives and routes a selected inner file through the normal import flow. ZIP
Wrapper supports inner-file discovery. GZip Wrapper, BZip2 / Tar+BZip2 Wrapper,
and XZ / Tar+XZ Wrapper support single-file unwrap, plus tar archive inspection
when available. Huge single-file compressed inputs may be refused when bounded
decompression cannot be guaranteed.

## Column names and types

Before the final import, review:

- Table names
- Column names
- Type overrides
- Any warnings shown by the wizard

Choose clear names up front. It makes later SQL easier to write and easier to understand.

## After import

Open the **Quality** tab or use **Tools > Data Quality Dashboard** to profile
the imported tables, review import reconciliation counts, and run validation
rules. The default quality profile is generated from schema metadata, so you can
run a useful check immediately without creating custom rules first.

Successful import summaries include **Run Quality Profile**. Use it when you
want Decent Bench to open the imported database and start the default/current
quality profile immediately after import.

## Imports should not freeze the app

Large imports run as background work. You should still be able to see progress and cancel when cancellation is available.

## Not Supported

These source types are not supported as native imports in this build. Use an
external tool to convert them to a supported file type such as CSV, TSV, JSON,
NDJSON, XML, HTML tables, Excel, SQLite, or SQL dump before importing.

- **RAR, CAB, DMG, ISO, and ZPAQ archives**: these are not planned as native
  data import wrappers because of licensing, platform, or low tabular-data
  value.
- **Arbitrary TOML, INI, properties, JSON5, RDS, and RData object files**:
  these are usually configuration files or arbitrary object graphs rather than
  clear tabular sources.
- **Direct mainframe database stores such as VSAM, IMS, IDMS, Adabas, and
  MultiValue/PICK**: use a migration/export tool to create CSV, fixed-width,
  SQL, or SQLite files first.
- **Full media, CAD, disk-image, raster, and 3D geometry content**: Decent Bench
  is not a media, CAD, or raster processing tool. Future metadata-only import
  may be considered for specific formats, but full content import is not
  planned.
- **Direct parsing of proprietary database/application files that require vendor
  runtimes**: export from the source application or use vendor tooling to create
  a supported intermediate file.

Live database connection import is not available in this build. Use file-based
exports as the practical bridge until read-only source import is implemented.
