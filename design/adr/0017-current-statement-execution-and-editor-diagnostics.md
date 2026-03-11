## Current-Statement Execution And Editor Diagnostics
**Date:** 2026-03-10
**Status:** Accepted

### Decision

Decent Bench will resolve the primary SQL execution target in this order:

- explicit non-empty selection
- current statement under the caret in a multi-statement buffer
- full tab buffer

The primary run command and `Ctrl+Enter` will execute that resolved target.
When the primary command is not targeting the full buffer, the UI will expose an
explicit `Run Buffer` command so the full tab remains one step away.

Best-effort query diagnostics will be projected back into the editor buffer and
shown in the gutter and editor status chrome when the engine returns enough
error detail to infer a location.

### Rationale

The SQL editor is one of the core product surfaces. Desktop SQL workflows often
keep several statements, scratch notes, and alternate query shapes in one tab.
Forcing users to either select exact text every time or split every statement
into separate tabs slows iteration.

Current-statement targeting improves the common `caret + run` workflow without
removing the ability to run a whole tab. Best-effort diagnostic projection makes
syntax failures actionable inside the editor even before a larger IDE-style
editing engine exists.

### Alternatives Considered

- Keep `Ctrl+Enter` limited to explicit selections and full-buffer execution
- Add separate statement-only commands without changing the primary run action
- Wait for a future full editor engine before adding location-aware diagnostics

### Trade-offs

- Statement targeting is heuristic and currently based on delimiter-aware SQL
  splitting rather than a full parser
- Diagnostic locations are inferred from engine error text and are therefore
  best-effort rather than guaranteed exact spans
- The editor now has two run commands when the primary action is narrowed to a
  selection or statement

### References

- `design/PRD.md`
- `design/SPEC.md`
- `design/adr/0015-custom-sql-editor-surface-rendering.md`
- `design/adr/0016-selection-aware-sql-editor-commands.md`
- `apps/decent-bench/lib/features/workspace/presentation/workspace_screen.dart`
- `apps/decent-bench/lib/features/workspace/application/workspace_controller.dart`
- `apps/decent-bench/lib/features/workspace/domain/sql_execution_target.dart`
- `apps/decent-bench/lib/features/workspace/domain/sql_error_location.dart`
