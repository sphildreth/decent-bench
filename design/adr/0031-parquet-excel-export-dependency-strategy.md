## Parquet and Excel Export Dependency Strategy
**Date:** 2026-05-18
**Status:** Proposed

### Decision

Parquet and Excel (`.xlsx`) export will be evaluated as two independent work
streams, not a single combined effort. Each format will be assessed for
feasibility, licensing, and implementation cost before any code is written.
Neither format will be implemented before JSON export (ADR-003?) ships, so the
initial work benefits from a mature, tested cursor streaming infrastructure.

### Rationale

The PRD and SPEC both list Parquet and Excel export as deferred "Next" scope.
However, these two formats have radically different dependency landscapes,
implementation costs, and target audiences. Treating them as a single line item
obscures the fact that Excel export is feasible today (with the right dependency
choice) while Parquet export has no viable Dart library and may require a
significant FFI investment.

Evaluating them separately ensures that one does not block the other and that
each gets the appropriate architecture and dependency review.

### Licensing Requirements

All export dependencies must be **Apache 2.0 compatible**. The project's
`THIRD_PARTY_NOTICES.md` must be updated for every new dependency. License
verification happens during dependency evaluation, not during implementation.

### Streaming Requirement

Both export paths must consume cursor pages incrementally through the existing
paging pipeline. Full materialization of the result set in memory before writing
to disk is prohibited (per ADR-0002 and the SPEC section 6.2). Any library that
requires building the complete output in memory is unacceptable.

### Parquet Export

**Status**: No mature, maintained Dart library for writing Parquet exists as of
May 2026.

**Primary path**: FFI bridge to a Rust or C library. Options:
- `parquet` crate (Rust, Apache 2.0) — mature, widely used in the Rust
  ecosystem. Used by Apache DataFusion, Polars, and others. Would need
  `flutter_rust_bridge` or manual `dart:ffi` + `NativeFinalizer`.
- `apache-parquet` C++ library (Apache 2.0) — the reference implementation.
  Significant binding complexity due to C++ ABI and build system.
- Alternative: DuckDB as a Parquet writer. DuckDB can write Parquet via SQL
  (`COPY ... TO 'output.parquet' (FORMAT PARQUET)`). If a DuckDB import
  connector is also planned, this creates a dependency synergy.

**Evaluation criteria** (to be completed before implementation begins):
1. Can the chosen library be compiled and linked for all three desktop platforms
   (Windows, macOS, Linux)?
2. Does it support incremental/streaming write, or must all data be available
   before writing?
3. What is the CI complexity increase (new build dependencies, platform-specific
   toolchains)?
4. What is the binary size increase for the shipped application?

**Implementation gates**: Parquet export implementation does not begin until:
- An evaluation ADR or update to this ADR confirms the chosen approach.
- A functional prototype writes a valid Parquet file from a small dataset.
- Licensing is verified and documented.
- CI pipeline successfully compiles the required native library on all three
  platforms.

### Excel Export

**Status**: The current `excel` package dependency (v4.0.6) is read-only — it
parses `.xlsx`/`.xls` files for import but does not support writing.

**Primary path**: Find or build a write-capable Excel package. Options:
- `excel` package: Check if the upstream project has added write support since
  v4.0.6, or if a fork has done so.
- Alternative Dart package: Search pub.dev for a dedicated `.xlsx` writer.
- FFI bridge: Same complexity considerations as Parquet but with a lighter
  format (Office Open XML is a ZIP of XML files — a custom writer using
  `dart:io` + `archive` package is feasible for simpler output).
- Simple `.xlsx` writer using built-in tools: The `archive` package (already a
  dependency for ZIP/GZip/BZip2 import) can create ZIP files. Office Open XML
  `.xlsx` is a ZIP containing XML worksheets. A minimal writer that produces
  well-formed `.xlsx` with basic formatting is feasible without a native FFI
  bridge.

**Evaluation criteria**:
1. Can the chosen approach produce valid `.xlsx` files readable by Excel, Google
   Sheets, and LibreOffice?
2. Does it support streaming/incremental write, or must the entire workbook be
   built in memory?
3. What column formatting is supported (date, number, header styling)?
4. How does it handle the ~1M row per sheet limit (multi-sheet splitting)?

**Implementation gates**: Excel export implementation does not begin until:
- An evaluation confirms the chosen approach and licensing.
- A functional prototype writes a valid `.xlsx` file readable by all major
  spreadsheet applications.
- Streaming behavior is tested with result sets exceeding available memory.

### Non-Goals

- Parquet import (the import pipeline uses existing import connectors; columnar
  import is a separate concern).
- Excel export with formula evaluation or pivot-table structures.
- Any export format not listed in the PRD/SPEC scope.

### Trade-offs

- **DuckDB as Parquet intermediary**: Using DuckDB for Parquet export reduces
  implementation effort (DuckDB already writes Parquet) but introduces DuckDB as
  a dependency — an embedded database engine. This is a heavy dependency for a
  single export format. Only viable if DuckDB import is already planned and
  implemented.
- **Custom `.xlsx` writer vs. library**: A custom writer using the `archive`
  package avoids licensing and dependency risks but requires implementing XML
  generation for the Office Open XML format. This is more work upfront but more
  maintainable long-term since it avoids an external dependency that may be
  abandoned.
- **Deferred evaluation = delayed user value**: Parquet and Excel export are
  frequently requested. Deferring them preserves engineering focus on
  higher-impact features (command palette, table editor, saved queries) but
  delays format support. The trade-off is intentional: a polished core workflow
  is more valuable than a broad but shallow format surface.

### References

- ADR-0002 Results Paging and Streaming Contract
- `design/PRD.md` section 3.2 (deferred exports)
- `design/SPEC.md` section 11.2 (deferred exports)
- `design/SPEC.md` section 6.2 (result materialization rule)
- JSON export is a current foundation; `design/FUTURE_WINS.md` Priority 13
  covers Parquet and Excel export

### Alternatives Considered

**Implement Parquet and Excel export now with whatever dependencies are
available**: Rejected because:
- Parquet has no viable Dart library. Choosing an immature or abandoned library
  creates maintenance debt.
- Excel has a read-only dependency in use. Blindly adding a second Excel
  dependency for write duplicates the format support surface.
- Both exports benefit from a mature cursor streaming pipeline. JSON export
  ships first and hardens that pipeline before these more complex formats
  attempt to use it.

**Skip Parquet export entirely**: Rejected because Parquet is the standard
columnar interchange format and its absence excludes Decent Bench from data
engineering workflows. But the implementation is gated on finding a viable Dart
or FFI path, not on shipping by a specific date.

**Use `syncfusion_flutter_xlsio` for Excel export**: Rejected because of
licensing concerns (community license vs. Apache 2.0 compatibility needs
verification). Can be evaluated alongside the other Excel options.
