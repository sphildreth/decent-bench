# Changelog

This file records notable project changes. It follows the
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[unreleased]: https://github.com/sphildreth/decent-bench/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/sphildreth/decent-bench/releases/tag/v1.1.0
[1.0.0]: https://github.com/sphildreth/decent-bench/releases/tag/v1.0.0
