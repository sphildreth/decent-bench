## Computed Column Transforms During Import
**Date:** 2026-05-18
**Status:** Proposed

### Decision

Decent Bench's import wizard will support computed columns: users may define new
columns whose values are computed from existing source columns during import. The
expression language is a constrained subset covering arithmetic, string
operations, date construction, and `CASE`/`WHEN` branching. Expressions execute
row-by-row during the import pipeline and produce values in DecentDB native
types.

### Rationale

Computed columns were the single most-requested deferred transform during MVP
development. They were explicitly excluded from MVP scope in `SPEC.md` section
8.3 with the caveat "computed columns are deferred to Next." Users who import
data from CSV, Excel, or SQLite frequently need derived columns — concatenating
first and last name, computing a full address from components, applying a
discount rate to a price column, or converting between unit systems.

Without computed columns, users must:
1. Import the raw data.
2. Write `UPDATE` statements to populate computed columns.
3. Alternatively, create views or generated columns after import.

Each alternative either requires SQL knowledge or produces derived data that is
decoupled from the import workflow. Computed columns put the derivation where it
belongs — in the import wizard, alongside column renames and type overrides.

### Expression Language

The expression language is deliberately constrained. It is NOT a general-purpose
scripting or SQL dialect. It is a column-level, row-local expression evaluator.

**Supported operations:**

**Arithmetic**: `+`, `-`, `*`, `/`, `%` (modulo)
- Operands: column references, numeric literals, or nested arithmetic
  expressions.
- Division by zero produces NULL with a warning in the import summary.

**String**: `CONCAT(col1, col2, ...)`, `SUBSTR(col, start, length)`,
`UPPER(col)`, `LOWER(col)`, `TRIM(col)`
- String literals are quoted with single quotes: `'literal'`.
- Empty string and NULL are distinct: concatenating NULL with a string produces
  NULL.

**Date and time**: `DATE(year_col, month_col, day_col)`, `DATETIME(col,
format)`
- `DATE` constructs a date from three integer columns.
- `DATETIME` parses a string column using a format string (ISO 8601 by default).
- Date arithmetic and interval support are NOT included in the initial slice.

**Conditional**: `CASE WHEN condition THEN expr ELSE expr END`
- Conditions support `=`, `!=`, `<`, `>`, `<=`, `>=`, `IS NULL`, `IS NOT NULL`.
- Nested CASE expressions are supported but must have explicit ELSE clauses.
- No `ELSE` is treated as `ELSE NULL`.

**Type conversion**: `TO_INTEGER(col)`, `TO_REAL(col)`, `TO_TEXT(col)`
- `TO_INTEGER` and `TO_REAL` return NULL on unparseable input with a warning.
- `TO_TEXT` stringifies any value.

**Null handling**: `COALESCE(col, default_val)`, `NULLIF(col, val)`

