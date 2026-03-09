## Pinned DecentDB SQL Capability Baseline
**Date:** 2026-03-09
**Status:** Accepted

### Decision

Decent Bench treats the official SQL reference for the pinned DecentDB engine
version as the normative SQL capability contract.

The app may phase dedicated UI affordances and schema-browser coverage over
time, but it should not intentionally narrow the SQL surface below what the
pinned engine documents as supported. This applies in particular to:

- DDL for tables, temp objects, indexes, views, triggers, generated columns,
  and supported constraints
- DML and planner operations such as `INSERT`, `SELECT`, `UPDATE`, `DELETE`,
  and `ANALYZE`
- query features such as CTEs, joins, set operations, scalar/aggregate/window
  functions, transactions, `EXPLAIN`, `EXPLAIN ANALYZE`, table-valued
  functions, and positional parameters

### Rationale

The value of Decent Bench is tightly coupled to DecentDB itself. If the app
documents or implements a smaller SQL dialect than the engine actually
supports, users will lose trust in both the editor and the schema browser.

Using the pinned upstream SQL reference as the capability baseline keeps the
project aligned with the real engine surface, improves future autocomplete and
schema metadata work, and prevents accidental product drift toward a
SELECT-only workbench.

### Alternatives Considered

1. Keep documentation focused on a smaller "core query workflow" SQL subset.
2. Define a Decent Bench-specific SQL compatibility document separate from the
   upstream engine reference.
3. Expand support opportunistically during implementation without a stated
   baseline.

### Trade-offs

- The validation matrix grows because representative tests should cover more
  than simple `SELECT` queries.
- Dedicated UI coverage can still be phased, so the docs must distinguish
  between engine capability parity and when a feature gets first-class UI.
- Future engine-version upgrades will require deliberate review of the upstream
  SQL reference and corresponding doc/test updates.

### References

- https://decentdb.org/user-guide/sql-reference/
- `design/adr/0001-decentdb-flutter-binding-strategy.md`
- `design/IMPLEMENTATION_PHASES.md`
