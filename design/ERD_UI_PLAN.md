# Decent Bench - Entity Relationship Diagram UI Plan

**Status:** Accepted implementation plan
**Last updated:** 2026-05-19
**Primary references:** `design/PRD.md`, `design/SPEC.md`,
`design/adr/0035-read-only-erd-viewer-and-image-export.md`

## Purpose

Decent Bench should provide a graphical Entity Relationship Diagram (ERD) for
schemas that expose foreign-key relationships. The ERD is a read-only
navigation and discovery surface: it helps users understand table structure,
foreign-key direction, and related tables without leaving the workspace.

The first implementation should generate the ERD from the loaded
`SchemaSnapshot`. It should not introduce a separate schema introspection path,
and it should not become a table-design or migration-authoring tool.

## Scope Classification

This feature is a user-approved post-`v1.0.0` scope expansion accepted by
ADR-0035. Earlier PRD/SPEC language excluded an "ERD designer"; that exclusion
still stands for schema editing and modeling workflows. This plan covers only a
read-only ERD viewer used for schema discovery, navigation, table preview, and
image export.

Implementation may proceed under this classification. PRD, SPEC, and Future Wins
documentation reference ADR-0035 and distinguish the read-only viewer from an
ERD designer.

## Goals

- Generate a graphical diagram from DecentDB schema metadata.
- Represent tables as nodes and foreign keys as directed edges.
- Support schemas with isolated tables, missing references, cycles, and
  self-references.
- Let users navigate from a diagram node back into the normal workspace.
- Reuse the existing table preview behavior for double-click table loading.
- Keep rendering responsive for large schemas.
- Avoid new runtime dependencies for the first slice unless a license and
  packaging review proves a dependency is clearly better.

## Non-goals

- Editing relationships in the ERD.
- Creating or dropping tables, columns, indexes, or constraints from the ERD.
- Reverse-engineering relationships without explicit foreign-key metadata.
- Inferring cardinality from data values.
- Building a general-purpose diagram editor.

## Object Coverage

The first implementation includes table nodes only. Views are excluded from the
initial ERD because the current relationship source is explicit foreign-key
metadata, and views do not carry FK metadata in the app-level schema model.

Future work may add views as a separate optional overlay or isolated-node mode,
but that should be designed separately so users do not confuse derived query
objects with FK-backed table relationships.

## User Experience

### Entry points

Add these entry points:

- `Tools -> Entity Relationship Diagram`
- Command palette item: `Entity Relationship Diagram`
- Table context-menu item: `Show in ER Diagram`

The schema explorer remains the primary tree navigation surface. The ERD is a
secondary visual navigation surface that can focus the schema explorer and load
query results.

### Shell integration

The first implementation must not use a true modal dialog. The diagram is
expected to remain open while the user double-clicks tables, activates query
tabs, and inspects results, so a modal interaction would block the required
workflow.

Use the existing ADR-0010 2x2 shell structure:

- upper-left navigation pane: tab between `Schema` and `ERD`
- lower-left pane: keep `Properties`
- upper-right pane: keep SQL editor
- lower-right pane: keep results

Opening `Tools -> Entity Relationship Diagram` should reveal the upper-left
navigation pane if hidden, switch that pane to the `ERD` tab, and focus the
diagram. `Show in ER Diagram` from a table context menu should do the same and
focus the selected table node.

This keeps the diagram open while the SQL editor and results panes update. If
users need more diagram room, they can resize the left split. A future
full-workbench or editor-tab diagram view can be considered after the docked
navigation-pane implementation is validated.

### Diagram surface

The ERD view should include:

- pan and zoom
- zoom-to-fit
- search table
- focus selected table
- hide/show isolated tables
- show all tables
- show selected table neighborhood
- export image
- empty and no-relationship states

Default behavior:

- show all tables, including isolated tables
- show a non-blocking notice when tables exist but no foreign-key relationships
  are found
- show an empty state when the schema contains no tables
- let users hide isolated tables after the initial render

