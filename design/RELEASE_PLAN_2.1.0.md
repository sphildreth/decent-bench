# Decent Bench — Release 2.1.0 Phased Approach

**Status:** Proposed  
**Date:** 2026-06-21  
**Target Release:** v2.1.0  
**Primary References:** `design/PRD.md`, `design/SPEC.md`, `design/FUTURE_WINS.md`

---

## Phase Map

| Feature | Phase 1 (Core) | Phase 2 (Polish) | Phase 3 (Documentation) |
|---------|----------------|------------------|------------------------|
| Parquet Export | ✅ TODO | N/A | N/A |
| Excel (.xlsx) Export | ✅ TODO | N/A | N/A |
| Column Reordering in Results Grid | ✅ TODO | N/A | N/A |

---

## Executive Summary

Release 2.1.0 focuses on **completing the export feature set** and improving results grid UX. The three selected features directly address MVP backlog items identified in `design/PRD.md` Section 3.2 and `design/SPEC.md` Section 11.2, while delivering high user value with minimal architectural risk.

### Feature Selection Rationale

1. **Parquet Export** — Addresses SPEC backlog (v2.0.0 CHANGELOG lists Parquet as "Next"), standard analytical format for large datasets
2. **Excel (.xlsx) Export** — Completes import/export symmetry (users can import Excel but cannot export to it); v2.0.0 CHANGELOG mentions minimal writer was added
3. **Column Reordering** — Low-complexity enhancement; SPEC states "desirable but not mandatory for MVP"

---

## Phase 1: Core Implementation (Weeks 1-2)

### 1.1 Parquet Export

**Goal:** Implement cursor-based streaming Parquet export to avoid memory issues with large result sets.

**Implementation Tasks:**
- [ ] Add `apache-arrow` dependency (verify Apache 2.0 license compatibility)
- [ ] Create `apps/decent-bench/lib/features/export/infrastructure/parquet_exporter.dart`
- [ ] Implement cursor-based page consumption (per SPEC Section 11.3 export execution model)
- [ ] Support schema fingerprint preservation from query contract metadata
- [ ] Add progress indicator during export
- [ ] Wire into Results pane export menu

**ADR Reference:** ADR-0031 (`parquet-excel-export-dependency-strategy.md`) covers dependency strategy

**Acceptance Criteria:**
- Export 100k rows to `.parquet` without UI freeze
- Schema fingerprint preserved in exported file
- Progress indicator shows completion percentage
- Error handling for unsupported types (e.g., spatial EWKB as hex)

---

### 1.2 Excel (.xlsx) Export

**Goal:** Implement Office Open XML writer for `.xlsx` result export with native type metadata preservation where possible.

**Implementation Tasks:**
- [ ] Verify current implementation status (v2.0.0 CHANGELOG mentions "minimal Office Open XML writer")
- [ ] If incomplete: add minimal writer using existing `archive` dependency or new package
- [ ] Implement cursor-based streaming to avoid materializing full result set
- [ ] Preserve DecentDB native type metadata in cell properties where applicable
- [ ] Add progress indicator during export
- [ ] Wire into Results pane export menu

**ADR Reference:** ADR-0031 covers dependency strategy; verify if new ADR needed

**Acceptance Criteria:**
- Export 50k rows to `.xlsx` without UI freeze
- Headers included by default (configurable)
- Native type metadata preserved for supported types
- Error handling for large sheets (>2M rows)

---

### 1.3 Column Reordering in Results Grid

**Goal:** Add drag-and-drop column reordering with persistent state per tab.

**Implementation Tasks:**
- [ ] Implement `ReorderableListView` or custom drag-and-drop widget
- [ ] Store column order in per-tab workspace state JSON (`workspace_state.json`)
- [ ] Add visual indicator (ghost cursor) during drag operation
- [ ] Persist order on drop; restore from config on tab reopen
- [ ] Add "Reset to default" button for quick reset

**Acceptance Criteria:**
- Drag-and-drop reordering works smoothly (60fps)
- Column order persists across app restarts
- Default column order stored in config TOML
- Visual feedback during drag operation

---

## Phase 2: Polish and Testing (Week 3)

### 2.1 Performance Validation

