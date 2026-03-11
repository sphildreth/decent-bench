<p align="center">
  <img
    src="assets/logo-256x256.png"
    alt="Decent Bench logo"
  >
</p>

<h1 align="center">Decent Bench</h1>

<p align="center"><strong>The DecentDB desktop workbench.</strong></p>

<p align="center">
  Import Excel, SQLite, and MySQL/MariaDB-style SQL dumps into DecentDB,
  inspect schema, iterate on SQL in a multi-tab editor, and export shaped
  results from a fast local-first desktop app built with Flutter.
</p>

<p align="center">
  <a href="https://github.com/sphildreth/decent-bench/actions/workflows/flutter-phase1.yml">
    <img
      alt="CI"
      src="https://github.com/sphildreth/decent-bench/actions/workflows/flutter-phase1.yml/badge.svg"
    >
  </a>
  <a href="LICENSE">
    <img
      alt="License: Apache 2.0"
      src="https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square"
    >
  </a>
  <img
    alt="Flutter desktop"
    src="https://img.shields.io/badge/Flutter-desktop-02569B?style=flat-square&logo=flutter&logoColor=white"
  >
  <img
    alt="DecentDB v1.6.x"
    src="https://img.shields.io/badge/DecentDB-v1.6.x-6f42c1?style=flat-square"
  >
</p>

<p align="center">
  <a href="#highlights">Highlights</a> •
  <a href="#project-status">Status</a> •
  <a href="#supported-file-types">Supported file types</a> •
  <a href="#quick-start">Quick start</a> •
  <a href="#repository-tour">Repository tour</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#contributing">Contributing</a>
</p>

## What is Decent Bench?

Decent Bench is a cross-platform desktop app for people who want a
**DecentDB-first** workflow:

- open or create a local DecentDB database
- drag and drop a file to open it or launch the right import wizard
- inspect schema without leaving the app
- run the pinned DecentDB SQL surface in a multi-tab editor
- export shaped query results when the data is ready

The product direction and implementation contract live in
[`design/PRD.md`](design/PRD.md) and [`design/SPEC.md`](design/SPEC.md).
Current engine compatibility is pinned to **DecentDB `v1.6.x`**, and the
canonical DecentDB desktop file extension is **`.ddb`**.

## Highlights

- **DecentDB-first, local-first workflow** with fast open/create, recent files,
  and drag-and-drop import entry.
- **Import wizards for SQLite, Excel, and SQL dumps** with preview,
  rename/type-override transforms, progress reporting, warnings, and summary
  actions.
- **Modern SQL workbench** with multiple tabs, per-tab results and errors,
  schema-aware autocomplete, snippets, and deterministic formatting.
- **Responsive by design** with background import work, paged results, and
  best-effort query cancellation instead of full default materialization.
- **Desktop-friendly packaging** with a repeatable native-library staging helper
  for Linux, macOS, and Windows bundles.
- **Config and workspace persistence** stored as TOML plus per-database
  workspace state.

## Project status

> **Pre-alpha / active implementation.** The app under `apps/decent-bench/`
> is already runnable and covers the core MVP loop: import or open a database,
> inspect schema, run SQL, stream/page through results, and export to CSV.

### Current feature matrix

| Area | Status | Details |
| --- | --- | --- |
| Open / create DecentDB files | ✅ Implemented | Open existing `.ddb` files or create new ones from the desktop app. |
| Drag and drop | ✅ Implemented | `.ddb` opens directly; `.db`, `.sqlite`, `.sqlite3`, `.xlsx`, and `.sql` launch the matching workflow. |
| SQLite import wizard | ✅ Implemented | Table selection, schema preview, rename/type overrides, progress, cancellation, and summary actions. |
| Excel import wizard | ✅ Implemented | Workbook and worksheet selection, header-row handling, type inference, rename/type overrides, and warnings. |
| SQL dump import wizard | ✅ Implemented | MVP-lite support for common MariaDB/MySQL-style `CREATE TABLE` plus `INSERT ... VALUES` flows. |
| Schema browser | ✅ Implemented | Tables, views, columns, indexes, and exposed constraint metadata loaded through the DecentDB adapter. |
| SQL editor | ✅ Implemented | Multi-tab editor with isolated per-tab results, errors, positional parameters, and keyboard-driven workflows. |
| Autocomplete / snippets / formatter | ✅ Implemented | Schema-aware completions, user-editable snippets, and deterministic SQL formatting. |
| Results grid | ✅ Implemented | Paged results instead of full default materialization. |
| Export | ✅ CSV now | CSV export is live; JSON, Parquet, and Excel export are deferred. |
| Config and workspace restore | ✅ Implemented | TOML-backed app config plus per-database workspace tab restoration. |
| Legacy `.xls` import | ⚠️ Not yet implemented | Legacy workbooks are detected and surfaced with a conversion hint to save as `.xlsx`. |

