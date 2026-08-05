## Parquet Export Implementation Strategy
**Date:** 2026-06-21  
**Status:** Proposed  

### Decision

Implement Parquet export using a streaming cursor-based approach that avoids full result set materialization. Use `apache-arrow` Dart package for Parquet writing, or FFI to Rust `parquet` crate if Apache Arrow licensing review reveals concerns.

### Rationale

Parquet is the standard columnar format for analytical workloads and large datasets. Users importing data into DecentDB from Parquet files (via future Parquet import) should also be able to export shaped results back to Parquet format, completing the round-trip workflow.

The streaming cursor-based approach follows the existing export execution model (SPEC Section 11.3):
- Consume query pages incrementally via `queryNext(cursor, pageSize)`
- Write batches to temporary file
- Finalize Parquet file on completion
- No full result set materialization in memory

### Implementation Approach

**Option A: Apache Arrow Dart Package** (Preferred)
- Use `apache_arrow` or `parquet` Dart package
- Verify Apache 2.0 license compatibility
- Leverage existing streaming cursor contract
- Implement in `apps/decent-bench/lib/features/export/infrastructure/parquet_exporter.dart`

**Option B: Rust FFI** (Fallback)
- Use Rust `parquet` crate through FFI
- Requires native toolchain on Linux/macOS
- More complex packaging but mature implementation
- Only if Apache Arrow Dart package proves insufficient

### Parquet Export Contract

The export must support:
- Cursor-based incremental page consumption
- Schema fingerprint preservation from query contract metadata
- Progress indicator during export
- Error handling for unsupported types (e.g., spatial EWKB → hex string fallback)
- Streaming behavior without full materialization

### Acceptance Criteria

1. Export 100k rows to `.parquet` in <5 seconds on typical dev hardware
2. Schema fingerprint preserved in exported file metadata
3. Progress indicator shows completion percentage or estimated time remaining
4. Error handling for unsupported types (e.g., spatial EWKB → hex string)
5. No UI freeze during export operation

### Out of Scope

- Parquet import (tracked separately in import backlog)
- Parquet schema evolution handling
- Parquet compression level configuration
- Parquet row group size configuration

### Trade-offs

| Aspect | Benefit | Cost |
|--------|---------|------|
| Streaming cursor-based export | Memory-efficient for large results | Slightly more complex implementation |
| Apache Arrow Dart package | Pure Dart, simpler packaging | May require native dependencies |
| Rust FFI fallback | Mature implementation | Requires native toolchain, complex packaging |

### References

- ADR-0031 Parquet and Excel Export Dependency Strategy
- ADR-0002 Results Paging and Streaming Contract
- `design/SPEC.md` Section 11.3 Export execution model
- `apps/decent-bench/lib/features/workspace/infrastructure/xlsx_export_support.dart` (Excel export reference)
