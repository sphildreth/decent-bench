# Decent Bench - ERD UI Implementation Guide

**Status:** Implementation guide
**Last updated:** 2026-05-19
**Primary references:** `design/ERD_UI_PLAN.md`,
`design/adr/0035-read-only-erd-viewer-and-image-export.md`, `design/SPEC.md`

## Purpose

This guide breaks the read-only Entity Relationship Diagram (ERD) viewer into
reviewable implementation phases. It is intended to help contributors land the
feature without turning it into a schema designer, a full graph-layout project,
or a risky image-export pipeline.

The ERD viewer is a schema discovery and navigation feature. It generates table
nodes and foreign-key edges from the loaded `SchemaSnapshot`, integrates into the
existing workspace shell, supports double-click table preview loading, and
exports PNG/JPG images.

## Status Values

- `COMPLETE`: phase is already satisfied by current docs or implementation
- `TODO`: phase is ready to start
- `IN PROGRESS`: implementation is actively underway
- `BLOCKED`: phase cannot proceed until a dependency or decision is resolved
- `AT RISK`: phase is proceeding, but scope or technical risk needs attention

## Phase Map

| Phase | Status | Depends On | Primary Output | Exit Criteria |
|---:|---|---|---|---|
| 0 | COMPLETE | None | Scope and design alignment | ADR, PRD, SPEC, Future Wins, and ERD plan agree that this is a read-only viewer |
| 1 | COMPLETE | Phase 0 | Domain graph model and builder | Graph unit tests pass for FK grouping, missing parents, cycles, self-FKs, isolated tables, and view exclusion |
| 2 | COMPLETE | Phase 1 | Simple deterministic layout | Layout unit tests pass; implementation does not become a full custom Sugiyama project |
| 3 | COMPLETE | Phases 1-2 | ERD navigation-pane viewer | Widget tests cover rendering states, search, responsive density, and keyboard focus basics |
| 4 | COMPLETE | Phase 3 | Workspace integration | Menu, command palette, context menu, and double-click table preview tests pass |
| 5 | COMPLETE | Phases 2-3 | PNG/JPG image export | Export tests cover full diagram, viewport, scale limits, and safe oversized export handling |
| 6 | COMPLETE | Phases 1-5 | Documentation and release hardening | README, SPEC, Future Wins, CHANGELOG, analyzer, tests, and build are clean |

## Phase 0 - Governance Alignment

**Status:** `COMPLETE`

This phase is complete when implementation is explicitly authorized by the
project documents.

Completed scope decisions:

- `design/adr/0035-read-only-erd-viewer-and-image-export.md` accepts the feature.
- `design/PRD.md` distinguishes read-only ERD viewing from ERD designer/schema
  modeling.
- `design/SPEC.md` defines read-only ERD viewer requirements.
- `design/FUTURE_WINS.md` tracks the feature until implementation is complete.
- `design/ERD_UI_PLAN.md` defines the design, risks, and non-goals.

Implementation guardrails:

- Do not add schema editing, modeling, migration, or DDL mutation.
- Do not include views in the first graph.
- Do not introduce a diagram/layout package unless the layout timebox fails and
  a dependency ADR accepts the package.
- Do not allocate image exports beyond safe raster limits.

## Phase 1 - Domain Graph

**Status:** `COMPLETE`

Build the schema relationship graph as pure domain code with no Flutter widget
dependency.

Suggested files:

- `apps/decent-bench/lib/features/workspace/domain/schema_relationship_graph.dart`
- `apps/decent-bench/test/features/workspace/domain/schema_relationship_graph_test.dart`

Tasks:

- Define `SchemaRelationshipGraph`.
- Define `SchemaRelationshipNode`.
- Define `SchemaRelationshipEdge`.
- Define `SchemaRelationshipColumnPair`.
- Define `SchemaRelationshipGraphOptions`.
- Build graph input from `SchemaSnapshot.tables`.
- Exclude `SchemaSnapshot.views` from the first implementation.
- Add placeholder nodes for referenced tables missing from `SchemaSnapshot.tables`.
- Add `constraintId` and nullable `constraintName` to relationship edges.
- Prefer upstream FK constraint identity if available.
- Fall back to synthetic grouping by `childTable`, `parentTable`, and matching
  delete/update actions.
