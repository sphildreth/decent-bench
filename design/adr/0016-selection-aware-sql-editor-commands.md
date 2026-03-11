## Selection-Aware SQL Editor Commands
**Date:** 2026-03-10
**Status:** Accepted

### Decision

When the SQL editor has a non-empty, non-whitespace selection, Decent Bench
will treat that selection as the target for primary editor commands:

- Run executes the selected SQL instead of the full tab buffer
- Format reformats the selected SQL instead of the full tab buffer

When there is no meaningful selection, the commands continue to operate on the
full active tab buffer.

### Rationale

Decent Bench is a SQL workbench, not a plain text editor. Running and
reformatting only the active selection is a core desktop database workflow for:

- iterating on one statement inside a larger scratch buffer
- comparing alternate query shapes without splitting tabs prematurely
- keeping notes or disabled statements in the same editor buffer

This improves editor utility immediately without requiring a larger editor
engine rewrite.

### Alternatives Considered

- Always operate on the full tab buffer
- Add separate Run Selection and Format Selection commands only
- Wait for a larger custom editor engine before improving command targeting

### Trade-offs

- Command behavior now depends on editor selection state
- The current implementation executes explicit selections, not automatic
  current-statement detection
- Selection-aware execution is a workbench behavior and should remain visible in
  the UI so it does not feel implicit

### References

- `design/PRD.md`
- `design/SPEC.md`
- `apps/decent-bench/lib/features/workspace/presentation/workspace_screen.dart`
- `apps/decent-bench/lib/features/workspace/application/workspace_controller.dart`