The search box should match the schema explorer's filtering style:
case-insensitive substring matching over table names and visible column names.
The filtered diagram should keep directly connected FK neighbors visible so
relationship context is not lost.

### Table node content

Each table node should show:

- table name
- primary-key columns
- foreign-key columns
- regular columns, truncated when the table has many columns
- optional badges for generated columns or constraints in later iterations

The node should not try to show every metadata detail from the schema browser.
It should remain scan-friendly.

Column display should default to a maximum of six visible columns per node before
showing `+N more`. This should be a hardcoded first-slice UI constant, not a user
preference. A preference can be added later if the default proves too dense or
too sparse.

Responsive density rules:

- wide navigation pane: show table name plus up to six columns
- medium navigation pane: show table name plus key columns first, capped at
  three visible columns
- narrow navigation pane: show table names and relationship edges only
- avoid text overflow; node labels must truncate or wrap within stable node
  dimensions

### Edge content

Each foreign-key edge should show:

- child table and column
- referenced parent table and column
- delete/update actions when available
- visual direction from child to parent

The current app-level schema model exposes FK metadata per column through
`SchemaColumn.refTable`, `refColumn`, `refOnDelete`, and `refOnUpdate`. The
DecentDB bridge maps these values from upstream column foreign-key metadata,
including the upstream local/referenced column arrays where available.

The ERD domain model should still store an edge as a list of column pairs so
composite foreign keys can be represented later without changing the diagram
contract. If the current snapshot cannot distinguish all composite FK constraint
groups cleanly, the first implementation should group only relationships it can
represent deterministically and leave richer grouping for a follow-up bridge
contract update.

First-slice edge grouping:

- Prefer an upstream FK constraint id/name when it is available.
- Otherwise generate a synthetic `constraintId`.
- The synthetic fallback groups column pairs by `childTable`, `parentTable`, and
  matching delete/update actions.
- If two same-table-pair relationships have different actions, render separate
  edges so labels remain truthful.
- If two independent same-table-pair relationships have the same actions, merge
  them into one edge with multiple column-pair labels. This is visually compact
  and reflects the best grouping the current app-level snapshot can provide.
- Do not emit one edge per column by default; that is too noisy for common
  composite or role-based relationships.

The edge label should list multiple column pairs compactly, for example:
`user_id -> users.id, approver_id -> users.id`.

### Missing-reference rendering

If a FK references a table that is not present in `SchemaSnapshot.tables`, the
diagram should render a placeholder node rather than silently dropping the
relationship:

- placeholder label: referenced table name
- visual style: dashed outline and subdued/italic label
- edge style: dashed edge from child table to placeholder
- tooltip/note: `Referenced table is not present in the loaded schema snapshot`

Image export must include missing-reference placeholder nodes and dashed edges so
exported diagrams preserve the same warning context as the live view.

## Double-click Table Loading

Double-clicking a table node should perform the same workflow users already get
from schema explorer `View Data`:

1. Select the table in the schema explorer navigation.
2. Create or activate a SQL query tab containing:

   ```sql
   SELECT *
   FROM "table_name"
   LIMIT <defaultPageSize>;
   ```

3. Run the query when a database is open.
4. Make the table-preview query the selected query view and show the top X rows
   in the active results grid, where X is the configured `defaultPageSize`.
5. Keep the diagram open unless the user explicitly closes it.

This should reuse the existing table-preview path instead of duplicating query
construction logic. The behavior should match the current table context menu
that opens `SELECT * FROM <table> LIMIT defaultPageSize`.

If the table node was opened from a project or sample state without an open
database, the app should still create the SQL tab but should not attempt to run
the query.

For this plan, "selected in the query view" means the generated table-preview
query tab becomes active and the first page of rows is loaded into the active
results surface. If row-level selection is available in the grid, the loaded
rows may be highlighted as the current preview range, but this must not imply a
pending edit, delete, or export selection.

## Example Workflow

Given this schema:

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT
);

