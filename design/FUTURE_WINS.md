# Decent Bench Future Wins

**Status:** DecentDB v2.5.x roadmap refresh
**Last reviewed:** 2026-05-19
**Purpose:** Product and engineering priority index for Decent Bench. Dedicated
specs and ADRs remain the implementation source of truth when they exist.

Decent Bench should win by being the polished DecentDB workbench: import data,
inspect schema, run SQL, export results, safely experiment with branches, and
generate application-facing artifacts without forcing users to hand-wire
database access.

## Roadmap Stance After DecentDB v2.5.x

DecentDB v2.5.1 is now released. That changes the Decent Bench roadmap more
than a normal engine patch because v2.5.0/v2.5.1 added several workbench-facing
capabilities:

- stable schema and query-contract metadata for tooling
- deterministic schema fingerprints
- native type metadata and query parameter/result-column contracts
- Dart binding exposure for the metadata surface
- open-with-options support for cache and durability tuning
- binding-native semantic data types: `ENUM`, `IPADDR`/`INET`, `CIDR`, `DATE`,
  `TIME`, `TIMESTAMPTZ`, `INTERVAL`, `MACADDR`, and `MACADDR8`
- native `GEOMETRY` and `GEOGRAPHY` values with WKB/WKT/GeoJSON conversion
  functions and spatial indexes
- named snapshots, branches, branch-local writes, read-only historical
  execution, row diffs, guarded restore, constrained merge, and a C ABI JSON
  bridge
- v2.5.1 binding fixes for native options and owned spatial value disposal

The highest-impact Decent Bench work is therefore no longer generic UI backlog.
The first milestone should align Decent Bench with the released engine and make
the new DecentDB-native capabilities visible, safe, and useful.

## Status Values

- `TODO`: prioritized roadmap work that is not actively being implemented right
  now.
- `IN PROGRESS`: active implementation or design work is underway right now.
- `DONE`: implemented roadmap work retained temporarily for traceability.
- `BACKLOG`: valuable, but blocked on external dependency, larger product scope,
  or user demand after a smaller slice ships.

Future version values are planning buckets, not release commitments.

Items are ranked by estimated user impact, DecentDB differentiation, dependency
ordering, and risk reduction for later features.

## Status Map