- Merge same-table-pair column pairs into a single edge when no better grouping
  is available.
- Preserve pair-level delete/update actions when an edge contains mixed action
  metadata.
- Produce deterministic ordering for nodes, edges, column pairs, and warnings.

Unit tests:

- Empty schema returns an empty graph.
- Tables with no FKs return isolated table nodes and no edges.
- Views are excluded.
- Single-column FK creates one edge.
- Multiple FKs between different table pairs create distinct edges.
- Same child/parent/actions column pairs merge into one deterministic edge.
- Same child/parent with different actions creates separate edges.
- Self-FK is marked as `isSelfReference`.
- Missing parent table creates a placeholder node and marks the edge as missing.
- Cyclic FKs remain representable without recursion errors.
- Output ordering is stable across repeated graph builds.

Documentation tasks:

- Add code comments only for non-obvious grouping rules.
- Keep `design/ERD_UI_PLAN.md` unchanged unless implementation discovers a
  mismatch in the agreed graph contract.

Exit criteria:

- Graph builder unit tests pass.
- No Flutter imports in the domain graph file.
- Graph output supports all rendering states needed by later phases.

## Phase 2 - Layout

**Status:** `COMPLETE`

Implement a simple deterministic layered-grid layout. This phase must not become
a full custom Sugiyama implementation.

Suggested files:

- `apps/decent-bench/lib/features/workspace/domain/schema_relationship_layout.dart`
- `apps/decent-bench/test/features/workspace/domain/schema_relationship_layout_test.dart`

Tasks:

- Define layout result objects for node bounds, edge routes, and canvas bounds.
- Group connected components.
- Rank parent/reference tables upstream with a basic topological pass where
  possible.
- Place child tables downstream in stable sorted order.
- Pack isolated tables into a stable compact grid.
- Detect strongly connected components and pack cycle members in a stable local
  grid.
- Route self-references as loop edges around the node.
- Use straight or two-segment edge routes for the first slice.
- Place missing-parent placeholder nodes consistently.
- Provide graph options for all tables vs selected-table neighborhood.
- Add a clear reassessment point if crossing reduction, orthogonal routing, or
  repeated layout tuning becomes necessary.

Unit tests:

- Layout is deterministic for the same graph.
- Parent/child ranking is stable.
- Isolated tables are packed consistently.
- Cycle components do not crash layout.
- Self-FK routes are present.
- Missing-reference placeholder nodes receive bounds.
- Selected-table neighborhood filtering keeps directly connected neighbors.
- Canvas bounds include all nodes and routed edges.

Documentation tasks:

- If a third-party layout package becomes necessary, stop implementation and
  create a dependency ADR before adding it.
- Document any intentionally imperfect layout cases in `design/ERD_UI_PLAN.md`.

Exit criteria:

- Layout unit tests pass.
- Layout remains simple and bounded.
- Large graphs have an isolate/scheduled-work path or a clearly documented
  threshold for adding one before UI integration.

## Phase 3 - ERD Viewer

**Status:** `COMPLETE`

Add the non-modal ERD viewer as a tab or mode in the upper-left navigation pane.

Suggested files:

- `apps/decent-bench/lib/features/workspace/presentation/shell/schema_relationship_diagram.dart`
- `apps/decent-bench/lib/features/workspace/presentation/shell/workspace_layout_shell.dart`
- `apps/decent-bench/test/features/workspace/presentation/shell/schema_relationship_diagram_test.dart`

Tasks:

- Add a `Schema` / `ERD` switch in the upper-left navigation pane.
- Render table nodes from graph/layout output.
- Render edges and arrowheads with `CustomPainter`.
- Render missing referenced tables with dashed placeholder nodes.
- Add pan and zoom through `InteractiveViewer`.
- Add zoom-to-fit.
- Add table search using case-insensitive substring matching over table and
  visible column names.
