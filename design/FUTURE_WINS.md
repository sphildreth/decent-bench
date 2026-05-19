# Decent Bench Future Wins

**Status:** v2.0.0 completion refresh
**Last reviewed:** 2026-05-19
**Purpose:** Product and engineering priority index for work that is still
future-facing. Implemented v2.0.0 capabilities are listed as current
foundations, not future wins.

Decent Bench now covers the high-priority v2.5.x workbench surface: rich
metadata, native types, branch-aware safety boundaries, table editing, saved
queries, diagnostics, visualization, repeatable profiles, typed exports, and
row-local import transforms. The remaining roadmap is mostly dependency-gated
or intentionally larger than the current workbench slice.

## Status Values

- `TODO`: prioritized roadmap work that is not actively being implemented right
  now.
- `IN PROGRESS`: active implementation or design work is underway right now.
- `BACKLOG`: valuable, but blocked on external dependency, larger product
  scope, or user demand after a smaller slice ships.

Future version values are planning buckets, not release commitments. Completed
items are removed from the Status Map instead of being marked with a completed
status.

## Status Map

| Priority | Future Version | Status | Feature | Current Source Of Truth | Why This Rank |
|---:|---|---|---|---|---|
| 1 | Future | BACKLOG | Public DecentDB Dart branch/snapshot API integration | `design/adr/0032-database-snapshot-and-safe-run.md`, `design/adr/0028-inline-table-data-editor.md`, `design/adr/0029-workspace-project-file-and-query-library.md` | Decent Bench owns the UI/domain boundary, but native branch execution, branch-local edits/imports, and project branch preferences require public Dart APIs before production wiring can be completed |
| 2 | Future | BACKLOG | Parquet export writer | `design/adr/0031-parquet-excel-export-dependency-strategy.md` | Excel export is implemented with the existing archive dependency; Parquet remains blocked on a maintained Apache-compatible Dart or FFI writer validated across desktop platforms |
| 3 | Future | TODO | SDK generation CLI and UI workflow | `design/adr/0034-schema-first-sdk-generation-prototype.md` | The TypeScript IR/prototype exists; a user-facing `dbench generate-sdk` workflow should reuse that IR after project-file workflows settle |
| 4 | Future | BACKLOG | Connector expansion beyond the current registry | `design/IMPORT_SUPPORT_PLAN.md`, `docs/IMPORT_FORMATS.md` | DuckDB, ODS, Parquet import, PostgreSQL dump expansion, DBF/Access, live database sources, clipboard tables, XZ, and PDF tables are recognized honestly but require dependency/product evaluation |
| 5 | Future | BACKLOG | Query-plan and performance diagnostics, full suite | Needs ADR/spec | Broader than the implemented EXPLAIN visualization; covers plan comparison, index recommendations, runtime profiling, and historical plan tracking |

## Current Foundations

These are shipped or present foundations as of the v2.0.0 line and should not
be treated as future roadmap claims:

- DecentDB-first desktop workspace with drag-and-drop open/import entry point.
- Import from 15 formats across 9 families:
  - Delimited: CSV, TSV, generic delimited text
  - Spreadsheet: Excel (`.xlsx`, `.xls`)
  - Structured document: JSON, NDJSON/JSONL, XML
  - Web/markup: HTML tables
  - Database: SQLite
  - Database dump: MariaDB/MySQL-style SQL dump, MVP-lite
  - Archive wrappers: ZIP, GZip, BZip2
- Recognized-but-unavailable connector states for fixed-width, ODS, DuckDB,
  Parquet import, PostgreSQL plain dump expansion, DBF/Access, XZ, clipboard
  tables, PDF tables, and other import roadmap formats.
- Generic import row-local transform model for filters, default values,
  computed columns, column ordering, and deduplication.
- Headless CLI import mode (`--in`, `--out`, `--plan`, `--silent`) with
  versioned import/export profile validation.
- Schema browser expansion for triggers, constraints, generated columns, temp
  objects, native type details, enum labels, spatial metadata, search/filter,
  and branch context.
