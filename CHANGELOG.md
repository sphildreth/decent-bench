# Changelog

This file records notable project changes. It follows the
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - [UNRELEASED] [WIP] [CURRENT WORK BRANCH]

### Added

- Added a DecentDB v2.6.0 enhancement adoption plan covering queued writes,
  operational `sys.*` metrics, SQL/PRAGMA compatibility, local web console,
  reactive streams, sync/relay, Lua extensions, and WASM/browser boundaries.
- Added ADRs for DecentDB v2.6.0 queued writes, local Web Console companion
  process handling, reactive refresh lifecycle, sync/relay diagnostics scope,
  and Lua extension trust management.
- Added DecentDB v2.6.0 alignment, including pinned binding/runtime metadata,
  native asset resolution hardening, and a v2.x fixture smoke path.
- Added DecentDB v2.6.0 operational diagnostics in Database Statistics,
  including WAL, storage, write-queue, sync, reactive, relay, and Lua extension
  inspection surfaces with graceful fallback for unavailable `sys.*` views.
- Added opt-in DecentDB queued-write configuration and queued app-generated
  inline table DML, with queue metrics and native queue error codes surfaced
  through the existing gateway error model.
- Added DecentDB CLI resolution/caching, `Tools -> Open Web Console`, a
  managed read-only `decentdb serve` companion-process service, and CLI-backed
  Lua extension package validation.
- Added DecentDB v2.6 SQL compatibility coverage for PRAGMA metadata,
  `generate_series`, `sqlite_schema`, `information_schema`, collations, and
  `main.`/`temp.` autocomplete qualifiers.
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
- Added native DecentDB branch and snapshot workflow integration for listing,
  creating, deleting, diffing, restoring, merging, and branch-scoped SQL
  execution through the public Dart binding.
- Added Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) with fuzzy-search for all
  registered commands. Searchable overlay shows command labels, icons, keyboard
  shortcuts, and disabled state. Navigate with arrow keys, execute with Enter,
  dismiss with Escape or click outside. Palette consumes the existing
  `MenuCommandRegistry`, so all menu commands appear automatically.
- Added `view_command_palette` (`Ctrl+Shift+P`) to default shortcut bindings.
- Added test-level menu-command contract coverage across in-app and native menu
  implementations and surfaced `Command Palette...` / `Open Web Console` in both.
- Added shortcut contract coverage for every default application-menu keybinding
  plus a production-shell smoke test for global shortcut dispatch.
- Added file-lifecycle menu behavior for workspace shell operations: `Save`
  now persists workspace state, query-library metadata, and config with clear
  durability messaging; `Save As...` duplicates the active `.ddb` and sidecars
  into a new copy and opens it; `Close` persists metadata, cancels active work,
  and returns the shell to an empty workspace state.
- Added menu-backed table and schema export workflows: selected tables route
  through the existing paged result export flow, and schema export writes SQL
  DDL from the loaded schema snapshot.
- Added a searchable in-app Help Center opened by Help > Documentation and
  F1, backed by bundled user-focused Markdown articles, a Start Here default
  entry topic, and local search.
- Added a module-backed import catalog with built-in TOML manifests, per-format
  documentation and fixture notes, adapter declarations, typed-batch placeholder
  models, module-driven import detection metadata, and docs/catalog validation
  tests.
- Added several import-format expansion covering clipboard table paste,
  fixed-width text, JSON log streams, common web/app log templates, Markdown
  pipe tables, SpreadsheetML, XZ wrappers, OpenDocument Spreadsheet, expanded
  PostgreSQL plain dumps, and HAR files.
- Added planning alignment for the Data quality, profiling, and validation suite:
  accepted ADRs (`0046`, `0047`, `0048`), implementation source-of-truth plan
  link updates, and `design/SPEC.md` / `design/FUTURE_WINS.md` references.
- Added the Data Quality workspace suite with schema-derived default profiles,
  saved validation profiles, table/column profiling, validation rule execution,
  import reconciliation persistence, duplicate summaries, stale-run detection,
  query-result profiling via temporary DecentDB tables, post-import quality
  actions, isolate-backed non-SQL checks, paged violation inspection,
  Markdown/HTML/JSON quality report export, and the headless `dbench quality`
  command.
- Added desktop window placement persistence for Linux, macOS, and Windows,
  including restored size, maximized/fullscreen state, and best-effort monitor
  placement through the TOML application config.
