# Decent Bench Future Wins

**Status:** Agent feedback consolidation refresh
**Last reviewed:** 2026-05-22
**Purpose:** Product and engineering priority index for future-facing work that
is not actively being implemented right now.

This document consolidates the Future Win suggestions produced by multiple
coding agents, removes duplicates, groups closely related ideas into coherent
enhancements, and ranks the result by estimated user impact.

Decent Bench is a local-first, DecentDB-first workbench. The strongest future
work is therefore work that improves the core loop:

1. bring messy or external data into a local DecentDB file,
2. prove what happened during import,
3. inspect, query, and shape the data safely,
4. export or rerun the shaped result repeatably.

This file is a roadmap index. It is not, by itself, an implementation spec.
Any feature below that changes persistent formats, security posture, execution
contracts, import/export behavior, branch semantics, dependency strategy, or
user-visible product scope still needs an ADR and SPEC/PRD alignment before
implementation.

## Review Basis

This refresh considered:

- `design/PRD.md`
- `design/SPEC.md`
- `design/IMPORT_SUPPORT_PLAN.md`
- the previous `design/FUTURE_WINS.md`
- recent ADRs, especially:
  - `design/adr/0022-headless-cli-import-mode-and-plan-file.md`
  - `design/adr/0029-workspace-project-file-and-query-library.md`
  - `design/adr/0031-parquet-excel-export-dependency-strategy.md`
  - `design/adr/0032-database-snapshot-and-safe-run.md`
  - `design/adr/0034-schema-first-sdk-generation-prototype.md`
  - `design/adr/0042-lua-extension-management-trust-model.md`
  - `design/adr/0044-live-connections-and-menu-deferrals.md`
- agent suggestions covering ingestion, validation, query workflow, results
  grid UX, automation, reporting, extensibility, collaboration, AI, and
  external integrations.

## Consolidation Rules

The agent feedback used different names for overlapping ideas. This refresh
uses these consolidation rules:

- If two ideas solve the same user job, they are grouped as one enhancement.
  For example, "statistical profiler", "data quality dashboard", "anomaly
  detection", and "validation report" are one data quality suite.
- If one idea is a user workflow and another is an implementation mechanism,
  the workflow owns the backlog item. For example, branch-backed import is
  grouped under safe import preview rather than tracked as a separate abstract
  branch API item.
- If an idea is already covered by current foundations, it is not ranked as a
  new Future Win unless there is a clear next pass.
- If an idea conflicts with current PRD/SPEC non-goals, it is either pushed to
  strategic/ADR-gated status or deferred.
- Broad platform expansions such as collaboration, cloud publish, mobile, AI,
  and marketplaces rank below local import/query/export improvements unless
  future product strategy changes.

## Priority Scale

| Priority | Meaning |
|---|---|
| `P0` | Highest 80/20 user value. Strongly reinforces the DecentDB-first import, trust, query, and export loop. Good candidate for near-roadmap planning. |
| `P1` | Strong next wave. Broadly useful and aligned with the workbench mission, but usually larger or less urgent than `P0`. |
| `P2` | Valuable targeted enhancement. Worth doing when the relevant feature area is active or user demand is clear. |
| `P3` | Strategic or architecture-heavy. Needs an ADR before implementation and may require PRD/SPEC scope expansion. |
| `P4` | Defer unless product direction changes. Often conflicts with local-first/single-user scope or has lower core workflow impact. |

## Status Values

| Status | Meaning |
|---|---|
| `TODO` | Prioritized roadmap work that can be specified when capacity exists. |
| `BACKLOG` | Valuable, but blocked on larger product scope, dependency evaluation, public APIs, or clear user demand. |
| `INVESTIGATE` | Worth evaluating, but value, technical fit, dependency fit, or product boundary is not yet clear. |
| `DEFER` | Do not pursue unless product strategy changes or strong demand appears. |

## ADR Gate Values

| Gate | Meaning |
|---|---|
| `None for backlog` | Adding the item to this roadmap does not require another ADR. Implementation still follows normal ADR policy. |
| `Existing ADR` | The broad decision is already covered by an ADR, but implementation may still need updates. |
| `ADR before implementation` | Do not implement without a new or updated ADR. |
| `Likely PRD/SPEC update` | The idea changes product boundaries enough that PRD/SPEC alignment is expected before implementation. |

## Product Guardrails

Future work should preserve these constraints:

- Keep DecentDB as the primary workspace and destination.
- Keep import/export/query work off the UI thread.
- Preserve paging and streaming by default. Do not materialize large result
  sets just to power a convenience feature.
- Keep data local by default.
- Prefer Apache 2.0-compatible dependencies. Validate licenses before adding
  any package and update third-party notices as required.
- Avoid turning Decent Bench into a general database administration client.
- Avoid collaboration, cloud, or live external database management as near-term
  scope unless explicitly accepted through PRD/SPEC and ADR updates.
- Treat branch/snapshot functionality as DecentDB-native where possible and do
  not call private binding internals.

## Current Foundations

The following shipped or present foundations should not be treated as new Future
Wins unless the item below names a clear next pass:

- DecentDB-first desktop workspace with drag-and-drop open/import entry point.
- Import registry covering common delimited, spreadsheet, structured document,
  web/markup, embedded database, dump, and archive families.
- Recognized-but-unavailable connector states for fixed-width, ODS, DuckDB,
  Parquet import, PostgreSQL plain dump expansion, DBF/Access, XZ, clipboard
  tables, PDF tables, and related roadmap formats.
- Generic import row-local transform model for filters, default values,
  computed columns, column ordering, and deduplication.
- Headless CLI import mode with versioned plan/profile validation.
- Schema browser expansion for triggers, constraints, generated columns, temp
  objects, native type details, enum labels, spatial metadata, search/filter,
  and branch context.
- DecentDB tooling metadata bridge with schema fingerprints and query
  contracts.