CREATE TABLE products (
  id INTEGER PRIMARY KEY,
  sku TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  price NUMERIC NOT NULL
);

CREATE TABLE invoices (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  product_id INTEGER NOT NULL REFERENCES products(id),
  invoice_number TEXT NOT NULL UNIQUE,
  total NUMERIC NOT NULL,
  issued_at TEXT NOT NULL
);
```

The generated ERD should contain:

- `users`
- `products`
- `invoices`
- edge `invoices.user_id -> users.id`
- edge `invoices.product_id -> products.id`

When the user opens the ERD and double-clicks the `invoices` table:

1. The schema explorer selects `table:invoices`.
2. A query tab opens with:

   ```sql
   SELECT *
   FROM "invoices"
   LIMIT <defaultPageSize>;
   ```

3. The query executes against the open DecentDB workspace.
4. The `invoices` table-preview query becomes the selected query view.
5. The results pane displays the top X `invoices` rows, where X is the
   configured page size.
6. The `invoices` node remains visually selected in the ERD.

## Domain Model

Add a small domain layer for the derived graph:

- `SchemaRelationshipGraph`
- `SchemaRelationshipNode`
- `SchemaRelationshipEdge`
- `SchemaRelationshipColumnPair`
- `SchemaRelationshipGraphOptions`

Recommended fields:

```text
SchemaRelationshipNode
  id
  tableName
  columns
  primaryKeyColumns
  foreignKeyColumns
  isTemporary
  isIsolated

SchemaRelationshipEdge
  id
  constraintId
  constraintName
  childTable
  parentTable
  columnPairs
  onDelete
  onUpdate
  isSelfReference
  hasMissingParent

SchemaRelationshipColumnPair
  childColumn
  parentColumn
  onDelete
  onUpdate
