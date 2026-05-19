# Schema-First SDK Generation Prototype
**Date:** 2026-05-19
**Status:** Accepted

### Decision

Decent Bench will prototype SDK generation from a stable internal IR built from
the loaded DecentDB schema snapshot, v2.5.x tooling metadata, and saved-query
contracts. The first language target is TypeScript declarations because it is
easy to golden test, broadly useful, and does not require runtime ORM behavior.

The generator IR records:

- table names and columns
- native type descriptors, including enum labels and spatial families
- nullability, generated-column, and primary-key flags
- saved-query parameters and result-column contracts
- schema fingerprints and generation warnings

The first implementation is a domain module, not a UI workflow. A future
headless command should expose the same IR:

```text
dbench generate-sdk --project <workspace.dbench-project.toml> \
  --language typescript --out <directory>
```

The command should load the project manifest, open the referenced DecentDB file,
load the saved-query library, build the same IR, write generated declarations,
and return a non-zero exit code when breaking schema/query changes are detected
against an optional previous manifest.

### Rationale

DecentDB v2.5.x provides the missing metadata surface: deterministic schema
fingerprints, query contracts, and native type metadata. Decent Bench can now
generate application-facing artifacts without guessing from SQL text alone.

Starting with a pure IR and TypeScript declaration output keeps the slice small
and testable. It also avoids prematurely adding a CLI or UI contract before the
generated shape has been exercised.

### Alternatives Considered

**Full ORM generator first**: Rejected. Change tracking, runtime query
execution, migrations, and multi-language runtime packages would create a new
product surface before the metadata mapping is proven.

**Generate from saved-query SQL only**: Rejected. Query text alone cannot
reliably infer native types, nullability, schema drift, or breaking changes.

**Dart first**: Reasonable, but TypeScript declaration output is smaller and
better suited to a first golden-tested prototype.

### Trade-offs

- The first slice generates declarations only; it does not execute queries or
  write a packaged SDK runtime.
- CLI and UI integration remain follow-up work. They must call the same IR
  builder instead of reimplementing metadata mapping.
- Compatibility reporting is intentionally conservative and limited to removed
  tables/columns, type changes, nullability narrowing, removed saved queries,
  and schema-fingerprint drift.

### References

- `design/FUTURE_WINS.md`
- `design/adr/0029-workspace-project-file-and-query-library.md`
- `apps/decent-bench/lib/features/workspace/domain/sdk_generation.dart`