| Priority | Future Version | Status | Feature | Current Source Of Truth | Why This Rank |
|---:|---|---|---|---|---|
| 1 | vNext | DONE | DecentDB v2.5.1 engine upgrade and compatibility hardening | New v2.5.x alignment item | Highest leverage because the app still needs to consume the released engine before any v2.5.x feature can matter; validates native asset staging, binding versioning, and fixture coverage |
| 2 | vNext | DONE | Tooling metadata and query-contract bridge | DecentDB v2.5.0 tooling metadata APIs | Foundation for type-aware UI, parameter forms, safer editing, typed export, SDK generation, and schema drift checks |
| 3 | vNext | IN PROGRESS | Native semantic and spatial type UX | New v2.5.x alignment item | Prevents Decent Bench from flattening the new engine value model into strings; required before table editing, import mapping, JSON export, and schema inspection are trustworthy |
| 4 | vNext | IN PROGRESS | Branch, snapshot, diff, restore, and safe-run workbench | `design/adr/0032-database-snapshot-and-safe-run.md` revised for v2.5.x | Major DecentDB differentiator; replaces file-copy-only backup thinking with native snapshots, branches, diffs, restore, and merge |
| 5 | vNext | IN PROGRESS | Query parameterization UI powered by query contracts | New proposal | v2.5.x query contracts can infer parameters and result columns; this unlocks repeatable operational queries without hand-written JSON parameter arrays |
| 6 | vNext | IN PROGRESS | Table data editor, type-aware and branch-safe | `design/adr/0028-inline-table-data-editor.md` revised for v2.5.x | Universal workbench feature, but it should build on query contracts, native type editors, and branch/snapshot safety instead of inventing a parallel editing model |
| 7 | vNext | IN PROGRESS | Saved queries and workspace projects | `design/adr/0029-workspace-project-file-and-query-library.md`, `design/PRD.md` post-1.0 scope | Near-universal repeatability feature; becomes more valuable when saved queries carry parameter contracts, expected result columns, and optional schema fingerprints |
| 8 | vNext | DONE | JSON and NDJSON export with typed metadata | `design/PRD.md`, `design/SPEC.md` Next scope | Broad interchange need and low implementation cost, but must serialize v2.5.x native values correctly instead of treating everything as display text |
| 9 | vNext+1 | IN PROGRESS | Query tab history, user-visible | `design/SPEC.md` marked optional for MVP | Useful productivity feature on existing persistence infrastructure; lower strategic impact than v2.5.x platform alignment |
| 10 | vNext+1 | TODO | Schema browser expansion and v2.5.x metadata presentation | `design/SPEC.md` phased object coverage | Existing rich schema snapshot work should be extended to show triggers, constraints, generated columns, temp objects, native type details, enum labels, spatial metadata, and branch context |
| 11 | vNext+1 | TODO | Schema-first strongly typed SDK generation prototype | Needs Decent Bench ADR/spec | No longer blocked by DecentDB metadata; should move from backlog to ADR/prototype once metadata/query-contract bridge lands |
| 12 | vNext+1 | TODO | Column statistics panel, type-aware | New proposal | Broad exploration value; should understand semantic/spatial types and avoid expensive scans by running lazily |
| 13 | vNext+1 | TODO | Database statistics dashboard | New proposal | Operational visibility for file size, WAL status, table counts, branch state, index inventory, and maintenance signals |
| 14 | vNext+1 | TODO | EXPLAIN visualization | `design/SPEC.md` pinned engine SQL surface | Lightweight diagnostics slice; still valuable, but follows metadata/type/safety work |
| 15 | vNext+2 | TODO | Data visualization from query results | `design/adr/0030-charting-library-and-visualization-contract.md` | High impact for analysts; should consume typed result metadata and can later consider map/spatial views |
| 16 | vNext+2 | TODO | Import/export profile persistence, GUI <-> headless | `design/adr/0022-headless-cli-import-mode-and-plan-file.md`, `design/adr/0029-workspace-project-file-and-query-library.md` | Workflow multiplier after the type-aware import/export contracts are stable |
| 17 | vNext+2 | TODO | Parquet and Excel export | `design/adr/0031-parquet-excel-export-dependency-strategy.md`, `design/PRD.md`, `design/SPEC.md` Next scope | Valuable but dependency-heavy; should inherit mature typed export handling from JSON/CSV |
| 18 | vNext+2 | TODO | Richer import transforms and connector expansion | `design/adr/0033-computed-column-transforms-during-import.md`, `design/IMPORT_SUPPORT_PLAN.md` | Power import work; important, but lower broad impact than making current DecentDB-native data first-class |
| - | Future | BACKLOG | Query-plan and performance diagnostics, full suite | Needs ADR/spec | Broader than EXPLAIN visualization; covers plan comparison, index recommendations, runtime profiling, and historical plan tracking |

## Current Foundations

These are shipped or present foundations as of the v1.1.x line and should not be
treated as future roadmap claims:

- DecentDB-first desktop workspace
- drag-and-drop open/import entry point
- import from 15 formats across 9 families:
  - Delimited: CSV, TSV, generic delimited
  - Spreadsheet: Excel (`.xlsx`, `.xls`)
  - Structured document: JSON, NDJSON/JSONL, XML
  - Web/markup: HTML tables
  - Database: SQLite
  - Database dump: MariaDB/MySQL-style SQL dump, MVP-lite
  - Archive wrappers: ZIP, GZip, BZip2