- Query-parameterized SQL execution with typed fields driven by contracts.
- Multi-tab SQL editor with schema-aware autocomplete, snippets, formatter,
  per-tab results, and best-effort cancellation.
- Paged/virtualized results grid.
- Per-tab query history and global query history dialog.
- Safe-run prompts for mutating/destructive SQL.
- App-owned branch/snapshot domain boundary, currently limited by public Dart
  binding availability.
- Type-aware inline table editor for editable single-table result sets.
- Saved query library and workspace project manifests.
- TypeScript SDK-generation prototype.
- Column statistics panel and database statistics dashboard.
- Lightweight EXPLAIN visualization.
- Basic data visualization from loaded query results.
- Read-only ERD viewing and image export.
- CSV, JSON, NDJSON, and Excel exports.
- Import/export profile persistence shared by GUI and headless workflows.
- TOML configuration, desktop preferences, command registry, native menu
  bridge, command palette, in-app help, and ADR-governed design process.

## Existing Future Commitments Still Active

These items remain important from the earlier roadmap and are folded into the
ranked index below:

### Public Branch/Snapshot API Integration

Decent Bench already has the branch/snapshot workbench surface, branch-aware
safe-run prompts, guarded restore/merge UI concepts, and branch-local gateway
contracts. Production wiring is blocked until public DecentDB Dart APIs expose
the required native branch/snapshot operations.

Relevant future work:

- native branch execution,
- native snapshot creation/deletion,
- branch-local import and edit sessions,
- large-import "run on branch",
- project branch preference activation.

### Parquet Export Writer

Excel export ships through the approved `archive` dependency path. Parquet
export remains future work until a maintained Apache-compatible Dart or FFI
writer is selected, validated for Linux/macOS/Windows packaging, and tested for
incremental writes.

Parquet import is tracked separately in connector expansion because reader and
writer dependency constraints may resolve independently.

### SDK Generation CLI And UI

The schema-first SDK-generation prototype has an internal IR and TypeScript
declaration output. A user-facing workflow should expose the same IR through a
stable CLI/UI after project-file workflows are stable.

Example future command shape:

```text
dbench generate-sdk --project <workspace.dbench-project.toml> \
  --language typescript --out <directory>
```

### Connector Expansion

The import registry remains the source of truth for supported and recognized
formats today. The planned modular import catalog should become that source of
truth before large new connector waves. Future connector work should prioritize
broad value, streaming behavior, and Apache-compatible distribution.

### Query-Plan And Performance Diagnostics

The implemented EXPLAIN visualization is intentionally lightweight. A full
diagnostics suite should cover plan comparison, index recommendations, runtime
profiling, historical plan tracking, and query performance advisories.

## Consolidated Priority Index

