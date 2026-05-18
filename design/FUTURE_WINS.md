# Decent Bench Future Wins

**Status:** Consolidated product roadmap
**Purpose:** Product and engineering priority index for Decent Bench. Dedicated
specs and ADRs remain the implementation source of truth when they exist.

Decent Bench should win by being the polished DecentDB workbench: import data,
inspect schema, run SQL, export results, and generate application-facing
artifacts without forcing users to hand-wire database access.

## Status Map

Status values:

- `TODO`: prioritized roadmap work that is not actively being implemented right now.
- `IN PROGRESS`: active implementation or design work is underway right now.
- `BACKLOG`: valuable, but blocked on an external dependency or not part of the
  near-term implementation path.

Future version values are planning buckets, not release commitments.

Items are ranked by estimated user impact — how many users benefit, how
frequently they benefit, and how materially the feature changes their workflow.

| Priority | Future Version | Status | Feature | Current Source Of Truth | Why This Rank |
|---:|---|---|---|---|---|
| 1 | vNext | TODO | Command palette (`Ctrl+Shift+P`) | New proposal | Universal — every user navigates the app every session; the menu command registry (40+ commands) already exists; a searchable palette makes every action keyboard-accessible with no new backend work |
| 2 | vNext | TODO | Table data editor (inline cell editing) | `design/adr/0028-inline-table-data-editor.md` | Universal — turns Decent Bench from a read-only query tool into a true workbench; every user who queries data also needs to fix or update it; the results grid already handles selection and copy, so the foundation is partially built |
| 3 | vNext | TODO | Saved queries and workspace projects | `design/adr/0029-workspace-project-file-and-query-library.md`, `design/PRD.md` post-1.0 scope | Near-universal — most users run the same queries repeatedly; tab persistence infrastructure already exists in `WorkspaceState`; naming, organizing, and recalling queries is the natural next layer |
| 4 | vNext | TODO | Query tab history (user-visible) | `design/SPEC.md` marked optional for MVP | Near-universal — every user who iterates on SQL wants to go back to a prior version; persistence layer already stores history entries per tab; purely a UI addition on existing infrastructure |
| 5 | vNext | TODO | JSON export | `design/PRD.md`, `design/SPEC.md` Next scope | Broad need — JSON is the universal data interchange format alongside CSV; zero external dependencies (`dart:convert` is built-in); placeholder menu item already wired; proven export pipeline to reuse |
| 6 | vNext | TODO | Database backup / snapshot | `design/adr/0032-database-snapshot-and-safe-run.md` | Universal safety concern — every user who runs DDL, destructive DML, or large imports wants a one-click safety net; trivial to implement (file copy with timestamp); builds trust and confidence in the tool |
| 7 | vNext | TODO | Column statistics panel | New proposal | Broad need — every user exploring a new or unfamiliar database wants a quick overview of value distributions, null counts, and ranges; the engine already supports all required aggregate functions; speeds up the "understand the data" phase dramatically |
| 8 | vNext+1 | TODO | Data visualization (charts from query results) | `design/adr/0030-charting-library-and-visualization-contract.md` | High impact for analysts and data explorers — differentiates Decent Bench from pure SQL editors; the engine returns structured columnar data; no visualization exists today; transforms exploration sessions into insight sessions |
| 9 | vNext+1 | TODO | Schema browser expansion (triggers, constraints, generated columns, temp objects) | `design/SPEC.md` phased object coverage | SPEC-defined gap — engine metadata already available through schema snapshot API; purely a UI gap; closes the last cataloged schema object kinds and makes the schema browser complete |
| 10 | vNext+1 | TODO | Database statistics dashboard | New proposal | Broad operational interest — database file size, per-table row counts, WAL status, index sizes; the SQLite import summary already surfaces some of this post-import; a live dashboard builds operational confidence without leaving the workspace |
| 11 | vNext+1 | TODO | EXPLAIN visualization | `design/SPEC.md` pinned engine SQL surface | Power user need — `EXPLAIN` and `EXPLAIN ANALYZE` are already validated in the Phase 1 smoke test matrix; today plan output is raw text in the grid; a structured tree/table view makes plans scannable without deeper diagnostics investment |
| 12 | vNext+1 | TODO | Query parameterization UI | New proposal | Targeted — the engine supports positional parameters and they're validated in smoke tests, but there is no UI for binding values; a parameter input panel next to the editor would unlock parameterized queries for non-programmers and make repeatable analysis safer than string interpolation |
| 13 | vNext+2 | TODO | Import / export profile persistence (GUI ↔ headless) | `design/adr/0022-headless-cli-import-mode-and-plan-file.md` (plan contract), `design/adr/0029-workspace-project-file-and-query-library.md` (project model) | Workflow multiplier — the headless CLI already defines a `--plan <plan.json>` contract but there is no GUI for creating, editing, or saving these profiles; closing this gap unifies the headless and desktop experience and enables repeatable, shareable import recipes for GUI users |
| 14 | vNext+2 | TODO | Parquet and Excel export | `design/adr/0031-parquet-excel-export-dependency-strategy.md`, `design/PRD.md`, `design/SPEC.md` Next scope | Format-specific — both require new Apache-compatible third-party dependencies and licensing review; Parquet has no mature Dart write library (likely needs FFI bridge); Excel write needs a different library than the read-only `excel` package currently in use; evaluate separately before implementation |
| 15 | vNext+2 | TODO | Richer import transforms and connector expansion | `design/adr/0033-computed-column-transforms-during-import.md` (computed columns), `design/IMPORT_SUPPORT_PLAN.md` (connector expansion) | Power import users — expands the import wizard with computed columns (deferred from MVP), conditional row filtering, column reordering, and additional format connectors per the tiered plan; broad scope, staged delivery |
| — | Future | BACKLOG | Query-plan and performance diagnostics (full) | Needs ADR/spec | Broader than EXPLAIN visualization; covers plan comparison across queries, index recommendations, runtime profiling, and historical plan tracking; follows after lightweight EXPLAIN vis lands and user feedback informs scope |
| — | Future | BACKLOG | Schema-first strongly typed SDK generation | Needs Decent Bench ADR/spec | Would turn Decent Bench into an app-integration workflow for DecentDB, but is **fully blocked** until DecentDB ships the stable schema/query-contract metadata surface; no implementation can proceed without that contract |

## Current Foundations

These are shipped foundations as of Decent Bench v1.1.0 and should not be treated
as future roadmap claims:

