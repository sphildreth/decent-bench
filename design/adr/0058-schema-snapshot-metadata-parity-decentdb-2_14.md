## Schema Snapshot Metadata Parity for DecentDB v2.14.0
**Date:** 2026-06-22
**Status:** Accepted

### Decision

When DecentDB upgrades its `getSchemaSnapshot()` metadata contract — adding
fields that the bridge was previously dropping — Decent Bench adopts those
fields into both the bridge worker serialization layer and the app-domain
schema models in the same change, so the schema browser stays at parity with
the engine's documented capabilities.

For the v2.8.0 → v2.14.0 upgrade, the adapter now projects:

- `SchemaTableInfo.rowCount` → `SchemaObjectSummary.rowCount` (tables only;
  views return `null` because views have no persistent row count in
  DecentDB).
- `SchemaTableInfo.primaryKeyColumns` → `SchemaObjectSummary.primaryKeyColumns`
  (in declaration order; replaces the previous "look at each column's
  `primaryKey` flag" heuristic).
- `SchemaTableInfo.foreignKeys` → `SchemaObjectSummary.foreignKeys`
  (full `List<SchemaForeignKey>` with `name`, `columns`, `referencedTable`,
  `referencedColumns`, `onDelete`, `onUpdate`). This is additive with the
  existing per-column `refTable` / `refColumn` / `refOnDelete` / `refOnUpdate`
  projection, which stays in place so the existing
  `SchemaRelationshipGraph` and ERD viewer consumers do not have to change.
- `SchemaColumnInfo.autoIncrement` → `SchemaColumn.autoIncrement`.
- `SchemaViewInfo.sqlText` → `SchemaObjectSummary.sqlText` (view-only;
  exposes the underlying `CREATE VIEW ... AS ...` SELECT body, not the
  synthesized `CREATE VIEW` DDL).
- `SchemaViewInfo.dependencies` → `SchemaObjectSummary.viewDependencies`
  (view-only; the list of tables/views this view reads from).
- `SchemaIndexInfo.includeColumns` → `IndexSummary.includeColumns` (covering
  index `INCLUDE (...)` payload columns).
- `SchemaIndexInfo.fresh` → `IndexSummary.fresh` (false ⇒ the index needs
  rebuild after a bulk load).

In addition, the schema-explorer pane now displays:

- view `SQL text` and `view dependencies` in the view details header,
- covering-index payload columns (`INCLUDE (...)`) on the index label,
- an `AUTOINCREMENT` column badge in the column list,
- a `(rows: N)` badge next to each table name in the tree.

### Rationale

ADR-0003 mandates that the schema browser consume DecentDB's rich schema
snapshot contract instead of synthesizing metadata from narrow projections
or DDL parsing. The bridge was already correctly calling
`db.schema.getSchemaSnapshot()`, but it was discarding several fields that
the engine has exposed since earlier `v2.x` releases:

- `view.sqlText` was dropped because the UI had no consumer for it.
- `index.includeColumns` and `index.fresh` were dropped because the schema
  explorer only labeled columns and DDL.
- `table.rowCount`, `table.primaryKeyColumns`, `table.foreignKeys`, and
  `column.autoIncrement` were dropped because the bridge flattened them into
  per-column flags.

Per ADR-0003, dropping these fields silently narrows the schema browser
below what the engine documents as supported. The 2.14.0 upgrade is the
natural point to close the gap because the upstream Dart binding's public
surface has been stable across `v2.8` → `v2.14` and the schema snapshot
fields have been present for several minor releases already.

Surfacing `SchemaTableInfo.foreignKeys` directly (instead of only via
per-column heuristics) is required to model composite foreign keys correctly.
The previous `_foreignKeyForColumn` helper returned the first
`ForeignKeyInfo` whose `columns` list contained a given column, which
silently merged multi-column constraints into the same per-column row and
hid composite FK identity from the UI.

### Alternatives Considered

1. Continue dropping these fields and rely on a separate "advanced schema
   inspector" dialog driven by raw SQL.
   - Rejected: violates ADR-0003 and fragments schema browsing across the
     app.
2. Replace the per-column FK projection with the new `foreignKeys` list
   only.
   - Rejected: would require changing `SchemaRelationshipGraph` and the ERD
     viewer in the same change, expanding scope beyond a metadata-parity
     upgrade.
3. Compute `rowCount` lazily via a `SELECT COUNT(*)` per table on demand.
   - Rejected: DecentDB already exposes `rowCount` in the schema snapshot,
     and an extra `COUNT(*)` round-trip per open is wasteful for the schema
     browser.

### Trade-offs

- The schema-explorer pane gains a small amount of additional chrome (an
  `AUTOINCREMENT` badge, an `(rows: N)` badge, covering-index payload
  rendering, view SQL text and dependencies). Each addition is a thin text
  label, no new widget tree.
- The `SchemaObjectSummary` model grows by three optional fields (`rowCount`,
  `sqlText`, `viewDependencies`) and one `List<SchemaForeignKey>` field
  (`foreignKeys`). Existing test fixtures must opt in to these new fields;
  missing fields fall back to safe defaults (`null`, empty list) so the
  change is additive.
- `IndexSummary.includeColumns` and `IndexSummary.fresh` are added as
  optional fields with `null` / `true` defaults.

### References

- `design/adr/0003-pinned-decentdb-sql-capability-baseline.md`
- https://decentdb.org/about/changelog/
- https://decentdb.org/api/dart/
- `apps/decent-bench/lib/features/workspace/infrastructure/decentdb_bridge.dart`
- `apps/decent-bench/lib/features/workspace/domain/schema_models.dart`
- `apps/decent-bench/lib/features/workspace/presentation/shell/schema_explorer_pane.dart`