- schema browser for tables, views, columns, and indexes
- DecentDB tooling metadata bridge with schema fingerprints and query contracts
- multi-tab SQL editor against the pinned DecentDB SQL surface
- schema-aware autocomplete, snippets, and deterministic SQL formatter
- paged/virtualized results grid with best-effort cancellation
- CSV, JSON, and NDJSON export
- headless CLI import mode (`--in`, `--out`, `--plan`, `--silent`)
- DecentDB native asset staging and hardened library resolution
- DecentDB-backed application logging (`Tools -> View Log`)
- TOML configuration and desktop preferences
- command registry, native menu bridge, and command palette foundation
- ADR-governed design process

## 1. DecentDB v2.5.1 Engine Upgrade And Compatibility Hardening

**Status:** `DONE`
**Future Version:** vNext
**Source of truth:** New v2.5.x alignment item

### Why This Matters

Decent Bench cannot expose v2.5.x capabilities until it actually consumes the
v2.5.1 Dart binding and native asset bundle. This is the highest priority
because it is the prerequisite for every other item in this refresh.

The upgrade is more than changing a tag. It must prove that Decent Bench can
open databases with the new format, stage the correct native library, display
the engine version, handle v2.5.x typed values, and keep existing import/query
workflows working.

### Scope

- Pin the Dart `decentdb` dependency to `v2.5.1`.
- Refresh the lockfile and verify package resolution.
- Verify native asset discovery and staging for the `v2.5.1` release artifact.
- Add a smoke fixture that contains v2.5.x semantic, temporal, spatial, and
  branch metadata.
- Verify open/import/query/export smoke flows against that fixture.
- Update README and binding/version documentation where Decent Bench describes
  the pinned DecentDB release.

### Implementation Notes

- `apps/decent-bench/pubspec.yaml` and `pubspec.lock` now pin the Dart binding
  and cached release resolution path to DecentDB `v2.5.1`.
- Compatibility smoke tests now include a dedicated v2.5.x fixture that exercises
  semantic, temporal, spatial, and branch-metadata-style fields through import,
  open, query, and CSV export.

### Non-Goals

- Implementing every new v2.5.x UX surface in the same change.
- Changing Decent Bench app versioning policy.
- Replacing existing import/export architecture.

## 2. Tooling Metadata And Query-Contract Bridge

**Status:** `DONE`
**Future Version:** vNext
**Source of truth:** DecentDB v2.5.0 tooling metadata APIs

### Why This Matters

DecentDB now exposes stable metadata designed specifically for tools:
deterministic schema fingerprints, native type metadata, parameter contracts,
and result-column contracts. Decent Bench should consume this directly instead
of inferring too much from display strings or ad hoc schema snapshots.

This bridge becomes the shared foundation for parameter forms, type-aware table
editing, typed JSON export, saved-query validation, schema drift warnings, and
future SDK generation.

### Scope

- Add bridge messages for database tooling metadata.
- Add bridge messages for describing a query contract before execution.
- Persist schema fingerprint and contract summaries where appropriate in
  workspace state.
- Surface query result column contracts to the result grid and export pipeline.
- Surface query parameter contracts to the SQL editor pane.
- Add regression tests around deterministic metadata decoding and error paths.

### Implementation Notes

- `WorkspaceDatabaseGateway` now exposes DecentDB tooling metadata and
  query-contract messages through the existing background bridge isolate.
- Workspace state schema version `3` persists the current schema fingerprint and
  per-tab query-contract summaries while continuing to load older state files.
- Query execution describes the contract before running SQL, stores parameter
  and result-column contracts on the active tab, and keeps typed column contract
  metadata available to the results grid and CSV export logging path.
- Regression coverage now includes deterministic metadata decoding, persisted
  contract summaries, bridge smoke coverage, and the pre-execution contract
  error path.

### Non-Goals

- Full SDK generation.
- Query optimizer visualization.
- Replacing the existing rich schema snapshot immediately.

## 3. Native Semantic And Spatial Type UX

