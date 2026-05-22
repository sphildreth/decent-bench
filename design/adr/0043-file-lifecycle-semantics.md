## File Lifecycle Semantics
**Date:** 2026-05-21
**Status:** Accepted

### Decision

Decent Bench implements the file lifecycle commands as follows:

- `Save` persists workspace state, saved-query library, and application config.
- `Save As...` saves the current workspace state and saved-query library to the
  target path sidecars, duplicates the active `.ddb` file to the selected path,
  then reopens the copied database.
- `Close` persists workspace state and saved-query library, persists config,
  cancels active query/import listeners, clears runtime workspace state, and
  returns the shell to the empty initial workspace.

For user feedback, `Save` and `Close` explicitly state that database data changes
are already durable in DecentDB and that file actions are persistence metadata and
session context helpers.

### Rationale

DecentDB writes are durable by default for executed transactions, so `Save` must
not imply a delayed commit operation that does not exist in the database engine.
The command still needs to provide a user-visible manual persistence point because
recent users expect save operations to flush application-level metadata and query
session context.

`Save As...` must be safe and explicit, not a format conversion. It therefore
copies the actual `.ddb` bytes and only recognized Decent Bench sidecars so users
can continue the same workspace with equivalent editor/query context.

`Close` needs a deterministic transition to avoid stale listeners operating
against an invalid database path and to return users to the shell-ready empty
workspace without requiring app restart.

### Alternatives Considered

- Implementing `Save` as a no-op with no metadata persistence. Rejected because
  it leaves workspace/query metadata and config changes implicit and difficult to
  reason about in crash-recovery scenarios.
- Implementing `Save As...` as export + reopen flow. Rejected because it adds
  additional conversion steps and ambiguity around metadata continuity.
- Disabling file lifecycle commands until dedicated persistence/transactions are
  added. Rejected because existing state is already persisted and users can use
  desktop shell semantics immediately.

### Trade-offs

- File duplication means `Save As...` can fail if the source `.ddb` is locked by
  another process before copying.
- Reopening from `Save As...` introduces a short synchronous transition where
  state persistence and project metadata are written twice (source first for a
  manual save boundary, then target sidecars).
- `Close` discards in-memory unsaved UI-only context by design to ensure a clean
  shell state.

### References

- `design/APPLICATION_MENU_REVIEW.md`
- `test/features/workspace/application/workspace_controller_test.dart`