| Rank | Priority | Status | Enhancement | Consolidated Scope | Why This Rank | ADR Gate |
|---:|---|---|---|---|---|---|
| 1 | `P0` | `TODO` | Modular import architecture and module catalog | Convert current import formats into declarative built-in modules with TOML manifests, docs, fixtures, capability declarations, adapter bindings, and docs validation | Highest leverage prerequisite for broad, high-fidelity import growth; prevents dozens of future formats from becoming hardcoded one-offs | Existing ADRs for plan; update ADRs if implementation changes the contract |
| 2 | `P0` | `TODO` | Data quality, profiling, and validation suite | Profiling dashboard, validation rules, anomaly/outlier detection, duplicate summaries, reconciliation reports, exportable quality reports | Highest trust-builder after import; helps users decide whether imported data can be queried or exported safely | Existing ADRs for plan; implementation follows accepted ADRs |
| 3 | `P0` | `TODO` | Import/export recipe rerun and profile reuse | Re-run last import/export, saved recipe/profile library, shareable TOML recipes, GUI and CLI reruns | Directly supports repeatable local workflows and completes existing deferred menu commands | Existing ADR; update ADR before implementation if recipe contract changes |
| 4 | `P0` | `BACKLOG` | Clipboard table import | Paste TSV/CSV/HTML table/JSON table data into import wizard with preview and type inference | High-frequency convenience feature for spreadsheet, browser, and portal workflows | ADR before implementation if clipboard formats or persistent profile contract changes |
| 5 | `P0` | `BACKLOG` | Safe import preview and branch-backed sandbox | Dry-run import preview, schema/data diff before commit, import on branch, merge/discard, rejected-row repair loop | Strong DecentDB-specific safety story for messy imports and table edits | Existing ADR for branch model; update ADR before implementation |
| 6 | `P0` | `TODO` | Multi-file batch import | Drop/import multiple files, folder/archive selection, shared or per-file wizard settings, dependency ordering | Extends the front-door workflow and removes repeated wizard friction | ADR before implementation |
| 7 | `P1` | `TODO` | Schema, data, database, branch, and query diff tools | Compare tables, query results, databases, branches, snapshots; show row, schema, type, and count deltas; optional migration SQL | Broad validation and debugging value after imports, edits, and query refactors | ADR before implementation |
| 8 | `P1` | `TODO` | Headless query/export automation | `dbench query`, headless export, streaming export, scheduled import/export/query jobs, watch folders | Strong for power users and scripting; reuses CLI posture | ADR before implementation |
| 9 | `P1` | `TODO` | Results grid power tools | Cell context menu, filter/exclude by value, copy as WHERE/INSERT/JSON/Markdown, local page filter/sort, find, column widths, conditional formatting | High daily-touch value with limited product-scope risk if kept page-aware | ADR only if persistence or mutation semantics change |
| 10 | `P1` | `TODO` | Query parameter sets and dashboard forms | Saved parameter sets, defaults, validation, query form/dashboard panel, quick switching for saved reports | Makes existing typed query contracts much more reusable | ADR before implementation if project-file contract changes |
| 11 | `P1` | `TODO` | Smarter import inference and reusable type profiles | ISO dates, currency, UUID, enum, geo inference, column-name patterns, reusable type-coercion profiles, import recommendations | Reduces manual override work in common imports | ADR before implementation if inference/profile formats persist |
| 12 | `P1` | `BACKLOG` | Query performance diagnostics suite | EXPLAIN ANALYZE, runtime profiling, slow-query history, plan comparison, index/advisor hints, regression tracking | Fits the "Bench" identity and helps developers optimize local datasets | ADR before implementation |
| 13 | `P1` | `TODO` | Provenance, lineage, and audit metadata | Source path/hash, import profile, transform plan, warnings, row counts, timestamps, query/table impact analysis, mutation/import audit trail | Helps users reproduce, trust, and debug data shaping workflows | ADR before implementation |
| 14 | `P1` | `TODO` | Global database search | Search values across selected tables/views with paged results and quick navigation | Common discovery workflow for unfamiliar imported data | ADR only if index/persistence strategy is added |
| 15 | `P1` | `BACKLOG` | Parquet, DuckDB, ODS, fixed-width, and other connector expansion | Prioritized import formats from `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`; Parquet import tracked separately from Parquet export | Expands the "front door into DecentDB" with high-value source families; should build on the module catalog | ADR/dependency review before each major connector |
| 16 | `P2` | `BACKLOG` | Incremental sync and merge/upsert import modes | Append, replace, ignore, upsert/merge by key, conflict handling, recurring refresh support | Valuable for recurring imports but changes import semantics materially | ADR before implementation |
| 17 | `P2` | `BACKLOG` | Advanced transform library | Regex extraction, split/merge columns, lookup joins, value mapping, date parsing presets, reusable transform presets | Useful once base import workflows and profiles are stable | ADR before implementation |
| 18 | `P2` | `TODO` | Query contract tests and regression harness | Saved queries as assertions for columns, types, row counts, sample values, performance baselines; CLI test runner | Strong developer/CI value and builds on query contracts | ADR before implementation |
| 19 | `P2` | `TODO` | Workspace organization and portability | Tab sessions, bookmarks, annotations, query collections, workspace templates, portable workspace snapshots | Improves daily organization without changing the database engine model | ADR before implementation if project-file format changes |
| 20 | `P2` | `BACKLOG` | Notebooks, dashboards, and structured reports | Markdown plus SQL notebooks, pinned query/chart dashboards, report packs, HTML/PDF export | High analyst/reporting value but larger product surface | ADR before implementation |
| 21 | `P2` | `BACKLOG` | Pivot tables and richer visualization | Pivot/crosstab builder, histograms, box plots, heatmaps, area charts, chart templates | Useful for exploration and reporting after query results exist | ADR only if new dependency or persistent chart contract changes |
| 22 | `P2` | `TODO` | Data masking and anonymized export | Redact, hash, pseudonymize, shuffle, or partially mask columns during export | Strong privacy fit for safe sharing and test datasets | ADR before implementation |
| 23 | `P2` | `TODO` | Accessibility and high-contrast audit | Screen reader results grid support, keyboard-only coverage, focus indicators, high-contrast mode, WCAG audit | Important product quality and broad usability work | ADR only if theme/config contract changes |
| 24 | `P2` | `TODO` | Database maintenance and workspace health panel | VACUUM, ANALYZE, integrity check, database size, native library/config/CLI doctor, stale sidecar checks | Practical support surface for local files and packaging issues | ADR before implementation if destructive operations or new diagnostics contracts are added |
| 25 | `P2` | `TODO` | SQL linting and static analysis | Warnings for missing WHERE on mutations, SELECT star, implicit coercion, wide scans, unindexed joins | Useful guardrail before execution and complements safe-run | ADR only if lint rules become persistent/project-enforced |
| 26 | `P2` | `TODO` | Documentation and onboarding in-app | Offline DecentDB SQL reference, sample datasets, guided tutorials, query explanation mode, shortcut trainer | Helps users complete the first import/query/export loop faster | None for backlog |
| 27 | `P3` | `BACKLOG` | Cross-DB and multi-workspace querying | Attach multiple `.ddb` files, cross-workspace execution, multi-file workspace panels | Useful, but conflicts with previous multi-workspace non-goal and needs scope decision | Likely PRD/SPEC update and ADR before implementation |
| 28 | `P3` | `INVESTIGATE` | Geospatial result view | Map/table dual view, WKT/WKB/GeoJSON copy/export, offline-capable rendering defaults | Strong value for spatial users, narrower audience and dependency-sensitive | ADR/dependency review before implementation |
| 29 | `P3` | `BACKLOG` | Extension, plugin, and scripting system | Custom importers/exporters/visualizers, Lua lifecycle UI, extension marketplace, trusted script execution | Strategic extensibility with high security and compatibility cost | Likely PRD/SPEC update and ADR before implementation |
| 30 | `P3` | `BACKLOG` | Local REST/API/mock server and polyglot SDKs | Local HTTP/IPC server, mock backend bundle, Python/Rust/Dart SDK generation | Useful developer expansion, but not core import/query/export UX | ADR before implementation |
| 31 | `P3` | `BACKLOG` | Live read-only source imports with secure credentials | PostgreSQL/MySQL/SQL Server imports, URL/S3 pulls, SSH tunnels, OS credential storage | Valuable source expansion but high security/support burden | Existing ADR notes deferral; new ADR before implementation |
| 32 | `P3` | `INVESTIGATE` | SQL editor power-user layer | SQL refactoring assists, Vim/modal mode, keyboard macros, advanced snippets | Valuable for some power users, lower broad impact than import/data trust | ADR only if editor architecture or persistence changes |
| 33 | `P4` | `DEFER` | AI and natural-language query assistant | Natural language to SQL, explain results, query error repair, optimization suggestions | Potentially useful, but privacy, dependency, cost, and product-positioning risks are high | Likely PRD/SPEC update and ADR before implementation |
| 34 | `P4` | `DEFER` | Collaboration and approval workflows | Real-time collaboration, query review, RBAC, shared workspaces, presence, permissions | Explicitly outside local-first single-user center today | PRD/SPEC update required |
| 35 | `P4` | `DEFER` | External integration hub and companion apps | BI connectors, webhooks, Zapier/Make, mobile companion, cloud publish, IDE plugins | Expansionary and lower fit for near-term local workbench roadmap | PRD/SPEC update required |
| 36 | `P4` | `DEFER` | UI customization marketplace and theme extensions | Toolbar customization, theme marketplace, UI extension packs | Nice-to-have but low core workflow impact | ADR only if extension/config contracts change |

