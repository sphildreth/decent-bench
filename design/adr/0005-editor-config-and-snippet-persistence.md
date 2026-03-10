## Editor Config And Snippet Persistence
**Date:** 2026-03-10
**Status:** Accepted

### Decision

Decent Bench stores Phase 3 editor preferences and SQL snippets in the global
`config.toml` file.

- Editor preferences stay as top-level scalar config values.
- SQL snippets are stored as repeated TOML tables under
  `[[editor_snippets]]`.
- The config file keeps an explicit `config_version` and snippet count so the
  app can distinguish default snippets from an intentionally empty snippet
  list.
- Per-database tab drafts remain outside `config.toml` in the separate
  workspace-state store defined by ADR 0004.

### Rationale

Phase 3 adds durable editor behavior that should follow the user across
databases: autocomplete settings, formatter settings, and reusable snippets.
Those are global preferences, not workspace state.

Keeping snippets in `config.toml` satisfies the MVP requirement for TOML-based
snippet storage without adding another config file or a TOML dependency just
for nested structures.

### Alternatives Considered

- Store snippets in a separate file next to `config.toml`
- Store snippets in per-database workspace state
- Store snippets as opaque JSON payloads inside `config.toml`

### Trade-offs

- Repeated TOML tables keep the file valid TOML and reasonably inspectable, but
  require a small amount of custom parsing logic.
- A separate snippet file would isolate concerns better, but would add another
  local artifact to document and migrate.
- Global snippet storage is correct for reusable SQL templates, but it means
  snippets are not currently scoped per database.

### References

- [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
- [design/IMPLEMENTATION_PHASES.md](/home/steven/source/decent-bench/design/IMPLEMENTATION_PHASES.md)
- [design/adr/0004-workspace-state-persistence.md](/home/steven/source/decent-bench/design/adr/0004-workspace-state-persistence.md)
- [AGENTS.md](/home/steven/source/decent-bench/AGENTS.md)