- Keep directly connected FK neighbors visible for search context.
- Add show/hide isolated tables.
- Add selected-table neighborhood mode.
- Implement empty state for schemas with no tables.
- Implement no-relationship notice for schemas with tables but no FKs.
- Implement responsive node density:
  - wide: table name plus up to six columns
  - medium: table name plus key columns, capped at three
  - narrow: table names and edges only
- Add keyboard focus traversal through toolbar, search, and table nodes.
- Make Enter on a focused node invoke the same action as double-click.

Widget tests:

- ERD tab renders for an empty graph.
- No-relationship state still shows table nodes by default.
- Missing-parent placeholder appears with warning styling.
- Search is case-insensitive.
- Search keeps connected neighbor context visible.
- Hide isolated tables removes isolated nodes.
- Selected-table neighborhood mode keeps adjacent nodes.
- Responsive density changes visible column count.
- Table nodes are keyboard focusable.
- Enter on a focused table invokes the load callback.

Documentation tasks:

- Update screenshots or manual verification notes only after the UI is stable.
- Keep user-facing text concise; do not add explanatory tutorial text inside the
  main workbench.

Exit criteria:

- Widget tests pass.
- ERD view is usable in the existing 2x2 shell without blocking SQL/results
  interactions.
- Pan, zoom, search, and focus do not resize or shift the shell unexpectedly.

## Phase 4 - Workspace Integration

**Status:** `COMPLETE`

Wire the ERD viewer into menus, commands, schema context menus, and table preview
loading.

Suggested files:

- `apps/decent-bench/lib/features/workspace/presentation/workspace_screen.dart`
- `apps/decent-bench/lib/features/workspace/presentation/shell/app_menu_bar.dart`
- `apps/decent-bench/lib/features/workspace/presentation/shell/command_palette.dart`
- `apps/decent-bench/test/features/workspace/presentation/workspace_screen_test.dart`

Tasks:

- Add `Tools -> Entity Relationship Diagram`.
- Add command palette item `Entity Relationship Diagram`.
- Add table context-menu item `Show in ER Diagram`.
- Reveal the schema/ERD navigation pane when invoking ERD commands.
- Switch the upper-left navigation pane to the ERD tab.
- Focus the selected table node when launched from a table context menu.
- Keep schema explorer selection synchronized with ERD node selection.
- On double-click or Enter:
  - select `table:<tableName>` in navigation
  - create or activate the top-X table preview query
  - run the query when a database is open
  - keep the ERD viewer open
  - keep the ERD node selected
- Reuse the existing table preview query behavior instead of duplicating SQL
  construction.

Widget/integration tests:

- Tools command opens the ERD tab.
- Command palette entry opens the ERD tab.
- Table context-menu item opens ERD focused on that table.
- Double-clicking `invoices` selects `table:invoices`.
- Double-clicking `invoices` opens the limited preview query.
- Double-clicking with no open database creates the SQL tab but does not run it.
- ERD remains open after query execution.
- Schema selection and ERD selection remain synchronized.

Documentation tasks:

- Add any command ID or shortcut documentation if a shortcut is introduced.
- Update `design/ERD_UI_PLAN.md` only if command behavior changes from the plan.

Exit criteria:

- Workspace integration tests pass.
- User can move from ERD node to results grid without closing or losing the ERD.

## Phase 5 - PNG/JPG Image Export

**Status:** `COMPLETE`

Add raster image export with safe pixel limits.

Suggested files:

- `apps/decent-bench/lib/features/workspace/domain/schema_relationship_export.dart`
- `apps/decent-bench/lib/features/workspace/presentation/shell/schema_relationship_diagram.dart`
- `apps/decent-bench/test/features/workspace/domain/schema_relationship_export_test.dart`
- `apps/decent-bench/test/features/workspace/presentation/shell/schema_relationship_diagram_test.dart`

Tasks:

- Add ERD toolbar action `Export Image`.
- Add export dialog options:
  - PNG or JPG/JPEG
  - full diagram or current visible viewport
  - 1x, 2x, or 3x scale
  - transparent PNG or solid JPG background
- Default to PNG, full diagram, 2x scale.
- Implement one offscreen raster renderer for both full-diagram and viewport
  export.
- Include diagram title/context:

  ```text
  <database filename or sample.decentdb> - ERD - <table count> tables, <relationship count> relationships
  ```

