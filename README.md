<p align="center">
  <img src="assets/logo-256x256.png" alt="Decent Bench logo" width="180">
</p>

<h1 align="center">Decent Bench</h1>

<p align="center">
  <strong>The modern, local-first DecentDB desktop workbench.</strong>
</p>

<p align="center">
  <a href="https://github.com/sphildreth/decent-bench/actions/workflows/flutter-build.yml">
    <img alt="CI" src="https://github.com/sphildreth/decent-bench/actions/workflows/flutter-build.yml/badge.svg">
  </a>
  <a href="https://github.com/sphildreth/decent-bench/releases">
    <img alt="Release" src="https://img.shields.io/github/v/release/sphildreth/decent-bench?style=flat-square&color=success">
  </a>
  <a href="LICENSE">
    <img alt="License: Apache 2.0" src="https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square">
  </a>
  <img alt="Flutter desktop" src="https://img.shields.io/badge/Flutter-desktop-02569B?style=flat-square&logo=flutter&logoColor=white">
  <img alt="DecentDB v2.6.0" src="https://img.shields.io/badge/DecentDB-v2.6.0-6f42c1?style=flat-square">
</p>

<p align="center">
  Import CSV/TSV, JSON/NDJSON, XML, HTML, Excel, SQLite, SQL dumps, and archive-wrapped sources into DecentDB, inspect schema, iterate on SQL in a multi-tab editor, visualize results, and export shaped data from a fast, responsive desktop app built with Flutter.
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-getting-started">Getting Started</a> •
  <a href="#-developer-onboarding">Developer Onboarding</a> •
  <a href="#-roadmap">Roadmap</a> •
  <a href="#-contributing">Contributing</a>
</p>

<p align="center">
  <img src="assets/screenshot.png" alt="Decent Bench App Screenshot" width="800" style="border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1);">
</p>

---

## ✨ Features

- 🚀 **DecentDB-First:** A fully local-first workflow. Fast open/create,
  recent files, intuitive drag-and-drop support, and guided legacy `.ddb`
  migration through the official `decentdb-migrate` tool.
- 📥 **Smart Import Wizards:** Import delimited text, JSON/NDJSON, XML, HTML tables, Excel, SQLite, SQL dumps, and wrapped archives (`.zip`, `.gz`, `.tgz`, `.bz2`, `.tbz2`). Includes previews, rename/type-override transforms, row-local filters/defaults/computed columns/dedup plans for generic imports, progress reporting, and post-import summaries.
- 🛠️ **Modern SQL Workbench:** Iterate in a multi-tab editor with isolated per-tab results, schema-aware autocomplete, editable snippets, deterministic formatting, typed parameter fields, per-tab query history, and a searchable command palette.
- ⚡ **Performance-Focused:** Background imports, paginated/streamed results grids, and best-effort query cancellation ensure the UI never freezes.
- 🧭 **Rich Engine Metadata:** Schema browsing is powered by DecentDB's rich
  upstream schema snapshot (tables/views/indexes/triggers, checks, foreign keys,
  generated columns, temp-object metadata, and canonical DDL), with v2.6.x
  tooling metadata and query contracts used for schema fingerprints, parameter
  types, and result-column types.
- 📊 **DecentDB v2.6 Diagnostics:** Database Statistics includes WAL, storage,
  write-queue, sync, reactive, relay, and Lua extension inspection surfaces,
  plus optional queued inline table edits and a read-only local Web Console
  launcher.
- 🧬 **Native Type Awareness:** DecentDB v2.6.x semantic and spatial types are
  surfaced in schema details, result metadata, autocomplete, snippets, import
  type overrides, copy behavior, and CSV export display values.
- 📊 **Diagnostics & Visualization:** Column statistics, database statistics,
  EXPLAIN visualization, and result charts help users understand data and query
  behavior without leaving the workspace.
- 🗺️ **Read-Only ERD Viewer:** Inspect table relationships from loaded
  foreign-key metadata in the navigation pane, search tables/columns, jump from
  ERD nodes to limited table-preview queries, and export full diagrams or the
  current viewport as PNG/JPG.
- 🛡️ **Safer SQL Execution:** Query contracts and SQL risk classification power
  typed parameters, result-column metadata, and prompts before mutating or
  destructive statements. Native branch execution is surfaced as unavailable
  until the Dart binding exposes public branch APIs.
- 🎨 **Workspace Persistence:** Application preferences are stored as TOML, and per-database workspace state is stored separately for reliable tab and query restoration.
- 🪵 **Operational Visibility:** Open the DecentDB-backed application log database directly from `Tools -> View Log`.
- 🧪 **Import Validation:** Blocking failure dialogs and richer import summaries make unsuccessful imports obvious and successful imports easier to verify.
- 📤 **Typed Exports:** CSV, JSON, NDJSON, and Excel export stream result pages
  and preserve DecentDB v2.6.x native value metadata where the format supports
  it. Result charts can be exported as PNG, and ERDs can be exported as PNG/JPG.