```

The graph builder should accept `SchemaSnapshot` and produce a deterministic
graph. It should not depend on Flutter widgets.

`constraintName` is nullable. `constraintId` is always present and may be a
synthetic grouping key when the loaded schema snapshot does not expose an
upstream FK constraint identity. Edge-level `onDelete` and `onUpdate` should be
set only when all column pairs in the edge share the same actions; otherwise the
pair-level action fields are the source of truth for labels/tooltips.

## Layout Strategy

Use a simple deterministic layered grid for the first implementation. Do not try
to build a production-quality Sugiyama layout in the initial slice. Full
Sugiyama-style layout requires cycle removal, layer assignment, crossing
reduction, coordinate assignment, and advanced edge routing; that is not required
to ship the first usable ERD viewer.

First-slice layout rules:

- group connected components
- rank referenced parent tables upstream with a basic topological pass where
  possible
- place child tables downstream in stable sorted order
- place isolated tables in a compact grid when visible
- detect strongly connected components for cycles and pack each cycle component
  in a stable local grid
- route self-references as loop edges around the node
- use simple straight or two-segment routed edges before attempting orthogonal
  crossing reduction

Keep layout separate from graph construction:

- `schema_relationship_graph.dart` builds the semantic graph
- `schema_relationship_layout.dart` computes node rectangles and edge routes
- `schema_relationship_diagram.dart` renders the result

For small and medium schemas, synchronous layout is acceptable. For larger
schemas, run layout through an isolate or scheduled background task before
painting to preserve UI responsiveness.

Timebox Slice 2 around the simple layout. If the implementation starts requiring
crossing reduction, complex edge routing, or repeated layout tuning to become
usable, stop and evaluate an Apache 2.0-compatible Dart layout package or graph
layout adapter under a separate dependency ADR. The first release should prefer a
clear, stable, imperfect diagram over a large custom graph-layout project.

Arrow-key navigation is intentionally not part of the first layout contract. If
it is added later, prefer spatial navigation based on rendered node positions so
arrow keys match what users see on screen. Graph-adjacency traversal can be added
as a separate relationship navigation command if needed.

## Rendering Strategy

Use Flutter-native rendering for the first slice:

- `InteractiveViewer` for pan and zoom
- `CustomPainter` for edges and arrowheads
- positioned Flutter widgets for table nodes

This avoids desktop packaging complexity from native graph engines or WebView
rendering. It also keeps text, focus, tooltips, context menus, and accessibility
in normal Flutter widgets.

Do not add Graphviz, Mermaid, or a web renderer in the first implementation.
Evaluate a diagram/layout package only if the simple deterministic layout is not
good enough after the Slice 2 timebox, and only after Apache 2.0 distribution
compatibility is verified.

## Image Export

The ERD viewer must support exporting the diagram as a raster image:

- PNG
- JPG/JPEG

The export action should be available from the ERD toolbar and command palette
when the ERD view is open. The export dialog should let the user choose:

- output format: PNG or JPG
- export scope: full diagram or current visible viewport
- scale: 1x, 2x, or 3x
- background: transparent for PNG, solid theme/background color for JPG

The default should be PNG, full diagram, 2x scale. JPG should always render on a
solid background because JPEG does not support transparency.

Implementation guidance:

- Use Flutter-native rasterization first.
- Use one offscreen export renderer for both full-diagram and visible-viewport
  export so 1x/2x/3x output is deterministic and not limited by the on-screen
  device pixel ratio.
- The visible-viewport export should pass the current viewport transform and
  bounds into the offscreen renderer.
- The full-diagram export should render the complete laid-out graph so clipped
  or offscreen nodes are included.
- A `RepaintBoundary` capture can remain useful for tests or diagnostics, but it
  should not be the primary high-resolution export path.
- Before allocating the export canvas, calculate the output pixel dimensions and
  enforce safe limits. The first implementation should use conservative defaults:
  maximum 8192 px on either axis and maximum 64 megapixels total.
- If the requested scale exceeds safe limits, automatically lower the scale to
  the largest safe value and notify the user. If 1x still exceeds safe limits,
  offer a clamped viewport export or a future tiled-export path rather than
  risking an out-of-memory crash.
- Tiled full-diagram export may be added later if users need very large raster
  diagrams, but it is not required for the first image export slice.
- Use the existing file picker/save-location flow for destination selection.
- Keep image encoding off the UI thread for large diagrams where practical.
- Show progress or a disabled export button while an image export is running.

Exported images should include table nodes, visible column labels, edges,
arrowheads, edge labels, missing-reference placeholders, and the current diagram
title/context. They should not include transient UI controls such as search
fields, toolbar buttons, hover states, or open context menus.

The diagram title/context should be:

```text
<database filename or sample.decentdb> - ERD - <table count> tables, <relationship count> relationships
```

SVG export remains deferred. It is not a simple `CustomPainter` export; it needs
a separate vector rendering path that maps nodes, text, and routed edges into SVG
primitives.

## Implementation Slices

### Slice 0 - Governance alignment

- Accept ADR-0035 before implementation.
- Update PRD/SPEC references so "ERD designer" remains out of scope while the
  read-only ERD viewer is in scope.
- Add the ERD viewer to `design/FUTURE_WINS.md` until implementation is
  complete.

### Slice 1 - Domain graph

Depends on Slice 0.

- Build graph from `SchemaSnapshot.tables`.
- Add unit tests for simple FK, multiple FKs, self-FK, missing parent,
  isolated tables, and cycles.
- Keep edge model multi-column-capable.
- Add `constraintId` and nullable `constraintName` to edges.
- Merge same-table-pair column pairs into one edge when the current schema
  snapshot cannot expose a more precise FK constraint grouping.

### Slice 2 - Layout

Depends on Slice 1.

- Add the simple deterministic layered-grid layout with stable node ordering.
- Add unit tests for coordinate stability and cycle fallback.
- Add graph options for all tables vs selected-table neighborhood.
- Add missing-reference placeholder node placement.
- Stop and reassess if this slice starts turning into a full custom Sugiyama
  implementation.

### Slice 3 - ERD viewer

Depends on Slices 1 and 2.

- Add an ERD tab/mode to the upper-left navigation pane.
- Render nodes and edges.
- Support pan, zoom, zoom-to-fit, search, and selection.
- Add empty states for schemas with no tables and schemas with tables but no
  foreign-key relationships.
- Add responsive node density for wide, medium, and narrow navigation widths.

### Slice 4 - Workspace integration

Depends on Slice 3 and the existing workspace controller/table-preview query
path.

- Add menu, command palette, and schema table context-menu entry points.
- Double-click table nodes to select schema navigation and load table data.
- Reuse the current `SELECT * FROM <table> LIMIT defaultPageSize` query path.
- Preserve active diagram selection after loading table data.

### Slice 5 - Image export and polish

Depends on Slice 3. Full-diagram export also depends on the layout contract from
Slice 2.

- Add PNG and JPG export.
- Support full-diagram and visible-viewport export scopes.
- Add image scale selection and JPG background handling.
- Add export canvas safe-limit handling before allocating raster images.
- Add optional SVG export after the rendering contract is stable.
- Add persisted diagram preferences if users need custom focus/filter settings.

## Performance Requirements

- Do not query the database to build the diagram; use the latest loaded schema
  snapshot.
- Do not block the UI thread for large layouts.
- Avoid rendering all column labels at high zoom-out levels.
- Provide a six-column default maximum per node with a `+N more` indicator.
- Keep pan and zoom smooth by repainting edges separately from node widgets
  where practical.
- Never allocate export images beyond the configured safe pixel limits; downscale,
  clamp, or fail clearly before risking GPU texture-limit or memory failures.

## Accessibility and Keyboard Support

- Nodes must be keyboard focusable.
- Enter should load the focused table the same way double-click does.
- Initial keyboard focus should support tabbing between the ERD toolbar, search,
  and table nodes.
- Arrow keys may move focus between nearby nodes in a later iteration, but that
  is not required for the first accessible implementation.
- Tooltips should describe FK edges and table-node actions.
- Search results should be reachable by keyboard.

## Documentation Updates

When implemented, update:

- `README.md` feature list
- `design/SPEC.md` schema browser/workbench section
- `CHANGELOG.md`
- `design/FUTURE_WINS.md`

ADR-0035 is the scope and shell-integration decision for the first
implementation. Create an additional ADR only if implementation chooses a
third-party diagram/layout dependency, changes the 2x2 shell contract beyond the
upper-left navigation tab, or adds schema-editing behavior.

## Validation Plan

Automated validation:

- graph-builder unit tests
- test that views are excluded from the first-slice graph
- test same-table-pair FK columns are grouped into deterministic edges when no
  upstream constraint identity exists
- test missing referenced tables produce placeholder nodes and dashed edges
- layout unit tests
- widget tests for opening ERD from menu/command palette
- widget tests for double-clicking a table node
- widget tests for case-insensitive table search and connected-neighbor context
- test that double-clicking `invoices` selects `table:invoices`
- test that double-clicking `invoices` opens the top-X preview query
- image export tests for PNG and JPG encoder paths where the test environment
  supports image bytes
- test full-diagram export includes offscreen nodes
- test export requests above safe texture/pixel limits are downscaled or rejected
  before image allocation
- test exported image metadata/title context includes database label, table
  count, and relationship count

Manual validation:

- open a schema with `users`, `products`, and `invoices`
- open `Tools -> Entity Relationship Diagram`
- verify `invoices -> users` and `invoices -> products` edges
- verify a schema with no FKs still shows table nodes with a no-relationships
  notice
- verify missing referenced tables render as placeholder nodes
- double-click `invoices`
- verify schema explorer selects `invoices`
- verify query tab contains the limited table preview query
- verify results pane displays the first page of `invoices` rows
- export the full ERD as PNG and JPG
- export the current viewport as PNG and JPG
- verify exported images contain nodes, edges, labels, and expected background
- verify the app remains responsive during pan, zoom, search, and query loading