## P0 Detailed Candidates

The `P0` group should be considered the highest-value backlog set. These items
reinforce Decent Bench's strongest identity: import into DecentDB, verify what
happened, query safely, and rerun or export the result.

### 1. Modular Import Architecture And Module Catalog

**Detailed plan:** `design/WIN_IMPORT_MODULAR_PLAN.md`

**Consolidates suggestions named:**

- modular import engine,
- import modules,
- format module manifests,
- import adapter catalog,
- pluggable import architecture,
- import format registry expansion foundation,
- Python-backed import worker foundation,
- typed import batch protocol,
- source-format capability catalog.

**User job:**

Users should be able to drag or pick a growing variety of files and get one
coherent Decent Bench import experience. The app should not become brittle as
new formats are added.

**Core scope:**

- Add a built-in import module catalog with one module directory per source
  format or wrapper.
- Use declarative TOML manifests for:
  - source id,
  - display name,
  - status,
  - priority,
  - detection rules,
  - extensions,
  - capabilities,
  - adapter binding,
  - supported actions,
  - options,
  - type-fidelity notes,
  - limitations,
  - module-specific quality checks,
  - fixtures,
  - documentation links.
- Convert all current registry entries into built-in modules.
- Keep executable behavior behind reviewed Dart adapters or reviewed
  worker-backed adapters.
- Treat SQLite as a source module, not as the canonical staging layer.
- Make DecentDB typed schema and typed batches the canonical import target.
- Make module metadata drive drag/drop detection, file picker routing,
  unsupported-format messaging, help text, and docs validation.
- Keep external third-party modules out of scope until a separate trust model
  is accepted.

**First useful slice:**

Create the manifest schema, built-in module directory layout, parser,
validator, and compatibility layer that derives the existing
`ImportFormatRegistry` metadata from module manifests without changing runtime
import behavior.

**Design constraints:**

- TOML manifests are declarative metadata only.
- Manifests must not contain scripts, shell commands, dynamic library paths, or
  executable import logic.
- Every long-running inspect/preview/import action must remain off the UI
  thread.
- All existing supported formats must continue to work while the conversion is
  underway.
- Module conversion must not imply support for external plugins.
- New high-fidelity formats should use a typed DecentDB handoff, not temporary
  SQLite staging.

**ADR need:**

ADR-0049, ADR-0050, ADR-0051, and ADR-0052 cover the built-in module manifest
contract, adapter/typed-batch contract, worker-backed module protocol, and
external module trust boundary. Update or supersede them before implementation
if the contract changes.

### 2. Data Quality, Profiling, And Validation Suite

**Consolidates suggestions named:**

- statistical table profiler,
- data profiling dashboard,
- data quality profiling report,
- anomaly detection dashboard,
- import validation rules,
- validation wizard,
- data reconciliation reports,
- duplicate detection wizard,
- data quality checks,
- profiling-driven data quality reports.

**User job:**

After importing a spreadsheet, SQLite database, dump, or structured file, users
need to know whether the data is trustworthy before they build queries or
exports on top of it.

**Core scope:**

- Table-level and column-level profile summary:
  - row count,
  - null count and null percentage,
  - empty string percentage where applicable,
  - distinct count and cardinality estimate,
  - min/max,
  - mean/median where type-appropriate,
  - value distribution summaries,
  - malformed date/time string counts,
  - high-cardinality and potential-key indicators.
- Import quality summary:
  - type coercion failures,
  - skipped rows,
  - transformed rows,
  - warning counts,
  - source row count versus imported row count.
- Validation rules:
  - required/non-null,
  - uniqueness,
  - regex/pattern,
  - numeric/date ranges,
  - referential checks,
  - allowed value sets.
- Violation report:
  - paged violation rows,
  - grouped issue summary,
  - copy/export report action.
- Duplicate and near-duplicate review:
  - exact duplicate detection first,
  - fuzzy matching only after the exact workflow proves useful and performant.

**First useful slice:**

Add a per-table "Quality" view that computes null counts, distinct counts,
min/max, basic distribution, import row reconciliation, and a paged list of
type/coercion warnings from import metadata.

**Design constraints:**

- Must run off the UI thread.
- Must page/stream violation rows and duplicate candidates.
- Must not scan every column of very large tables synchronously from the UI.
- Should prefer DecentDB SQL aggregates and metadata over app-side full-table
  materialization.
- Should define a stable result/report model before adding exportable reports.

**ADR need:**

Create an ADR before implementation because this establishes validation report
contracts, profile storage behavior, and possibly persistent rule formats.

### 3. Import/Export Recipe Rerun And Profile Reuse

**Consolidates suggestions named:**

- import/export recipe runner,
- re-run last import,
- re-run last export,
- import/export profile sharing,
- team import profile sharing,
- import template library,
- scheduled profile reuse,
- headless CLI profile extension,
- recipe persistence.

**User job:**

Users often receive the same source file shape repeatedly. They should not have
to reconfigure the wizard every time, and scripting users should be able to run
the same recipe without the GUI.

**Core scope:**

- Persist complete import recipes:
  - source kind,
  - selected sheets/tables/files,
  - target table naming,
  - type overrides,
  - transforms,
  - deduplication rules,
  - validation rules once available,
  - import mode,
  - profile version.
- Persist export recipes:
  - source query/table,
  - format,
  - destination,
  - column/type handling,
  - masking options once available,
  - profile version.
- Enable `Import > Re-run Last Import` and `Export > Re-run Last Export` only
  when the persisted recipe can be validated.
