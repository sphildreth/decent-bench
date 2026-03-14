# Changelog

This file records notable project changes. It follows the
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[unreleased]: https://github.com/sphildreth/decent-bench/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/sphildreth/decent-bench/releases/tag/v1.0.0