**Status:** `IN PROGRESS`
**Future Version:** vNext
**Source of truth:** New v2.5.x alignment item

### Why This Matters

DecentDB v2.5.0 added compact native storage and typed binding exposure for
semantic, temporal, network, MAC, enum, geometry, and geography values. Decent
Bench should make those values understandable instead of rendering them as
undifferentiated strings.

This matters for trust. A user editing an `ENUM`, exporting `TIMESTAMPTZ`, or
inspecting `GEOGRAPHY` should see that Decent Bench understands the value's
database type.

### Scope

- Show native type families in schema details and result column metadata.
- Render `ENUM` values with labels while preserving stable stored identity.
- Render IP, CIDR, MAC, date, time, timestamp, and interval values with clear
  copy/export behavior.
- Render geometry/geography cells with compact summaries and copy actions for
  WKT, WKB, and GeoJSON where available.
- Extend autocomplete/snippets for new column types and common spatial
  functions.
- Add import type mapping options for the new native types.
- Add JSON/CSV export tests for every new native type.

### Implementation Notes

- Native type descriptors now classify DecentDB values into enum, temporal,
  network, MAC, UUID, spatial, and foundational families for schema details and
  result-column tooltips.
- The bridge now encodes DecentDB enum, interval, time, UUID, geometry, and
  geography values into app-safe result values instead of leaking binding
  implementation strings or treating spatial bytes as anonymous blobs.
- Result cells and copy/export paths format native values with query-contract
  type context, including enum label identity when labels are present in the
  type declaration and compact EWKB summaries for `GEOMETRY`/`GEOGRAPHY`.
- Autocomplete, default snippets, and import target overrides now include the
  v2.5.x native semantic and spatial types plus common `ST_*` functions.
- Smoke coverage now verifies direct native v2.5.x query values and CSV export
  display behavior. JSON/NDJSON typed export remains covered by item 8.

### Non-Goals

- Full map visualization.
- Geometry editing widgets.
- Spatial index design tools.

## 4. Branch, Snapshot, Diff, Restore, And Safe-Run Workbench

**Status:** `IN PROGRESS`
**Future Version:** vNext
**Source of truth:** `design/adr/0032-database-snapshot-and-safe-run.md` needs
v2.5.x revision

### Why This Matters

The old backup/snapshot plan was file-copy centered. That is no longer the best
first-class Decent Bench experience because DecentDB now supports native
snapshots, branches, diffs, guarded restore, constrained merge, and time-travel
reads.

This should become one of Decent Bench's signature workflows: users can branch
before a risky import, run destructive SQL in an isolated branch, inspect the
row diff, and restore or merge only when satisfied.

### Scope

- Revise ADR-0032 around native DecentDB branch/snapshot primitives.
- Add a branch/snapshot panel to list named snapshots, branches, and current
  branch context.
- Add "Create Snapshot" and "Create Branch" commands.
- Add safe-run prompts for destructive statements and large imports.
- Add "Run on New Branch" for risky SQL/import workflows.
- Add branch diff viewer for primary-key row diffs.
- Add guarded restore UI with clear confirmation and automatic pre-restore
  snapshot.
- Add constrained merge UI after diff review.
- Retain file-copy snapshots as a fallback/exportable safety option, not as the
  primary model.

### Implementation Notes

- ADR-0032 now describes the v2.5.x-native branch/snapshot model and records the
  current Dart binding limitation: DecentDB exposes the C ABI branch JSON bridge,
  but the Dart package does not yet expose public branch APIs.
- Decent Bench now has a reusable SQL risk classifier for read-only, mutating,
  destructive, transaction-control, and unknown statements.
- Running mutating/destructive SQL from the editor now prompts before execution
  and clearly disables "Run on New Branch" until a public Dart branch API is
  available.

### Non-Goals

- Multi-user branch collaboration.
- Remote branch storage.
- Conflict-resolution UI beyond the constrained merge surface exposed by the
  engine.

## 5. Query Parameterization UI Powered By Query Contracts

