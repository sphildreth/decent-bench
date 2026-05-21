# DecentDB 2.6.0 Enhancement Plan

**Status:** Implemented
**Last reviewed:** 2026-05-21  
**Inputs reviewed:**
- `/home/steven/src/github/decentdb/docs/about/changelog.md`
- `/home/steven/src/github/decentdb/docs/api/dart.md`
- `/home/steven/src/github/decentdb/docs/user-guide/write-concurrency.md`
- `/home/steven/src/github/decentdb/docs/user-guide/sql-feature-matrix.md`
- `/home/steven/src/github/decentdb/docs/user-guide/sync/index.md`
- `/home/steven/src/github/decentdb/docs/user-guide/lua-extensions.md`
- `/home/steven/src/github/decentdb/docs/api/wasm.md`
- `/home/steven/src/github/decentdb/docs/api/cli-reference.md`
- `design/PRD.md`
- `design/SPEC.md`

## Goal

Upgrade Decent Bench to DecentDB v2.6.0, then adopt new engine features in a
way that strengthens the existing desktop workbench without turning Decent Bench
into a general-purpose database admin server, browser app, or sync management
suite by default.

## Phase Map

The actionable roadmap is Phase 1 through Phase 6. Phase 0 is the completed
dependency alignment, and WASM/browser work is tracked separately rather than
treated as part of the desktop v2.6.0 adoption sequence.

| Phase | Status | Workstream | ADR Required? | Notes |
|---:|---|---|---|---|
| 0 | Done | Compatibility upgrade | No | Version pin, lockfile, notices, and validation only. |
| 1 | Done | Observability and SQL surface parity | No | Database Statistics now loads bounded operational metrics and SQL tooling covers the v2.6 compatibility surface. |
| 2 | Done | Queued write integration | [ADR-0038](adr/0038-queued-write-integration.md) | Write queue config is disabled by default, open options are passed only when enabled, and inline table DML uses queued writes when configured. |
| 3 | Done | Optional local Web Console | [ADR-0039](adr/0039-local-web-console-companion-process.md) | CLI resolution/caching, process lifecycle service, and `Tools -> Open Web Console` are implemented with read-only/auth-preserving defaults. |
| 4 | Done | Reactive refresh boundary | [ADR-0040](adr/0040-reactive-refresh-watch-lifecycle.md) | Public Dart watch APIs are not available in v2.6.0; private C ABI watch wiring is intentionally not shipped. Reactive metrics are surfaced in diagnostics. |
| 5 | Done | Sync and relay inspection | [ADR-0041](adr/0041-sync-relay-diagnostics-boundary.md) | Read-only `sys.*` sync/retention/relay diagnostics are surfaced; relay management and changeset workflows remain out of scope. |
| 6 | Done | Lua extension management boundary | [ADR-0042](adr/0042-lua-extension-management-trust-model.md) | Read-only extension discovery and CLI validation are implemented; install/enable/trust execution UI remains gated by the ADR trust model. |
| Separate | Deferred | WASM/browser runtime | Not now | Future web target or companion app needs a separate PRD/SPEC slice and ADR. |

## Relevant v2.6.0 Capabilities

| Capability | DecentDB v2.6.0 surface | Decent Bench fit |
|---|---|---|
| Engine-owned queued writes | Dart open options, `Database.executeQueued`, `Database.writeQueueMetrics`, `sys.write_queue_metrics` | Good fit for self-contained app-generated writes and future concurrent reader/writer workflows; direct explicit transactions should remain the import/bulk-load path. |
| Operational metrics | `sys.wal_metrics`, `sys.write_queue_metrics`, `sys.storage_metrics`, `sys.sync_status`, `sys.reactive_metrics`, `sys.reactive_subscriptions` | Strong fit for the existing Database Statistics dashboard and copyable diagnostics. |
| SQL and PRAGMA compatibility | SQLite-style PRAGMA probes/assignments, `user_version`, `application_id`, schema introspection PRAGMAs, PRAGMA table functions, `sqlite_schema`, minimal `information_schema`, `generate_series`, query-time collations | Strong fit for autocomplete, formatter vocabulary, smoke tests, and schema explorer discoverability. |
| Local HTTP API and Web Console | `decentdb serve` with localhost auth, read-only mode, result limits, history, CSV export | Useful as an optional "Open Web Console" workflow if we package the CLI and keep auth/read-only defaults conservative. |
| Reactive subscriptions and change streams | Rust/C ABI JSON watch handles, `sys.reactive_*` views | Good future fit for schema/result refresh after writes, but currently gated by public Dart API exposure or a new ADR for lower-level ABI access. |
| Sync relay and changesets | CLI, C ABI JSON, relay HTTP/WebSocket routes, `sys.*` diagnostics | Valuable, but outside the current desktop import-query-export core. Start with inspection only; full workflows need PRD/SPEC and ADR work. |
| Sandboxed Lua extensions | CLI and C ABI JSON lifecycle, `sys.extension_*` views, trust allowlist | Useful for power users, but security-sensitive. Needs an ADR before any install/enable UI. |
| WASM/browser runtime | `@decentdb/web`, OPFS, worker ownership, browser metrics | Not a desktop-app feature. Track for a separate web companion or demo, not the Flutter desktop baseline. |

