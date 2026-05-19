# Changelog

This file records notable project changes. It follows the
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - [UNRELEASED] [WIP] [CURRENT WORK BRANCH]

### Added

- Added DecentDB v2.5.1 alignment, including pinned binding/runtime metadata,
  native asset resolution hardening, and a v2.5.x fixture smoke path.
- Added DecentDB tooling metadata and query-contract bridge support for schema
  fingerprints, parameter contracts, result-column contracts, and persisted
  workspace summaries.
- Added first-class display/copy/export handling for DecentDB native semantic
  and spatial values, including enum labels, temporal/network/MAC/UUID values,
  interval values, and EWKB spatial summaries.
- Added typed query parameter fields powered by query contracts while retaining
  the raw JSON parameter editor for advanced workflows.
- Added JSON and NDJSON result export with paged execution, optional metadata,
  schema fingerprints, and stable native-value encodings.
- Added Excel `.xlsx` result export through a minimal Office Open XML writer
  built on the existing archive dependency.
- Added column statistics, database statistics, EXPLAIN visualization, and
  result charts with PNG export.
- Added row-local generic import transforms for filters, defaults, computed
  columns, column ordering, and deduplication.
- Added import/export profile persistence and `--plan` validation for headless
  import workflows.
- Added schema-first SDK-generation prototype with TypeScript declaration
  output from schema metadata and saved query contracts.
- Added saved-query library and workspace project manifest support.
- Added type-aware inline table editing for editable single-table result sets.
- Added per-tab query history in the results surface, including load, rerun, and
  clear actions.
- Added a read-only ERD viewer in the navigation pane with deterministic
  schema-relationship graph/layout generation, table search, selected-table
  neighborhood mode, double-click/Enter table-preview loading, and PNG/JPG
  image export with safe raster limits.
- Added a guided legacy DecentDB migration workflow that detects unsupported
  format-version open failures, runs the official `decentdb-migrate` tool into
  a new copy, and opens the migrated database after success.
- Added safe-run SQL risk prompts for mutating and destructive statements, with
  branch execution clearly disabled until the Dart binding exposes public branch
  APIs.
- Added Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) with fuzzy-search for all
  registered commands. Searchable overlay shows command labels, icons, keyboard
  shortcuts, and disabled state. Navigate with arrow keys, execute with Enter,
  dismiss with Escape or click outside. Palette consumes the existing
  `MenuCommandRegistry`, so all menu commands appear automatically.
- Added `view_command_palette` (`Ctrl+Shift+P`) to default shortcut bindings.

### Changed

- Updated roadmap, README, and ADR documentation to treat completed v2.5.1,
  metadata, typed exports, diagnostics, visualization, profiles, import
  transforms, saved queries, and editor work as shipped foundations rather than
  future wins.
- Revised table-editor, saved-query/project, and branch/snapshot ADRs around
  DecentDB v2.5.x query contracts, native types, and branch safety.
- Revised charting, Excel/Parquet export, and import-transform ADRs to match
  the implemented dependency and execution choices.
- Refactored `DecentDbBridge` worker isolate into a `_BridgeWorkerState` class
  with dedicated handler methods for each operation (openDatabase, loadSchema,
  runQuery, fetchNextPage, cancelQuery, exportCsv).
- Reorganized test files with `group()` blocks for improved readability and
  navigation: `widget_test.dart`, `workspace_controller_test.dart`, and
  `workspace_shell_test.dart` now group tests by feature area.
- Added test fixture helpers (`_createController`, `_pumpShell`, `_tempDbPath`)
  to reduce boilerplate in widget and controller tests.
- Added coverage collection to CI pipeline (`flutter test --coverage` with
  Codecov upload) and improved CI cache key strategy.

### Fixed

- Stabilized Linux integration shell tests by centralizing app setup/teardown,
  unmounting the widget tree before controller disposal, and preventing
  intermittent `did not complete` failures.
- Removed unused `_requireDatabase` top-level function after worker refactor
  (database guard moved into `_BridgeWorkerState`).

## [1.1.0] - 2026-04-21

### Added

- Added DecentDB native asset staging and improved native-library resolution so
  desktop builds and packaged runners can acquire and load the engine more
  reliably across environments.
- Added headless CLI import mode plus broader import detection for wrapped
  inputs, including additional archive handling and initial MS SQL Server
  backup (`.bak`) workflow scaffolding.
- Added `Tools -> View Log` to open the DecentDB-backed application log
  database from inside the workspace.

### Changed

- Expanded import workflow coverage in the app, docs, ADRs, and tests to cover
  the broader supported import scope and native/runtime packaging decisions.
- Improved SQLite import summaries to show richer validation detail, including
  imported object counts, per-table row totals, target file size, and WAL
  status after import finalization.

### Fixed

- Fixed SQLite import handling for high-precision timestamp text and mixed
  date-like columns so large real-world databases such as Navidrome import
  correctly.
- Fixed import finalization so successful imports checkpoint and flush their
  WAL state before completion, avoiding misleading tiny database files paired
  with large sidecar WAL files.
- Fixed import failure UX so failed imports stop the workflow, surface a clear
  blocking error dialog with summary and details, and no longer look like a
  successful completion.

## [1.0.0] - 2026-03-14

### Added

- Shipped the DecentDB-first desktop workspace with open/create flows for
  `.ddb` files, drag-and-drop entry, recent files, and cross-platform desktop
  runners.
- Added import workflows for delimited text, JSON and NDJSON, XML, HTML
  tables, Excel, SQLite, and MariaDB/MySQL-style `.sql` dumps, including ZIP
  and GZip wrapper routing where supported.
- Added the schema browser, multi-tab SQL editor, schema-aware autocomplete,
  snippets, formatting, best-effort query cancellation, and paged results
  browsing needed for the core query workflow.
- Added CSV export, TOML-backed app configuration and workspace persistence,
  native-library staging support, and desktop/headless CLI launch paths for
  import workflows.

### Changed

- Formalized `1.0.0` as the shipped MVP release and aligned application
  metadata, bundled theme compatibility ranges, and project documentation with
  that release line.

[unreleased]: https://github.com/sphildreth/decent-bench/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/sphildreth/decent-bench/releases/tag/v2.0.0
[1.1.0]: https://github.com/sphildreth/decent-bench/releases/tag/v1.1.0
[1.0.0]: https://github.com/sphildreth/decent-bench/releases/tag/v1.0.0
