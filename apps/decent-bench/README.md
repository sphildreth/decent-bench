# Decent Bench App

This directory contains the shipped Flutter desktop app source for Decent
Bench `1.0.0`, which is the project's MVP release.

## Current state

- `pubspec.yaml`, `lib/`, `test/`, and `integration_test/` are present
- the workspace controller, multi-tab UI, desktop bridge, autocomplete,
  snippets, formatter, drag-and-drop entry flow, shared import registry,
  generic import wizard, SQLite import wizard, Excel import wizard, and SQL
  dump import wizard are in place
- reopening the same DecentDB file restores persisted query tabs for that
  workspace
- editor settings and SQL snippets persist in `config.toml`
- SQLite, Excel, and SQL dump inspection plus import execution run off the UI
  thread
- CSV, TSV, generic delimited text, JSON, NDJSON/JSONL, XML, HTML tables, and
  ZIP/GZip wrapper routing now use the generic import preview/execution path
- desktop runner folders (`linux/`, `macos/`, `windows/`) are checked in
- the DecentDB Dart package is pinned from the upstream Git tag
  (`https://github.com/sphildreth/decentdb`), and desktop packaging stages the
  matching `decentdb-dart-native-<tag>-...` release asset
- Excel import currently supports `.xlsx`; legacy `.xls` files route through
  the existing conversion/normalization path and remain explicitly partial
- SQL dump import currently targets the MVP-lite parser scope documented in
  `design/SPEC.md`: common MariaDB/MySQL-style `CREATE TABLE` plus
  `INSERT ... VALUES`, with unsupported statements surfaced as warnings rather
  than hard failures when possible
- `docs/IMPORT_FORMATS.md` summarizes the currently implemented, partial, and
  recognized-but-unimplemented import formats
- `CHANGELOG.md` records shipped releases starting with `1.0.0`
- native-library resolution uses bundled app location first, then system
  paths (`/usr/local/lib/`, `~/.local/lib/`), with a packaging helper
  to stage the library into built bundles
- schema browsing is backed by DecentDB's rich schema snapshot surface
  (`Schema.getSchemaSnapshot()`), including canonical DDL, checks, foreign keys,
  generated-column metadata, triggers, and temp-object metadata

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

The app expects a compatible DecentDB v2.x native library to be available via:

1. System library paths (`/usr/local/lib/`, `~/.local/lib/`)
2. Bundled with the app

CI, local tests, and Linux desktop builds resolve the pinned `decentdb` tag from
`pubspec.lock` and use the matching `decentdb-dart-native-<tag>-...` asset from
DecentDB Releases. You can still override the source library explicitly with
`tool/stage_decentdb_native.dart --source <native-lib-path>` when needed.

Workspace tab drafts are stored separately from `config.toml` under the
platform-specific `workspaces/` directory documented in the root
[README.md](/home/steven/source/decent-bench/README.md).

For packaged builds on other platforms, use the same staging helper with the
platform bundle root:

- macOS: `build/macos/Build/Products/Release/decent_bench.app`
- Windows: `build/windows/x64/runner/Release`
