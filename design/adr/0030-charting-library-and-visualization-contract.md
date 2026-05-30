## Charting Library And Data Visualization Contract
**Date:** 2026-05-18
**Status:** Accepted

### Decision

Decent Bench adds data visualization as an alternative rendering target for
query results. The v2.0.0 implementation uses an internal `CustomPainter`
renderer for bar, line, scatter, and pie charts instead of adding a charting
package dependency.

Charts consume the result columns, loaded rows, and query-contract metadata that
already feed the results grid. They do not trigger full cursor materialization.
PNG export is implemented through the rendered chart boundary.

### Rationale

SQL grids are right for inspecting records, but they are weak for spotting
patterns, distributions, and relationships. Basic charts keep users inside
Decent Bench for common query -> visualize -> export workflows.

An internal renderer is the right first slice because:

- it adds no new dependency or license review burden
- it is enough for the four initial chart types
- it can stay visually aligned with the app theme
- it keeps large BI-style interactions out of scope until users ask for them

`fl_chart` remains a reasonable future option, but the first implementation did
not need it.

### Chart Data Contract

Charts consume the currently loaded tab data:

1. Result columns and rows come from the same `QueryTabState` used by the grid.
2. Query-contract result metadata helps identify numeric and semantic columns.
3. Users choose chart type and X/Y columns from bounded controls.
4. Line, bar, and scatter charts require numeric Y values.
5. Pie charts require one label column and one numeric value column.
6. Additional pages update the chart when they are loaded into the tab.

The chart layer must not fetch the entire cursor independently. Large datasets
should be summarized by SQL or by a future sampling/aggregation chart adapter.

### Initial Scope

- Bar chart
- Line chart
- Scatter plot
- Pie chart
- X/Y column assignment
- Empty/unsupported state handling
- Theme-aware rendering
- PNG export

### Non-Goals

- Dashboard canvas.
- Real-time streaming charts.
- Full GIS/map workbench.
- Drill-down, brushing, or linked grid filters.
- External chart package dependency in the first implementation.

### Trade-offs

- **Internal renderer vs. package capability**: The internal renderer is smaller
  and safer to ship, but it lacks advanced legends, tooltips, zoom, and BI
  interactions.
- **Loaded rows only**: Charts reflect the visible/loaded row window. Users who
  need exact visualizations over large data should use aggregate SQL or exports
  until a sampling layer is designed.
- **No dependency risk**: Avoiding `fl_chart` or Syncfusion keeps Apache 2.0
  distribution straightforward.

### References

- ADR-0002 Results Paging and Streaming Contract
- ADR-0023 External TOML Theme System
- `apps/decent-bench/lib/features/workspace/domain/result_visualization.dart`
- `apps/decent-bench/lib/features/workspace/presentation/shell/results_pane.dart`

### Alternatives Considered

**`fl_chart`**: Deferred. MIT licensing is compatible, but the first workbench
slice did not need a dependency for basic charting.

**`syncfusion_flutter_charts`**: Rejected for the initial implementation due to
licensing complexity around community/commercial terms.

**No visualization**: Rejected because forcing users to export to a spreadsheet
for every chart preserves unnecessary workflow friction.
