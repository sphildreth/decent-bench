## Desktop CLI Import Launch And Binary Name
**Date:** 2026-03-10
**Status:** Accepted

### Decision

Decent Bench desktop builds expose a command-line startup path:

- the generated desktop executable name is `dbench`
- `dbench --import <path>` launches the app and opens the matching import
  wizard after initialization completes

The `--import` launch path reuses the existing incoming-file detection rules and
existing import dialogs. It does not create a second import workflow.

The command currently targets import sources only:

- SQLite: `.db`, `.sqlite`, `.sqlite3`
- Excel: `.xls`, `.xlsx`
- SQL dump: `.sql`

Passing a DecentDB file or an unsupported path through `--import` surfaces a
clear notice instead of silently opening a different workflow.

### Rationale

Users need a scriptable desktop entry point that can be invoked from shells,
launchers, and file-manager integrations without requiring drag-and-drop.

Using a narrow startup intent keeps the behavior predictable and maps cleanly
onto the app’s existing import dialogs. Renaming the generated binary to
`dbench` gives the CLI path a short, stable command name.

### Alternatives Considered

- Keep the generated executable name as `decent_bench`
- Add a broader CLI grammar before any single workflow is proven
- Build a separate import-only runner or headless mode
- Treat `--import` as a generic “open whatever this path is” command

### Trade-offs

- Desktop packaging metadata now needs to stay aligned across Flutter’s Linux,
  Windows, and macOS runner files.
- The CLI path is intentionally narrow; opening DecentDB files from the command
  line without `--import` remains a future option rather than part of this
  slice.
- Startup import dialogs wait for app initialization, so recent-workspace
  restore may complete first and remain visible behind the wizard.

### References

- [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
- [apps/decent-bench/lib/app/startup_launch_options.dart](/home/steven/source/decent-bench/apps/decent-bench/lib/app/startup_launch_options.dart)
- [apps/decent-bench/lib/features/workspace/presentation/workspace_screen.dart](/home/steven/source/decent-bench/apps/decent-bench/lib/features/workspace/presentation/workspace_screen.dart)
