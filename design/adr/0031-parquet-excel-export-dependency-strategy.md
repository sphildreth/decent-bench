## Parquet And Excel Export Dependency Strategy
**Date:** 2026-05-18
**Status:** Accepted

### Decision

Parquet and Excel (`.xlsx`) export are treated as independent work streams.
Excel export is implemented in v2.0.0 with a minimal Office Open XML writer
built on the already-approved `archive` dependency. Parquet export remains
blocked until a maintained Apache-compatible Dart or FFI writer is selected and
validated for desktop packaging.

### Rationale

The two formats have different dependency landscapes:

- Excel `.xlsx` is a ZIP of XML parts. The app already depends on `archive`
  for import wrapper handling, so a minimal writer can ship without adding a
  new package or native toolchain.
- Parquet is a columnar binary format with no mature maintained Dart writer in
  the current dependency set. Shipping an invalid or unverified writer would be
  worse than exposing an honest unavailable state.

### Excel Export

The implemented Excel path:

- runs through the existing query export gateway/controller/menu flow
- consumes query pages incrementally from the DecentDB statement cursor
- writes worksheet XML to a temporary file and zips workbook parts to disk
- supports optional header rows
- writes numbers and booleans as typed spreadsheet cells
- writes strings and native DecentDB display values as inline strings
- avoids formula, pivot-table, style, and multi-sheet complexity

No new dependency was added.

### Parquet Export

**Status:** Backlog, dependency-gated.

Candidate implementation paths:

- Rust `parquet` crate through FFI
- Apache Arrow/Parquet native bindings
- DuckDB intermediary if DuckDB import/export becomes a broader product
  dependency

Parquet export must not begin until:

- a functional prototype writes a valid Parquet file
- licensing is verified and documented
- Linux, macOS, and Windows packaging are validated
- incremental/streaming behavior is proven

### Non-Goals

- Parquet import.
- Excel formula generation, pivot tables, charts, workbook styling, or macro
  content.
- Replacing CSV/JSON/NDJSON as the core typed export paths.

### Trade-offs

- **Custom `.xlsx` writer**: Lower dependency and licensing risk, but limited to
  basic worksheet output.
- **No Parquet placeholder output**: Users get an explicit unavailable dialog
  instead of a fake `.parquet` file.
- **Temporary worksheet file**: The XML writer avoids keeping worksheet content
  in memory while still using `archive` to produce the final ZIP.

### References

- ADR-0002 Results Paging and Streaming Contract
- `apps/decent-bench/lib/features/workspace/infrastructure/xlsx_export_support.dart`
- `apps/decent-bench/lib/features/workspace/infrastructure/decentdb_bridge.dart`
- `design/FUTURE_WINS.md`