- Support recipe library actions:
  - save,
  - rename,
  - duplicate,
  - export to TOML/JSON if accepted,
  - import from shared file,
  - validate against current workspace.
- Reuse the same contract in GUI and headless CLI.

**First useful slice:**

Enable re-running the most recent import recipe for a local source file when
the source still exists, the target workspace is open, and the target schema
validation passes.

**Design constraints:**

- Must fail clearly when source files are missing.
- Must detect stale schema fingerprints.
- Must handle changed source shape without silently applying old mappings.
- Must not store credentials in plaintext when live imports arrive.
- Should remain compatible with existing headless import plan/profile work.

**ADR need:**

ADR-0044 already identifies recipe persistence as the gate for rerun commands.
Update or create a focused ADR before implementation to define the durable
recipe format and validation behavior.

### 4. Clipboard Table Import

**Consolidates suggestions named:**

- clipboard table paste import,
- clipboard table preview,
- clipboard table capture,
- clipboard-to-table fast intake,
- HTML table fragment paste,
- TSV/CSV clipboard import.

**User job:**

Users frequently copy data from Excel, Google Sheets, internal web portals,
reports, browser tables, terminals, and JSON responses. Requiring a temporary
file creates unnecessary friction.

**Core scope:**

- Detect structured clipboard content:
  - TSV,
  - CSV-like text,
  - HTML table fragments,
  - Markdown table text if supported later,
  - JSON arrays of objects when clear.
- Launch the existing import wizard with a clipboard-backed source.
- Show preview before commit.
- Allow column naming, type override, and target table selection.
- Record clipboard import metadata without storing sensitive clipboard payloads
  beyond the import session unless explicitly saved as part of a recipe.

**First useful slice:**

Support TSV clipboard data from spreadsheet copy operations and route it
through the generic delimited import preview/type inference flow.

**Design constraints:**

- Clipboard inspection must be quick and cancellable.
- Large clipboard payloads must not freeze the UI.
- The app should not monitor clipboard contents continuously.
- The user should explicitly initiate paste/import.
- Sanitization is required for HTML fragments.

**ADR need:**

Create an ADR before implementation if clipboard source metadata becomes a
persistent recipe source or if HTML sanitization rules are accepted.

### 5. Safe Import Preview And Branch-Backed Sandbox

**Consolidates suggestions named:**

- import dry-run,
- preview diff,
- branch-backed import sandbox,
- schema diff on re-import,
- data reconciliation before commit,
- rejected row repair loop,
- branch comparison,
- import-on-branch,
- merge/discard after review.

**User job:**

Before committing a messy import or table edit, users need to see what will
change and have a safe way to discard bad results.

**Core scope:**

- Import dry-run summary:
  - new tables,
  - changed tables,
  - added/removed/changed columns,
  - type coercion warnings,
  - estimated row counts,
  - skipped/rejected row counts,
  - storage estimate where feasible.
- Re-import diff:
  - target schema drift,
  - source-to-target mapping changes,
  - row-count deltas.
- Branch-backed execution:
  - run import or risky edit on a DecentDB branch,
  - inspect branch diff,
  - merge or discard.
- Rejected row repair:
  - quarantine failed rows into a side table or job-owned staging area,
  - allow mapping/value correction,
  - retry only rejected rows.

**First useful slice:**

Add import dry-run summaries and schema diff previews without native branch
execution. Once public branch APIs are available, wire the same preview model to
branch-local import sessions.

**Design constraints:**

- Branch support must use public DecentDB APIs.
- Diff views must be paged/streamed.
- Preview must be honest when estimates are approximate.
- Repair loops must not mutate source files.
- Staging/quarantine tables must have clear lifecycle rules.

**ADR need:**

ADR-0032 covers the native branch/snapshot safety model. Update it or create a
focused import-sandbox ADR before implementation, especially for staging table
lifecycle and merge/discard semantics.

### 6. Multi-File Batch Import

**Consolidates suggestions named:**

- multi-file batch import,
- folder import,
- multi-file archive import,
- per-file wizard configuration,
- shared profile application,
- dependency ordering.

**User job:**

Users often receive a folder of CSVs, several related spreadsheets, a collection
of JSON files, or an archive containing many supported sources. Running the
wizard repeatedly is slow and error-prone.

**Core scope:**

- Allow selecting or dropping multiple importable sources.
- Show a batch queue with per-source detected type and status.
- Support shared defaults across the batch:
  - target database,
  - naming convention,
  - import mode,
  - default type profile,
  - validation profile once available.
- Allow per-source overrides.
- Detect dependency/order hints where possible:
  - table names,
  - foreign-key-like columns,
  - archive ordering,
  - explicit user ordering.
- Summarize batch success, warnings, failures, and skipped sources.

**First useful slice:**

Support multiple delimited/text files with a shared import profile and per-file
target table names.

**Design constraints:**

- Must preserve responsive progress and cancellation.
- Must continue importing independent files when one file fails only if the
  chosen batch policy allows it.
- Must not hide partial failure.
- Must support retrying failed files.

**ADR need:**

Create an ADR before implementation because this changes the PRD/SPEC
single-file import boundary and introduces batch job semantics.

## P1 Detailed Candidates

### 7. Schema, Data, Database, Branch, And Query Diff Tools

**Consolidates:**

- SQL diff tool,
- database comparison tool,
- data diff/compare tool,
- query result diffing,
- schema diff/migration generator,
- branch comparison,
- schema drift detection.

**Value:**

Diff answers one of the most common questions after import, edit, migration, or
query refactor: "What changed?"

**Recommended progression:**

1. Query result diff for two loaded result sets with matching columns.
2. Schema diff for two schema snapshots.
3. Table diff using primary key or selected key columns.
4. Branch/database diff once native APIs and performance constraints are clear.
5. Optional migration script generation after schema diff behavior stabilizes.

**Constraints:**