**Column references**: Identifiers matching source column names (case-sensitive
after the import wizard's rename step). Column references resolve against the
post-rename column names, not the original source names.

**Literals**: Integer (`42`), real (`3.14`), string (`'hello'`), boolean
(`TRUE`, `FALSE`), null (`NULL`).

### Expression Execution Model

Expressions execute row-by-row during import, between the source parsing step
and the target insert step. The execution order is:

1. Source parser produces a row of raw values.
2. Rename and type-override transforms apply.
3. Computed column expressions evaluate against the transformed row.
4. The row (original columns + computed columns) is inserted into the target
   table in DecentDB.

Computed columns are always appended after all source columns. Column ordering
within the set of computed columns follows the order the user defined them.

Expressions that reference other computed columns are NOT supported in the
initial slice — all computed columns operate on source columns only. This avoids
ordering dependencies and makes validation simpler.

### Type Inference for Computed Columns

The wizard attempts to infer the output type of each computed column expression:
- Arithmetic expressions → type of the widest operand (integer → real promotion
  if any operand is real).
- String functions → TEXT.
- Date functions → DATE or DATETIME (as appropriate).
- CASE expressions → type of the `THEN`/`ELSE` clauses (must be consistent
  across all branches; inconsistency is a validation error).
- Type conversion functions → the target type.

If type inference fails or is ambiguous, the wizard defaults to TEXT and allows
the user to override the type, same as for source columns.

### UI in the Import Wizard

A new optional transform step "Computed Columns" appears after the Rename
Columns and Type Overrides steps:

1. "Add Computed Column" button opens a dialog.
2. Dialog shows:
   - Column name (text field, validated for uniqueness).
   - Expression editor (text field with syntax highlighting for keywords,
     column-name autocomplete from available source columns).
   - Preview: sample of computed values against the first N preview rows.
   - Inferred type (dropdown override available).
3. User can add multiple computed columns, reorder them (drag handles), and
   delete them.
4. Validation runs on expression save: parse errors are shown inline, type
   consistency errors are flagged, and referencing a non-existent column is
   caught.
5. The preview step in the wizard shows the computed columns alongside source
   columns in the sample data grid.

### Non-Goals

- Expressions that reference other computed columns (chaining). Revisit if user
  demand is strong; adds ordering dependency complexity.
- Expressions that reference values from other rows (e.g., running totals,
  `LAG`/`LEAD` semantics). This is a fundamentally different computation model
  (window vs. row-local) and belongs in post-import SQL, not the import wizard.
- Subqueries or lookups against the target database. The import pipeline
  operates on source data in isolation.
- Regular expression matching, JSON extraction, or other complex parsing.
- User-defined functions or expression libraries.
- Expression reuse across imports (expression presets). Revisit with import
  recipe persistence (ADR-003?).

### Error Handling

- **Parse errors**: Caught at expression editing time. The wizard shows the
  error inline and prevents saving an unparseable expression.
- **Runtime errors** (e.g., division by zero, type conversion failure): Produce
  NULL with a per-row warning. Warnings are summarized in the import summary
  (count of rows affected, affected columns).
- **Type mismatch errors** (e.g., CASE branches returning inconsistent types):
  Caught at validation time, before import execution begins.
- If a computed column expression fails for a significant percentage of rows
  (configurable threshold, default: 10%), the wizard offers to abort or
  continue with NULLs.

### Trade-offs

- **Constrained language vs. expressiveness**: The expression language is
  intentionally small. A richer language (Lua, JavaScript, or full SQL
  expressions) would be more powerful but introduces sandboxing, dependency, and
  complexity concerns disproportionate to the value of import-time transforms.
  Users who need complex transformations should import raw data and use
  post-import SQL — the tool already has a full SQL editor.
- **No cross-row computation**: Window functions and running totals are
  excluded. These require materializing the entire source dataset before
  computation, which conflicts with the streaming import architecture. Users who
  need window functions should apply them via SQL after import.
- **Row-local execution only**: This aligns with the import pipeline's
  streaming model (rows arrive from the source parser, transforms apply
  row-by-row, rows are inserted). Cross-row or cross-column-chaining
  computations would require buffering, which adds memory pressure for large
  imports.

### References

- ADR-0007 Excel Import Parser and Legacy Workbook Handling
- ADR-0008 SQL Dump Import MVP Parser and Warning Contract
- `design/SPEC.md` section 7 (Import Specifications)
- `design/SPEC.md` section 8.3 (Deferred Transforms — computed columns)
- `design/FUTURE_WINS.md` Priority 15 (Richer Import Transforms)

### Alternatives Considered

**Post-import SQL views instead of computed columns**: Rejected because views
are query-time computations that don't persist in the table. Users who want
persisted derived columns (for export, further querying, or application use)
should not need to create generated columns manually after import.

**Full SQL expression language**: Use the DecentDB engine's own expression
evaluator for computed column expressions. Rejected because:
- The engine's expression evaluator may not be accessible as a standalone row
  evaluator through the Dart FFI bindings.
- Engine expression semantics include engine-specific behavior that may not
  match user expectations for a data-derivation tool.
- Tying computed columns to the engine version creates a compatibility coupling
  that complicates both products.

**No computed columns — rely on generated columns in DecentDB**: Suggest users
import raw data, then add `GENERATED ALWAYS AS ... STORED` columns via DDL.
Rejected because generated columns have engine-specific limitations (e.g.,
cannot reference other generated columns, restricted function set) and require
SQL knowledge that the import wizard intentionally abstracts away.
