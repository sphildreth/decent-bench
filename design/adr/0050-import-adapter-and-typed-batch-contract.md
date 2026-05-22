## Import Adapter And Typed Batch Contract
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench will route import behavior through reviewed import adapters
referenced by built-in module manifests.

The module manifest declares an adapter id and adapter kind. The application
owns an adapter registry that maps those ids to reviewed implementations. A
manifest may not provide executable code, command lines, dynamic library paths,
or arbitrary entrypoints.

The initial adapter kinds are:

- `none` for unavailable modules,
- `direct_open` for DecentDB files,
- `dart_generic` for current generic import paths,
- `legacy_wizard` for current dedicated Excel, SQLite, and SQL dump paths,
- `wrapper` for archive wrappers,
- `worker` for future reviewed process-backed adapters.

Adapters implement a stable action contract. The exact Dart names may evolve,
but the behavior must include:

- runtime capability reporting,
- bounded source probing,
- schema/source inspection,
- row/table preview,
- full import or selected-table import where supported,
- progress reporting,
- cancellation,
- structured warnings and limitations.

All expensive adapter work runs off the Flutter UI isolate. Preview and import
work must be cancellable, must report progress where possible, and must avoid
unbounded memory growth.

The canonical import handoff is DecentDB typed schema plus typed batches. SQLite
is not a universal staging format. SQLite remains one source adapter for
`.db`, `.sqlite`, and `.sqlite3` inputs.

Typed schema and typed batches must be able to represent:

- source table name and target table name,
- source column name and target column name,
- source physical type where known,
- source logical type where known,
- DecentDB target type,
- nullability,
- precision and scale,
- timezone metadata,
- encoding metadata,
- binary values,
- JSON/nested values where supported,
- table relationships where supported,
- constraints where supported,
- indexes where supported,
- per-column, per-row, and per-cell conversion warnings.

Current generic imports may use a compatibility bridge from existing table
drafts and materialized row maps into typed schema/batch models. That bridge is
temporary compatibility, not the target architecture for high-fidelity formats.

The Decent Bench application remains responsible for writing DecentDB output.
Worker-backed adapters may parse and emit typed batches, but they must not
write directly into the user's DecentDB file unless a future ADR explicitly
changes that boundary.

GUI import and headless import use the same adapter contracts and module
metadata. They must not maintain separate format behavior.

### Rationale

The module manifest catalog solves metadata drift, but parsing and import
behavior still need a controlled execution boundary. A reviewed adapter
registry keeps behavior explicit, testable, and owned by the app.

The typed batch contract is necessary because many future sources carry richer
types than SQLite can faithfully represent. Parquet, Arrow, Avro, ORC,
geospatial sources, data-science files, and database backups can include
decimals, timestamps, timezones, binary values, nested values, logical types,
constraints, or metadata that would be flattened or lost through SQLite.

Keeping DecentDB writing centralized preserves transaction behavior,
rollback/cancellation semantics, progress reporting, type mapping policy, and
future quality/provenance integration.

Using the same contract for GUI and CLI import prevents divergence between
interactive and automated workflows.

### Alternatives Considered

- Continue switching directly on `ImportFormatKey`.
  Rejected because it does not scale to dozens of formats and keeps behavior
  scattered across detection, preview, execution, and UI routing.

- Use SQLite as the universal intermediate for all formats.
  Rejected because SQLite's dynamic type model loses or blurs important source
  type fidelity.

- Let each adapter write DecentDB files directly.
  Rejected because it would duplicate transaction, cancellation, warning,
  provenance, and type-coercion behavior across adapters.

- Make every future parser a Dart implementation.
  Rejected because some high-value formats have stronger ecosystems outside
  Dart. The adapter contract must allow reviewed worker-backed adapters.

- Make every future parser a Python implementation.
  Rejected because simple built-in formats are already implemented in Dart and
  moving all import work to Python would increase packaging, startup, and
  dependency complexity unnecessarily.

- Let manifests define arbitrary import actions.
  Rejected because action execution belongs to reviewed adapters, not metadata
  files.

### Trade-offs

- A typed batch model is more work than row maps, but it is required for broad
  high-fidelity import.
- Central DecentDB writing may require workers to serialize parsed data back to
  the app, but it keeps transaction and safety behavior consistent.
- Existing generic imports need a compatibility bridge during migration. That
  creates temporary complexity, but it allows current behavior to remain stable
  while the module architecture lands.
- Adapter capability reporting adds validation overhead, but it lets the UI
  explain limitations and prevents unsupported actions from appearing.

### References

- `design/WIN_IMPORT_MODULAR_PLAN.md`
- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`
- `apps/decent-bench/lib/features/import/infrastructure/import_preview_service.dart`
- `apps/decent-bench/lib/features/import/infrastructure/import_execution_service.dart`
- `apps/decent-bench/lib/features/import/domain/import_models.dart`
- `design/adr/0049-built-in-import-module-manifest-contract.md`
- `design/adr/0051-worker-backed-import-module-protocol.md`