- Use keys/checksums/page cursors rather than full materialization.
- Make approximate or sampled comparisons explicit.
- Keep migration generation separate from read-only diff until the UX is safe.

### 8. Headless Query/Export Automation

**Consolidates:**

- CLI query execution mode,
- headless export mode,
- scheduled query execution,
- scheduled import/export jobs,
- watch folder auto-import,
- cron-style scheduler,
- incremental/streaming export,
- export to remote destinations.

**Value:**

Power users and developers need Decent Bench workflows to run in scripts and
automation environments without opening the desktop UI.

**Recommended progression:**

1. `dbench query --sql ... --out json/csv`.
2. Headless export from saved query or table using existing export formats.
3. Streaming export while query pages are produced.
4. Recipe-driven scheduled jobs.
5. Watch folders and remote destinations only after source/destination security
   contracts are accepted.

**Constraints:**

- The same paging/export contracts used by the UI should power CLI export.
- Scheduling should not imply background daemon behavior until that operating
  model is accepted.
- Remote destinations require credential and retry policies.

### 9. Results Grid Power Tools

**Consolidates:**

- cell context menus,
- filter by this value,
- exclude this value,
- copy as INSERT,
- copy as WHERE clause,
- copy JSON/Markdown/SQL,
- client-side page filtering/sorting,
- find and replace in grid,
- column width persistence,
- auto-fit,
- conditional formatting,
- bulk row operations.

**Value:**

The results grid is one of the most frequently touched surfaces. Small
improvements here reduce friction every day.

**Recommended progression:**

1. Context menu actions for single cell/row copy and filter SQL generation.
2. Column width persistence and auto-fit.
3. Loaded-page find/filter/sort clearly labeled as page-local.
4. Conditional formatting rules for nulls, thresholds, and type patterns.
5. Bulk row operations only after table-editing safety and branch behavior are
   mature.

**Constraints:**

- Do not imply page-local filtering is a full query filter.
- Mutating grid operations must honor existing safe-run and table-editor
  contracts.
- Persistence should use workspace/project state intentionally, not ad hoc
  local storage.

### 10. Query Parameter Sets And Dashboard Forms

**Consolidates:**

- query parameter preset manager,
- query parameter sets UI,
- parameterized query builder UI,
- interactive SQL parameter binding UX,
- parameterized query dashboard,
- advanced query variable system.

**Value:**

Saved parameterized queries become more useful when users can save named
parameter values and run them without editing SQL.

**Recommended progression:**

1. Named parameter sets per saved query.
2. Defaults and validation messages from query contracts.
3. Quick switch between parameter sets in the SQL editor.
4. Form-style dashboard panels for saved report queries.
5. Environment profiles only if project scope requires them.

**Constraints:**

- Keep SQL as the source of truth.
- Do not create a separate non-SQL query language.
- Persist parameter sets through the project manifest only after the format is
  accepted.

### 11. Smarter Import Inference And Reusable Type Profiles

**Consolidates:**

- smart data type inference v2,
- type coercion profile library,
- import template system,
- smart import recommendations,
- log schema synthesis where template-based.

**Value:**

Better inference means less wizard correction and cleaner imported tables.

**Recommended progression:**

1. Improve string sample detection for ISO dates, timestamps, booleans, UUIDs,
   currency, percentages, enums, and latitude/longitude pairs.
2. Save column-name pattern rules such as `*_date -> DATE`.
3. Add confidence and explanation messages to inference decisions.
4. Add recommendations for common source families.

**Constraints:**

- Users must be able to override all guesses.
- Inference should be deterministic for the same source sample.
- Expensive inference should run off-thread and be sample-bounded.

### 12. Query Performance Diagnostics Suite

**Consolidates:**

- query-plan full suite,
- EXPLAIN ANALYZE visualizer,
- execution profiler,
- historical performance baseline,
- slow-query log,
- query performance advisor,
- index recommendations,
- query cost prediction.

**Value:**

This is a strong fit for "Bench" and for developer users optimizing queries
over imported data.

**Recommended progression:**

1. Persist query duration, row count, status, and timestamp for saved queries.
2. Add slow-query filters and trends.
3. Add plan comparison for saved query revisions.
4. Add EXPLAIN ANALYZE visualization if the engine exposes stable runtime
   metrics.
5. Add advisories only after the app can explain why a recommendation is safe.

**Constraints:**

- Avoid noisy or speculative recommendations.
- Keep plan collection opt-in or bounded to avoid overhead.
- Any persisted telemetry must stay local.

### 13. Provenance, Lineage, And Audit Metadata

**Consolidates:**

- import provenance ledger,
- column-level data provenance,
- schema change audit log,
- audit trail for mutations,
- data lineage/impact analysis,
- table dependency graph,
- Git-aware workspace diff summaries.

**Value:**

Users need to know where a table came from, which transform shaped it, and what
queries or exports depend on it.

**Recommended progression:**

1. Import provenance ledger with source path/hash, profile id, transform plan,
   warnings, row counts, and timestamp.
2. Query dependency index for saved queries and export profiles.
3. Schema change log for app-mediated DDL and imports.
4. Mutation audit for table edits and DML if safe-run/table-editor workflows
   need it.

**Constraints:**

- Do not log sensitive data values by default.
- Be explicit about what Decent Bench can audit: app-mediated operations, not
  arbitrary external file mutations.
- Use stable ids and schema fingerprints where possible.

### 14. Global Database Search

**Consolidates:**

- full-text search across database,
- global database search,
- search values across selected tables/views.

**Value:**

When a user opens an unfamiliar `.ddb` file or imports a large dump, they often
start by searching for a known customer id, email, SKU, or term.

**Recommended progression:**

1. Search selected tables/columns with paged results.
2. Add type-aware search modes for text, exact value, and pattern.
3. Add recent searches and quick navigation.
4. Consider search indexes only after measuring demand and cost.

**Constraints:**

- Default search must be cancellable and bounded.
- Do not build persistent indexes without an ADR.
- Show which tables/columns are included.

