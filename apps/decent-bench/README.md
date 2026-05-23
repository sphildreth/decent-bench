# Decent Bench App

This directory contains the shipped Flutter desktop app source for Decent
Bench `2.0.0`, which builds on the project's shipped `1.0.0` MVP release.

## Current state

- `pubspec.yaml`, `lib/`, `test/`, and `integration_test/` are present
- the workspace controller, multi-tab UI, desktop bridge, autocomplete,
  snippets, formatter, drag-and-drop entry flow, module-backed import registry,
  generic import wizard, SQLite import wizard, Excel import wizard, and SQL
  dump import wizard are in place
- reopening the same DecentDB file restores persisted query tabs for that
  workspace
- editor settings and SQL snippets persist in `config.toml`
- SQLite, Excel, and SQL dump inspection plus import execution run off the UI
  thread
- CSV, TSV, generic delimited text, JSON, NDJSON/JSONL, XML, HTML tables, and
  ZIP/GZip/BZip2 wrapper routing are implemented; wrappers extract supported
  inner files and route them into the normal generic or dedicated import path
- desktop runner folders (`linux/`, `macos/`, `windows/`) are checked in
- the DecentDB Dart package is pinned from the upstream Git tag
  (`https://github.com/sphildreth/decentdb`), currently `v2.6.0`, and desktop
  packaging stages the matching `decentdb-dart-native-<tag>-...` release asset
  plus the official `decentdb-migrate` and `decentdb` CLI tools from the full
  release asset
- Excel import currently supports `.xlsx`; legacy `.xls` files route through
  the existing conversion/normalization path and remain explicitly partial
- SQL dump import currently targets the MVP-lite parser scope documented in
  `design/SPEC.md`: common MariaDB/MySQL-style `CREATE TABLE` plus
  `INSERT ... VALUES`, with unsupported statements surfaced as warnings rather
  than hard failures when possible
- `apps/decent-bench/import_modules/builtin/` is the source of truth for
  built-in import modules; `assets/help/importing-data.md` lists formats users
  can import today, and `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md` is the
  single backlog for future import formats
- `CHANGELOG.md` records shipped releases starting with `1.0.0`
- native-library resolution uses bundled app location first, then system
  paths (`/usr/local/lib/`, `~/.local/lib/`), with a packaging helper
  to stage the library into built bundles
- schema browsing is backed by DecentDB's rich schema snapshot surface
  (`Schema.getSchemaSnapshot()`), including canonical DDL, checks, foreign keys,
  generated-column metadata, triggers, and temp-object metadata
- DecentDB v2.6.x tooling metadata and query contracts flow through the bridge
  for schema fingerprints, parameter contracts, and result-column contracts
- read-only ERD viewing uses the loaded schema snapshot to draw table nodes,
  foreign-key edges, missing-reference placeholders, search/filter context, and
  table-preview navigation without adding schema-design or mutation workflows
- DecentDB v2.6.x native semantic/spatial types have first-class display
  helpers for schema details, result cells, autocomplete/snippets, import type
  overrides, WKB copy, and CSV export formatting
- DecentDB v2.6.0 operational metrics, queued writes, SQL compatibility, local
  Web Console launch, sync/reactive inspection, and Lua extension discovery are
  wired into the desktop workbench within the documented ADR boundaries
- JSON and NDJSON result export reuse the paged query pipeline and can include
  column type metadata plus schema fingerprints
- ERD image export writes full-diagram or viewport PNG/JPG files with safe
  raster limits before allocation
- legacy DecentDB format-version open failures offer a safe copy-based
  migration through `decentdb-migrate --source <old> --dest <new>` and then open
  the migrated copy

## Validation

From `apps/decent-bench/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter test integration_test
flutter run -d linux
flutter build linux
dart run tool/stage_decentdb_native.dart --bundle build/linux/x64/release/bundle
dart run tool/stage_decentdb_native.dart --bundle build/linux/x64/release/bundle --verify-only
```

The app expects a compatible DecentDB v2.6.0 native library to be available via:

1. System library paths (`/usr/local/lib/`, `~/.local/lib/`)
2. Bundled with the app

CI, local tests, and Linux desktop builds resolve the pinned `decentdb` tag from
`pubspec.lock` and use the matching `decentdb-dart-native-<tag>-...` asset from
DecentDB Releases. The migration workflow resolves `decentdb-migrate` from
PATH, `DECENTDB_MIGRATE_PATH`, a packaged bundle, or the pinned full release
asset. The optional Web Console workflow resolves the `decentdb` CLI from
PATH, `DECENTDB_CLI_PATH`, a packaged bundle, or the same pinned full release
asset. You can still override the staged native library, migration tool, and
CLI with
`tool/stage_decentdb_native.dart --source <native-lib-path>
--migration-tool-source <decentdb-migrate-path> --cli-source <decentdb-path>`
when needed.

Workspace tab drafts are stored separately from `config.toml` under the
platform-specific `workspaces/` directory documented in the root
[README.md](/home/steven/source/decent-bench/README.md).

For packaged builds on other platforms, use the same staging helper with the
platform bundle root:

- macOS: `build/macos/Build/Products/Release/decent_bench.app`
- Windows: `build/windows/x64/runner/Release`