- Include nodes, visible column labels, edges, arrowheads, edge labels, and
  missing-reference placeholders.
- Exclude transient UI controls, hover states, open menus, and search controls.
- Enforce conservative first-slice safe limits before allocating images:
  - maximum 8192 px on either axis
  - maximum 64 megapixels total
- If requested scale exceeds limits, downscale to the largest safe scale and
  notify the user.
- If 1x full-diagram export still exceeds limits, offer viewport export or fail
  clearly.
- Keep tiled full-diagram export deferred.
- Keep SVG export deferred because it requires a separate vector renderer.

Unit/widget tests:

- PNG export produces non-empty bytes.
- JPG export produces non-empty bytes on a solid background.
- Full-diagram export includes offscreen nodes.
- Viewport export honors viewport bounds.
- 2x/3x export requests calculate expected output dimensions.
- Oversized export requests are downscaled or rejected before image allocation.
- Missing-reference placeholders are included in exported images.
- Export title/context includes database label, table count, and relationship
  count.

Documentation tasks:

- Document image export behavior in README once implemented.
- Add CHANGELOG entry for PNG/JPG ERD export.

Exit criteria:

- Export tests pass.
- Large export requests cannot trigger unsafe image allocation.
- Manual PNG/JPG exports are readable and omit transient controls.

## Phase 6 - Documentation, Hardening, And Release Validation

**Status:** `COMPLETE`

Finalize documentation and run full validation.

Tasks:

- Update `README.md` feature list.
- Update `design/SPEC.md` only if implementation differs from the current
  accepted behavior.
- Remove ERD from `design/FUTURE_WINS.md` once fully implemented.
- Update `CHANGELOG.md`.
- Add or update manual verification steps.
- Confirm no new dependency was added. If one was added, verify Apache
  2.0-compatible distribution and update notices if required.
- Run code formatters if the repo requires them.
- Run analyzer, tests, and build.

Required validation:

```sh
cd apps/decent-bench
flutter analyze
flutter test
flutter build linux
```

Run integration tests if they exist and the environment supports them:

```sh
cd apps/decent-bench
flutter test integration_test
```

Manual validation:

- Open a schema with `users`, `products`, and `invoices`.
- Open `Tools -> Entity Relationship Diagram`.
- Verify `invoices -> users` and `invoices -> products`.
- Double-click `invoices`.
- Verify `table:invoices` is selected in navigation.
- Verify the limited preview query opens and runs.
- Verify the first page of invoice rows appears in results.
- Verify a schema with no FKs still shows tables with a no-relationship notice.
- Verify missing referenced tables render as placeholders.
- Export full diagram as PNG and JPG.
- Export current viewport as PNG and JPG.
- Verify oversized export requests are safely downscaled or rejected.
- Verify app responsiveness during pan, zoom, search, table loading, and export.

Exit criteria:

- Analyzer passes.
- Unit/widget tests pass.
- Build completes without errors.
- Documentation reflects shipped behavior.
- ERD is removed from Future Wins only after the feature is fully implemented.

## Phase Risk Register

| Risk | Phase | Mitigation |
|---|---:|---|
| Custom layout grows beyond first-slice scope | 2 | Timebox simple layered-grid layout; evaluate package under ADR if needed |
| Composite FK grouping is ambiguous | 1 | Use `constraintId` when available; otherwise deterministic synthetic grouping |
| Large image export exceeds GPU/memory limits | 5 | Enforce axis and megapixel limits before allocation |
| ERD becomes schema designer by accident | All | Keep all schema mutation out of model, UI, commands, and tests |
| Navigation pane is narrow for dense schemas | 3 | Responsive node density and resizable shell split |
| Workspace preview behavior diverges from schema context menu | 4 | Reuse existing table preview query path |

## Implementation Notes

- Keep each phase independently reviewable.
- Prefer domain tests before widget work.
- Keep shell changes small; preserve ADR-0010's 2x2 layout.
- Avoid dependency additions unless the phase explicitly escalates to an ADR.
- Preserve current user changes in the worktree; do not revert unrelated files.