**Status:** `IN PROGRESS`
**Future Version:** vNext
**Source of truth:** New proposal

### Why This Matters

The editor already has a low-level parameter JSON path, but that is not a good
end-user interface. DecentDB v2.5.x query contracts let Decent Bench build a
typed parameter panel from the SQL itself.

This turns parameterized SQL into a normal GUI workflow: write a query, see the
parameters, fill in values, execute, and save the query with parameter metadata.

### Scope

- Detect parameters through `describeQueryContract(sql)`.
- Render one field per parameter with type-aware widgets when known.
- Persist parameter values per tab and per saved query.
- Show validation state before execution.
- Support quick rerun with changed parameter values.
- Keep the existing JSON parameter editor as an advanced/debug view.

### Implementation Notes

- The SQL editor now renders typed parameter fields from the current query
  contract while keeping the raw JSON array editor visible for advanced/debug
  workflows.
- Field edits update the same per-tab `parameterJson` persisted by workspace
  state, with basic type coercion for numeric and boolean parameter contracts.
- Required non-nullable parameters surface inline validation before rerun.

### Non-Goals

- Named parameter support unless the engine exposes it.
- Parameter presets beyond saved query defaults.
- Query-generated dropdown values.

## 6. Table Data Editor, Type-Aware And Branch-Safe

**Status:** `IN PROGRESS`
**Future Version:** vNext
**Source of truth:** `design/adr/0028-inline-table-data-editor.md` needs v2.5.x
revision

### Why This Matters

Inline editing remains the biggest gap between Decent Bench and a true
workbench. However, it should not be implemented as a purely text-based grid
feature. With v2.5.x, the editor can be safer and more correct by using query
contracts, native type metadata, and branches.

### Scope

- Detect editable result sets using query contracts and schema metadata.
- Use type-aware editors for semantic, temporal, enum, network, and MAC values.
- Treat spatial values as view/copy-only in the first pass.
- Generate parameterized `UPDATE`, `INSERT`, and `DELETE` statements.
- Offer "edit on branch" for risky sessions.
- Show branch/snapshot safety state in the grid status bar.
- Surface constraint and type errors inline.

### Implementation Notes

- ADR-0028 has been revised around query-contract editability, native type
  handling, and branch-safe editing. Code implementation remains pending beyond
  the native type display/copy foundations delivered under priority 3.

### Non-Goals

- Multi-row bulk edit.
- Foreign-key lookup editors.
- Geometry drawing/editing tools.
- Full undo history beyond the branch/snapshot safety model.

## 7. Saved Queries And Workspace Projects

**Status:** `IN PROGRESS`
**Future Version:** vNext
**Source of truth:** `design/adr/0029-workspace-project-file-and-query-library.md`,
`design/PRD.md` section 3.2

### Why This Matters

Users repeatedly run the same validation checks, reports, cleanup statements,
and exploratory queries. Saved queries and projects turn tabs into durable,
portable workflows.

With v2.5.x metadata, saved queries can carry stronger contracts: expected
parameters, expected result columns, schema fingerprints, and drift warnings.

### Scope

- Save current tab as a named query.
- Organize saved queries by folder or tag.
- Open saved queries into tabs with persisted parameter defaults.
- Store query contract summaries and schema fingerprint at save time.
- Warn when the active database schema has drifted from the saved query's last
  known fingerprint.
- Add project files that reference a DecentDB path plus query library, import
  defaults, export defaults, and branch/snapshot preferences.

### Implementation Notes

- ADR-0029 now includes query-contract summaries, schema fingerprints, parameter
  metadata, and branch-safety preferences in the saved-query/project file model.
  User-facing saved-query/project code remains pending.

### Non-Goals

- Collaborative query libraries.
- Scheduled query execution.
- Full query version-control integration.

## 8. JSON And NDJSON Export With Typed Metadata