- Added global error boundary in `main.dart` with `FlutterError.onError` and
  `PlatformDispatcher.instance.onError` handlers to capture unhandled Flutter
  and async errors, preventing silent crashes and improving diagnostic visibility.
- Added focused gateway interfaces (`DatabaseLifecycleGateway`,
  `SchemaIntrospectionGateway`, `QueryExecutionGateway`, `ExportGateway`,
  `ImportGateway`, `BranchWorkflowGateway`) to decompose the monolithic
  `WorkspaceDatabaseGateway` into single-responsibility contracts, improving
  testability and enabling targeted dependency injection for extracted controllers.
- Added `BranchController` as an extracted `ChangeNotifier` following the
  `DataQualityController` pattern, owning branch/snapshot state, workflow logic,
  and gateway interactions. `WorkspaceController` now delegates all branch
  operations to `branch.*` methods while maintaining backward-compatible public API.
- Added configurable query timeout via `query_timeout_seconds` TOML setting
  (default: 60 seconds). All query execution, page fetching, and export operations
  now enforce a timeout to prevent indefinite hangs on unresponsive worker isolates.
  Branch operations use a shorter 10-second timeout. Configurable through the
  preferences UI or by editing `config.toml` directly.
- Added request timeout mechanism to `DecentDbBridge` with per-operation timeout
  support, preventing infinite hangs when the worker isolate becomes unresponsive.

### Changed

- Bumped TOML config version from 3 to 4 to accommodate the new
  `query_timeout_seconds` setting. Existing configs are migrated automatically.

- Updated the pinned DecentDB Dart binding/runtime dependency from v2.6.0 to
  v2.7.0, adopting ABI v5 with stable `ddb_db_execute_on_branch` entry point,
  Dart `Database.branchWorkflow` APIs for named snapshots and branch-local SQL
  execution, and fixed canonical `sys.*` inspection query execution through
  prepared statements.
- Updated README badge to reflect DecentDB v2.7.0 alignment.
- Refactored `WorkspaceController` to extract branch/snapshot workflow logic into
  a dedicated `BranchController`, reducing the monolithic controller by ~300 lines
  and establishing the extraction pattern for future import/export controller work.
- Updated `WorkspaceController` lifecycle methods (`openDatabase`, `closeWorkspace`,
  `dispose`) to properly wire `BranchController` through `attachWorkspace` calls
  and cleanup, ensuring branch state resets on database transitions.
- Updated the desktop runtime/app icons to use the Decent Bench logo instead
  of the default Flutter logo.
- Updated the About dialog to use the Decent Bench logo, branded layout, and
  modern license/close actions.
- Replaced desktop platform placeholder identifiers with the stable
  `com.decentdb.bench` application identity documented in ADR-0053.
- Updated DecentDB v2.6 operational metrics display to keep a single
  compatibility note only when older runtimes still reject `sys.*` inspection
  views.
- Updated DecentDB operational metrics to read canonical `sys.*` inspection
  views through prepared paging now that the engine supports that path.
- Updated the TOML configuration version for write-queue settings while keeping
  the DecentDB write queue disabled by default.
- Updated roadmap, README, and ADR documentation to treat completed v2.x,
  metadata, typed exports, diagnostics, visualization, profiles, import
  transforms, saved queries, and editor work as shipped foundations rather than
  future wins.
- Revised table-editor, saved-query/project, and branch/snapshot ADRs around
  DecentDB v2.x query contracts, native types, and branch safety.
- Revised charting, Excel/Parquet export, and import-transform ADRs to match
  the implemented dependency and execution choices.
- Updated deferred menu commands for live database import, connection
  management, rerun import/export, and Parquet export so they remain visible
  but disabled until their accepted product/dependency contracts exist.
- Updated the TOML configuration version for persisted desktop window
  placement while keeping legacy configs loadable.
- Simplified the top command toolbar into a compact quick-action bar with New,
  Open, Import, and Commands entries while leaving full command access in the
  application menus and command palette.
- Updated native staging to prefer built artifacts from the local DecentDB path
  dependency before downloading release assets, so integration builds work
  against unpublished local DecentDB versions.
- Updated the README import documentation to align with the module-backed
  catalog, current supported formats, the future import-format backlog, and
  refreshed import roadmap.
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
