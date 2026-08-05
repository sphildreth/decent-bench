## Column Reordering UX Contract
**Date:** 2026-06-21  
**Status:** Proposed  

### Decision

Implement drag-and-drop column reordering in the results grid with persistent per-tab state. The feature will use Flutter's built-in drag-and-drop APIs and store column order in the per-tab workspace state JSON file.

### Rationale

Users frequently want to rearrange columns for better readability after running queries. This is a low-complexity enhancement that improves UX without introducing new dependencies or architectural changes. The feature aligns with SPEC guidance ("Column resize and reorder are desirable but not mandatory for MVP") as an ideal post-MVP enhancement.

### Implementation Approach

Use Flutter's `ReorderableListView` or custom drag-and-drop widget:
- Wrap results grid columns in reorderable widget
- Add visual ghost cursor during drag operation
- Store column order array in per-tab workspace state JSON
- Restore order on tab reopen from config
- Add "Reset to default" button for quick reset

### Column Order Storage Contract

Column order is stored in the per-tab workspace state JSON file:

```json
{
  "tab_id": "query-1",
  "column_order": ["id", "name", "email", "created_at"],
  "default_column_order": ["id", "name", "email", "created_at"]
}
```

- `column_order`: Current user-specified order (array of column names)
- `default_column_order`: Original order before reordering (for reset functionality)

### UX Requirements

1. **Drag Handle:** Add drag handle icon (≡) to each column header
2. **Visual Feedback:** Show ghost cursor during drag operation
3. **Smooth Animation:** 60fps during drag; no layout thrashing
4. **Snap-to-Grid:** Drop only at column boundaries, not mid-column
5. **Reset Functionality:** "Reset to default" button in results toolbar

### Performance Requirements

- Drag operation must maintain 60fps scroll performance
- No memory leak from repeated reordering operations
- Column order persistence must be atomic (no corruption on crash)

### Out of Scope

- Column width resizing automation or presets
- Batch column reordering via keyboard shortcuts
- Column visibility toggling (existing feature)
- Column grouping/folding

### Trade-offs

| Aspect | Benefit | Cost |
|--------|---------|------|
| Drag-and-drop API | Familiar UX pattern | Slightly more complex than click-to-reorder |
| Per-tab state storage | Preserves user preference per query | Small JSON file growth (negligible) |
| Reset button | Quick recovery from mistakes | Extra UI element |

### References

- `design/SPEC.md` Section 10.1 Results grid specification
- `apps/decent-bench/lib/features/workspace/domain/app_config.dart` (workspace state model)
- Flutter documentation: https://api.flutter.dev/flutter/widgets/ReorderableListView-class.html