**Status:** `DONE`
**Future Version:** vNext
**Source of truth:** `design/PRD.md` section 3.2, `design/SPEC.md` section 11.2

### Why This Matters

CSV covers spreadsheet-style interchange. JSON and NDJSON cover application,
API, scripting, and log-pipeline workflows. The implementation can reuse the
existing cursor paging and export infrastructure, but it must be updated for
v2.5.x typed values.

### Scope

- Export query results as JSON array of objects.
- Export query results as NDJSON/JSONL.
- Stream pages without materializing the full result set.
- Offer compact and pretty-printed modes.
- Optionally include column type metadata and schema fingerprint.
- Define stable JSON encodings for v2.5.x native values.
- Add tests for semantic, temporal, enum, network, MAC, geometry, and geography
  export behavior.

### Implementation Notes

- `WorkspaceDatabaseGateway.exportJson` streams paged result rows to JSON array
  or NDJSON without loading the full result set into memory.
- JSON array export supports compact or pretty output and can wrap rows with
  column type metadata and schema fingerprint details.
- NDJSON emits one row object per line, with an optional first metadata line.
- Native v2.5.x values use stable JSON encodings: enum and interval values carry
  structured identity fields, spatial values carry EWKB base64 plus a display
  summary, UUID bytes render as canonical UUID text, and temporal/network/MAC
  values render as stable strings.
- Bridge smoke coverage verifies enum, date, time, timestamptz, interval,
  IP/CIDR, MAC, geometry, geography, JSON, NDJSON, and CSV display behavior.

### Non-Goals

- Arbitrary nested JSON transformation.
- JSON Schema generation.
- Full database dump as JSON.

## 9. Query Tab History, User-Visible

**Status:** `IN PROGRESS`
**Future Version:** vNext+1
**Source of truth:** `design/SPEC.md` section 4.3

### Why This Matters

SQL authoring is iterative. Decent Bench already persists execution history in
workspace state; users need a visible way to restore prior tab contents.

### Scope

- Per-tab history panel.
- Show first SQL line, timestamp, row count, and duration.
- Restore a prior query into the editor.
- Configurable history depth.
- Clear history action.

### Implementation Notes

- The lower-right results surface now includes a per-tab History panel showing
  the first SQL line, timestamp, outcome, duration, row counts, and affected row
  counts.
- History entries can be loaded back into the active editor or rerun from the
  panel.
- The active tab history can be cleared without clearing other tabs. Configurable
  history depth remains pending.

### Non-Goals

- Global history across all databases.
- Result-set persistence with history entries.
- Diff view between history entries.

## 10. Schema Browser Expansion And v2.5.x Metadata Presentation

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** `design/SPEC.md` section 4.4

### Why This Matters

The schema browser should become the user's authoritative view of a DecentDB
file. Existing rich schema snapshot support should be joined with v2.5.x
tooling metadata so users see the real engine model.

### Scope

- Show triggers, constraints, generated columns, and temp objects.
- Show native type details, enum label metadata, and spatial metadata.
- Show index details, including spatial indexes when exposed by metadata.
- Show current branch context where schema visibility is branch-specific.
- Extend search/filter across all schema object kinds.

### Non-Goals

- Constraint editing.
- ERD diagrams.
- Cross-database schema diff.

## 11. Schema-First Strongly Typed SDK Generation Prototype

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** Needs Decent Bench ADR/spec

### Why This Moved Up

This used to be blocked on DecentDB shipping stable schema and query-contract
metadata. That dependency is now satisfied by DecentDB v2.5.0. The feature still
needs a Decent Bench ADR because it expands the product from workbench into
developer integration tooling, but it is no longer a pure backlog item.

### Scope

- Write an ADR covering generator ownership, IR shape, language targets, and
  project-file integration.
- Build a metadata IR from DecentDB tooling metadata and saved query contracts.
- Prototype golden-testable output for one language first.
- Add a headless `dbench generate-sdk` concept to the ADR.
- Include schema drift and breaking-change reporting in the design.

