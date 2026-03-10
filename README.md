# Decent Bench

> The GUI for DecentDB.

Decent Bench is a cross-platform desktop app (Flutter) for power users who need
to work directly with **DecentDB**: open or create a database, inspect schema,
run the full pinned DecentDB SQL surface, and export shaped results. The longer
term product also includes drag-and-drop imports from common source formats.

## Project status

**Pre-alpha / active implementation.** Phase 1 is implemented and runnable
under `apps/decent-bench/`.

Current engine capability baseline: **DecentDB v1.6.x**.

### Implemented now (Phase 1)

- open an existing DecentDB file or create a new one
- inspect schema metadata loaded through the DecentDB adapter
- run SQL in a single editor tab with positional parameters
- page large result sets instead of materializing everything by default
- best-effort query cancellation
- export query results to CSV
- persist recent files, default page size, and CSV defaults in TOML
- run unit, smoke, and integration tests for the Phase 1 workflow

### Not implemented yet

- drag-and-drop open/import flow
- Import Wizard
- Excel, SQLite, and SQL dump imports
- multi-tab SQL editing
- autocomplete, snippets, and SQL formatting
- JSON, Parquet, and Excel export

For the full planned product scope, read:

- [design/PRD.md](/home/steven/source/decent-bench/design/PRD.md)
- [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
- [design/IMPLEMENTATION_PHASES.md](/home/steven/source/decent-bench/design/IMPLEMENTATION_PHASES.md)

## Engine baseline

- Decent Bench tracks the **DecentDB `v1.6.x` compatibility line**.
- The official DecentDB SQL reference for that line is the normative SQL
  contract for the app.
- Patch upgrades inside `v1.6.x` do not require doc churn unless they change
  capability surface, validation expectations, or packaging assumptions.

## Repository layout

```text
apps/decent-bench/              Flutter desktop app
.github/workflows/              CI workflows
design/                         Product docs, roadmap, and ADRs
design/adr/                     Architecture Decision Records
THIRD_PARTY_NOTICES.md          Third-party attribution tracking
LICENSE                         Apache 2.0 license
AGENTS.md                       Repo workflow and guardrails
```

## Source of truth

- Product requirements: [design/PRD.md](/home/steven/source/decent-bench/design/PRD.md)
- Product specification: [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
- Delivery phases: [design/IMPLEMENTATION_PHASES.md](/home/steven/source/decent-bench/design/IMPLEMENTATION_PHASES.md)
- ADR policy and decisions: [design/adr/README.md](/home/steven/source/decent-bench/design/adr/README.md)
- Repo workflow and validation rules: [AGENTS.md](/home/steven/source/decent-bench/AGENTS.md)

## Developer onboarding

### Prerequisites

- Git
- Flutter stable with desktop tooling enabled for your OS
- the native toolchain required by Flutter desktop on your platform
- Nim, for building the local DecentDB native library
- a local DecentDB checkout placed as a sibling repo, or an equivalent update
  to the path dependency in `apps/decent-bench/pubspec.yaml`

### Expected checkout layout

The current Flutter app depends on the upstream Dart binding via a local path:

```text
decent-bench/apps/decent-bench/pubspec.yaml -> ../../../decentdb/bindings/dart/dart
```

The simplest layout is:

```text
/path/to/source/decent-bench
/path/to/source/decentdb
```

### Bootstrap

1. Build the DecentDB native library:

```bash
cd ../decentdb
nimble build_lib
```

2. Install Flutter dependencies:

```bash
cd ../decent-bench/apps/decent-bench
flutter pub get
```

### Validate

From `apps/decent-bench/`:

```bash
flutter analyze
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter test
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter test integration_test
```

If `flutter` is not on `PATH`, use its full path instead.

### Run locally

From `apps/decent-bench/`, pick the desktop target you want:

```bash
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter run -d linux
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter run -d macos
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter run -d windows
```

The app resolves the native DecentDB library in this order:

1. `DECENTDB_NATIVE_LIB`
2. a bundled desktop-runner location
3. a sibling `../decentdb/build/` checkout discovered from the app working
   directory

If the sibling build is present and resolves correctly, you can omit
`DECENTDB_NATIVE_LIB` when launching locally.

### Local config file

Phase 1 stores config as TOML at:

- Linux: `~/.config/decent-bench/config.toml`
- macOS: `~/Library/Application Support/Decent Bench/config.toml`
- Windows: `%APPDATA%\Decent Bench\config.toml`

### Contributing

Read these before making non-trivial changes:

1. [design/PRD.md](/home/steven/source/decent-bench/design/PRD.md)
2. [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
3. [design/IMPLEMENTATION_PHASES.md](/home/steven/source/decent-bench/design/IMPLEMENTATION_PHASES.md)
4. [AGENTS.md](/home/steven/source/decent-bench/AGENTS.md)

Important repo expectations:

- keep changes small and testable
- keep heavy work off the UI thread
- prefer paging/streaming over full materialization
- create an ADR for lasting architectural or product-impacting decisions
- only add Apache-2.0-compatible dependencies
- update `THIRD_PARTY_NOTICES.md` when required by a dependency license

## License

Decent Bench is licensed under the Apache License 2.0. See `LICENSE`.

## Third-party notices

See `THIRD_PARTY_NOTICES.md` for dependency attributions and license tracking.
