## Type-Aware, Branch-Safe Table Data Editor
**Date:** 2026-05-19
**Status:** Proposed

### Decision

Decent Bench's results grid will gain an inline cell editing mode. When a
result set is determined to be editable, users can double-click cells to edit
values in place. On commit, the tool generates and executes parameterized DML
(`UPDATE`, `INSERT`, `DELETE`) against the database through the existing
`DecentDbBridge` isolate. The grid becomes a write-through surface, not a
separate "data editor" view.

With DecentDB v2.5.x, editability and editor selection must use query contracts,
tooling metadata, and native type metadata instead of relying on display text.
Risky edit sessions should be branch-aware: when native branch operations are
available through the Dart binding, Decent Bench should offer "edit on branch"
before applying writes to the main branch.

### Rationale

The single biggest gap between Decent Bench and being a "true workbench" is the
inability to edit data directly. Competing tools (DB Browser for SQLite,
TablePlus, DBeaver, DataGrip) all provide inline cell editing. The
UPDATE→SELECT→verify loop is appropriate for batch changes but punishing for
ad-hoc corrections.

The foundations already exist: a virtualized, selection-aware grid with copy
support, a typed cursor pipeline, query-contract metadata for result columns,
tooling metadata for native column types, and a `DecentDbBridge` isolate capable
of executing arbitrary parameterized SQL. Inline editing is a UI addition on
top of proven infrastructure.

### Editability Detection Rules

A result set is editable when ALL of the following hold:

1. The query contract reports a read-only `query` statement.
2. Every editable result column maps to a `catalog_column` with a source table
   and source column.
3. All editable columns map to one source table.
4. The source table has a stable primary-key column present in the result set.
5. The column's native type has a supported editor in the current release.
6. The user has write permission on the database file.

If the result set is NOT editable, the grid status bar shows why (e.g.,
"Result includes a JOIN — editing requires a single-table query").

### DML Generation Strategy

**UPDATE**: On cell commit, generate `UPDATE <table> SET <col> = $1 WHERE <pk>
= $2` with the new value and the primary key value of the edited row. Values are
always sent as bound parameters through the existing parameterized execution
path; never interpolated into SQL strings.

**INSERT**: An empty "new row" is rendered at the bottom of editable result
sets. Typing into any cell in that row triggers an `INSERT INTO <table>
(<cols>) VALUES ($1, $2, ...)` on first commit, using column defaults for
unfilled cells. Subsequent edits to the same new row produce UPDATEs.

**DELETE**: Right-click or keyboard shortcut on a row generates `DELETE FROM
<table> WHERE <pk> = $1`. Requires confirmation unless the user has enabled "skip
delete confirmation" in preferences.

### Inline Validation Model

- Engine constraint violations and type errors are surfaced as inline validation
  on the specific cell, not in modal dialogs.
- The cell shows a red border and an error tooltip with the engine message.
- The edited value is preserved so the user can correct it without losing input.
- Tab/Enter navigation is blocked until the violating cell is corrected or
  reverted (Esc).

### Native Type Handling

- Text, integer, float, decimal, boolean, UUID, date/time, timestamp,
  timestamptz, interval, enum, IP/CIDR, and MAC values use type-aware parsing
  before binding.
- Spatial values (`GEOMETRY`, `GEOGRAPHY`) are view/copy-only in the first
  editor slice. Users can copy WKT/WKB/GeoJSON when available, but cannot edit
  geometry in-grid.
- Unknown or ambiguous query-contract diagnostics disable write-through editing
  for affected columns.

### Branch Safety

When native branch operations are exposed by the Dart binding:

- The grid status bar shows whether edits target main or a branch.
- Risky sessions offer "Edit on Branch" before the first write.
- Branch diffs are the review path before merge.

Until that API is available, Decent Bench should keep editing disabled for
high-risk workflows that require branch safety.

### Non-Goals

- Multi-row bulk edit (apply value to all selected rows simultaneously).
- Foreign-key-aware dropdown editors that query referenced tables for value
  suggestions.
- DML preview/dry-run mode that shows the generated SQL before execution.
- Editing non-table result sources (views, CTEs, set operations, subqueries).
- Undo stack beyond single-cell Esc revert (no multi-step undo history).
- Spatial drawing/editing tools.

### Trade-offs

- **Scope vs. usability**: Restricting editability to single-table SELECTs
  excludes many useful queries, but the alternative — attempting to reverse-map
  arbitrary expressions to underlying tables — is unbounded complexity and
  fragile. Users who need to edit data from complex queries can open a new tab
  with a targeted single-table SELECT.
- **DML behind the scenes**: Users don't see the generated SQL by default, which
  could hide mistakes. Mitigation: the grid status bar shows row counts (rows
  edited, pending) and the query tab history captures executed DML so users can
  later inspect what was run.
- **No multi-row transactions**: Each cell commit is a separate DML statement
  and transaction boundary by default. Batching edits into a single transaction
  is a follow-up workflow feature, not part of the initial slice.

### References

- ADR-0002 Results Paging and Streaming Contract
- ADR-0032 Native Branch, Snapshot, and Safe-Run Workbench
- `design/SPEC.md` section 6 (Query Execution and Paging Contract)
- `design/SPEC.md` section 10 (Results Grid Specification)
- `design/FUTURE_WINS.md` Priority 6

### Alternatives Considered

**Separate "Data Editor" view**: A distinct UI mode where users select a table
and edit it in a spreadsheet-like view disconnected from the query editor.
Rejected because it fragments the workflow — users who just ran a SELECT and
found a bad value must switch contexts to fix it. Inline editing keeps the
query→inspect→fix loop in one surface.

**Always-editable grid with no detection rules**: Allow editing any result set
and attempt to reverse-map to underlying tables. Rejected because multi-table
joins, aggregates, and expressions have ambiguous or impossible reverse
mappings. Detecting editability up front and explaining why non-editable results
can't be edited is a better UX than partial, unpredictable editing behavior.
