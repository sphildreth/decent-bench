## Separate Workspace State Persistence
**Date:** 2026-03-10
**Status:** Accepted

### Decision

Decent Bench persists **user config** and **workspace state** separately.

- Global user preferences continue to live in TOML at the OS-standard config
  path (`config.toml`).
- Per-database workspace state is stored in a separate file under a
  `workspaces/` directory in the same config root.
- Workspace state currently captures query-tab drafts and the active tab for a
  specific DecentDB file.
- Workspace state is restored only when that same database is opened again; the
  app does **not** automatically reopen the last workspace on startup.
- Workspace-state files are keyed by a base64url-encoded database path so they
  remain filesystem-safe without introducing another dependency.

### Rationale

Phase 2 requires better workspace ergonomics and reopening behavior for
multi-tab SQL work. Persisting tab drafts per database makes the workbench feel
continuous without conflating transient workspace state with durable global
preferences.

Keeping workspace state separate from `config.toml` also aligns with
`design/SPEC.md`, which distinguishes user config from open-file-specific UI
state.

### Alternatives Considered

- Store tabs inside `config.toml`
- Do not persist query tabs at all until a later phase
- Auto-reopen the last workspace on startup

### Trade-offs

- Separate files make the storage boundary clearer, but add one more local file
  type to document and validate.
- Using JSON for workspace state avoids adding a TOML dependency for nested tab
  structures, but means not all local state is stored in TOML.
- Manual reopen-only restore is less aggressive than session restoration, but
  avoids committing the app to startup behavior that has not been specified yet.

### References

- [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
- [design/IMPLEMENTATION_PHASES.md](/home/steven/source/decent-bench/design/IMPLEMENTATION_PHASES.md)
- [AGENTS.md](/home/steven/source/decent-bench/AGENTS.md)