- DecentDB-first desktop workspace
- drag-and-drop open/import entry point
- import from 15 formats across 9 families:
  - Delimited: CSV, TSV, generic delimited
  - Spreadsheet: Excel (`.xlsx`, `.xls`)
  - Structured document: JSON, NDJSON/JSONL, XML
  - Web/markup: HTML tables
  - Database: SQLite
  - Database dump: MariaDB/MySQL-style SQL dump (MVP-lite)
  - Archive wrappers: ZIP, GZip, BZip2
- schema browser for tables, views, columns, and indexes
- multi-tab SQL editor against the pinned DecentDB SQL surface
- schema-aware autocomplete, snippets, and deterministic SQL formatter
- paged/virtualized results grid with best-effort cancellation
- CSV export
- headless CLI import mode (`--in`/`--out`/`--plan`/`--silent`)
- DecentDB native asset staging and hardened library resolution
- DecentDB-backed application logging (`Tools → View Log`)
- TOML configuration and desktop preferences
- ADR-governed design process (27 accepted ADRs)

---

## 1. Command Palette (`Ctrl+Shift+P`)

**Status:** `TODO`
**Future Version:** vNext
**Source of truth:** New proposal

### Why This Is the Highest-Impact Win

Every user navigates the app every session. Today, actions are scattered across
the native menu bar, context menus, toolbar buttons, and keyboard shortcuts.
Users must learn where each action lives — there is no single, searchable entry
point.

A command palette changes that. Press `Ctrl+Shift+P`, type a few characters, and
execute any action in the application. This is the standard productivity pattern
in VS Code, Sublime Text, IntelliJ, Obsidian, Figma, and every other tool that
takes keyboard-first workflows seriously.

The implementation surface is already well-prepared. The `MenuCommandRegistry`
defines 40+ commands with IDs, labels, and keyboard shortcut bindings. The
native menu bridge (`ADR-0011`) already routes commands. The palette is purely a
UI layer over the existing command registry: fuzzy-search command labels, show
results in an overlay, and dispatch the selected command through the same
registry.

### Why It Matters for Decent Bench Specifically

Decent Bench has a broad feature surface — import, schema browsing, query
editing, export, settings, logging. Users who discover the tool through one
workflow (e.g., importing Excel) may never discover other capabilities (e.g.,
JSON import, EXPLAIN, themes) because they aren't visible in the immediate UI.
A command palette surfaces the full capability set on demand. It also makes the
tool usable without a mouse, which matters for keyboard-oriented power users —
the primary persona defined in the PRD.

### Scope

- Searchable overlay triggered by `Ctrl+Shift+P` (macOS: `Cmd+Shift+P`)
- Real-time fuzzy matching against all registered command labels
- Display keyboard shortcut alongside each result when one is bound
- Enter to execute, Escape to dismiss
- Recent / frequently-used command ranking (optional initial scope, can land later)
- Commands that require context (e.g., "Export Results" needs an active results
  pane) should show as disabled with a reason rather than being hidden

### Non-Goals

- Custom user-defined commands
- Multi-step command chains or macros
- Natural-language command input
- Replacing the existing menu bar or toolbar

### Relationship to Existing Work

The `MenuCommandRegistry` (`lib/features/workspace/application/menu_command_registry.dart`)
already defines a typed command model with IDs, labels, and shortcut bindings.
The `WorkspaceShellController` routes these commands through a `CommandAction`
dispatch. The native menu bridge syncs command labels into the OS-native menu
bar. The palette would consume the same command registry, so all future commands
added to the menu automatically appear in the palette.

---

## 2. Table Data Editor (Inline Cell Editing)

**Status:** `TODO`
**Future Version:** vNext
**Source of truth:** `design/adr/0028-inline-table-data-editor.md`

### Why This Matters

The single biggest gap between Decent Bench and being a "true workbench" is the
inability to edit data directly. Today, the workflow for fixing a single cell
value is:

1. Write an `UPDATE` statement by hand
2. Include the correct `WHERE` clause to target the right row
3. Execute it
4. Re-run the `SELECT` to verify

This is appropriate for batch changes but punishing for ad-hoc corrections.
Compare this to DB Browser for SQLite, TablePlus, DBeaver, or DataGrip — in all
of these, you double-click a cell, type the new value, and the tool generates
and executes the correct DML behind the scenes. This is the feature that makes a
database tool feel like a workbench rather than a terminal with a pretty face.

### Why It Fits Decent Bench

Decent Bench already has the foundations:

- A virtualized, selection-aware results grid with cell/row copy support
- A query-to-cursor pipeline that knows column names, types, and the source
  table for each result column (when the query is against a single table)
- A `DecentDbBridge` isolate that can execute arbitrary SQL, including
  `UPDATE` and `INSERT`

The gap is turning the grid from read-only to read-write. Inline editing
requires:

1. Detecting when a result set is editable (single-table SELECT, no aggregates,
   no expressions without aliases, results include a stable row identifier such
   as `rowid` or a PRIMARY KEY)
2. Rendering editable cells in the grid with type-appropriate input widgets
   (text field for strings, number input for integers/reals, date picker for
   dates, checkbox for booleans)
3. On commit (Enter or focus loss), generating and executing the correct
   `UPDATE` statement parameterized with the old and new values, then refreshing
   the affected row in the grid
4. Surfacing constraint violations and type errors from the engine as
   inline validation rather than modal error dialogs

### Scope

- Double-click to enter edit mode on a cell
- Type-appropriate editors: text, number, date, boolean
- `Tab` / `Shift+Tab` to move between cells in edit mode
- Esc to cancel edit and revert
- Enter to commit edit (generate and execute UPDATE)
- Visual indicator for edited-but-not-yet-committed cells (pending state)
- Inline error display when engine rejects a value (constraint violation, type
  mismatch)
- Editable indicator in the grid status bar showing whether the current result
  set is editable and, if not, why (multi-table join, aggregate, expression
  column, etc.)
- `INSERT` row: a blank row at the bottom of editable result sets for adding new
  records
- `DELETE` row: right-click → Delete Row, or a keyboard shortcut in edit mode

### Non-Goals

- Multi-row bulk edit (apply value to selected rows)
- Foreign-key-aware dropdown editors (lookup from referenced table)
- Arbitrary DML preview / dry-run mode
- Editing non-table results (views, CTEs, set operations)
- Undo stack beyond single-cell revert

---

## 3. Saved Queries and Workspace Projects

**Status:** `TODO`
**Future Version:** vNext
**Source of truth:** `design/adr/0029-workspace-project-file-and-query-library.md`, `design/PRD.md` section 3.2

### Why This Matters