## Current Decent Bench Fit

- The app already uses the upstream Dart FFI binding behind a local gateway and
  worker isolate, matching ADR-0001 and SPEC section 5.
- Query execution and exports already use paged `Statement.nextPage`, matching
  ADR-0002.
- Import workers use direct DecentDB handles and explicit transactions. That is
  still the right model for bulk loads because queued writes reject explicit
  transaction-control SQL and are intended for self-contained statements.
- The schema browser and ERD already consume rich schema snapshot metadata, so
  2.6.0 adoption should extend diagnostics and vocabulary before adding large
  new workflows.
- Branch/snapshot UI remains honest about the public Dart API gap. v2.6.0 does
  not add a public Dart branch workflow API in the packaged `decentdb` library.

## Adoption Phases

### Phase 0 - Compatibility Upgrade

Status: implemented by the DecentDB v2.6.0 alignment change.

- Pin the `decentdb` Dart dependency to `v2.6.0`.
- Refresh `pubspec.lock` and verify the resolved DecentDB package version is
  `2.6.0`.
- Update third-party notices, dependency ADR examples, and changelog entries.
- Validate with `flutter analyze`, `flutter test`, and at least one native
  smoke path that opens a DecentDB database and executes paged SQL.

### Phase 1 - Observability and SQL Surface Parity

This is the highest-value v2.6.0 feature slice because it uses SQL-visible
engine surfaces and keeps the app's existing scope intact.

Status: implemented.

- Add a gateway method such as `loadOperationalMetrics()` that queries known
  `sys.*` metrics views with bounded result sizes.
- Extend Database Statistics to show:
  - WAL metrics
  - storage metrics
  - write-queue metrics
  - sync status when present
  - reactive subscription counts when present
- Treat missing `sys.*` views as graceful degradation so older or damaged
  engines do not break the dashboard.
- Add autocomplete and formatter vocabulary for:
  - `PRAGMA`
  - `generate_series`
  - `sqlite_schema`
  - `information_schema`
  - query-time `COLLATE BINARY`, `COLLATE NOCASE`, and `COLLATE RTRIM`
  - `main.` and `temp.` qualifier snippets
- Add smoke tests for `PRAGMA user_version`, `PRAGMA application_id`,
  `generate_series`, `sqlite_schema`, `information_schema`, and the new
  `sys.*` metrics views.

### Phase 2 - Queued Write Integration

Governed by [ADR-0038](adr/0038-queued-write-integration.md) because it
changes the app-owned write execution model.

Status: implemented. Queued writes remain disabled by default and are used for
inline table DML only when the user enables the write queue in TOML config.

- Add configuration fields for write-queue options, defaulting to disabled:
  - `write_queue_enabled`
  - `write_queue_capacity`
  - `write_queue_default_timeout_ms`
  - `write_queue_max_batch`
  - `write_queue_max_group_delay_us`
- Pass open options through `Database.open(..., options: ...)` only when the
  feature is enabled.
- Add a gateway method for self-contained queued writes.
- Use queued writes first for app-generated, single-statement DML where no
  explicit transaction is required, such as inline table-cell edits.
- Keep imports, exports, migration, save-as, and explicit SQL transactions on
  direct handles until a measured concurrent-reader/write design proves useful.
- Surface `DDB_ERR_BUSY`, `DDB_ERR_TIMEOUT`, `DDB_ERR_CANCELED`,
  `DDB_ERR_QUEUE_FULL`, and `DDB_ERR_QUEUE_CLOSED` as actionable UI errors.
- Feed `Database.writeQueueMetrics()` and `sys.write_queue_metrics` into the
  diagnostics dashboard.

