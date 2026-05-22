# Import Formats

The implemented and partial sections mirror the code-level import registry in
`apps/decent-bench/lib/features/import/infrastructure/import_format_registry.dart`.
The future table combines registry-recognized unavailable formats with broader
candidate formats that are worth tracking for future import work.

Future import-format expansion is planned in
`design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`.

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

Priority is ranked by broad expected user value, with lower numbers meaning
higher priority. `Registry` means the current `ImportFormatRegistry` already
has an explicit format key or extension entry. Rows without registry coverage
are future candidates that should be added to the registry only when accepted
for implementation.

Status values:

- `Planned`: accepted as a likely roadmap format, pending implementation.
- `Investigate`: worth evaluating, but dependency quality, user demand, or
  import semantics are not clear enough yet.
- `Deferred`: intentionally postponed until quality, dependency, or product fit
  improves.
- `Candidate`: not yet accepted into the registry, but worth tracking as a
  future request class.

| Priority | Status | Registry | Format / Source | Extensions / Source | Import Considerations |
|---:|---|---|---|---|---|
| 1 | Planned | Yes | Parquet | `.parquet` | High-value analytics format; needs Apache-compatible reader, nested type mapping, and large-file streaming/chunking. |
| 2 | Planned | Yes | OpenDocument Spreadsheet | `.ods` | Common LibreOffice/OpenOffice spreadsheet source; needs multi-sheet preview, formula policy, and type inference. |
| 3 | Planned | Yes | Fixed-width text | usually `.txt`, `.dat` | Common in banking, payroll, government, and batch exports; needs column-boundary editor and malformed-row handling. |
| 4 | Planned | Yes | DuckDB | `.duckdb` | Strong local analytics overlap; needs table selection, type mapping, and dependency/packaging decision. |
| 5 | Planned | Yes | PostgreSQL plain SQL dump expansion | `.sql` | Extend current SQL dump support to common `pg_dump --format=plain` output, especially `COPY FROM stdin`. |
| 6 | Investigate | Yes | Clipboard table capture | clipboard TSV/CSV/HTML | Very high workflow value; needs explicit user action, HTML sanitization, size limits, and no continuous clipboard monitoring. |
| 7 | Candidate | No | Apache Avro | `.avro`, `.avsc` | Common streaming/data-platform interchange; needs schema handling, logical type mapping, and dependency review. |
| 8 | Investigate | No | Apache Arrow IPC | `.arrow`, `.ipc` | Strong typed columnar interchange; useful if a maintained Dart/FFI path exists. |
| 9 | Investigate | No | Feather | `.feather` | Common Python/R data science interchange built around Arrow; likely shares Arrow dependency decisions. |
| 10 | Investigate | No | GeoPackage | `.gpkg` | SQLite-based GIS container; valuable if DecentDB spatial workflows grow. Needs spatial metadata and geometry mapping. |
| 11 | Investigate | No | Shapefile bundle | `.shp`, `.shx`, `.dbf`, `.prj` | Common GIS legacy format; requires multi-file bundle handling, projection metadata, and geometry conversion. |
| 12 | Investigate | No | GeoJSON | `.geojson` | Common web/GIS spatial interchange; can build on JSON parsing plus spatial type mapping. |
| 13 | Investigate | No | Zstandard wrapper | `.zst`, `.tar.zst` | Increasingly common compressed data wrapper; needs dependency or system-tool decision and safe extraction. |
| 14 | Investigate | Yes | XZ wrapper | `.xz`, `.tar.xz` | Common Linux/data engineering wrapper; needs cross-platform extraction strategy. |
| 15 | Investigate | Yes | YAML / YML | `.yaml`, `.yml` | Useful for structured records and config-like datasets; must avoid pretending arbitrary config is clean tabular data. |
| 16 | Investigate | Yes | Markdown tables | `.md` | Useful for docs-driven datasets; needs table detection, escaped pipe handling, and malformed table warnings. |
| 17 | Investigate | Yes | Microsoft Access | `.mdb`, `.accdb` | Valuable corporate legacy source; dependency and cross-platform driver support are main risks. |
| 18 | Investigate | Yes | DBF / FoxPro | `.dbf` | Common legacy/GIS/business source; needs code page, memo file, deleted-row handling. |
| 19 | Investigate | No | Stata | `.dta` | Common research/economics/government data; needs metadata labels and missing-value handling. |
| 20 | Investigate | No | SPSS | `.sav`, `.zsav` | Common survey/research data; needs value labels, encodings, and dependency review. |
| 21 | Investigate | No | SAS transport | `.xpt` | Common regulated/research exchange; useful for government/health datasets. |
| 22 | Deferred | No | R data | `.rds`, `.rdata` | Useful for R users but often arbitrary object graphs rather than relational records. |
| 23 | Investigate | No | Excel XML Spreadsheet / SpreadsheetML | `.xml` | Older Office XML spreadsheet export; conflicts with generic XML extension handling and needs signature detection. |
| 24 | Investigate | No | Apache / Nginx access logs | `.log` | Common operational data; better as log-template import than generic delimited text. |
| 25 | Investigate | No | Syslog / structured logs | `.log`, `.syslog` | Useful for local diagnostics; needs templates and timestamp parsing rules. |
| 26 | Investigate | Yes | JSON log stream | `.jsonl`, `.ndjson`, `.log` | Current NDJSON support covers many cases, but explicit log workflow could add timestamp extraction and presets. |
| 27 | Candidate | No | AWS CloudTrail logs | `.json`, `.json.gz` | Common cloud audit data; likely a JSON template/profile over existing JSON import. |
| 28 | Candidate | No | Google Takeout tabular exports | `.json`, `.csv`, archives | Potentially high user value but broad and inconsistent; best handled as format profiles over existing importers. |
| 29 | Investigate | No | SQL Server BCP / bulk export | `.bcp`, `.fmt`, `.txt` | Enterprise data pipeline format; often requires companion format metadata. |
| 30 | Planned | Yes | SQL Server backup | `.bak` | Recognized for future container-assisted import; high complexity and tooling/licensing questions. |
| 31 | Investigate | No | PostgreSQL custom/binary backup | `.backup`, `.dump`, `.tar` | Valuable but requires external tooling or staged conversion, not direct parsing. |
| 32 | Candidate | No | Oracle dump / Data Pump | `.dmp` | Enterprise migration source; likely requires Oracle tooling and is high support burden. |
| 33 | Candidate | No | Oracle SQL*Loader files | `.ctl` plus data files | Enterprise batch format; requires control-file parser and companion data handling. |
| 34 | Candidate | No | SQLite/SpatiaLite spatial databases | `.sqlite`, `.db` with spatial metadata | SQLite import exists, but spatial metadata/type handling could become a specialized profile. |
| 35 | Candidate | No | KML / KMZ | `.kml`, `.kmz` | Common GIS/web mapping format; KMZ also requires ZIP wrapper behavior and geometry mapping. |
| 36 | Candidate | No | GPX | `.gpx` | Common GPS track/waypoint source; XML-based and maps naturally to track/point tables. |
| 37 | Candidate | No | iCalendar | `.ics` | Common calendar/event data; maps to event tables but not core data-wrangling priority. |
| 38 | Candidate | No | vCard | `.vcf` | Common contact data; useful niche import with clear table mapping. |
| 39 | Candidate | No | OFX / QFX | `.ofx`, `.qfx` | Common finance/banking exports; needs transaction/account mapping and privacy care. |
| 40 | Candidate | No | QIF | `.qif` | Legacy finance export format; useful for personal/business finance datasets. |
| 41 | Candidate | No | EDI X12 / EDIFACT | `.edi`, `.x12`, `.edifact` | Important business interchange family; high parser complexity and domain-specific mapping. |
| 42 | Candidate | No | HL7 v2 | `.hl7` | Healthcare integration format; useful in specialized settings, but requires domain-specific parsing. |
| 43 | Candidate | No | FHIR bundles / NDJSON | `.json`, `.ndjson` | Healthcare data; current JSON/NDJSON can import raw records, but FHIR-aware table mapping would be specialized. |
| 44 | Investigate | No | 7-Zip wrapper | `.7z` | Common archive wrapper; dependency and extraction safety need review. |
| 45 | Deferred | No | RAR wrapper | `.rar` | Common archive type but licensing/tooling concerns make it lower priority. |
| 46 | Deferred | Yes | PDF table extraction | `.pdf` | Attractive but only worth doing if extraction quality and correction UX are acceptable. |
| 47 | Deferred | Yes | TOML | `.toml` | Usually config, not tabular data; useful only for niche key/value or example datasets. |
| 48 | Deferred | No | ORC | `.orc` | Big-data columnar format; lower expected user frequency than Parquet. |
| 49 | Candidate | No | Delta Lake table folders | `_delta_log` plus Parquet files | Important data-lake format; likely depends on Parquet import first. |
| 50 | Candidate | No | Apache Iceberg table metadata | metadata folder plus data files | Strategic data-lake format; complex catalog/manifest handling. |
| 51 | Candidate | No | Apache Hudi table folders | Hudi metadata plus data files | Strategic data-lake format; complex and lower near-term desktop demand. |

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
6. clipboard table capture
7. Avro
8. Arrow IPC / Feather
9. GeoPackage / GeoJSON
10. Zstandard / XZ wrappers