Users who work with the same DecentDB file over multiple sessions accumulate
queries they run repeatedly — daily reports, validation checks, data cleanup
routines. Today, these queries live only in open tabs, and tabs are lost when
the user closes them without the workspace state having been explicitly saved.

The persistence infrastructure is already in place. `WorkspaceState` stores
per-tab SQL text, parameters, and export path. `FileWorkspaceStateStore`
serializes this as JSON. Saved queries are the user-facing layer on top: give
queries names, organize them into folders or tags, and make them recallable
across sessions without relying on "keep this tab open forever."

A workspace project file goes one step further: bundle a DecentDB database
reference with a named query library, import settings, and export defaults into
a portable project file. This makes it possible to share analysis setups with
colleagues or check them into version control alongside the data.

### Scope

- Save current tab SQL as a named query (name, optional description, optional
  folder/tag)
- Query library browser panel: list, search, filter saved queries
- Double-click a saved query to open it in a new tab
- Edit a saved query → opens in a tab; save updates the stored version
- Delete and rename saved queries
- Folder or tag organization for grouping related queries
- Workspace project file: `my-analysis.dbench-project.toml` that references a
  DecentDB file path (relative or absolute) and lists saved queries with their
  SQL, parameters, and export settings
- "Open Project" command that restores the database connection and populates the
  query library, optionally auto-opening pinned queries
- Auto-save workspace state on close so unsaved tab contents are never lost,
  even without explicit "save" actions

### Non-Goals

- Query version history beyond what tab history provides (see Priority 4)
- Shared/collaborative query libraries requiring server infrastructure
- Query scheduling or automation triggers
- Integration with external version control beyond the project file being a
  plain TOML file that can be committed

---

## 4. Query Tab History (User-Visible)

