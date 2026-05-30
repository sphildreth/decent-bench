## Sync and Relay Diagnostics Boundary
**Date:** 2026-05-21
**Status:** Accepted

### Decision

Decent Bench may expose DecentDB v2.6.0 sync and relay state as read-only
diagnostics through SQL-visible `sys.*` inspection views. This diagnostic slice
does not include peer configuration, changeset import/export, relay process
management, WebSocket subscriptions, auth management, retention controls, or
conflict-resolution workflows.

Any user workflow beyond read-only inspection requires PRD/SPEC updates and a
separate ADR that defines:

- supported topology
- where generated changeset files live
- how conflicts are displayed and resolved
- how relay endpoints and credentials are configured
- how retention and pruning are guarded
- what manual verification is required for data movement

Implementation note: the v2.6.0 adoption slice surfaces sync status,
retention, peer lag, and relay status inspection views in Database Statistics
only. It does not configure peers, move changesets, manage relays, or mutate
retention state.

### Rationale

DecentDB v2.6.0 adds meaningful sync and relay surfaces, but Decent Bench's
product promise is still a local desktop import-query-export workbench. Read-only
diagnostics fit the existing Database Statistics and inspector model. Data
movement, auth, relay operation, and conflict handling would create a new
workflow class with security and product-scope implications.

The boundary lets the app take advantage of operational metadata without
silently expanding into a sync administration tool.

### Alternatives Considered

- Ignore sync surfaces entirely. Rejected because read-only status helps users
  understand databases that already use DecentDB sync.
- Add full sync management immediately. Rejected because it conflicts with
  current PRD/SPEC scope and needs auth, topology, and conflict UX decisions.
- Shell out to sync CLI commands as generic tools. Rejected for now because
  generated files, retention, and conflicts need product-level guardrails.
- Treat relay management as a local web-console extension. Rejected because
  relay operation has different security and deployment assumptions.

### Trade-offs

- Users can inspect sync state but cannot resolve or configure sync from Decent
  Bench in the first slice.
- Future sync work will require explicit documentation updates before
  implementation.
- Read-only diagnostics must gracefully handle databases with no sync metadata
  or older engine surfaces.

### References

- `design/DECENTDB_2_6_ENHANCEMENT_PLAN.md`
- `design/PRD.md`
- `design/SPEC.md`
- `/home/steven/src/github/decentdb/docs/user-guide/sync/index.md`
- `/home/steven/src/github/decentdb/docs/user-guide/sync/relay.md`
