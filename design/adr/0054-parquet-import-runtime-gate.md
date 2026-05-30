## Parquet Import Runtime Gate
**Date:** 2026-05-23
**Status:** Accepted

### Decision

Decent Bench will not mark Parquet import as planned or implemented until an
Apache-compatible reader/runtime path, packaging plan, streaming behavior, and
logical type policy are accepted.

The Parquet module remains recognized by extension so users receive an explicit
unavailable state, but its backlog status moves to `Investigate`.

### Rationale

The Wave 1 import expansion intentionally shipped formats that can reuse the
existing Dart import, archive, XML, JSON, delimited, and SQL-dump paths. Parquet
does not fit that bounded shape. The current app dependency set does not include
a maintained Parquet reader, and ADR-0051 requires each concrete worker-backed
module to complete dependency review, platform packaging, performance,
cancellation, fixture, and notice work before it can ship.

Adding DuckDB, Python/pyarrow, a Rust FFI bridge, or native Arrow/Parquet
bindings would be a lasting runtime and packaging decision. Shipping that inside
this slice would create product and maintenance scope beyond the completed
Wave 1 adapters.

### Alternatives Considered

- Add DuckDB as the Parquet reader now. Rejected for this slice because DuckDB
  itself is still a separate embedded database import candidate with unresolved
  native packaging and type-mapping decisions.
- Add a Python `pyarrow` worker now. Rejected for this slice because Python
  workers are allowed by ADR-0051 only after concrete dependency, packaging,
  startup, cancellation, fixture, and third-party notice work is complete.
- Implement a minimal Dart Parquet parser in-repo. Rejected because Parquet
  encoding, compression, statistics, page formats, and logical/nested types
  would be high-risk to implement partially.
- Treat Parquet as planned without an implementation path. Rejected because
  planned backlog entries are expected to be implementable once scheduled.

### Trade-offs

- Users cannot import `.parquet` files in this build, but the app reports a
  clear recognized-unavailable result instead of silently failing or shipping an
  unvalidated reader.
- Parquet remains high value, but it no longer blocks smaller import formats
  that have bounded implementations.
- The eventual implementation can choose a reader/runtime deliberately with
  platform packaging and type fidelity tests from the start.

### References

- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`
- `design/WIN_IMPORT_MODULAR_PLAN.md`
- `design/adr/0031-parquet-excel-export-dependency-strategy.md`
- `design/adr/0051-worker-backed-import-module-protocol.md`
