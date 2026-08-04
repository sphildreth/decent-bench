## Database performance profile and plan-cache open options in Preferences
**Date:** 2026-08-04
**Status:** Accepted

### Decision

Expose two engine open options through the existing `AppConfig` /
TOML surface and Preferences UI:

- `profile` — one of `default | low_memory | balanced | embedded_fast |
  tuned_durable`.
- `plan_cache_enabled` (bool) and `plan_cache_max_bytes` (int, optional).

The new fields are stored as a `DatabaseOpenSettings` value on
`AppConfig`. They round-trip through TOML via the `[database_open]`
section.

A new menu command **Tools → Flush Plan Cache** issues
`PRAGMA flush_plan_cache` against the open database so users can
re-exercise `EXPLAIN` against fresh statistics after schema edits.

### Rationale

- The `profile` key is documented in `include/decentdb.h` since v2.15.
  Critical ordering constraint: setting `profile=` **replaces the entire
  `DbConfig`**, so other open-option keys applied after it override any
  conflicting values. We therefore emit `profile=` first in the
  `_buildOpenOptionsFromPayload` string.
- Plan-cache controls are new in v2.17 and let users cap a small but
  hot cache footprint on laptops.
- Storing the settings in `AppConfig` keeps them versioned with the
  user's TOML rather than scattering them across the codebase.

### Alternatives Considered

- **PRAGMA-only configuration.** Rejected: profile selection must
  happen at open time, not after.
- **A per-database settings table.** Rejected: the engine itself keys
  the profile against the file handle at open time.

### Trade-offs

- Invalid `profile` values are rejected at the engine boundary
  (`c_api.rs:1470`); the Preferences UI must validate before save.
- Plan cache size is best-effort: a too-small value may yield no cache
  hits.

### References

- `crates/decentdb/src/c_api.rs:1470` (`db_config_profile`)
- `include/decentdb.h` open-options documentation
- ADR-0060 (migration contract)
- ADR-0061 (doctor diagnostics boundary)