### Non-Goals

- Runtime ORM with change tracking.
- Dynamic SQL extraction from application repositories.
- Full multi-language generator implementation in the first slice.

## 12. Column Statistics Panel, Type-Aware

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** New proposal

### Why This Matters

Users opening unfamiliar data need quick answers about nulls, distinct values,
ranges, and common values. A statistics panel answers those questions without
requiring hand-written exploratory SQL.

### Scope

- Lazy statistics from schema browser columns and result grid headers.
- Counts, null percentage, distinct count, min/max, and top values.
- Numeric summaries where applicable.
- Date/time ranges for temporal columns.
- Type-aware handling for enum, network, MAC, and spatial values.
- Session caching and copy summary action.

### Non-Goals

- Precomputed statistics.
- Cross-column correlation.
- Histogram rendering.

## 13. Database Statistics Dashboard

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** New proposal

### Why This Matters

Users need operational confidence: file size, WAL state, object counts, row
counts, and maintenance signals should be visible without manual filesystem or
PRAGMA inspection.

### Scope

- Database file size and WAL sidecar status.
- Table, view, index, trigger, branch, and snapshot counts.
- Lazy per-table row counts.
- Branch/snapshot state summary.
- Checkpoint/maintenance hints when exposed safely.
- Copy dashboard summary.

### Non-Goals

- Historical growth tracking.
- Automated tuning recommendations.
- Query performance profiling.

## 14. EXPLAIN Visualization

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** `design/SPEC.md` pinned engine SQL surface

### Why This Matters

`EXPLAIN` and `EXPLAIN ANALYZE` are already part of the pinned SQL surface, but
raw plan output is hard to scan in a grid. A tree or indented table would make
basic plan structure visible without committing to a full diagnostics suite.

### Scope

- Detect `EXPLAIN` and `EXPLAIN ANALYZE` result sets.
- Render plan output as a tree or indented table.
- Show operation, estimated rows, actual rows when present, and table/index
  references.
- Copy raw plan text.

### Non-Goals

- Plan comparison.
- Index recommendation engine.
- Runtime profiler.

## 15. Data Visualization From Query Results

**Status:** `TODO`
**Future Version:** vNext+2
**Source of truth:** `design/adr/0030-charting-library-and-visualization-contract.md`

### Why This Matters

Charts turn query results into analysis. This remains a strong feature, but it
should consume the same typed result metadata used by exports and editors.

### Scope

- Visualize button in the results pane.
- Initial chart types: line, bar, pie, scatter.
- Assign result columns to axes and series.
- Export chart as PNG.
- Respect app theme and result paging.
- Revisit spatial/map visualization after native spatial UX is stable.

### Non-Goals

- Dashboard canvas.
- Real-time streaming charts.
- Full GIS/map workbench in the first slice.

## 16. Import/Export Profile Persistence, GUI <-> Headless

**Status:** `TODO`
**Future Version:** vNext+2
**Source of truth:** `design/adr/0022-headless-cli-import-mode-and-plan-file.md`,
`design/adr/0029-workspace-project-file-and-query-library.md`

### Why This Matters

The GUI import wizard and headless `--plan` mode should converge into one
repeatable workflow. Users should be able to configure in the GUI, save a plan,
and run the same plan in automation.

### Scope

- Save import plans from the wizard.
- Load and validate import plans in the wizard.
- Save export profiles.
- Add headless export profile concept.
- Document the plan/profile schema.
- Include v2.5.x native type mappings in saved plans.

### Non-Goals

- Plan chaining.
- Scheduling.
- Cloud profile sharing.

## 17. Parquet And Excel Export

**Status:** `TODO`
**Future Version:** vNext+2
**Source of truth:** `design/adr/0031-parquet-excel-export-dependency-strategy.md`,
`design/PRD.md`, `design/SPEC.md`

### Why This Is Deferred