**Tasks:**
- [ ] Benchmark Parquet export with 100k row dataset (<5 seconds)
- [ ] Benchmark Excel export with 50k row dataset (<8 seconds)
- [ ] Verify column reordering doesn't impact scroll performance
- [ ] Add performance tests to `integration_test/`

### 2.2 Edge Case Handling

**Tasks:**
- [ ] Handle unsupported Parquet types (e.g., DecentDB spatial EWKB → hex string)
- [ ] Handle Excel sheet size limits (>1M rows warning)
- [ ] Test with empty result sets for all three features
- [ ] Verify cancellation works during export operations

### 2.3 User Testing

**Tasks:**
- [ ] Gather feedback from 5-10 power users
- [ ] Identify friction points in export workflow
- [ ] Validate column reordering UX matches user mental model

---

## Phase 3: Documentation and Release Prep (Week 4)

### 3.1 User Documentation

**Tasks:**
- [ ] Update `apps/decent-bench/assets/help/importing-data.md` with export formats
- [ ] Add "Export Results" section covering CSV, JSON, NDJSON, Parquet, Excel
- [ ] Document column reordering shortcuts (drag-and-drop only)
- [ ] Add troubleshooting guide for export failures

### 3.2 Developer Documentation

**Tasks:**
- [ ] Update `design/SPEC.md` Section 11.2 to move Parquet/Excel from "Next" to "Implemented"
- [ ] Create ADRs documenting implementation decisions (if not already created)
- [ ] Add code comments for new export infrastructure

### 3.3 Release Artifacts

**Tasks:**
- [ ] Update `CHANGELOG.md` with 2.1.0 release notes
- [ ] Update `pubspec.yaml` version to `2.1.0+X`
- [ ] Run `flutter analyze` and `flutter test --coverage`
- [ ] Build platform-specific binaries (Linux, macOS, Windows)
- [ ] Create GitHub release with changelog and binaries

---

## Implementation Order

**Recommended Sequence:**

1. **Column Reordering** — Lowest risk, quickest implementation, validates drag-and-drop infrastructure
2. **Parquet Export** — Medium complexity, establishes cursor-based streaming pattern for exports
3. **Excel Export** — Medium complexity, can reuse Parquet export infrastructure patterns

**Rationale:** Start with lowest-risk feature to build confidence, then implement larger features in sequence so lessons from earlier work inform later implementation.

---

## Dependencies and Risks

### Dependencies

- **Parquet Export:** `apache-arrow` or equivalent (verify Apache 2.0 license)
- **Excel Export:** May reuse existing `archive` dependency; verify if new package needed
- **Column Reordering:** Flutter's built-in drag-and-drop APIs; no new dependencies

### Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Parquet export memory spike on large results | High | Use cursor-based streaming (per SPEC contract); benchmark before merge |
| Excel writer dependency licensing | Medium | Verify Apache 2.0 compatibility; add to THIRD_PARTY_NOTICES if needed |
| Column reordering degrades scroll performance | Low | Profile during implementation; optimize widget tree if needed |

---

## Success Metrics

- **Parquet Export:** 100k rows exported in <5 seconds without UI freeze
- **Excel Export:** 50k rows exported in <8 seconds without UI freeze
- **Column Reordering:** 60fps during drag operation; zero crashes on rapid column reordering
- **User Satisfaction:** All three features rated "useful" or "very useful" in user testing

---

## ADR References

- **ADR-0031** (`parquet-excel-export-dependency-strategy.md`) — Dependency strategy for Parquet/Excel exports

---

## Out of Scope for 2.1.0

The following features are explicitly out of scope and remain deferred:

- Parquet import (tracked separately in import backlog)
- Excel import improvements beyond current implementation
- Column resizing automation or presets
- Batch export to multiple formats simultaneously
- Export format selection via Command Palette (Phase 3 work)

---

## Notes

This release plan assumes the following are already implemented per v2.0.0 CHANGELOG:

- JSON and NDJSON result export
- Excel `.xlsx` result export (minimal Office Open XML writer)
- Column resizing in results grid
- Schema export (SQL DDL from schema snapshot)

If any of these are incomplete, adjust the plan accordingly by adding them to Phase 1 or deferring.
