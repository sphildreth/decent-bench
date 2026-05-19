## Charting Library and Data Visualization Contract
**Date:** 2026-05-18
**Status:** Proposed

### Decision

Decent Bench will add data visualization (charts) as an alternative rendering
target for query results. The initial implementation will use the `fl_chart`
package (MIT-licensed) for basic chart types: line, bar, pie, and scatter.
Charts consume the same cursor-based paging pipeline that feeds the results
grid.

### Rationale

SQL results grids are the right tool for inspecting individual records. They are
the wrong tool for understanding patterns, trends, distributions, and
relationships. A 10,000-row sales table tells you nothing at a glance; a line
chart of revenue over time tells you everything.

Users currently export data to CSV, open it in Excel or Google Sheets, and build
charts there. Every round-trip is friction — and a reason to use a different
tool. Adding visualization keeps users in Decent Bench for a complete
query→visualize→export workflow, which competing SQL editors (DBeaver,
DataGrip) and BI tools (Metabase, Superset) have proven is a core workflow.

### Library Selection: `fl_chart`

`fl_chart` was selected over alternatives:

| Criterion | `fl_chart` | `syncfusion_flutter_charts` | Custom Canvas |
|---|---|---|---|
| License | MIT (Apache 2.0 compatible) | Community license terms; commercial component | No dependency |
| Flutter ecosystem adoption | Most popular charting package on pub.dev | Well-known but smaller Flutter-specific adoption | N/A |
| Chart types supported | Line, bar, pie, scatter, radar | All major types + specialized (financial, etc.) | Unlimited but requires implementation |
| Customization | Themeable, composable | Highly customizable | Full control |
| Performance | Good for modest datasets | Optimized for large datasets | Depends on implementation |
| Maintenance burden | External dependency risk | External dependency + licensing risk | Internal maintenance burden |

`fl_chart` is the pragmatic choice: MIT-licensed (no licensing gates), widely
adopted in the Flutter ecosystem, and provides the four chart types that cover
the vast majority of query visualization needs. Custom canvas rendering and
`syncfusion_flutter_charts` remain available as fallbacks if `fl_chart` proves
insufficient for performance or customization requirements.

### Chart Data Contract

Charts consume the same data source as the results grid: a `QueryPage` from the
cursor pipeline. The chart data adapter:

1. Receives `QueryPage` objects (column metadata + row batches) as pages arrive.
2. Maps columns to chart axes based on user configuration (drag-and-drop or
   dropdown selectors).
3. For line/bar/scatter charts, X must be a single column (categorical or
   continuous) and Y must be one or more numeric columns.
4. For pie charts, one categorical column (labels) and one numeric column
   (values).
5. Charts update incrementally as new pages arrive, with a "chart in progress"
   indicator until the cursor reports completion.
6. Chart data is held in memory up to a configurable "max chart rows" limit
   (default: 50,000). Beyond that, chart rendering uses sampling or
   bucketing.

Key constraint: charts never trigger full materialization of the result set.
They operate on pages as they arrive and discard raw page data after
aggregation for the chart data model.

### Chart Types and Scope

**Initial chart types (Future Wins Priority 11 scope):**
- **Line chart**: X = continuous or categorical, Y = one or more numeric series.
- **Bar chart**: X = categorical, Y = one or more numeric series. Grouped or
  stacked.
- **Pie chart**: One label column (categorical), one value column (numeric).
- **Scatter plot**: X = numeric, Y = numeric, optional color/group-by column.

**Chart interactions:**
- Tooltips on hover showing exact values.
- Legend toggles to show/hide individual series.
- Zoom by drag-select on scatter plots (resets on double-click).
- Export chart as PNG via `dart:ui` canvas snapshot.

**Chart layout:**
- Split view: chart on one side, results grid on the other (resizable divider).
- Full-width toggle: expand chart to fill the results pane.
- Chart title (configurable, defaults to truncated query text).
- Axis labels auto-generated from column names.

### Non-Goals

- Dashboard canvas with multiple independent chart tiles composited on a single
  surface.
- Chart filter interactions that modify the underlying SQL query (bidirectional
  brushing/linking).
- Animated or streaming real-time charts.
- Custom chart themes beyond the app's light/dark theme system (ADR-0023).
- Geospatial/map visualizations. DecentDB spatial type support is a separate,
  later consideration.
- Chart type auto-detection from column data types and cardinality (e.g.,
  "this looks like a time series, suggest line chart").
- `syncfusion_flutter_charts` or custom canvas as alternative backends in the
  initial implementation.

### Trade-offs

- **`fl_chart` vs. full BI tool capability**: `fl_chart` provides basic charts
  but lacks dashboard composition, drill-down, and advanced interactions. This
  is intentional — Decent Bench is a workbench, not a BI platform. Users who
  need dashboards should use Metabase or Superset and consume DecentDB exports.
- **In-memory chart data cap**: Limiting chart data to 50,000 rows before
  sampling means very large result sets get approximate charts. This is
  acceptable because charts are for pattern recognition, not precision — users
  who need exact values from large datasets should use the results grid or
  aggregated queries.
- **No bidirectional linking**: Chart selections do not filter the results grid,
  and grid selections do not highlight chart points. This keeps the interaction
  model simple. Bidirectional linking can be added if user feedback demands it.

### References

- ADR-0002 Results Paging and Streaming Contract
- ADR-0023 External TOML Theme System
- `design/SPEC.md` section 6 (Query Execution and Paging Contract)
- `design/FUTURE_WINS.md` Priority 11
- `fl_chart` package: https://pub.dev/packages/fl_chart (MIT license)

### Alternatives Considered

**`syncfusion_flutter_charts`**: Rejected for the initial implementation due to
licensing complexity. While the community license permits free use in many
scenarios, the commercial component and unclear Apache 2.0 compatibility create
unnecessary licensing risk. Can be reconsidered if `fl_chart` proves
insufficient.

**Custom canvas rendering with `dart:ui`**: Rejected because it would require
building chart primitives (axes, legends, tooltips, zoom) from scratch —
significant effort for no user-visible benefit over using an established
library. Custom rendering is a fallback if all charting libraries prove
unsuitable, not a first choice.

**No visualization — rely on CSV export for external charting**: Rejected
because it preserves the very friction this feature aims to eliminate. The
"export to Excel to chart" workflow is what drives users away from the tool.