### Phase 3 - Optional Local Web Console

Governed by
[ADR-0039](adr/0039-local-web-console-companion-process.md) because it adds a
managed companion process and changes desktop packaging requirements.

Status: implemented.

- Package or locate the `decentdb` CLI alongside the existing native library
  and migration tool staging flow.
- Add an explicit command, for example `Tools -> Open Web Console`.
- Launch `decentdb serve --db=<current.ddb> --read-only --open` by default.
- Keep localhost auth enabled and do not expose `--no-auth`, remote binding, or
  broad CORS controls in the first UI.
- Track process lifecycle, port selection, stdout/stderr, and shutdown.
- Document manual verification for token handling and read-only enforcement.

### Phase 4 - Reactive Refresh

Governed by [ADR-0040](adr/0040-reactive-refresh-watch-lifecycle.md). This
phase should wait for a public Dart API unless a superseding ADR accepts
lower-level C ABI access from the app.

Status: completed to the accepted boundary. Decent Bench surfaces
`sys.reactive_metrics` and `sys.reactive_subscriptions` through Database
Statistics, but does not create watch handles because DecentDB v2.6.0 does not
expose a public Dart watch API. A future public API or superseding ADR is
required before implementing live schema/result refresh.

- Use table/query watches to refresh schema browser metadata after app-owned
  writes.
- Mark result sets stale after watched tables change instead of silently mixing
  old results with new state.
- Show lag/drop metrics from `sys.reactive_metrics` when subscriptions are
  active.
- Keep all watch polling off the UI thread and bounded by cancellation.

### Phase 5 - Sync and Relay Inspection

Governed by [ADR-0041](adr/0041-sync-relay-diagnostics-boundary.md). This is a
larger product feature and should start as read-only inspection.

Status: implemented for read-only diagnostics.

- Add read-only sync status and retention diagnostics from `sys.sync_status`
  and related inspection views.
- Consider CLI-backed changeset import/export only after an ADR defines where
  generated files live, how conflicts surface, and which workflows are in
  product scope.
- Do not ship production relay management UI without PRD/SPEC updates, auth
  design, and operational docs.

### Phase 6 - Lua Extension Management

Governed by
[ADR-0042](adr/0042-lua-extension-management-trust-model.md). This phase is
security-sensitive, and lifecycle/trust workflows must follow that ADR.

Status: implemented for read-only discovery and package validation. Execution,
install, enable, disable, and unsigned override workflows remain outside the
normal UI.

- Start with read-only discovery of installed/enabled extensions from
  `sys.extension_*` views.
- Add package validation through the official CLI or a future public Dart API.
- Require explicit trust entries by `name@sha256:<hash>` for execution.
- Keep unsigned extension overrides development-only and hidden from normal
  users unless a debug setting is explicitly enabled.
- Extend autocomplete only for trusted/enabled extension functions surfaced by
  engine metadata.

### Tracked Separately - WASM and Browser Runtime

No desktop implementation is planned for the v2.6.0 desktop upgrade.

- Track `@decentdb/web` for a future companion web workbench or documentation
  sample.
- Do not move the Flutter desktop app's primary query path from native FFI to a
  browser worker model.
- If a web target is later accepted, create a separate PRD/SPEC slice around
  OPFS durability, browser support tiers, and import/export behavior.

## Not Adopting Immediately

- Replacing the FFI adapter with `decentdb serve`.
- Enabling queued writes globally by default.
- Calling private Dart binding internals for branch, sync, reactive, or Lua
  JSON bridges.
- Exposing production relay administration in the desktop app without a product
  scope update.
- Shipping unsigned Lua extension execution as a normal user workflow.
- Treating WASM/browser support as part of the desktop MVP line.

## Validation Plan

Each implementation phase should include:

- `flutter analyze`
- `flutter test`
- targeted native smoke tests for the touched DecentDB surface
- manual verification for behavior-sensitive UI, especially process lifecycle,
  query cancellation, queue timeout handling, and large metrics/result sets

Manual Web Console verification:

- Open a `.ddb` workspace and run `Tools -> Open Web Console`.
- Confirm the launched command is equivalent to
  `decentdb serve --db=<current.ddb> --read-only --open`.
- Confirm the console binds only to localhost, keeps auth/token behavior
  enabled, and rejects write attempts in read-only mode.
- Close Decent Bench or press Stop in the Web Console dialog and confirm the
  companion process exits.
