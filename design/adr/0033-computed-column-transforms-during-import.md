## Row-Local Import Transforms
**Date:** 2026-05-18
**Status:** Accepted

### Decision

Decent Bench supports a serializable, deterministic, row-local transform model
for generic imports. The v2.0.0 model covers:

- computed columns
- conditional row filtering
- default value assignment
- column ordering
- deduplication by key columns

The implementation lives in the import domain and execution pipeline:

- `apps/decent-bench/lib/features/import/domain/import_transforms.dart`
- `apps/decent-bench/lib/features/import/domain/import_transform_application.dart`
- `apps/decent-bench/lib/features/import/infrastructure/import_execution_service.dart`

The model is intentionally not a general scripting language. Expressions are
structured data with a small function set, which keeps plan/profile documents
portable and safe to validate.

### Expression Language

Supported computed-expression operations include:

- arithmetic: `add`/`+`, `subtract`/`-`, `multiply`/`*`, `divide`/`/`,
  `modulo`/`%`
- string functions: `concat`, `substr`/`substring`, `upper`, `lower`, `trim`
- null/type helpers: `coalesce`, `nullif`, `to_integer`, `to_real`, `to_text`
- conditionals and predicates: `if`/`case`, `eq`, `ne`, `lt`, `lte`, `gt`,
  `gte`, `is_null`, `is_not_null`, `and`, `or`, `not`
- literals and post-rename column references

Runtime conversion failures and division/modulo by zero produce `NULL` plus a
summary warning.

### Execution Model

For each selected generic-import table:

1. Source rows are projected into post-rename target column names.
2. Row filters remove rows that do not match the configured predicates.
3. Default value transforms apply.
4. Computed columns evaluate against the row-local source values.
5. Deduplication keeps either the first or last row for each key.
6. Column ordering is applied before table creation and inserts.

Transforms run inside the existing background import worker. They do not use
arbitrary scripting, cross-row lookups, database queries, or window semantics.

### Connector Expansion

Connector expansion is tracked separately from transforms. Future import
formats such as ODS, DuckDB, Parquet import, PostgreSQL dump expansion,
Access/DBF, XZ, clipboard tables, and PDF tables are not faked as supported;
they remain planned, investigate, deferred, or backlog depending on
dependency/product fit.

### Non-Goals

- Arbitrary scripting.
- Expressions that reference other computed columns.
- Cross-row/window computation.
- Database lookups during import.
- Connector marketplace.
- Server-hosted import automation.

### Trade-offs

- **Structured expressions over free-form text**: Less convenient to author by
  hand, but safer to serialize and validate.
- **Row-local only**: Fits the streaming/import-worker model and avoids memory
  pressure from buffering entire sources.
- **Generic importer first**: Dedicated Excel/SQLite/SQL dump wizards can adopt
  the same model later without duplicating transform semantics.

### References

- ADR-0007 Excel Import Parser And Legacy Workbook Handling
- ADR-0008 SQL Dump Import MVP Parser And Warning Contract
- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`
- `apps/decent-bench/assets/help/importing-data.md`
- `design/FUTURE_WINS.md`