- DecentDB v2.5.1 engine, binding, and fixture compatibility.
- DecentDB tooling metadata bridge with schema fingerprints and query contracts.
- Query-parameterized SQL execution with typed fields driven by contracts, plus
  pre-execution validation for contract-required arguments.
- DecentDB v2.5.x native semantic and spatial type UX across schema metadata,
  result grids, copy actions, autocomplete, snippets, import overrides, and
  typed export paths.
- Multi-tab SQL editor against the pinned DecentDB SQL surface.
- Schema-aware autocomplete, snippets, and deterministic SQL formatter.
- Paged/virtualized results grid with best-effort cancellation.
- Per-tab query history panel and global history dialog with load, rerun, clear,
  outcome metadata, row counts, elapsed time, and configurable per-tab history
  depth.
- Safe-run prompts for mutating/destructive SQL plus an app-owned
  branch/snapshot domain boundary that reports the current public Dart binding
  blocker honestly.
- Type-aware inline table editor for editable single-table result sets, with
  parameterized DML, direct-write confirmation when branch APIs are unavailable,
  and inline constraint/type error reporting.
- Saved query library and workspace project manifests with query contracts,
  schema fingerprints, import/export defaults, and branch preference fields.
- TypeScript SDK-generation prototype built from schema metadata and saved
  query contracts.
- Column statistics panel and database statistics dashboard.
- EXPLAIN visualization with operation/table/index metadata and raw-plan copy.
- Data visualization from loaded query results for bar, line, scatter, and pie
  charts with PNG export.
- Read-only ERD viewing with schema-pane navigation, table-preview loading, and
  full-diagram or viewport PNG/JPG image export.
- CSV, JSON, NDJSON, and Excel (`.xlsx`) exports with full v2.5.x native type
  handling where the target format supports it.
- Import/export profile persistence shared by GUI/headless workflows.
- DecentDB native asset staging and hardened library resolution.
- DecentDB-backed application logging (`Tools -> View Log`).
- TOML configuration, desktop preferences, command registry, native menu
  bridge, command palette, and ADR-governed design process.

## Remaining Future Work

### Public Branch/Snapshot API Integration

Decent Bench already has the branch/snapshot workbench surface, branch-aware
safe-run prompts, guarded restore/merge UI, and branch-local gateway contracts.
The production bridge returns an explicit unavailable state because the
DecentDB Dart package does not yet expose public branch/snapshot APIs.

Future work should wire the existing boundary to public APIs when they are
available:

- native branch execution
- native snapshot creation/deletion
- branch-local import and edit sessions
- large-import "run on branch"
- project branch preference activation

### Parquet Export Writer

Excel export now ships through a minimal Office Open XML writer built on the
already-approved `archive` dependency. Parquet export must not be faked. It
remains future work until an Apache-compatible Dart or FFI writer is selected,
validated for Linux/macOS/Windows packaging, and tested for incremental writes.

### SDK Generation CLI And UI

The schema-first SDK-generation prototype has an internal IR and TypeScript
declaration output. The future user-facing workflow should expose the same IR
through a command such as:

```text
dbench generate-sdk --project <workspace.dbench-project.toml> \
  --language typescript --out <directory>
```

The command should produce stable artifacts and fail clearly on breaking schema
or saved-query contract drift.

### Connector Expansion

The import registry is the current source of truth for recognized formats and
support states. Future connector work should prioritize formats that add broad
user value without compromising Apache 2.0-compatible distribution:

- fixed-width text
- OpenDocument Spreadsheet (`.ods`)
- DuckDB files
- Parquet import
- PostgreSQL plain dump expansion
- DBF/Access and other legacy business sources
- live PostgreSQL, MySQL/MariaDB, and SQL Server read-only imports
- clipboard table capture
- XZ and other wrapper formats
- PDF table extraction only if extraction quality is acceptable

### Query-Plan And Performance Diagnostics

The implemented EXPLAIN visualization is intentionally lightweight. A full
diagnostics suite would need a separate ADR/spec and should cover:

- plan comparison across query revisions
- index recommendations
- runtime profiling
- historical plan tracking
- query performance advisories
