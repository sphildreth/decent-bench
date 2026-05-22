# Import Formats

This document mirrors the code-level import registry in
`apps/decent-bench/lib/features/import/infrastructure/import_format_registry.dart`.
It summarizes what the current build can import now, what is only partially
supported, and what is recognized but not implemented yet.

## Fully implemented now

- DecentDB `.ddb` open path
- CSV
- TSV
- generic delimited text (`.txt`, `.dat`, `.log`, `.psv`)
- JSON
- NDJSON / JSONL
- XML
- HTML tables (`.html`, `.htm`)
- ZIP wrapper routing to supported inner files
- GZip wrapper routing to supported inner files (`.gz`, `.tgz`, `.tar.gz`)
- BZip2 wrapper routing to supported inner files (`.bz2`, `.tbz2`, `.tar.bz2`)
- Excel `.xlsx` via the existing workbook wizard
- SQLite via the existing SQLite wizard
- SQL dump via the existing MVP-lite SQL dump wizard
- Row-local generic-import transforms for filters, defaults, computed columns,
  column ordering, and deduplication

## Partial support now

- Excel `.xls`
  - routed through the existing Excel import path
  - relies on the current conversion/normalization contract and surfaces
    warnings when the runtime conversion path is required

## Recognized but not implemented yet

- fixed-width text
- OpenDocument Spreadsheet (`.ods`)
- YAML / YML
- TOML
- Markdown tables
- DuckDB
- Microsoft Access (`.mdb`, `.accdb`)
- DBF / FoxPro
- MS SQL Server backup (`.bak`)
- broader PostgreSQL plain SQL dump handling
- Parquet
- XZ wrapper formats
- clipboard table capture
- PDF table extraction

## Notes on the current architecture

- `ImportFormatRegistry` is the source of truth for family, support state, and
  implementation path.
- `ImportDetectionService` is used for drag-and-drop, `--import`, and the file
  picker entry flow.
- Delimited text, structured documents, and HTML tables use the generic
  preview/execution pipeline. Wrappers extract a supported inner file and then
  route that file to the normal generic or dedicated import path.
- Generic imports carry a serializable transform plan for row filters, default
  values, computed columns, deduplication, and column ordering.
- Excel, SQLite, and SQL dump still use the existing dedicated wizards and
  background workers, but are now routed through the shared detector.

## Next recommended formats

The next most valuable additions after this slice are:

1. fixed-width text
2. ODS
3. Parquet
4. DuckDB
5. PostgreSQL plain SQL dump expansion