- 📦 **Desktop Native:** Packaged for Linux, macOS, and Windows with a repeatable native-library staging helper.

### Supported File Types

| File type | Action | Details |
| --- | --- | --- |
| `.ddb` | **Open / Migrate** | Current-format files open directly. Legacy format-version failures offer a copy-based `decentdb-migrate` upgrade path. |
| `.db`, `.sqlite`, `.sqlite3` | **Import Wizard** | Background import with schema preview and table selection. |
| `.csv`, `.tsv` | **Import Wizard** | CSV/TSV import through the generic delimited-text pipeline. |
| `.txt`, `.dat`, `.log`, `.psv` | **Import Wizard** | Generic delimited-text import with header, delimiter, quoting, malformed-row, preview, and type-override controls. |
| `.json`, `.ndjson`, `.jsonl` | **Import Wizard** | Structured and line-oriented JSON import with relational previews. |
| `.xml` | **Import Wizard** | XML import with flatten or parent-child normalization strategies. |
| `.html`, `.htm` | **Import Wizard** | HTML table extraction with table selection and header inference. |
| `.xlsx` | **Import Wizard** | Select worksheets and map DecentDB types automatically. |
| `.xls` | *Partial / Warning Path* | Routed through the legacy Excel path and may require conversion/normalization warnings. |
| `.sql` | **Import Wizard** | Supports the current MariaDB/MySQL-style MVP-lite dump scope (`CREATE TABLE` plus common `INSERT ... VALUES`). |
| `.zip` | **Unwrap & Import** | Archive wrapper that discovers supported inner files and routes them to the normal import flow. |
| `.gz`, `.tar.gz`, `.tgz` | **Unwrap & Import** | Supports single-file gzip unwrap and tar+gzip archive inspection/extraction. |
| `.bz2`, `.tar.bz2`, `.tbz2` | **Unwrap & Import** | Supports single-file bzip2 unwrap and tar+bzip2 archive inspection/extraction. |
| `.bak` | *Recognized / Not Implemented* | Tracked for future container-assisted SQL Server backup import. |

### Recognized But Not Yet Implemented

The current build recognizes, but does not yet import, several formats and
wrappers including fixed-width text, `.ods`, `.yaml`, `.yml`, `.toml`, `.md`,
`.duckdb`, `.mdb`, `.accdb`, `.dbf`, `.bak`, `.parquet`, `.pdf`, and `.xz`.

## 🚀 Getting Started (End Users)