## Supported file types

| File type | Current behavior | Notes |
| --- | --- | --- |
| `.ddb` | Open directly | Main DecentDB workspace format. |
| `.db`, `.sqlite`, `.sqlite3` | Import now | SQLite import wizard runs in the background and previews tables before import. |
| `.xlsx` | Import now | Excel import wizard supports worksheet selection and inferred DecentDB type mapping. |
| `.sql` | Import now | Targets common MariaDB/MySQL-style dumps and preserves unsupported statements as warnings when possible. |
| `.xls` | Recognized, not imported | Convert to `.xlsx` first. |
| Anything else | Not supported | The app should surface a clear unsupported-type path. |

## Quick start

### Prerequisites

- Git
- Flutter stable with desktop tooling enabled for your OS
- The native toolchain required by Flutter desktop on your platform
- Nim, to build the local DecentDB native library
- A sibling `decentdb` checkout, or an equivalent update to the local path
  dependency in `apps/decent-bench/pubspec.yaml`

### Expected checkout layout

The current Flutter app consumes the upstream Dart binding from a sibling local
checkout:

```text
/path/to/source/decent-bench
/path/to/source/decentdb
```

`apps/decent-bench/pubspec.yaml` currently points to:

```text
../../../decentdb/bindings/dart/dart
```

### Bootstrap

```bash
cd ../decentdb
nimble build_lib

cd ../decent-bench/apps/decent-bench
flutter pub get
```

### Run locally

Use the native library filename that matches your platform:
`libc_api.so` on Linux, `libc_api.dylib` on macOS, and `c_api.dll` on Windows.

```bash
cd apps/decent-bench
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/<platform-native-lib> flutter run -d linux
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/<platform-native-lib> flutter run -d macos
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/<platform-native-lib> flutter run -d windows
```

The app resolves the native DecentDB library in this order:

1. `DECENTDB_NATIVE_LIB`
2. A bundled desktop-runner location
3. A sibling `../decentdb/build/` checkout discovered from the app working
   directory

If the sibling build is present and resolves correctly, you can often omit
`DECENTDB_NATIVE_LIB` during local development.

### Validate

From `apps/decent-bench/`:

```bash
flutter analyze
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter test
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter test integration_test
```

### Package desktop builds

Build the Flutter desktop bundle first, then stage the DecentDB native library
into the generated output:

```bash
cd apps/decent-bench
flutter build linux

dart run tool/stage_decentdb_native.dart --bundle build/linux/x64/release/bundle
dart run tool/stage_decentdb_native.dart --bundle build/linux/x64/release/bundle --verify-only
```

Equivalent bundle roots:

- macOS: `build/macos/Build/Products/Release/decent_bench.app`
- Windows: `build/windows/x64/runner/Release`

The staging helper uses the same resolution contract as the app. See
[`design/adr/0009-desktop-native-library-packaging-and-resolution.md`](design/adr/0009-desktop-native-library-packaging-and-resolution.md).

### Command-line startup path

Packaged desktop builds expose a narrow CLI entry for import flows:

```bash
dbench --import /path/to/source.xlsx
```

That startup path reuses the same file-kind detection rules as drag and drop and
opens the matching import wizard after initialization completes. See
[`design/adr/0013-desktop-cli-import-launch-and-binary-name.md`](design/adr/0013-desktop-cli-import-launch-and-binary-name.md).

## Configuration and workspace state

Global app config is stored as TOML at:

- Linux: `~/.config/decent-bench/config.toml`
- macOS: `~/Library/Application Support/Decent Bench/config.toml`
- Windows: `%APPDATA%\Decent Bench\config.toml`

`config.toml` currently stores recent files, CSV defaults, editor settings, and
SQL snippets.

Per-database workspace state is stored separately under:

- Linux: `~/.config/decent-bench/workspaces/`
- macOS: `~/Library/Application Support/Decent Bench/workspaces/`
- Windows: `%APPDATA%\Decent Bench\workspaces\`

That workspace-state store restores query tabs only when the same database is
opened again. See
[`design/adr/0004-workspace-state-persistence.md`](design/adr/0004-workspace-state-persistence.md)
and
[`design/adr/0005-editor-config-and-snippet-persistence.md`](design/adr/0005-editor-config-and-snippet-persistence.md).

## Architecture and source of truth

If repository docs ever appear to disagree, treat the implementation scope in
[`design/SPEC.md`](design/SPEC.md) as authoritative over the PRD.

Primary documents:

- [`design/PRD.md`](design/PRD.md) — product goals, user journeys, and non-goals
- [`design/SPEC.md`](design/SPEC.md) — implementation scope and MVP contract
- [`design/IMPLEMENTATION_PHASES.md`](design/IMPLEMENTATION_PHASES.md) — phased
  delivery plan and status
- [`design/adr/README.md`](design/adr/README.md) — ADR policy and workflow
- [`AGENTS.md`](AGENTS.md) — repository guardrails and coding-agent workflow

At a high level, the app is organized around:

- a Flutter desktop shell in `apps/decent-bench/`
- a DecentDB Dart binding adapter over the native library
- import pipelines for SQLite, Excel, and SQL dumps
- a multi-tab SQL workspace with paged results and CSV export
- TOML-backed config plus per-database workspace persistence

## Repository tour

| Path | What it contains |
| --- | --- |
| `apps/decent-bench/` | Flutter desktop app source, tests, packaging helper, and desktop runner folders |
| `apps/decent-bench/lib/` | App shell, theme system, workspace feature code, dialogs, controllers, and infrastructure |
| `apps/decent-bench/test/` | Unit and widget tests for app startup, workspace logic, config, formatting, autocomplete, and native-library resolution |
| `apps/decent-bench/integration_test/` | Higher-level integration coverage for the desktop workflow |
| `design/` | PRD, SPEC, roadmap, and architecture docs |
| `design/adr/` | Architecture Decision Records for long-lived product and technical choices |
| `.github/workflows/` | CI that runs analysis, tests, integration tests, and desktop package verification |
| `assets/` | Shared project assets, including the repository logo |
| `test-data/` | Sample data used during development and testing |
| `themes/` | Theme-related assets and supporting material |
| `THIRD_PARTY_NOTICES.md` | Dependency attribution and license tracking |

## Quality gates and manual verification

The repository already checks important developer workflows in CI, and local
validation should still focus on the behavior that matters most:

- Run a large query and confirm paging keeps the UI responsive.
- Cancel a longer-running query and confirm the tab reports cancellation or
  partial results cleanly.
- Run SQLite, Excel, and SQL dump imports large enough to show progress, then
  verify summary messaging and cancellation behavior.
- Export CSV with different header and delimiter settings and verify the file
  matches the visible result shape.
- Verify packaged builds can resolve the staged native library without relying
  on `DECENTDB_NATIVE_LIB`.

## Roadmap

Implemented today:

- open/create DecentDB workspaces
- drag-and-drop open/import flows
- SQLite, Excel, and SQL dump import wizards
- schema browsing for the pinned DecentDB compatibility line
- multi-tab SQL editing with autocomplete, snippets, and formatter support
- paged results, best-effort cancellation, and CSV export
- TOML-backed settings and workspace restoration
- native-library packaging support for Linux, macOS, and Windows

Planned / not yet implemented:

- JSON, Parquet, and Excel export
- legacy binary `.xls` parsing
- computed-column import transforms
- broader import/connectivity surface beyond the current MVP-lite scope

For the full product direction, read [`design/PRD.md`](design/PRD.md),
[`design/SPEC.md`](design/SPEC.md), and
[`design/IMPLEMENTATION_PHASES.md`](design/IMPLEMENTATION_PHASES.md).

## Contributing

Before making a non-trivial change, read:

1. [`design/PRD.md`](design/PRD.md)
2. [`design/SPEC.md`](design/SPEC.md)
3. [`design/IMPLEMENTATION_PHASES.md`](design/IMPLEMENTATION_PHASES.md)
4. [`AGENTS.md`](AGENTS.md)

Project expectations:

- Keep changes small, reviewable, and testable.
- Keep heavy work off the UI thread.
- Prefer paging/streaming over full materialization.
- Create an ADR for lasting architectural or product-impacting decisions.
- Only add Apache-2.0-compatible dependencies.
- Update `THIRD_PARTY_NOTICES.md` when a dependency license requires it.

Recommended local validation for meaningful changes:

```bash
cd apps/decent-bench
flutter analyze
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter test
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter test integration_test
```

## FAQ

### Is this a general-purpose database admin tool?

No. Decent Bench is intentionally **DecentDB-first**. The core workflow is to
open or create a local DecentDB file, import supported sources into it, inspect
schema, run SQL, and export results.

### Does the app load entire query results into memory?

No by default. Paging/streaming is a core design constraint, and the results
experience is built around paged retrieval rather than full materialization.

### Can I import legacy `.xls` Excel files?

Not yet. The current app detects legacy workbooks and surfaces a conversion hint
so you can save them as `.xlsx` first.

### What should I do if the native library is not found?

First point `DECENTDB_NATIVE_LIB` at the built DecentDB native library. If
you are packaging a build, use
`dart run tool/stage_decentdb_native.dart --bundle <bundle-path>` and verify the
bundle with `--verify-only`.

### Can I script import startup from the command line?

Yes. Packaged desktop builds expose `dbench --import <path>` to launch the
matching import wizard on startup.

## License

Decent Bench is licensed under the Apache License 2.0. See [`LICENSE`](LICENSE).

## Third-party notices

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for dependency
attributions and license tracking.
