## SQLite Import Entry And Worker Architecture
**Date:** 2026-03-10
**Status:** Accepted

### Decision

Phase 4 introduces SQLite import through a dedicated import path with three
parts:

- Drag-and-drop entry on the main workspace window for `.ddb`, `.db`,
  `.sqlite`, and `.sqlite3` files.
- A modal SQLite import wizard covering source selection, target selection,
  preview, transforms, execution, and summary.
- Background SQLite inspection and import execution using the existing
  `WorkspaceDatabaseGateway` boundary and isolate-based worker model.

The implementation uses:

- `desktop_drop` for desktop drag-and-drop events
- `file_selector` for cross-platform file picking and target save selection
- `sqlite3` for direct SQLite schema inspection, preview reads, and source-row
  iteration

SQLite source work stays outside the UI thread. Inspection and preview run in
background isolates, and the import job runs in its own worker isolate that
streams progress updates back through the DecentDB bridge.

### Rationale

Phase 4 needs the first real import workflow without blocking the desktop UI.
SQLite is bounded enough to validate the import architecture while still
covering table discovery, schema mapping, previews, transforms, long-running
copy work, and failure/cancellation behavior.

Using `sqlite3` for source inspection avoids shelling out to external tools and
keeps the source-side logic deterministic and testable from Dart. Reusing the
existing bridge boundary keeps import execution aligned with the app's existing
background-query model.

### Alternatives Considered

- Read SQLite source metadata through a native helper outside Dart
- Perform SQLite inspection and import directly on the UI isolate
- Add drag-and-drop only after Excel and SQL dump imports exist
- Build a generic import framework first and defer the SQLite-specific path

### Trade-offs

- A Phase-4-specific SQLite worker path ships value faster, but Excel and SQL
  dump imports will still need to conform to the same wizard contract later.
- Using `sqlite3` adds another dependency surface, but it is Apache-compatible
  for distribution goals and provides the bounded local SQLite API Phase 4
  needs.
- Drag-and-drop now recognizes future import types, but only SQLite is
  implemented; Excel and SQL dump drops currently route to a clear
  not-yet-implemented message.

### References

- [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
- [design/IMPLEMENTATION_PHASES.md](/home/steven/source/decent-bench/design/IMPLEMENTATION_PHASES.md)
- [THIRD_PARTY_NOTICES.md](/home/steven/source/decent-bench/THIRD_PARTY_NOTICES.md)
- [AGENTS.md](/home/steven/source/decent-bench/AGENTS.md)