*Binary releases for Linux, macOS, and Windows are listed on the [Releases](https://github.com/sphildreth/decent-bench/releases) page.*

### Command-line Launch
Packaged desktop builds expose a small CLI surface for direct-open and import
flows:
```bash
dbench /path/to/workspace.ddb
dbench --import /path/to/source.xlsx
dbench --in /path/to/source.sqlite --out /tmp/import.ddb
dbench --version
```

- Passing a `.ddb` path opens that workspace directly.
- `--import` reuses drag-and-drop detection rules and opens the matching wizard.
- `--in` / `--out` run the shipped headless import path.
- `--silent` suppresses headless progress output.
- `--plan` loads and validates a versioned import/export profile document for
  repeatable headless workflows.
- `--help` and `--version` print CLI help and the app version.

## 💻 Developer Onboarding

Want to build from source or contribute? Welcome! 

### Prerequisites

- **Git**
- **Flutter** (stable, desktop tooling enabled)
- OS-specific native toolchain (C++ compiler, etc.)
- `tar` on systems where you want tar+gzip or tar+bzip2 archive detection and extraction
- A matching **DecentDB native library** for the pinned app version

Decent Bench pins the upstream Dart package by Git tag and expects the matching
DecentDB desktop native library alongside it. CI and release packaging currently
resolve `v2.6.0` from `apps/decent-bench/pubspec.lock` and download the matching
`decentdb-dart-native-<tag>-...` asset from
[`sphildreth/decentdb` Releases](https://github.com/sphildreth/decentdb/releases).

### 1. Bootstrap the Flutter App
```bash
cd apps/decent-bench
flutter pub get
```

### 2. Install the Matching DecentDB Native Library
The app and test tooling resolve the pinned `decentdb` tag from
`apps/decent-bench/pubspec.lock` and download the matching
`decentdb-dart-native-<tag>-...` release asset from DecentDB Releases into a
local cache when needed. The app still prefers a bundled native library first,
then the cached pinned asset, then common system locations.

### 3. Run Locally
```bash
flutter run -d linux
```

### 4. Testing & Validation
```bash
flutter analyze
flutter test
flutter test integration_test
```

These commands will fetch the matching pinned DecentDB native library on first
use if it is not already cached. Legacy `.ddb` migration also resolves the
official `decentdb-migrate` executable from PATH, an explicit
`DECENTDB_MIGRATE_PATH`, a packaged app bundle, or the pinned full DecentDB
release asset. The optional Web Console workflow resolves the official
`decentdb` CLI from PATH, `DECENTDB_CLI_PATH`, a packaged bundle, or the same
pinned full release asset.

### 5. Packaging Desktop Builds
Build the bundle, then use the staging helper to inject the DecentDB native
library, `decentdb-migrate`, and the `decentdb` CLI. The `--source` path can
point at either an extracted `decentdb-dart-native-<tag>-...` release asset or a
local DecentDB build, `--migration-tool-source` can point at a local migration
executable, and `--cli-source` can point at a local CLI executable:
```bash
flutter build linux
dart run tool/stage_decentdb_native.dart --bundle build/linux/x64/release/bundle
dart run tool/stage_decentdb_native.dart --bundle build/linux/x64/release/bundle --source /path/to/libdecentdb.so --migration-tool-source /path/to/decentdb-migrate --cli-source /path/to/decentdb
```
If `--source` is omitted, the helper resolves and downloads the pinned matching
DecentDB native release asset automatically. If `--migration-tool-source` is
omitted, it resolves the official migration tool from the pinned full release
asset. If `--cli-source` is omitted, it resolves the official CLI from the
pinned full release asset.

*(For macOS use `build/macos/Build/Products/Release/decent_bench.app` and
Windows `build/windows/x64/runner/Release`.)*

## 🏗️ Architecture & Configuration

The application stores its local state under the platform app-support
directory:
- **Linux:** `~/.config/decent-bench/`
- **macOS:** `~/Library/Application Support/Decent Bench/`
- **Windows:** `%APPDATA%\Decent Bench\`

Typical files under that root include:
- `config.toml` for application preferences
- per-workspace `.json` state files for saved tabs/history/restoration
- `decent-bench-log.ddb` for the application log database opened by
  `Tools -> View Log`

**Project Source of Truth:**
- 📐 [`design/PRD.md`](design/PRD.md) — Product goals and user journeys
- 📝 [`design/SPEC.md`](design/SPEC.md) — Implementation scope (Authoritative)
- 🧠 [`design/adr/README.md`](design/adr/README.md) — Architecture Decision Records
- 🤖 [`AGENTS.md`](AGENTS.md) — Agent instructions and guardrails

## 🗺️ Roadmap

**Shipped through 2.0.0:**
- ✅ Drag-and-drop open/import flows
- ✅ Expansive import support: delimited text, JSON/NDJSON, XML, HTML tables, SQLite, Excel, and SQL dumps
- ✅ ZIP, GZip, and BZip2 wrapper routing for imports
- ✅ Headless CLI import mode
- ✅ DecentDB v2.6.0 binding alignment, native asset staging, CLI staging, and pinned runtime resolution
- ✅ In-app application log viewing
- ✅ Clear blocking import-failure dialogs and richer import summaries
- ✅ Schema browsing, metadata fingerprints, query contracts, and native type display
- ✅ Multi-tab SQL editing with typed parameters, autocomplete, snippets, formatter, command palette, and query history
- ✅ Paged results, query cancellation, safe-run prompts, and CSV/JSON/NDJSON export
- ✅ Excel result export and PNG chart export
- ✅ Column statistics, database statistics, EXPLAIN visualization, and result charts
- ✅ Read-only ERD viewer with table-preview navigation and PNG/JPG image export
- ✅ Import/export profiles plus row-local generic import transforms
- ✅ Local app config plus persistent per-database workspaces

**Near-Term Roadmap:**
- 🔜 **Public branch/snapshot API wiring:** Complete branch-local execution,
  edits, imports, restore, and merge once the DecentDB Dart package exposes the
  native branch API publicly.
- 🔜 **Parquet export:** Select and validate an Apache-compatible Dart or FFI
  writer before shipping the format.
- 🔜 **SDK generation workflow:** Promote the schema-first TypeScript prototype
  into a user-facing CLI/UI workflow.
- 🔜 **Connector expansion:** Add dependency-vetted imports for ODS, DuckDB,
  Parquet, PostgreSQL dumps, live database sources, and legacy formats.

## 🤝 Contributing

We love contributions! Before making non-trivial changes, please review the [`SPEC.md`](design/SPEC.md) and our [`AGENTS.md`](AGENTS.md) guidelines.

**Core Rules:**
1. **Performance First:** Keep heavy work off the UI thread. Use isolates.
2. **Paging Everywhere:** Stream data, never fully materialize large results.
3. **ADRs are Mandatory:** Document lasting architectural or product-impacting decisions.
4. **License Compliance:** Only add Apache 2.0 compatible dependencies.

## ❓ FAQ

**Is this a general-purpose database admin tool?**
No. Decent Bench is intentionally **DecentDB-first**. 

**Does the app load entire query results into memory?**
No. Paging and streaming are core design constraints to ensure UI responsiveness.

## 📄 License & Attribution

Decent Bench is open-source under the [Apache License 2.0](LICENSE).  
For third-party dependencies and attributions, see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