**Status:** `TODO`
**Future Version:** vNext
**Source of truth:** `design/SPEC.md` section 4.3 ("per-tab history is optional
for MVP")

### Why This Matters

SQL authoring is iterative. Users write a query, run it, inspect results, tweak
the SQL, run again, and repeat. Sometimes the fifth iteration is worse than the
third, and they want to go back — but the editor only holds the current text.
Undo within an editing session helps, but only within the current tab lifetime.

The persistence layer already captures execution history. Each tab in
`WorkspaceState` stores `queryHistory` entries with the SQL text, timestamp, row
count, and execution duration. This data is written to the workspace state file
and survives app restarts. What's missing is making it visible and navigable to
the user.

A per-tab history panel — a sidebar or bottom drawer listing past executions —
lets users click to restore any prior query into the editor. This turns an
accidental clear, a bad refactor, or a "what was that query I ran yesterday?"
moment into a single click. It also enables a lightweight comparison workflow:
restore the prior version, run it in a new tab, and compare results side by
side.

### Scope

- Per-tab history panel showing past executions as a scrollable list
- Each entry shows: first line of SQL (truncated), timestamp, row count,
  execution duration
- Click an entry to restore that exact SQL into the editor, replacing current
  content (with confirmation if current content is unsaved)
- Configurable history depth per tab (default: 50 entries)
- History survives tab close and workspace reopen (reads from
  `WorkspaceState.queryHistory`)
- "Clear history" action per tab
- Entries distinguishable: user-executed queries vs. auto-run queries
  (reopening auto-restore)

### Non-Goals

- Global query history across all databases (privacy concern)
- Diff view between history entries
- Pinning or starring specific history entries (that belongs in saved queries)
- Execution plan or result set stored with history (storage cost)

---

## 5. JSON Export

**Status:** `TODO`
**Future Version:** vNext
**Source of truth:** `design/PRD.md` section 3.2, `design/SPEC.md` section 11.2

### Why This Matters

CSV export covers tabular downstream workflows — spreadsheets, bulk data
processing, legacy systems. JSON export covers the other half: APIs, web
applications, scripting languages, NoSQL databases, config-driven pipelines, and
virtually every modern development workflow. Together, CSV and JSON cover the
vast majority of data interchange needs.

The implementation cost is near-zero. `dart:convert` provides `jsonEncode` in
the standard library — no third-party dependency, no licensing review, no build
configuration. The export pipeline is already proven: cursor paging streams rows
from the engine, a background task serializes them, the file-save dialog chooses
the destination, and progress is reported to the UI. JSON export reuses all of
this; only the serialization format changes.

The placeholder menu item (`export_results_json`) is already registered in the
command registry. It currently shows "JSON export is planned but not implemented
yet." Converting that placeholder to a working export is the lowest-effort,
highest-visibility win in the entire roadmap.

### Scope

- Export query results as a JSON array of objects (`[{...}, {...}]`)
- Export query results as NDJSON/JSONL (one object per line, no outer array,
  suitable for streaming consumers and log pipelines)
- Toggle between pretty-printed (indented, multi-line) and compact (single-line)
  output
- Include column type metadata as a `$types` preamble or alongside each value
  (configurable)
- Respect cursor paging: never materialize the full result set in memory; stream
  pages from the engine and write incrementally
- Progress reporting identical to CSV export: rows written, file size estimate,
  cancellation support

### Non-Goals

- Schema-level JSON export (that belongs with schema export, a separate feature)
- Arbitrary nested JSON structure transformation (e.g., grouping rows by a
  column into nested objects)
- JSON Schema generation alongside export
- Configurable date/time serialization format (use ISO 8601)

---

## 6. Database Backup / Snapshot

**Status:** `TODO`
**Future Version:** vNext
**Source of truth:** `design/adr/0032-database-snapshot-and-safe-run.md`

### Why This Matters

Decent Bench is a tool where users perform irreversible operations: running
`DROP TABLE`, executing `DELETE` without `WHERE`, importing data that may
overwrite existing tables, or experimenting with schema changes whose
consequences aren't fully understood. In every other tool that deals with
mutable data — photo editors, CAD software, IDEs with refactoring — "save a
copy" or "create snapshot" is a one-click action. Database tools have been slow
to adopt this pattern, forcing users to manually copy files in their OS file
manager before risky operations.

A one-click database snapshot changes the user's relationship with the tool.
Instead of hesitating before a risky query, they snapshot first and proceed with
confidence. If the result is bad, they restore the snapshot and continue. This
removes fear from the workflow and encourages experimentation — exactly what a
workbench should do.

### Why It's Trivial to Implement

DecentDB is an embedded database. The entire database is a single `.ddb` file
(plus transient WAL/SHM sidecars that can be checkpointed). Taking a snapshot
is:

1. Optionally issue a `PRAGMA wal_checkpoint(TRUNCATE)` or equivalent to flush
   the WAL into the main database file
2. Copy the `.ddb` file to a timestamped path: `mydb-2026-05-18T14-28-42.snapshot.ddb`
3. Report the snapshot location to the user

That's it. No SQL-level export, no format conversion, no data transformation.
The snapshot is a valid DecentDB file that can be opened directly in Decent
Bench. Restore is just opening the snapshot file and optionally saving it over
the original.

### Scope

- `File → Snapshot Database` command (or toolbar button with a camera/database icon)
- Configurable snapshot directory (default: alongside the original file)
- Timestamped filename: `<dbname>-<ISO8601>.snapshot.ddb`
- Automatic WAL checkpoint before copy (with warning if checkpoint fails)
- Snapshot list in the workspace: show recent snapshots with timestamp and file
  size
- "Restore Snapshot" action: opens the snapshot as the active database (warns
  about discarding current changes, offers to snapshot current state first)
- Configurable auto-snapshot: take a snapshot automatically before running any
  statement containing `DROP`, `DELETE`, `ALTER`, or `INSERT` (opt-in setting)
- Maximum snapshot count or age-based cleanup to prevent disk accumulation

### Non-Goals

- Incremental/differential snapshots
- Snapshot encryption or compression
- Cloud/remote snapshot storage
- Point-in-time recovery chains
- Snapshotting databases that are not local files (future external connector
  scenario)

### Relationship to Workspace Projects

Snapshots complement workspace projects (Priority 3). Workspace projects provide
reproducibility through named queries. Snapshots provide safety before executing
those queries. Together, they make Decent Bench the safest tool for exploratory
database work.

---

## 7. Column Statistics Panel

**Status:** `TODO`
**Future Version:** vNext
**Source of truth:** New proposal

### Why This Matters

When a user opens an unfamiliar DecentDB file — whether they imported it, received
it from a colleague, or downloaded it — their first question is always "what's
in here?" The schema browser answers the structural question: table names,
column names, types. But it doesn't answer the data question: how many distinct
values? Any nulls? What's the range? Are there outliers?

Today, answering those questions requires writing a series of exploratory
queries:

```sql
SELECT COUNT(*), COUNT(DISTINCT col), MIN(col), MAX(col), AVG(col) FROM t;
SELECT col, COUNT(*) FROM t GROUP BY col ORDER BY COUNT(*) DESC LIMIT 10;
```

Power users write these reflexively. But every user benefits from having the
answers surfaced automatically. A column statistics panel — accessible by
clicking a column in the schema browser or hovering over a column header in the
results grid — would compute and display these statistics on demand.

The engine already supports every aggregate function needed: `COUNT`, `MIN`,
`MAX`, `AVG`, `SUM`, `COUNT(DISTINCT ...)`. The `DecentDbBridge` can execute
arbitrary SQL and return results. The only new work is the UI that triggers
these queries and renders their results in a compact, scannable format.

### Why It's Broad Impact

Every user who opens a database they didn't create themselves benefits from this
feature. That covers:
- Users importing data from external sources (the core import workflow)
- Users receiving databases from colleagues
- Users returning to a database they last worked on weeks ago
- Users exploring open datasets or sample databases

The feature is also session-opening: the statistics panel is one of the first
things users interact with when opening a database. Making that first impression
informative and fast builds confidence and reduces the time to the first useful
query.

### Scope

- Column statistics available from two entry points:
  - **Schema browser**: click a column to show its statistics in the properties
    pane (replacing or augmenting the current column detail view)
  - **Results grid**: right-click a column header → "Column Statistics" shows a
    popover or updates a side panel
- Statistics computed lazily on click (not pre-computed for all columns, which
  would be expensive on large databases)
- Minimum set of statistics:
  - Row count (total rows in the table)
  - Distinct value count
  - Null count and null percentage
  - For numeric columns: MIN, MAX, AVG, SUM, standard deviation
  - For text columns: MIN length, MAX length, AVG length
  - For date columns: MIN date, MAX date
  - Top 10 most frequent values with counts (non-distinct for privacy-conscious
    users: show only if distinct count > 10, otherwise show "all values are
    unique or nearly unique")
- Loading indicator while statistics query runs (should be fast for most tables;
  timeout and partial results for very large tables)
- Cache statistics for the current session so re-clicking a column is instant
- "Copy Statistics" action that puts a text summary on the clipboard

### Non-Goals

- Pre-computed statistics or materialized statistical metadata
- Histogram or distribution chart (belongs in data visualization, Priority 8)
- Cross-column correlation statistics
- Statistics for expression results or computed values
- Exporting statistics as a structured report

### Relationship to Data Visualization

Column statistics answer "what's the shape of this column?" Data visualization
(Priority 8) answers "what's the relationship between columns?" Statistics are
lower cost and broader impact; they should ship first and serve as the
foundation for later charting work (the statistics query patterns can be reused
as data sources for chart widgets).

---

## 8. Data Visualization (Charts from Query Results)

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** `design/adr/0030-charting-library-and-visualization-contract.md`

### Why This Matters

SQL results grids are the right tool for inspecting individual records. They are
the wrong tool for understanding patterns, trends, distributions, and
relationships. A results grid showing 10,000 rows of sales data tells you
nothing at a glance; a line chart of revenue over time or a bar chart of sales
by region tells you everything.

This gap is why "SQL tool + charting" is one of the most common pairings in data
work. Users export query results to CSV, open them in Excel or Google Sheets,
and build charts there. Or they copy data into Python/R notebooks. Every
round-trip between tools is friction — and every round-trip is a reason to use a
different tool that has charting built in.

Adding data visualization to Decent Bench keeps users in the tool longer. An
analyst who can write a query and immediately see the result as a chart has no
reason to leave. This is not a nice-to-have; it's a retention and
differentiation feature. Metabase, Superset, Grafana, and Tableau have all
proven that "query → visualize" is a core workflow, not a secondary one.

### Why It Fits Decent Bench's Architecture

Decent Bench already has the hard part: structured, typed, columnar data flowing
from the engine through a cursor-based paging pipeline. The charting layer
consumes this same data. A chart is just an alternative rendering target for
query results — the same data source, a different view.

The primary constraint is the Flutter charting library ecosystem. Options
include:

- `fl_chart` — most popular Flutter charting package, Apache/MIT licensed,
  supports line, bar, pie, scatter, and radar charts
- `syncfusion_flutter_charts` — feature-rich but has a commercial license
  component; needs careful license review
- Custom canvas rendering — no dependency but significant implementation effort

A pragmatic approach: start with `fl_chart` for a basic set of chart types,
validate the integration pattern, and evaluate whether the library meets
performance and customization needs before committing to broader chart support.

### Scope

- "Visualize" button in the results pane toolbar (alongside Export)
- Chart type selector: line, bar, pie, scatter (initial set)
- Drag columns from the result set metadata onto chart axes:
  - X axis: one column (categorical or continuous)
  - Y axis: one or more columns (numeric)
  - Color/group-by: optional column for series splitting
- Automatic axis labeling from column names
- Chart title configurable (defaults to a truncated version of the query)
- Resizable chart panel: split view with results grid on one side and chart on
  the other, or toggle to full-width chart
- Chart respects cursor paging: for streaming results, chart updates
  incrementally as pages arrive (with a "chart in progress" indicator)
- Export chart as PNG (via `dart:ui` canvas snapshot or the charting library's
  image export)
- Basic interactivity: tooltips on hover, legend toggles for series
  visibility, zoom on drag-select for scatter plots

### Non-Goals

- Dashboard canvas with multiple chart tiles
- Chart filter interactions that modify the underlying query
- Animated or streaming real-time charts
- Custom chart themes beyond the app's light/dark theme
- Geospatial/map visualizations (DecentDB spatial type support is a separate,
  later consideration)
- Chart type auto-detection from column types and cardinality

### Relationship to Column Statistics

Column statistics (Priority 7) and data visualization are complementary.
Statistics answer univariate questions (what's the range of this column?).
Visualization answers multivariate questions (how does this column relate to
that one?). Statistics should ship first because they're lower implementation
cost and provide immediate value during schema exploration. Charts build on the
same data pipeline but require a more significant UI investment.

---

## 9. Schema Browser Expansion

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** `design/SPEC.md` section 4.4

### Why This Matters

The SPEC defines phased schema browser coverage toward the full pinned-engine
object catalog. As of v1.1.0, the schema browser displays tables, views,
columns, and indexes. Missing are: triggers, constraints (CHECK, UNIQUE, FOREIGN
KEY), generated-column metadata, and explicit temp-object identification.

These are not esoteric objects. Constraints define data integrity rules that
users must understand before writing DML. Triggers execute side effects that can
surprise users if invisible. Generated columns are increasingly common in modern
schema design. Temp objects are session-scoped and users need to know they exist
and will disappear.

The engine already exposes all of this metadata through the schema snapshot API.
The `DecentDbBridge.loadSchema()` method retrieves a rich metadata structure
that includes trigger definitions, constraint details, and generated-column
expressions. The gap is entirely in the presentation layer — parsing that
already-available metadata into UI widgets.

### Scope

- **Triggers**: listed under each table in the schema tree; detail view shows
  trigger name, timing (BEFORE/AFTER/INSTEAD OF), event (INSERT/UPDATE/DELETE),
  `FOR EACH ROW` vs. `FOR EACH STATEMENT`, `WHEN` condition if present, and full
  trigger body SQL
- **Constraints**: CHECK constraints displayed with their Boolean expression;
  UNIQUE constraints listed with the columns they cover; FOREIGN KEY constraints
  shown with the referenced table and columns, plus ON DELETE / ON UPDATE
  actions
- **Generated columns**: displayed in the column list with a distinct icon;
  detail view shows whether STORED or VIRTUAL (DecentDB currently supports
  STORED), the generation expression, and the resulting type
- **Temp objects**: visually distinguished in the schema tree (italic label,
  "TEMP" badge, or separate tree section); temp tables and temp views shown
  identically to their persistent counterparts but with a clear lifecycle
  indicator
- **Search/filter** extended to match across all object kinds, including trigger
  names and constraint expressions

### Non-Goals

- Constraint editing or DDL generation from the schema browser
- ERD-style visual relationship diagrams showing FK connections
- Schema diff/comparison between databases
- Schema export as DDL script

---

## 10. Database Statistics Dashboard

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** New proposal

### Why This Matters

Users who work with databases over time develop operational questions that the
schema browser doesn't answer: How big is my database? Which tables are growing?
Is the WAL file getting out of hand? How much space are my indexes consuming?

These questions matter for:
- Users managing databases that grow with each import
- Users deciding whether to archive or clean up old data
- Users troubleshooting performance issues (large indexes, bloated WAL)
- Users preparing to share or distribute a database file

Today, users must either run `PRAGMA` queries manually (if they know them) or
inspect the file system. A live dashboard accessible directly from the workspace
would make this information visible at a glance, building operational confidence
and surfacing issues before they become problems.

The SQLite import workflow already proves this pattern works. The import summary
shows per-table row counts, target file size, and WAL status after import
finalization. The dashboard generalizes that post-import view into a persistent,
always-available panel.

### Scope

- Dashboard accessible from the workspace: menu item `View → Database Statistics`
  or a status bar indicator showing database file size (click to open dashboard)
- Live metrics:
  - Database file size (human-readable: KB/MB/GB)
  - WAL file size and checkpoint status (if WAL is enabled)
  - Total table count, total view count, total index count
  - Per-table row counts (lazily computed; cached with manual refresh)
  - Per-table estimated disk usage (if engine exposes this; otherwise file size
    is global)
  - Index count per table
  - Free pages / fragmentation estimate (if `PRAGMA freelist_count` or
    equivalent is available)
- Refresh button to recompute all lazily-fetched metrics
- Warning indicators: large WAL file relative to database (suggest checkpoint),
  table row count exceeding a configurable threshold, database file size
  approaching a configurable limit
- Copy dashboard summary as text for sharing with colleagues or filing issues

### Non-Goals

- Historical metric tracking or growth charts
- Query performance statistics (belongs in diagnostics, BACKLOG)
- Automated recommendations or tuning suggestions
- Cross-database comparison

### Relationship to Column Statistics

The database statistics dashboard answers "how big and healthy is my database?"
Column statistics (Priority 7) answer "what's inside this column?" Both provide
visibility, but at different granularity levels — database-level vs. column-level.
Column statistics have broader user impact (more users care about column contents
than database file size) and ship first.

---

## 11. EXPLAIN Visualization

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** `design/SPEC.md` pinned engine SQL surface

### Why This Matters

`EXPLAIN` and `EXPLAIN ANALYZE` are already part of the pinned engine SQL surface
and are validated in the Phase 1 representative engine smoke-test matrix. When
a user runs `EXPLAIN SELECT ...`, the engine returns plan output — opcodes,
estimated row counts, loop structures — as structured text. Today, that text is
dumped into the results grid as a flat column.

A structured visualization — an indented tree, a nested table, or a simple
hierarchy view — makes query plans scannable. Users can see at a glance:
- Which part of the plan is the outermost loop
- Where the engine scans vs. seeks (index usage)
- Which subqueries are materialized
- Relative cost distribution across plan nodes (with EXPLAIN ANALYZE)

This is deliberately scoped as a lightweight visualization, not a full
diagnostics suite. The engine already produces the data; the work is purely
presentational. A tree or indented-table widget with expandable nodes, estimated
row counts, and loop-type labels is a weekend project that delivers immediate
value to every user who ever wonders "why is this query slow?"

### Scope

- Detect `EXPLAIN` and `EXPLAIN ANALYZE` queries and route their output to a
  dedicated plan view instead of (or in addition to) the results grid
- Tree or indented-table rendering of plan nodes with:
  - Opcode or operation name
  - Estimated row count
  - Actual row count (from EXPLAIN ANALYZE)
  - Loop type indicator (SCAN, SEARCH, etc.)
- Expandable/collapsible sub-nodes for nested loops and subqueries
- Color-coded severity or cost indicator (optional, based on row count ratios)
- "Copy Plan as Text" action to get the raw plan output for sharing or filing
  issues
- Basic search/filter within the plan for finding specific table references or
  opcodes

### Non-Goals

- Plan comparison across queries (save one plan, run a different query, compare
  side by side)
- Index recommendation engine ("consider adding an index on ...")
- Runtime profiling or historical plan tracking
- Visual plan graph / flame charts / tree maps
- Automatic detection of "slow" plan patterns

### Relationship to Full Diagnostics Suite

The full Query-Plan and Performance Diagnostics item (BACKLOG) covers plan
comparison, index recommendations, runtime profiling, and historical tracking.
EXPLAIN visualization is the MVP slice of that larger vision — deliver the
immediately useful part first, gather feedback, and let user demand inform the
scope of the full diagnostics investment.

---

## 12. Query Parameterization UI

**Status:** `TODO`
**Future Version:** vNext+1
**Source of truth:** New proposal

### Why This Matters

The engine supports positional parameters (`$1`, `$2`, `$3`, ...) and they are
validated in the Phase 1 representative engine smoke-test matrix. Parameters are
the correct way to write reusable, injection-safe queries. Instead of:

```sql
SELECT * FROM orders WHERE customer_id = 42 AND status = 'shipped';
```

A parameterized query:

```sql
SELECT * FROM orders WHERE customer_id = $1 AND status = $2;
```

Today, Decent Bench has no UI for binding parameter values. Users can write
parameterized SQL in the editor, but there is no input field, no form, no panel
— nothing to provide the values for `$1` and `$2`. The query engine will reject
the execution because no values are bound. This means one of the pinned engine's
documented capabilities is effectively unusable through the GUI.

Adding a parameter binding panel changes this. A simple form next to or below
the editor — with one input field per parameter, labeled by position — lets users
fill in values and execute. The same SQL can be run repeatedly with different
values, making Decent Bench usable for routine operational queries (look up a
customer, check inventory for a SKU, validate a recent transaction) without
writing a new SQL statement each time.

### Why It's Targeted, Not Universal

Not every user parameterizes queries. Many are comfortable with string
interpolation or write one-off queries where parameters add ceremony without
benefit. But for the users who do parameterize — developers integrating DecentDB
into applications, analysts running daily reports with varying filters, anyone
who values injection safety — this feature is essential. It's also a building
block for future features: saved queries with parameter slots (Priority 3)
become much more powerful when the parameters are visible and editable.

### Scope

- Parameter panel: displayed below the SQL editor or as a toggleable side panel
- Automatically detects `$1`, `$2`, `$3`, ... tokens in the current SQL and
  creates one input field per unique parameter
- Input fields labeled by position: `$1`, `$2`, etc.
- Type inference from context: if the parameter is used in a comparison with a
  typed column, the input widget adapts (number, text, date picker)
- If type can't be inferred, default to text input
- Execute (Ctrl+Enter) reads current parameter values from the panel and binds
  them before sending the query to the engine
- Parameter values persisted in `WorkspaceState` alongside tab SQL text (already
  stored as JSON in the current persistence model)
- Visual indicator when a parameter is referenced in SQL but has no value bound
  (warning icon or red border on the input field)
- Support for named parameters if/when the engine adds them

### Non-Goals

- Dropdown parameter values sourced from a database query (e.g., "list all
  customer IDs")
- Parameter validation beyond type coercion
- Multi-value or array parameters
- Parameter sets or presets (save a group of parameter values as a named preset)
- Date range picker for BETWEEN-style queries (single-value parameters only)

### Relationship to Saved Queries

Parameterized queries without saved queries have limited value — users must
retype the SQL each session. Saved queries (Priority 3) with parameters create a
compounding effect: save a query once, reopen it, fill in the parameters, and
execute. The two features together form the foundation for repeatable, safe,
non-programmatic database access.

---

## 13. Import / Export Profile Persistence (GUI ↔ Headless)

**Status:** `TODO`
**Future Version:** vNext+2
**Source of truth:** `design/adr/0022-headless-cli-import-mode-and-plan-file.md` (plan contract), `design/adr/0029-workspace-project-file-and-query-library.md` (project model)

### Why This Matters

Decent Bench ships with a headless CLI import mode (`--in`/`--out`/`--plan`).
The `--plan` flag accepts a JSON file describing import options — source path,
table selection, column renames, type overrides, delimiter settings, encoding —
and executes the import without launching the GUI. This is governed by ADR-0022
and is a shipped v1.1.0 feature.

However, there is no GUI for creating or editing plan files. Users who discover
the import wizard in the desktop app cannot save their import configuration for
reuse. Users who want to automate an import must hand-write a JSON plan file
with no validation, no schema reference, and no preview. These are separate
worlds — GUI and headless — that should be one unified workflow.

Closing this gap would make Decent Bench the only database tool with a seamless
"configure in GUI, automate in CLI" import workflow. Users configure an import
in the wizard, preview the results, tweak the settings, save the plan, and then
run it headlessly in CI, cron jobs, or batch scripts. The plan file becomes a
version-controllable, shareable artifact that captures the exact import
configuration used.

The same pattern applies to export: save export profiles (format, delimiter,
destination pattern, options) and reuse them from the GUI or headless CLI. This
is currently listed as a placeholder menu item (`export_rerun_last`).

### Scope

- **Save Import Plan**: At the end of any import wizard flow, offer "Save Import
  Plan" that writes the current import configuration as a versioned JSON plan
  file (same format consumed by `--plan`)
- **Load Import Plan**: In the import wizard, offer "Load Plan File" that
  pre-populates all wizard steps from a saved plan (user can then modify and
  re-save or execute immediately)
- **Plan Validation**: Validate plan files when loading — check that referenced
  source files exist, format is known, options are within valid ranges; surface
  errors clearly
- **Export Profiles**: Save export configuration as a named profile (format,
  delimiter, destination pattern); list saved profiles in the export dialog;
  "Re-run Last Export" becomes "Run Saved Export Profile"
- **Headless Export**: Extend the CLI to support `dbench --export <profile.json>`
  for headless export automation
- **Plan File Documentation**: Document the JSON plan schema so users can
  generate plans programmatically from other tools

### Non-Goals

- Import plan chaining or multi-step workflow orchestration
- Plan file parameters or templating (run same plan with different source files
  by substituting `$SOURCE_PATH`)
- Export profile scheduling
- Cloud-based plan sharing or plan marketplace

### Relationship to Workspace Projects

Workspace projects (Priority 3) are user-facing organizational containers:
"these are my queries for analyzing the sales database." Import/export profiles
are operational containers: "this is how I load the weekly CSV dump into the
database." Both use plain-text formats (TOML for projects, JSON for plans) and
are version-controllable. They serve different purposes but share the same
design philosophy of making workflows repeatable and portable.

---

## 14. Parquet and Excel Export

**Status:** `TODO`
**Future Version:** vNext+2
**Source of truth:** `design/adr/0031-parquet-excel-export-dependency-strategy.md`, `design/PRD.md` section 3.2, `design/SPEC.md` section 11.2

### Why These Are Deferred

ADR-0031 governs the dependency evaluation and implementation gating strategy
for both formats. Summary of the key blockers:

### Parquet Export

Parquet is a columnar storage format widely used in data engineering, analytics,
and machine learning pipelines. It is the standard interchange format for tools
like Apache Spark, DuckDB, Pandas, and Polars. Supporting Parquet export would
make Decent Bench a viable tool in data engineering workflows where CSV is too
slow and JSON is too verbose.

**Blockers:**
- No mature, maintained Dart library for writing Parquet files exists as of 2026.
- The most plausible approach is an FFI bridge to a Rust or C library (e.g.,
  `parquet` crate in Rust, or `apache-parquet` C++ library), which adds
  significant build complexity, platform-specific packaging, and testing burden.
- Dart FFI with Rust requires `flutter_rust_bridge` or manual `dart:ffi` +
  `NativeFinalizer` patterns, both of which increase CI complexity and platform
  matrix testing requirements.

**If unblocked, scope includes:**
- Columnar write with type mapping from DecentDB native types to Parquet logical
  types
- Row group configuration (size-based or row-count-based)
- Compression codec selection (Snappy, GZip, Zstd, uncompressed)
- Streaming from cursor pages: write row groups incrementally as pages arrive
- Schema metadata embedded in the Parquet footer

### Excel Export

Excel (`.xlsx`) is the most commonly requested export format after CSV. Business
users, managers, and stakeholders consume data in Excel. Providing native Excel
export eliminates the "export CSV → open in Excel → format columns → save as
.xlsx" round-trip that every data professional has performed hundreds of times.

**Blockers:**
- The current `excel` package dependency is **read-only** — it parses `.xlsx`
  and `.xls` files for import but does not support writing.
- A write-capable Excel library for Dart would need to either:
  - Replace the current `excel` dependency if a read+write library is found
  - Add a second Excel dependency specifically for writing
  - Use an FFI bridge to a native library (same complexity as Parquet)
- Excel files have practical limits: ~1M rows per sheet. Exporting a 5M-row
  query result requires either multi-sheet splitting or a clear error before
  hitting the limit mid-export.

**If unblocked, scope includes:**
- Workbook/sheet output with configurable sheet name
- Column formatting: date formats, number formats, header styling (bold,
  background color)
- Auto-sizing column widths based on content sampling
- Streaming write: build and flush rows incrementally to avoid memory pressure
- Multi-sheet splitting for result sets exceeding sheet row limits
- Formula columns if applicable (e.g., SUM row at bottom — optional)

### Recommendation

Evaluate Parquet and Excel export dependencies separately. JSON and CSV cover
most interchange needs. Parquet is valuable for a narrower (but growing)
audience. Excel is valuable for a broader audience but has library constraints.
Both should proceed after the foundational export pipeline (CSV, JSON) and
data-editing features (table editor) are stable, so that export work benefits
from a mature, well-tested cursor streaming infrastructure.

---

## 15. Richer Import Transforms and Connector Expansion

**Status:** `TODO`
**Future Version:** vNext+2
**Source of truth:** `design/adr/0033-computed-column-transforms-during-import.md` (computed columns), `design/IMPORT_SUPPORT_PLAN.md` (connector expansion)

### Why This Is Deferred

Decent Bench v1.1.0 supports 15 import formats — a broad foundation that covers
the most common real-world data sources. The remaining import work falls into
two categories:

1. **Additional transforms** — capabilities that users request during the import
   wizard: computed columns (deferred from MVP, now specified in ADR-0033 with a
   constrained expression language), conditional row filtering (import only rows
   matching a condition), column reordering, default value assignment for null
   cells, deduplication strategies.
2. **Additional connectors** — formats defined in `IMPORT_SUPPORT_PLAN.md` that
   are not yet implemented: fixed-width text, ODS spreadsheets, DuckDB, Parquet
   import, PostgreSQL plain dump, live PostgreSQL/MariaDB/MySQL/SQL Server
   connections, and tier-3 specialized formats.

These are valuable but target power import users specifically — users who import
regularly and need more control over the process. For the broader user base,
imports already work well for the common cases (CSV, Excel, JSON, SQLite). The
return on investment for the next import feature is lower than for features that
benefit all users (command palette, table editing, saved queries).

### Expansion Strategy

Follow the tiered priority in `IMPORT_SUPPORT_PLAN.md`:

- **Tier 1** (highest practical value, not yet implemented): fixed-width text,
  ODS, DuckDB, Parquet import, PostgreSQL plain dump, live database connections
- **Tier 2** (strong expansion): additional live connectors, format-specific
  options
- **Tier 3** (specialized/legacy): Access, DBF, Stata/SPSS/SAS, log templates

### Transforms

- **Computed columns**: the single most-requested deferred transform. Allow
  users to define new columns whose values are computed from existing columns
  using a constrained expression language (arithmetic, string concatenation,
  CASE/WHEN). This was explicitly deferred from MVP in `SPEC.md` section 8.3.
- **Conditional row filtering**: import only rows where a column value meets a
  condition (e.g., `status = 'active'`, `amount > 0`). Reduces import time and
  database size when only a subset of source data is relevant.
- **Column reordering**: drag-and-drop reorder of columns in the import preview
  to match a desired target table column order.
- **Default value assignment**: set a default value for null cells in specific
  columns during import.
- **Deduplication**: detect and skip or merge duplicate rows based on a key
  column or column set.

### Import Recipe Persistence

See Priority 13 (Import / Export Profile Persistence) for the plan file
infrastructure. Import transforms and connector expansion are the features that
fill those plan files with configuration options.

---

## BACKLOG — Query-Plan and Performance Diagnostics

**Status:** `BACKLOG`
**Future Version:** Future
**Source of truth:** Needs ADR/spec

A full diagnostics suite goes beyond EXPLAIN visualization (Priority 11) to
include:

- **Plan comparison**: save a query plan, modify the query or add an index, run
  EXPLAIN again, and view the two plans side by side with diffs highlighted
- **Index recommendations**: analyze query patterns and suggest missing indexes
  based on scan operations in query plans
- **Runtime profiling**: track query execution time, page fetch time, and result
  set size over multiple runs; surface regressions
- **Historical plan tracking**: store query plans over time as schema and data
  volume change; detect when a query becomes slower
- **Performance advisories**: warn when a query has no WHERE clause on a large
  table, uses SELECT *, or has a cartesian join

This is a significant engineering investment. It should follow after the
lightweight EXPLAIN visualization lands and user feedback confirms demand and
informs scope. An ADR is required before any implementation.

---

## BACKLOG — Schema-First Strongly Typed SDK Generation

**Status:** `BACKLOG`
**Future Version:** Future
**Source of truth:** Needs Decent Bench ADR/spec

### Why This Is BACKLOG

This feature is valuable in concept: it would turn Decent Bench from an
import/query workbench into the official app-integration workflow for DecentDB.
It is, however, **fully blocked** on an external dependency:

- DecentDB must ship a **stable schema/query-contract metadata surface** that
  includes versioned schema metadata export, schema fingerprinting, query
  describe/contract primitives, and deterministic JSON output.
- None of these capabilities exist in DecentDB today. No DecentDB ADR or
  roadmap commitment to this contract has been published.

Until that contract is committed and shipped by the DecentDB engine, no
implementation work on SDK generation can begin. The product-level scope
expansion (workbench → developer tooling platform) also warrants its own ADR
before implementation.

### What Changes to Promote This to vNext

1. DecentDB publishes a roadmap commitment to the required metadata surface.
2. A prototype metadata export is available for Decent Bench to consume.
3. A Decent Bench ADR is accepted confirming ownership boundaries and generator
   architecture.

### Original Scope (Retained for Reference)

The Decent Bench-owned scope:

- generator workflow in the GUI and a headless `dbench` command for CI/agents
- canonical generator IR that adapts DecentDB metadata into codegen-friendly form
- generated models/types from tables and views
- generated parameter-binding helpers
- typed query result contracts for explicit named queries
- schema drift and breaking-change reports
- deterministic file layout and golden-testable output
- initial language targets: C#/.NET, TypeScript/Node, Python

The DecentDB-owned foundation (not yet committed):

- versioned schema metadata export
- schema fingerprinting suitable for drift checks
- complete DecentDB type metadata, including native spatial values
- query describe/contract primitives for explicit named queries
- Rust API, C ABI, and binding exposure for required metadata
- deterministic JSON output suitable for golden tests and CI

### Non-Goals

- runtime ORM with change tracking
- arbitrary dynamic SQL extraction from application repositories
- full LINQ-style query DSL generation
- remote-service SDK generation
- putting codegen templates or language package layouts in the DecentDB engine

---

## Near-Term Sequence

This sequence reflects the impact-ordered priority ranking from the Status Map.
Items at the top benefit the most users the most frequently.

1. **Command palette** — consume existing `MenuCommandRegistry`; fuzzy-search
   overlay; zero new backend work; ships keyboard-first navigation to every user.

2. **Table data editor** — inline cell editing in the results grid; turns
   Decent Bench from read-only query tool into a true workbench; builds on
   existing grid selection/copy infrastructure.

3. **Saved queries and workspace projects** — named query library and project
   file format on top of existing `WorkspaceState` persistence; enables
   repeatable, portable analysis sessions.

4. **Query tab history** — user-visible history panel consuming already-stored
   per-tab history entries; purely a UI addition; immediate productivity gain
   for iterative query authoring.

5. **JSON export** — reuse proven CSV export pipeline with `dart:convert`
   serialization; convert existing placeholder menu item into working export;
   lowest-effort format expansion.

6. **Database backup / snapshot** — timestamped file copy with optional WAL
   checkpoint; one-click safety net before risky operations; trivial to
   implement, universally valuable.

7. **Column statistics panel** — lazily computed per-column aggregate statistics
   from the schema browser and results grid; accelerates data exploration; all
   required SQL functions already available in the engine.

8. **Data visualization** — chart rendering from query results; evaluate
   `fl_chart` or alternatives; line, bar, pie, scatter; differentiates Decent
   Bench from pure SQL editors.

9. **Schema browser expansion** — trigger, constraint, generated-column, and
   temp-object rendering from already-available engine metadata; closes
   SPEC-defined object coverage gap.

10. **Database statistics dashboard** — live database-level metrics (file size,
    WAL status, per-table row counts); generalizes the SQLite import summary
    pattern into a persistent view.

11. **EXPLAIN visualization** — tree/table presentation of `EXPLAIN` plan output
    already returned by the engine; lightweight diagnostics without full
    diagnostics investment.

12. **Query parameterization UI** — parameter binding panel next to the SQL
    editor; makes pinned-engine parameter support usable from the GUI; building
    block for saved parameterized queries.

13. **Import / export profile persistence** — save, load, and share import/export
    configurations; unifies GUI wizard and headless CLI through the `--plan`
    contract.

14. **Parquet and Excel export** — evaluate dependencies and licensing separately;
    proceed when the cursor streaming pipeline is mature and library options are
    validated.

15. **Richer import transforms and connector expansion** — computed columns,
    conditional filtering, new format connectors per `IMPORT_SUPPORT_PLAN.md`
    tiered priorities.
