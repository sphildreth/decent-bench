## Doctor/advisor diagnostics boundary: CLI primary, sys.* fallback
**Date:** 2026-08-04
**Status:** Accepted

### Decision

The new **Database Doctor** panel in the **Tools** menu uses a two-tier
strategy:

1. **Primary: CLI shell-out.** When the resolved `decentdb` CLI is
   available (env var, executable in `PATH`, release-asset cache, or
   side-by-side bundle), Decent Bench invokes:

   ```
   decentdb doctor --db <path> --format json --checks all \
       --include-recommendations=true
   ```

   and surfaces the JSON report. Optional flags `--verify-indexes`,
   `--verify-index <name>`, and `--max-index-verify` are forwarded as
   selected.

2. **Fallback: in-process sys.* views.** When the CLI cannot be resolved
   the in-process `sys.doctor_findings` and `sys.fix_plan` views are
   queried via the workspace bridge and rendered with a prominent
   **"Degraded results"** banner so the user does not mistake the
   fallback for a clean bill of health.

The Doctor CLI's `--fail-on=error` default returns a non-zero exit code
when the database is unhealthy; this is **expected** and not a tool
failure. The service parses the JSON payload regardless of exit code.

### Rationale

- The CLI is the authoritative doctor: it can run offline (no DB lock
  contention), it can verify indexes by name, and it covers the full 8
  check categories (`header`, `storage`, `wal`, `fragmentation`,
  `schema`, `statistics`, `indexes`, `compatibility`).
- The in-process fallback keeps the panel useful when the CLI asset
  fails to download or the user installs Decent Bench without the CLI on
  `PATH`.
- The boundary matters because runtime-tracing-backed views
  (`sys.slow_queries`, `sys.lock_waits`, `sys.index_usage`,
  `sys.sessions`) are **deliberately excluded** from the Tier 1
  operational metrics list: `RuntimeTracingConfig::enabled` defaults to
  `false` and there is no C ABI open option to enable it (verified
  against the v2.17 `include/decentdb.h`). Those views would return
  empty results without warning; surfacing them would mislead users.

### Alternatives Considered

- **CLI-only.** Rejected: a fresh install with a half-broken asset cache
  would have no path forward.
- **sys.* only.** Rejected: missing verify-indexes and 2 of the 8
  categories; can't run while the DB is open under another handle.
- **Auto-launch a background trace on the open DB.** Rejected: the engine
  has no C ABI hook for it.

### Trade-offs

- The CLI binary is large; existing CI/release pipelines already stage
  it as part of the desktop bundle.
- The fallback path must be loudly labelled to avoid being mistaken for
  the authoritative view.

### References

- `crates/decentdb-cli/src/commands/mod.rs` (`DoctorCommand`)
- `crates/decentdb-cli/src/output.rs` (`OutputFormat`)
- `crates/decentdb/src/tracing/config.rs`
- `include/decentdb.h` (documented open options list — tracing is not in it)
- ADR-0060 (migration contract)