### 15. Connector Expansion

**Detailed plan:** `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`

**Consolidates:**

- Parquet import reader,
- DuckDB import,
- ODS import,
- fixed-width text,
- markdown table import/export,
- log templates,
- Access/DBF,
- PostgreSQL dump expansion,
- SQL Server import,
- cloud storage import where source-only.

**Value:**

Connector expansion directly supports the "front door into DecentDB" product
direction. This item should now build on the modular import architecture rather
than adding more hardcoded registry entries.

**Recommended priority within this group:**

1. Create or promote the module manifest for the target format.
2. Add module docs, fixture plan, type-fidelity notes, and dependency notes.
3. Implement the adapter only after the module contract is in place.
4. Parquet import, because it is high-value for analytics users and separate
   from Parquet export writer constraints.
5. DuckDB import, because it overlaps with local analytics workflows.
6. ODS and fixed-width text, because they cover common spreadsheet/legacy data.
7. PostgreSQL plain dump expansion, because plain SQL dumps are common.
8. Markdown tables and log templates, because they are useful but narrower.
9. Access/DBF and SQL Server live import after dependency/driver risk is clear.

**Constraints:**

- Each major connector needs licensing review.
- Each connector must preserve streaming behavior where possible.
- Live sources need credential and cancellation contracts.
- New connectors should not bypass the module manifest, fixture, and docs
  validation workflow.

## P2 Detailed Candidates

### 16. Incremental Sync And Merge/Upsert Import Modes

This would let users choose append, replace, ignore, or upsert/merge behavior
when refreshing a table from a recurring source. It is valuable for repeatable
local ETL, but it changes import semantics and error handling enough to require
careful design.

First useful slice: upsert into a single table using explicit user-selected key
columns and a transaction-bound import job.

### 17. Advanced Transform Library

This extends import transforms beyond the current row-local basics:

- split columns,
- merge columns,
- regex extraction,
- date parsing presets,
- lookup joins,
- value mapping,
- reusable transform presets.

This should follow recipe/profile stabilization so advanced transforms can be
saved, shared, and rerun consistently.

### 18. Query Contract Tests And Regression Harness

Saved queries can become testable contracts:

- expected columns,
- expected types,
- row-count ranges,
- sample values,
- runtime thresholds,
- plan stability checks where supported.

A future CLI such as `dbench test --project <project>` would make Decent Bench
useful in CI for local DecentDB artifacts.

### 19. Workspace Organization And Portability

This group includes:

- tab sessions,
- workspace presets,
- favorites,
- bookmarks,
- query annotations,
- saved query collections,
- workspace templates,
- portable workspace snapshots.

These features improve organization for power users, but they should be added
only through the project/workspace manifest rather than scattered local state.

### 20. Notebooks, Dashboards, And Structured Reports

This group includes:

- markdown plus SQL notebooks,
- query result notebooks,
- dashboard-mode query panels,
- saved chart templates,
- structured HTML/PDF reports,
- report packs.

This is valuable for analysis and communication, but it is a larger product
surface than the current workbench loop. A first slice should reuse saved
queries and existing chart/result components rather than create a separate
runtime.

### 21. Pivot Tables And Richer Visualization

This group includes:

- pivot/crosstab builder,
- histograms,
- box plots,
- area charts,
- heatmaps,
- saved visualizations.

The first useful slice is a pivot builder over a loaded, bounded result set
with clear row/column/value controls and export back to CSV/Excel.

### 22. Data Masking And Anonymized Export

This feature applies export-time masking rules:

- redact,
- partial redact,
- hash,
- pseudonymize,
- shuffle,
- deterministic replacement.

It fits the privacy-first product stance and is useful for test/dev datasets.
It needs careful rule persistence and preview behavior before implementation.

### 23. Accessibility And High-Contrast Audit

This group includes:

- screen reader support for the results grid,
- keyboard-only navigation coverage,
- high-contrast theme,
- focus indicators,
- WCAG audit,
- theme toggle polish where not already complete.

This should be treated as product quality work rather than optional polish.

### 24. Database Maintenance And Workspace Health Panel

This group includes:

- VACUUM,
- ANALYZE,
- integrity check,
- database size/file stats,
- native library version checks,
- DecentDB CLI availability,
- migration tool availability,
- profile compatibility checks,
- stale sidecar detection.

Destructive or long-running actions need confirmation, progress, cancellation,
and clear status reporting.

### 25. SQL Linting And Static Analysis

This would add warnings before execution:

- `DELETE` or `UPDATE` without `WHERE`,
- `SELECT *` on wide tables,
- implicit type coercion,
- suspicious joins,
- missing indexes for common join/filter patterns,
- non-deterministic query patterns where relevant.

Linting should be actionable and suppressible. It should not block execution by
default unless the existing safe-run policy says otherwise.

### 26. Documentation And Onboarding In-App

This group includes:

- offline DecentDB SQL reference,
- searchable function/operator examples,
- guided import/query/export tutorials,
- sample datasets,
- query explanation mode,
- shortcut trainer.

The goal is to reduce time-to-first-success without turning the app into a
training product.

## P3 Strategic Or ADR-Gated Candidates

### 27. Cross-DB And Multi-Workspace Querying

This group includes:

- opening multiple `.ddb` files simultaneously,
- attaching multiple DecentDB files,
- cross-database joins/unions,
- cross-workspace query execution.

This is useful, but it conflicts with prior non-goals around multi-workspace
support. It needs PRD/SPEC alignment and an ADR before implementation.

### 28. Geospatial Result View

This would render spatial result data as a map/table dual view:

- WKT,
- WKB,
- GeoJSON,
- native spatial types,
- latitude/longitude pairs.

It is compelling for spatial users and aligns with DecentDB native type support,
but dependency choice, offline map behavior, and large geometry rendering need
an ADR.

### 29. Extension, Plugin, And Scripting System

This group includes:

- app-level plugin API,
- extension marketplace,
- custom importers/exporters/visualizers,
- custom SQL function libraries,
- Lua extension lifecycle UI,
- trusted transformation scripts.

This can future-proof niche needs, but it is security-sensitive and
architecture-heavy. It must not be implemented as an ad hoc script runner.

### 30. Local REST/API/Mock Server And Polyglot SDKs

This group includes:

- local REST or IPC server mode,
- saved queries exposed as endpoints,
- mock backend generator,
- Python/Rust/Dart SDK generation,
- bundled local prototype server.

This is a developer-facing expansion beyond the current workbench. It should
reuse the SDK IR and query contracts rather than invent a separate model.

### 31. Live Read-Only Source Imports With Secure Credentials

This group includes:

- PostgreSQL live import,
- MySQL/MariaDB live import,
- SQL Server live import,
- SSH tunnels,
- URL or S3-style source pulls,
- connection testing,
- OS credential storage.

ADR-0044 already defers live connection commands until the product contracts
exist. Future work must remain import-only unless PRD/SPEC explicitly expand
Decent Bench into live database browsing/querying.

### 32. SQL Editor Power-User Layer

This group includes:

- Vim/modal editing,
- keyboard macro recording,
- SQL refactoring assists,
- extract selection as CTE,
- inline subquery,
- rename column across saved queries.

These are useful for keyboard-heavy users, but they should not displace broader
import/data-trust work. Refactoring features need schema and saved-query impact
analysis to be safe.

## P4 Deferred Candidates

### 33. AI And Natural-Language Query Assistant

This group includes:

- natural language to SQL,
- explain results,
- query error diagnosis,
- optimization suggestions.

This should be deferred because it introduces privacy, model dependency, cost,
offline behavior, and product-positioning questions. It can be reconsidered if
a local-first model strategy becomes part of product direction.

### 34. Collaboration And Approval Workflows

This group includes:

- real-time collaborative workspaces,
- presence indicators,
- shared query libraries with permissions,
- RBAC,
- query review/approval for destructive queries,
- mobile approval flows.

These conflict with the current local-first, single-user product center and
should not be near-roadmap work.

### 35. External Integration Hub And Companion Apps

This group includes:

- BI tool connectors,
- webhooks,
- Zapier/Make templates,
- mobile companion app,
- one-click cloud publish,
- VS Code/JetBrains plugins.

These may be useful in a larger ecosystem strategy, but they are not central to
the current import/query/export desktop workbench.

### 36. UI Customization Marketplace And Theme Extensions

This group includes:

- toolbar customization,
- theme marketplace,
- UI extension packs.

Small configuration improvements can happen locally, but a marketplace or
extension economy is not a core backlog item.

## Recommended Near-Term Backlog Additions

If only five new backlog items are promoted from this consolidation, use:

1. Modular import architecture and module catalog.
2. Data quality, profiling, and validation suite.
3. Import/export recipe rerun and profile reuse.
4. Clipboard table import.
5. Safe import preview and branch-backed sandbox.

These are ranked highest because they deepen Decent Bench's core promise rather
than expanding into a different product category.

## ADR Notes

Individual implementation ADRs are intentionally not created for every item in
this file. Most entries are not yet accepted implementation designs. Creating
one ADR per idea now would over-specify features before discovery.

Before implementation, create or update ADRs for at least these areas:

- built-in import module manifest contract if ADR-0049 changes,
- import adapter and typed batch contract if ADR-0050 changes,
- worker-backed import module protocol if ADR-0051 changes,
- data quality rule/report persistence,
- recipe/profile persistence and validation,
- multi-file batch import job semantics,
- import dry-run and branch-backed sandbox semantics,
- schema/data/query diff algorithms and persistence,
- headless query/export CLI contracts,
- scheduled job execution model,
- provenance/audit storage,
- major connector dependencies,
- live source credential storage,
- app extension/scripting APIs,
- REST/API server mode,
- any AI integration.

## Deduplicated Idea Groups

The following source ideas were intentionally merged:

- **Import modules, module manifests, adapter catalog, typed import batches,
  Python-backed importer foundation** -> Modular import architecture and module
  catalog.
- **Profiler, validation, duplicate detection, reconciliation, anomaly
  detection** -> Data quality, profiling, and validation suite.
- **Re-run last import/export, profile sharing, import templates, recipe
  runner** -> Import/export recipe rerun and profile reuse.
- **Clipboard preview, paste table, HTML fragment paste, clipboard capture** ->
  Clipboard table import.
- **Dry-run import, schema diff before commit, branch import sandbox, rejected
  row repair** -> Safe import preview and branch-backed sandbox.
- **Batch import, folder import, multi-file archive import** -> Multi-file
  batch import.
- **SQL diff, data compare, database compare, query result diff, migration
  generator** -> Schema/data/database/branch/query diff tools.
- **CLI query mode, headless export, scheduler, watch folders, streaming
  export** -> Headless query/export automation.
- **Cell menu, filter by value, copy as SQL/JSON/Markdown, grid find,
  conditional formatting, column persistence** -> Results grid power tools.
- **Parameter presets, variable system, query dashboard forms** -> Query
  parameter sets and dashboard forms.
- **Smart inference, type profile library, import recommendations, log schema
  templates** -> Smarter import inference and reusable type profiles.
- **Slow query log, performance history, EXPLAIN ANALYZE, advisor,
  regression tracker** -> Query performance diagnostics suite.
- **Provenance ledger, lineage, audit trail, schema change log, dependency
  graph** -> Provenance, lineage, and audit metadata.
- **Notebook, dashboard, chart templates, structured reports** -> Notebooks,
  dashboards, and structured reports.
- **Plugin system, extension marketplace, Lua lifecycle, custom importers** ->
  Extension, plugin, and scripting system.
- **REST server, IPC, mock server, SDK generation expansion** -> Local
  REST/API/mock server and polyglot SDKs.
- **AI query assistant, natural language SQL, auto-fix/explain** -> Deferred AI
  and natural-language query assistant.
