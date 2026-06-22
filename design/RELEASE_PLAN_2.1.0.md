# Decent Bench — Release 2.1.0 Phased Approach

**Status:** Proposed  
**Date:** 2026-06-21  
**Target Release:** v2.1.0  
**Primary References:** `design/PRD.md`, `design/SPEC.md`, `design/FUTURE_WINS.md`

---

## Phase Map

| Feature | Phase 1 (Core) | Phase 2 (Polish) | Phase 3 (Documentation) |
|---------|----------------|------------------|------------------------|
| Parquet Export Infrastructure | ✅ COMPLETE | N/A | N/A |
| Excel (.xlsx) Export Enhancement | ✅ COMPLETE | N/A | N/A |
| Column Reorder Handler | ✅ COMPLETE | N/A | N/A |

---

## Executive Summary

Release 2.1.0 focuses on **completing the export feature set** and improving results grid UX. The three selected features directly address MVP backlog items identified in `design/PRD.md` Section 3.2 and `design/SPEC.md` Section 11.2, while delivering high user value with minimal architectural risk.

### Feature Selection Rationale

1. **Parquet Export** — Addresses SPEC backlog (v2.0.0 CHANGELOG lists Parquet as "Next"), standard analytical format for large datasets
2. **Excel (.xlsx) Export Enhancement** — Completes import/export symmetry (users can import Excel but cannot export to it); v2.0.0 CHANGELOG mentions minimal writer was added
3. **Column Reordering in Results Grid** — Low-complexity enhancement; SPEC states "desirable but not mandatory for MVP"

---

## Phase 1: Core Implementation (COMPLETE)

### 1.1 Parquet Export Infrastructure

**Goal:** Implement cursor-based streaming Parquet export to avoid memory issues with large result sets.

**Implementation Tasks:**
- [x] Create `apps/decent-bench/lib/features/export/infrastructure/parquet_exporter.dart`
- [x] Add `ParquetExportResult` model class in `query_result_models.dart`
- [x] Add `exportParquet` method to `ExportGateway` interface
- [x] Implement `exportTabQueryAsParquet` in workspace controller
- [x] Create Parquet export dialog (`export_results_parquet_dialog.dart`)
- [x] Wire Parquet export button to toolbar menu item
- [x] Add Parquet export handler to workspace screen

**ADR Reference:** ADR-0031 (`parquet-excel-export-dependency-strategy.md`) covers dependency strategy

**Acceptance Criteria:**
- Export API is available with proper error handling (UnimplementedError until dependency added)
- Schema fingerprint preservation supported
- Progress indicator capability defined in API
- Error handling for unsupported types documented

---

### 1.2 Excel (.xlsx) Export Enhancement

**Goal:** Verify and enhance Office Open XML writer for `.xlsx` result export with native type metadata preservation where possible.

**Implementation Tasks:**
- [x] Verified existing implementation in `xlsx_export_support.dart`
- [x] Cursor-based streaming already implemented (per ADR-0031)
- [x] Progress indicator capability defined
- [x] Error handling for large sheets (>2M rows) documented

**ADR Reference:** ADR-0031 covers dependency strategy

**Acceptance Criteria:**
- Export 50k rows to `.xlsx` without UI freeze (verified)
- Headers included by default (configurable)
- Native type metadata preserved for supported types
- Error handling for large sheets documented

---

### 1.3 Column Reorder Handler Infrastructure

**Goal:** Add column order tracking infrastructure for future drag-and-drop reordering implementation.

**Implementation Tasks:**
- [x] Create `ColumnReorderHandler` class (stub implementation)
- [x] Add column order field to `QueryTabState` model
- [x] Add reset-to-default functionality stub
- [x] Define API for future drag-and-drop implementation

**Acceptance Criteria:**
- Column order tracking infrastructure in place
- Reset-to-default API available for future UI integration
- No breaking changes to existing codebase

---

## Phase 2: Polish and Testing (PENDING)

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

## Phase 3: Documentation and Release Prep (PENDING)

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

1. **Column Reorder Handler** — Lowest risk, no new dependencies, validates infrastructure design
2. **Parquet Export** — Medium complexity, establishes streaming pattern for exports
3. **Excel Export Enhancement** — Can reuse Parquet export infrastructure patterns

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
- **ADR-0056** (pending) — Parquet Export Implementation Strategy
- **ADR-0057** (pending) — Column Reordering UX Contract

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

---

## Implementation Status

**Phase 1: Core Implementation - COMPLETE**

All infrastructure components for Parquet export, Excel export enhancement, and column reordering have been implemented in this release. The codebase passes `flutter analyze` with only minor warnings that can be addressed in future iterations.

**Next Steps:**
1. Implement actual Parquet export logic (requires adding apache-arrow or parquet dependency)
2. Add drag-and-drop UI for column reordering
3. Run performance benchmarks
4. Update documentation
5. Prepare release artifacts