Both formats are valuable, but both require dependency and packaging decisions.
They should inherit the typed export semantics established by JSON/CSV rather
than define their own inconsistent mappings for v2.5.x values.

### Scope

- Re-evaluate Dart and FFI options.
- Define native DecentDB type mappings.
- Stream large result sets safely.
- Add dependency/license review before implementation.

### Non-Goals

- Implementing Parquet and Excel in the same first change.
- Replacing CSV/JSON as the core export path.

## 18. Richer Import Transforms And Connector Expansion

**Status:** `TODO`
**Future Version:** vNext+2
**Source of truth:** `design/adr/0033-computed-column-transforms-during-import.md`,
`design/IMPORT_SUPPORT_PLAN.md`

### Why This Is Deferred

Decent Bench already has broad import coverage. Additional transforms and
connectors are valuable for power import users, but current DecentDB-native
types, metadata, and branch safety should become first-class before adding more
surface area.

### Scope

- Computed columns.
- Conditional row filtering.
- Column reordering.
- Default value assignment.
- Deduplication strategies.
- Fixed-width, ODS, DuckDB, Parquet import, PostgreSQL dump, and live database
  connector expansion per `IMPORT_SUPPORT_PLAN.md`.
- Type override controls for v2.5.x native DecentDB types.

### Non-Goals

- Arbitrary scripting during import.
- Connector marketplace.
- Server-hosted import automation.

## BACKLOG - Query-Plan And Performance Diagnostics

**Status:** `BACKLOG`
**Future Version:** Future
**Source of truth:** Needs ADR/spec

A full diagnostics suite goes beyond EXPLAIN visualization to include:

- plan comparison across query revisions
- index recommendations
- runtime profiling
- historical plan tracking
- query performance advisories

This should follow after lightweight EXPLAIN visualization lands and user
feedback confirms that deeper diagnostics are worth the product and engineering
scope.

## Near-Term Sequence

This sequence reflects the impact-ordered priority ranking from the Status Map.

1. **DecentDB v2.5.1 engine upgrade and compatibility hardening**: update the
   pinned engine, refresh native asset handling, and add v2.5.x fixture coverage.

2. **Tooling metadata and query-contract bridge**: expose metadata and query
   contracts through the bridge so later UI work can depend on stable engine
   facts.

3. **Native semantic and spatial type UX**: make new v2.5.x values visible and
   correctly encoded in schema views, result grids, copy, import, and export.

4. **Branch, snapshot, diff, restore, and safe-run workbench**: revise ADR-0032
   and build the branch/snapshot safety workflow on native DecentDB primitives.

5. **Query parameterization UI powered by query contracts**: replace raw JSON
   parameter editing with a typed parameter panel.

6. **Table data editor, type-aware and branch-safe**: implement inline editing
   on top of query contracts, native type editors, and branch/snapshot safety.

7. **Saved queries and workspace projects**: persist named queries, parameter
   defaults, query contracts, and schema fingerprints.

8. **JSON and NDJSON export with typed metadata**: ship the low-dependency
   export format once native value serialization is defined.

9. **Query tab history**: expose already-stored per-tab execution history.

10. **Schema browser expansion and v2.5.x metadata presentation**: finish object
    coverage and display the richer native metadata.

11. **Schema-first strongly typed SDK generation prototype**: write the ADR and
    prove one generator path using the new metadata surface.

12. **Column statistics panel**: add lazy, type-aware data profiling.

13. **Database statistics dashboard**: add database-level visibility for files,
    WAL, object counts, branches, and snapshots.

14. **EXPLAIN visualization**: render plan output as a scannable tree/table.

15. **Data visualization**: add charts after result metadata and typed values are
    stable.

16. **Import/export profile persistence**: unify GUI and headless repeatable
    workflows.

17. **Parquet and Excel export**: proceed after dependency evaluation and typed
    export semantics settle.

18. **Richer import transforms and connector expansion**: continue import power
    features after v2.5.x-native workflows are stable.
