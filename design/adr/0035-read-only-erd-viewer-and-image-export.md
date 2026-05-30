## Read-only ERD Viewer And Image Export
**Date:** 2026-05-19
**Status:** Accepted

### Decision

Decent Bench will add a read-only Entity Relationship Diagram (ERD) viewer as a
post-`v1.0.0` scope expansion. The ERD viewer generates a graphical diagram from
foreign-key metadata in the loaded `SchemaSnapshot`.

This decision does not add an ERD designer. The viewer must not create, edit, or
drop tables, columns, indexes, constraints, or relationships.

The first implementation will:

- derive table nodes and FK edges from the current schema snapshot
- integrate as a non-modal workspace surface
- preserve the existing 2x2 shell by adding an ERD mode/tab to the upper-left
  navigation pane with the schema explorer
- let users double-click a table node to select that table in navigation and run
  the existing top-X table preview query
- support PNG and JPG/JPEG export for both the full diagram and the visible
  viewport
- include table nodes only in the first slice; views remain excluded until a
  separate view-overlay design is accepted
- render missing referenced tables as warning-style placeholder nodes instead of
  silently dropping those relationships
- use a simple Flutter-native deterministic layered-grid layout before
  considering diagram packages or native graph engines
- enforce conservative raster image export size limits before allocating
  high-resolution PNG/JPG canvases

### Rationale

The original PRD/SPEC excluded an "ERD designer" to avoid schema-editing scope
creep. A read-only ERD viewer is different: it is a schema discovery and
navigation feature backed by metadata that Decent Bench already exposes. It
helps users understand imported or existing database structure without turning
the app into a modeling tool.

A non-modal shell surface is required because the ERD is expected to remain open
while table preview queries load in the editor/results area. A true modal dialog
would block the interaction model needed for double-click table loading.

Using the existing upper-left navigation pane keeps ADR-0010's 2x2 shell intact:
schema tree and ERD are alternate schema-navigation surfaces, while properties,
SQL editor, and results retain their current roles.

PNG/JPG export is part of the first accepted feature because ERDs are commonly
shared in design notes, bug reports, and documentation.

### Alternatives Considered

**Keep all ERD work out of scope:** Rejected. The user has explicitly requested
this feature, and a read-only viewer can be implemented without adding schema
designer behavior.

**Modal ERD dialog:** Rejected for the primary implementation because it
conflicts with keeping the diagram open while selecting tables and loading query
results.

**Dock a new fifth pane:** Rejected for the first implementation because it
would disturb the accepted 2x2 shell more than needed.

**Use Graphviz, Mermaid, WebView, or a diagram package immediately:** Deferred.
Native Flutter rendering avoids packaging and license risk for the first slice.
If the simple custom layout timebox turns into a full graph-layout project, the
team should stop and evaluate an Apache 2.0-compatible Dart graph/layout package
under a separate dependency ADR.

### Trade-offs

- The upper-left navigation pane may be narrow for large diagrams, so users may
  need to resize the left split. A future full-workbench or editor-tab view can
  be considered if the first surface is too constrained.
- A simple custom deterministic layout is smaller and easier to ship, but it will
  be less sophisticated than mature graph layout engines. Production-quality
  Sugiyama layout is explicitly deferred unless a future implementation or
  package evaluation justifies it.
- The current app-level schema model exposes FK references per column. The ERD
  model must be multi-column-capable, but richer composite-FK grouping may need
  future DecentDB snapshot metadata if the current snapshot cannot distinguish
  all composite constraints cleanly. The first implementation may merge
  same-table-pair column pairs into one synthetic edge when no upstream FK
  constraint identity is exposed.
- Full-diagram raster export can exceed platform texture or memory limits for
  very large schemas. The implementation must downscale, clamp, tile in a future
  enhancement, or fail clearly before allocating unsafe image sizes.

### References

- `design/ERD_UI_PLAN.md`
- `design/PRD.md`
- `design/SPEC.md`
- `design/FUTURE_WINS.md`
- `design/adr/0010-desktop-shell-layout-and-shortcut-configuration.md`
- `apps/decent-bench/lib/features/workspace/domain/workspace_models.dart`
- `apps/decent-bench/lib/features/workspace/infrastructure/decentdb_bridge.dart`
