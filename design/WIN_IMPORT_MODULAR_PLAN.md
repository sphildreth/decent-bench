# Future Win Plan: Modular Import Architecture And Module Catalog

**Status:** Planning document
**Last reviewed:** 2026-05-22
**Source roadmap item:** `design/FUTURE_WINS.md` rank 1, `P0`
**Target outcome:** Convert the current import registry and import-specific
wizard routing into a module-based import architecture that can support dozens
of present and future formats without hardcoded scattered format knowledge.

## Purpose

Decent Bench is expected to grow into a broad import front door for DecentDB.
The current import system already recognizes many file families and implements
several useful import paths, but format knowledge is still concentrated in Dart
enums, registry objects, switch statements, help text, and separate planning
documents.

That approach works while the format list is small. It will not scale cleanly
as the product adds Parquet, ODS, DuckDB, fixed-width text, geospatial sources,
data science formats, legacy business databases, compressed wrappers, log
templates, healthcare formats, finance formats, and user-requested niche
sources.

This plan defines the full slice-by-slice path for making importing
module-based.

The core idea is:

```text
import module = declarative manifest + documentation + fixtures + reviewed adapter
```

Each import format receives a module directory. The module contains a TOML
manifest that describes the format, its detection rules, capabilities,
documentation metadata, quality checks, import actions, fixtures, and adapter
binding. The manifest does not execute arbitrary code. Import execution remains
behind reviewed Dart adapters or reviewed worker-process adapters that implement
a typed contract owned by Decent Bench.

This architecture is a prerequisite for the long-term import-format expansion
plan in `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`.

## Product Goal

Users should experience one coherent import system regardless of source
format:

1. Drag or pick a source file.
2. Decent Bench detects the best matching import module.
3. The wizard explains what the module can do.
4. The module inspects the source off the UI thread.
5. The user previews tables, columns, types, warnings, and unsupported
   capabilities.
6. The user adjusts names, types, transforms, and module-specific options.
7. The import runs with progress, cancellation, rollback, and clear summaries.
8. The result lands as typed DecentDB tables without using SQLite as a universal
   staging layer.
9. Import metadata, documentation, and tests stay synchronized because they are
   driven from the same module catalog.

## Definition Of 100% Complete

This Future Win is complete only when all of these are true:

- A first-class import module catalog exists in the repository.
- Every currently supported import/open format has a built-in module:
  - DecentDB `.ddb` open path,
  - CSV,
  - TSV,
  - generic delimited text,
  - JSON,
  - NDJSON / JSONL,
  - XML,
  - HTML tables,
  - Excel `.xlsx`,
  - legacy Excel `.xls`,
  - SQLite,
  - SQL dump,
  - ZIP wrapper,
  - GZip / Tar+GZip wrapper,
  - BZip2 / Tar+BZip2 wrapper.
- Every currently recognized unavailable format has a built-in planned,
  investigate, deferred, or candidate module:
  - fixed-width text,
  - ODS,
  - YAML,
  - TOML,
  - Markdown tables,
  - DuckDB,
  - Access,
  - DBF / FoxPro,
  - SQL Server backup,
  - PostgreSQL plain SQL dump expansion,
  - Parquet,
  - JSON log stream,
  - delimited log templates,
  - XZ wrapper,
  - clipboard table capture,
  - PDF tables,
  - all future candidates accepted from `docs/IMPORT_FORMATS.md`.
- `ImportFormatRegistry` is generated from or loaded from module manifests
  rather than being the hand-maintained source of truth for format metadata.
- Drag-and-drop, file picker, headless import, archive candidate detection, and
  help/documentation surfaces all read from the same module catalog.
- The module manifest schema is versioned and validated.
- Module manifests are declarative. They cannot run shell commands, import
  libraries, or execute scripts.
- Import behavior is provided by reviewed adapters implementing a stable Dart
  interface or reviewed worker protocol.
- The module system distinguishes source adapters, wrapper adapters, preview
  adapters, import adapters, and future validation/check contributors.
- SQLite is treated as one source module, not as the canonical staging or
  interchange layer for other formats.
- The canonical import handoff model is DecentDB typed schema plus typed
  preview/import batches.
- Built-in module documentation can be validated against
  `docs/IMPORT_FORMATS.md` and bundled Help Center pages.
- Every module has declared fixtures or an explicit reason fixtures are not
  applicable.
- Tests prove module loading, manifest validation, detection, routing, adapter
  dispatch, docs synchronization, and backward compatibility.

## Non-Goals

Do not implement these as part of this Future Win:

- Third-party plugin marketplace.
- Untrusted external module loading.
- Runtime installation of arbitrary parser packages.
- User-authored executable import scripts.
- Live external database browsing or administration.
- A generic ODBC/JDBC source layer.
- Replacing DecentDB as the destination.
- Using SQLite as a universal import staging database.
- Implementing new file formats beyond converting existing support and
  recognized unavailable formats into modules.

Future external modules, extension marketplaces, and scripting bridges require
separate PRD/SPEC alignment and ADRs.

## Required ADRs Before Implementation

This document is a plan. Implementation must not begin unless the accepted ADRs
below still cover the lasting architectural decisions for the slice being
implemented.

### ADR-0049: Built-In Import Module Manifest Contract

**ADR:** `design/adr/0049-built-in-import-module-manifest-contract.md`

Required decision points:

- Module manifests are TOML.
- Module manifests are declarative metadata only.
- Built-in module manifests are bundled with the app.
- The manifest schema is versioned.
- The module catalog, not ad hoc registry lists, is the source of truth for
  format metadata.
- Runtime catalog packaging uses generated Dart constants derived from TOML.
- Manifest loading and generation failure behavior is fail-fast in debug/tests,
  with release builds produced only from a validated generated catalog.

### ADR-0050: Import Adapter And Typed Batch Contract

**ADR:** `design/adr/0050-import-adapter-and-typed-batch-contract.md`

Required decision points:

- DecentDB typed schema and typed batches are the canonical import handoff.
- SQLite is not a universal staging layer.
- Adapters implement stable actions such as detect, inspect, preview, import,
  cancel, and explain warnings.
- Dart-native adapters and worker-backed adapters are both allowed behind the
  same contract.
- All large import work remains off the UI thread.
- Preview and import flows must support progress, cancellation, and bounded
  memory.

### ADR-0051: Worker-Backed Import Module Protocol

**ADR:** `design/adr/0051-worker-backed-import-module-protocol.md`

Required only before the first non-Dart worker module ships.

Required decision points:

- Supported worker runtimes.
- Process launch and cancellation model.
- IPC protocol.
- Typed batch serialization format.
- Error, progress, and warning envelopes.
- Dependency packaging and license review.
- Security model for bundled workers.

### ADR-0052: External Import Module Trust Boundary

**ADR:** `design/adr/0052-external-import-module-trust-boundary.md`

Required only before third-party modules are loaded from outside the app
bundle.

Required decision points:

- Whether external modules are supported at all.
- Manifest signing or trust prompts.
- Sandboxing limits.
- Dependency installation policy.
- User-visible trust and disable flows.
- Compatibility versioning.

## Current Import Architecture Baseline

This plan starts from the current code layout.

### Primary Files

| File | Current Role |
|---|---|
| `apps/decent-bench/lib/features/import/domain/import_models.dart` | Defines import families, support states, implementation kinds, format keys, generic import request/result models, table drafts, column drafts, options, and summaries. |
| `apps/decent-bench/lib/features/import/infrastructure/import_format_registry.dart` | Hardcoded source of truth for format definitions, extensions, support state, family, implementation kind, labels, descriptions, and basic path detection. |
| `apps/decent-bench/lib/features/import/infrastructure/import_detection_service.dart` | Uses the registry to detect source paths, warn on suspicious SQLite files, inspect ZIP/GZip/BZip2 wrappers, and build archive candidates. |
| `apps/decent-bench/lib/features/import/infrastructure/import_preview_service.dart` | Switches over generic import format keys and runs preview inspection in an isolate. |
| `apps/decent-bench/lib/features/import/infrastructure/import_execution_service.dart` | Switches over generic import format keys, materializes supported generic sources, writes DecentDB tables in a background isolate, and reports progress. |
| `apps/decent-bench/lib/features/import/infrastructure/delimited_import_support.dart` | Implements delimited source inspection/materialization. |
| `apps/decent-bench/lib/features/import/infrastructure/structured_import_support.dart` | Implements JSON, NDJSON, and XML inspection/materialization. |
| `apps/decent-bench/lib/features/import/infrastructure/html_import_support.dart` | Implements HTML table inspection/materialization. |
| `apps/decent-bench/lib/features/import/presentation/generic_import_dialog.dart` | Generic import wizard for the current generic pipeline. |
| `apps/decent-bench/lib/features/import/presentation/import_archive_chooser_dialog.dart` | Archive candidate selection UI. |

### Current Strengths

- Format detection already has a single registry entry point.
- Support state is already modeled.
- Generic imports already share preview, transforms, execution, progress,
  cancellation, and DecentDB writing.
- Dedicated legacy paths exist for Excel, SQLite, and SQL dumps.
- Archive wrappers already route supported inner files into normal import
  flows.
- The code already separates domain models, infrastructure, and presentation.

### Current Limitations

- The registry is hardcoded Dart data.
- Format metadata is duplicated in docs and help text.
- Adding a format requires editing enums, registry entries, detection logic,
  preview switches, execution switches, wizard routing, tests, docs, and help.
- Unsupported future formats are not represented as full product modules with
  fixtures, capability declarations, and documentation.
- Adapter capabilities are implied by implementation kind instead of declared
  explicitly.
- Current generic preview/execution can materialize rows for some formats,
  which is not enough for very large future formats.
- There is no stable contract for Python or other worker-backed importers.
- There is no module-level place to declare default validation checks, type
  fidelity warnings, fixture expectations, or format-specific docs.

## Target Repository Layout

Add a first-class module catalog under the app package:

```text
apps/decent-bench/import_modules/
  README.md
  schema/
    import_module_manifest.schema.md
    import_module_manifest.example.toml
  builtin/
    decentdb/
      module.toml
      README.md
      fixtures/
    csv/
      module.toml
      README.md
      fixtures/
    tsv/
      module.toml
      README.md
      fixtures/
    generic_delimited/
      module.toml
      README.md
      fixtures/
    json/
      module.toml
      README.md
      fixtures/
    ndjson/
      module.toml
      README.md
      fixtures/
    xml/
      module.toml
      README.md
      fixtures/
    html_table/
      module.toml
      README.md
      fixtures/
    xlsx/
      module.toml
      README.md
      fixtures/
    xls/
      module.toml
      README.md
      fixtures/
    sqlite/
      module.toml
      README.md
      fixtures/
    sql_dump/
      module.toml
      README.md
      fixtures/
    zip_archive/
      module.toml
      README.md
      fixtures/
    gzip_archive/
      module.toml
      README.md
      fixtures/
    bzip2_archive/
      module.toml
      README.md
      fixtures/
    parquet/
      module.toml
      README.md
      fixtures/
    ods/
      module.toml
      README.md
      fixtures/
    fixed_width/
      module.toml
      README.md
      fixtures/
```

Use `apps/decent-bench/import_modules/builtin/` for all built-in modules,
including planned and deferred formats. Do not add `external/` until the
external module trust boundary is updated or superseded by a future accepted
ADR. ADR-0052 explicitly excludes external modules from this Future Win.

## Target Code Layout

Add module-domain code without deleting existing import code in the first
slices:

```text
apps/decent-bench/lib/features/import_modules/
  domain/
    import_module_manifest.dart
    import_module_capabilities.dart
    import_module_detection.dart
    import_module_actions.dart
    import_module_validation.dart
  infrastructure/
    import_module_catalog.dart
    import_module_manifest_loader.dart
    import_module_manifest_validator.dart
    import_module_asset_bundle_loader.dart
    import_module_registry_adapter.dart
  application/
    import_module_router.dart
    import_module_action_dispatcher.dart
  test_support/
    import_module_fixture_loader.dart
```

Keep current import implementation files under
`apps/decent-bench/lib/features/import/` until the module system is fully
adopted. Do not move all existing import code at once. The initial goal is to
make modules drive metadata and routing while preserving current behavior.

## Module Manifest Contract

Each module must have one `module.toml`.

The manifest is declarative. Values name capabilities and adapter ids. Values
must not contain executable code, shell fragments, inline scripts, SQL to run
against arbitrary user files, or dynamic library paths.

### Required Top-Level Fields

```toml
schema_version = 1
id = "parquet"
kind = "source"
status = "planned"
priority = "P1"
name = "Apache Parquet"
family = "analytical"
summary = "Columnar analytics file format with logical type metadata."
description = """
Imports Parquet files into typed DecentDB tables while preserving logical type
metadata where supported by the accepted adapter.
"""
```

Required field definitions:

| Field | Type | Required | Rules |
|---|---|---:|---|
| `schema_version` | integer | yes | Must be `1` for the first implementation. |
| `id` | string | yes | Lowercase snake_case. Stable forever after release. |
| `kind` | enum | yes | `source`, `wrapper`, `direct_open`, `template`, or `profile`. |
| `status` | enum | yes | `complete`, `partial`, `planned`, `investigate`, `deferred`, `candidate`, `not_started`. |
| `priority` | enum | yes | `P0`, `P1`, `P2`, `P3`, `P4`, or `none`. |
| `name` | string | yes | User-visible name. |
| `family` | enum | yes | Maps to import family values listed below. |
| `summary` | string | yes | One sentence, shown in lists. |
| `description` | string | yes | Longer help text. |

Allowed `family` values:

- `decentdb`
- `delimited_text`
- `spreadsheet`
- `structured_document`
- `database`
- `database_dump`
- `analytical`
- `legacy_business`
- `web_markup`
- `compressed_archive`
- `logs_events`
- `geospatial`
- `data_science`
- `finance`
- `healthcare`
- `calendar_contacts`
- `data_lake`
- `other`

### Detection Section

```toml
[detection]
extensions = [".parquet"]
mime_types = ["application/vnd.apache.parquet"]
filename_patterns = []
magic_numbers = []
priority = 80
```

Rules:

- `extensions` must include the leading dot and lowercase value.
- `mime_types` are advisory only until platform file pickers expose them
  consistently.
- `filename_patterns` must be simple glob-like patterns, not regular
  expressions, in the first implementation.
- `magic_numbers` must use documented byte-prefix syntax only after the
  manifest validator supports it.
- `priority` breaks ties when multiple modules match a source.
- Detection must never read full files on the UI thread.

### Support Section

```toml
[support]
implementation = "recognized_unsupported"
availability = "builtin"
min_app_version = "0.0.0"
requires_dependency_review = true
requires_adr = true
```

Allowed `implementation` values:

- `direct_open`
- `generic_wizard`
- `dedicated_wizard`
- `wrapper`
- `recognized_unsupported`
- `worker_backed`
- `unknown`

Rules:

- `status = "complete"` requires an implementation other than
  `recognized_unsupported` or `unknown`.
- `status = "partial"` requires a `limitations` section.
- `worker_backed` must follow ADR-0051.
- `requires_dependency_review = true` means implementation cannot be marked
  complete until dependency/license review is documented.

### Capabilities Section

```toml
[capabilities]
detect_by_extension = true
detect_by_signature = false
inspect_schema = true
preview_rows = true
import_full = true
import_selected_tables = false
supports_multiple_tables = false
supports_archives = false
supports_streaming_preview = true
supports_streaming_import = true
supports_cancellation = true
supports_rejected_rows = true
preserves_logical_types = true
preserves_constraints = false
preserves_indexes = false
preserves_relationships = false
can_export_recipe = true
```

Rules:

- Capabilities describe what the module intends to support.
- Runtime adapters must report actual capabilities during inspection.
- If a runtime adapter reports less than the manifest, the UI must show a
  warning and use the runtime capability.
- If a runtime adapter reports more than the manifest, tests must fail until
  the manifest is updated.

### Adapter Section

```toml
[adapter]
id = "parquet_worker"
kind = "worker"
protocol = "typed_batch_v1"
entrypoint = "decent_bench_parquet_worker"
```

Allowed `kind` values:

- `none`
- `dart_builtin`
- `dart_generic`
- `legacy_wizard`
- `worker`
- `wrapper`

Rules:

- `none` is allowed only for unavailable modules.
- `dart_builtin` maps to a reviewed Dart adapter id.
- `dart_generic` maps to the existing generic import pipeline.
- `legacy_wizard` maps to current dedicated import paths during migration.
- `worker` must follow ADR-0051.
- `entrypoint` is an identifier, not a path, command, or script.

### Actions Section

```toml
[[actions]]
id = "inspect_schema"
label = "Inspect Schema"
required = true

[[actions]]
id = "preview_rows"
label = "Preview Rows"
required = true

[[actions]]
id = "import_full"
label = "Import"
required = true
```

Allowed action ids for the first implementation:

- `detect`
- `inspect_schema`
- `preview_rows`
- `import_full`
- `import_selected_tables`
- `list_archive_entries`
- `extract_archive_entry`
- `open_existing_workspace`
- `explain_limitations`

Rules:

- Actions are names dispatched by Decent Bench code.
- Actions are not scripts.
- Every `status = "complete"` source module must provide `inspect_schema`,
  `preview_rows`, and `import_full`, except `direct_open` modules.
- Every wrapper module must provide `list_archive_entries` and
  `extract_archive_entry`.

### Options Section

```toml
[[options]]
id = "header_row"
label = "Header Row"
type = "boolean"
default = true
required = true

[[options]]
id = "delimiter"
label = "Delimiter"
type = "string"
default = ","
required = true
```

Allowed option types for the first implementation:

- `boolean`
- `integer`
- `string`
- `enum`
- `string_list`

Rules:

- Options describe user-configurable module behavior.
- Options must be serializable for future import recipes.
- Option ids are lowercase snake_case.
- Defaults must be explicit when `required = true`.
- Options must not contain callbacks or code.

### Type Mapping Section

```toml
[[type_mappings]]
source_type = "decimal"
target_type = "DECIMAL"
fidelity = "exact"
notes = "Preserve precision and scale when available from source metadata."

[[type_mappings]]
source_type = "timestamp_millis_utc"
target_type = "TIMESTAMP"
fidelity = "lossless_with_timezone_note"
notes = "Store UTC value and preserve original logical metadata in import provenance."
```

Allowed `fidelity` values:

- `exact`
- `lossless_with_metadata`
- `lossless_with_timezone_note`
- `coerced`
- `stringified`
- `unsupported`

Rules:

- Complete modules must declare the important source types they preserve,
  coerce, stringify, or reject.
- Source modules with no native type system may declare inferred source types.
- Type mapping docs must be shown in module help.

### Checks Section

```toml
[[checks]]
id = "parquet.logical_type_fidelity"
name = "Logical Type Fidelity"
description = "Warn when source logical types cannot be represented exactly."
default_enabled = true
severity = "warning"
quality_profile = "default_import_quality"
```

Rules:

- Checks declare module-specific quality checks.
- Check execution is owned by the Data Quality, Profiling, and Validation Suite.
- Checks may be inactive until that suite is implemented.
- Checks must never run arbitrary module-provided code.

### Limitations Section

```toml
[[limitations]]
id = "xls.conversion_required"
severity = "warning"
message = "Legacy .xls support depends on the installed conversion path."
```

Rules:

- `status = "partial"` requires at least one limitation.
- Deferred modules should explain why they are deferred.
- Limitations must be user-readable and testable.

### Documentation Section

```toml
[documentation]
help_topic = "importing-parquet"
format_docs = "README.md"
fixture_notes = "fixtures/README.md"
```

Rules:

- `format_docs` must point to the module-local `README.md`.
- Help topic ids must be stable.
- The docs sync test must verify that complete and partial modules are visible
  in user documentation.

### Fixtures Section

```toml
[[fixtures]]
id = "basic"
path = "fixtures/basic.parquet"
purpose = "Single-table import with primitive logical types."
expected_tables = ["basic"]
expected_warnings = []
```

Rules:

- Complete modules should have at least one fixture.
- Planned/investigate modules may include placeholder fixture notes without
  binary files.
- Large binary fixtures should be avoided unless the repo already accepts them.
- If a fixture cannot be checked in, the module README must document how to
  generate it deterministically.

## Example Complete Module Manifest

CSV after conversion should look like this:

```toml
schema_version = 1
id = "csv"
kind = "source"
status = "complete"
priority = "P0"
name = "CSV"
family = "delimited_text"
summary = "Comma-separated text import."
description = """
Imports comma-separated text files through the generic import wizard with
header detection, preview, type inference, transforms, progress, cancellation,
and DecentDB table creation.
"""

[detection]
extensions = [".csv"]
mime_types = ["text/csv"]
filename_patterns = []
magic_numbers = []
priority = 100

[support]
implementation = "generic_wizard"
availability = "builtin"
min_app_version = "0.0.0"
requires_dependency_review = false
requires_adr = false

[capabilities]
detect_by_extension = true
detect_by_signature = false
inspect_schema = true
preview_rows = true
import_full = true
import_selected_tables = false
supports_multiple_tables = false
supports_archives = false
supports_streaming_preview = false
supports_streaming_import = false
supports_cancellation = true
supports_rejected_rows = true
preserves_logical_types = false
preserves_constraints = false
preserves_indexes = false
preserves_relationships = false
can_export_recipe = true

[adapter]
id = "generic_delimited"
kind = "dart_generic"
protocol = "dart_import_adapter_v1"

[[actions]]
id = "inspect_schema"
label = "Inspect Source"
required = true

[[actions]]
id = "preview_rows"
label = "Preview Rows"
required = true

[[actions]]
id = "import_full"
label = "Import"
required = true

[[options]]
id = "header_row"
label = "Header Row"
type = "boolean"
default = true
required = true

[[options]]
id = "delimiter"
label = "Delimiter"
type = "string"
default = ","
required = true

[[type_mappings]]
source_type = "text"
target_type = "TEXT"
fidelity = "coerced"
notes = "Delimited files do not carry native column types; target types are inferred from samples and can be overridden."

[documentation]
help_topic = "importing-data"
format_docs = "README.md"
fixture_notes = "fixtures/README.md"

[[fixtures]]
id = "basic"
path = "fixtures/basic.csv"
purpose = "Headers, simple scalar values, and inferred numeric columns."
expected_tables = ["basic"]
expected_warnings = []
```

## Adapter Contract

All import behavior must be accessed through an adapter contract. This contract
can wrap existing Dart code in early slices.

### Required Adapter Interface

The Dart contract should be conceptually equivalent to:

```dart
abstract interface class ImportModuleAdapter {
  String get adapterId;

  Future<ImportModuleRuntimeCapabilities> runtimeCapabilities(
    ImportModuleContext context,
  );

  Future<ImportModuleDetectionProbe> probe(
    ImportModuleProbeRequest request,
  );

  Future<ImportModuleInspection> inspect(
    ImportModuleInspectRequest request,
  );

  Stream<ImportModulePreviewUpdate> preview(
    ImportModulePreviewRequest request,
  );

  Stream<ImportModuleImportUpdate> import(
    ImportModuleImportRequest request,
  );

  Future<void> cancel(String jobId);
}
```

Implementation detail names may differ, but the behavior must not.

### Import Module Context

Every adapter call receives context:

| Field | Required | Meaning |
|---|---:|---|
| `moduleId` | yes | Stable module id from the manifest. |
| `moduleVersion` | yes | Manifest schema version plus module revision if added. |
| `sourceUri` | yes | Local file path or explicit source identifier. |
| `workspaceId` | no | Open workspace id when available. |
| `targetPath` | no | Target DecentDB path for import actions. |
| `jobId` | yes for long work | Stable id for progress and cancellation. |
| `options` | yes | Validated module options. |
| `capabilities` | yes | Manifest capabilities plus runtime override. |

### Inspection Result

Inspection must return:

- detected source identity,
- source fingerprint when safe and feasible,
- module id,
- runtime capabilities,
- table drafts,
- column drafts,
- source type metadata,
- recommended target DecentDB types,
- preview sample rows,
- warnings,
- limitations,
- estimated row counts when available,
- whether estimates are exact or approximate.

### Import Result

Import updates must include:

- job id,
- module id,
- source path,
- target path,
- phase,
- current table,
- completed table count,
- total table count if known,
- current rows copied,
- total rows copied,
- warnings,
- rejected row count,
- rollback state,
- cancellation state,
- final summary.

### Typed Batch Requirement

The canonical adapter handoff must be typed DecentDB data, not SQLite.

For current generic imports, existing row maps may be wrapped temporarily. For
future high-fidelity sources, the adapter contract must support typed columnar
or row batches with:

- DecentDB target type,
- source type,
- source logical type,
- nullability,
- precision and scale where available,
- timezone metadata where available,
- binary values,
- JSON/nested values where supported,
- source column name,
- target column name,
- per-cell or per-row conversion warnings.

The typed batch contract is governed by ADR-0050. Worker-backed batch
serialization is governed by ADR-0051.

## Module Catalog Behavior

### Loading

The module catalog loader must:

1. Discover all `module.toml` files under
   `apps/decent-bench/import_modules/builtin/`.
2. Parse each file as TOML.
3. Validate required fields.
4. Validate enum values.
5. Validate id uniqueness.
6. Validate extension uniqueness unless an explicit conflict rule exists.
7. Validate adapter references.
8. Validate fixture references.
9. Produce an immutable `ImportModuleCatalog`.

### Runtime Packaging

The first implementation may load manifests from source files during
development and tests. Production builds must bundle the same manifests as
Flutter assets or generated Dart constants. Pick one packaging method in the
ADR and use it consistently.

### Compatibility

The catalog must expose a compatibility layer that can produce the existing
`ImportFormatDefinition` values until all call sites consume modules directly.

This layer must be named explicitly, for example:

```text
ImportModuleRegistryAdapter
```

Do not keep two independent sources of truth.

## Detection Behavior

Detection should move from extension-only registry lookup to module-driven
matching.

Required detection order:

1. Exact extension match.
2. Compound extension match such as `.tar.gz`, `.tar.bz2`, `.tar.xz`.
3. Filename pattern match.
4. Signature/magic-number match when supported.
5. Wrapper inner-file detection.
6. Unknown source fallback.

Rules:

- Detection must be bounded.
- Signature checks may read only the required leading bytes.
- Archive detection must not extract full archives just to identify candidates.
- Detection warnings must identify ambiguous or suspicious matches.
- Unknown files should still show helpful recognized-but-unavailable suggestions
  when possible.

## Documentation Behavior

The module catalog should become the source for import-format documentation
metadata.

Required documentation updates:

- `docs/IMPORT_FORMATS.md` must say the module catalog is the source of truth
  once conversion is complete.
- Complete and partial modules must appear in "Fully implemented now" or
  "Partial support now".
- Planned, investigate, deferred, and candidate modules must appear in the
  future-format table.
- Bundled Help Center importing docs must list complete and partial modules.
- Module README files must explain:
  - what the source format is,
  - supported extensions,
  - current status,
  - capabilities,
  - limitations,
  - type fidelity notes,
  - fixture coverage,
  - known unsupported cases.
- Documentation tests must fail when a complete or partial module is missing
  from user-visible docs.

Do not hand-maintain contradictory format lists after the catalog conversion is
complete.

## Relationship To Data Quality

The module plan and data quality plan should integrate, but neither should
block the other entirely.

Module manifests may declare checks such as:

- type fidelity warnings,
- source row count reconciliation,
- required field detection,
- constraint preservation gaps,
- duplicate detection hints,
- malformed source row checks,
- archive extraction warnings.

Execution of checks belongs to
`design/WIN_DATA_QUALITY_PROFILING_VALIDATION_PLAN.md`.

Rules:

- Module checks are declarations.
- The quality engine owns execution and result storage.
- If the quality suite is not implemented yet, module checks appear as inactive
  future capabilities.
- Import summaries may still surface adapter warnings before the quality suite
  exists.

## Relationship To Import Format Expansion

`design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md` should not be implemented as a
collection of one-off code paths. New formats should first receive module
manifests, fixture plans, type-fidelity notes, and adapter contracts.

After this Future Win is complete, adding a new format should require:

1. Add or promote a module manifest.
2. Add module docs.
3. Add fixtures.
4. Implement or bind the adapter.
5. Add adapter tests.
6. Add docs sync tests.
7. Update support status from `planned` or `investigate` to `complete` or
   `partial`.

## Slice Plan

The slices below are sequencing boundaries. The Future Win is not complete
until all slices are implemented, tested, and documented.

### Slice 0: ADRs And SPEC Alignment

**Goal:** Record the durable architecture decisions before code changes.

Implementation tasks:

1. Verify ADR-0049 still matches the planned built-in module manifest contract.
2. Verify ADR-0050 still matches the planned import adapter and typed batch
   contract.
3. Verify ADR-0051 still matches any planned worker-backed import work.
4. Verify ADR-0052 still excludes external third-party modules.
5. Update or supersede any ADR that no longer matches the implementation
   slice.
6. Update `design/SPEC.md` import sections to reference module-driven import
   routing without changing current MVP behavior.
7. Update `design/PRD.md` only if product scope language needs to describe
   modules as an internal architecture. Do not expose modules as user plugins.
8. Confirm that external module loading remains out of scope.

Acceptance criteria:

- ADR-0049, ADR-0050, ADR-0051, and ADR-0052 are accepted or have accepted
  superseding ADRs.
- SPEC references module-driven import routing.
- Existing supported import formats remain unchanged.
- No code implementation starts before the ADRs are accepted.

Tests:

- Documentation-only slice. Run `git diff --check`.

### Slice 1: Module Manifest Schema And Example

**Goal:** Define the manifest schema and example before converting formats.

Implementation tasks:

1. Create `apps/decent-bench/import_modules/README.md`.
2. Create `apps/decent-bench/import_modules/schema/import_module_manifest.schema.md`.
3. Create `apps/decent-bench/import_modules/schema/import_module_manifest.example.toml`.
4. Document every field listed in this plan.
5. Document every enum and validation rule.
6. Document that manifests are declarative and cannot execute code.
7. Document that SQLite is a source module only, not universal staging.

Acceptance criteria:

- A coding agent can create a valid module manifest using only the schema doc.
- The schema doc matches this plan.
- The example manifest uses only supported fields.

Tests:

- `git diff --check`
- Markdown link check if the repo has one.

### Slice 2: Domain Models And Manifest Parser

**Goal:** Add typed Dart models for module manifests.

Implementation tasks:

1. Add `ImportModuleManifest`.
2. Add `ImportModuleKind`.
3. Add `ImportModuleStatus`.
4. Add `ImportModulePriority`.
5. Add `ImportModuleFamily`.
6. Add `ImportModuleDetection`.
7. Add `ImportModuleSupport`.
8. Add `ImportModuleCapabilities`.
9. Add `ImportModuleAdapterRef`.
10. Add `ImportModuleAction`.
11. Add `ImportModuleOption`.
12. Add `ImportModuleTypeMapping`.
13. Add `ImportModuleCheck`.
14. Add `ImportModuleLimitation`.
15. Add `ImportModuleDocumentation`.
16. Add `ImportModuleFixture`.
17. Add TOML parsing using the repository's existing TOML dependency or add an
    ADR/dependency review before adding a new dependency.
18. Add strict unknown-field validation as required by ADR-0049.

Acceptance criteria:

- Valid example manifests parse into typed models.
- Invalid enum values fail validation.
- Missing required fields fail validation.
- Duplicate option ids fail validation.
- Duplicate action ids fail validation.
- Invalid extension casing fails validation.
- Unsupported schema versions fail validation.

Tests:

- Unit tests for every manifest model.
- Unit tests for successful parsing.
- Unit tests for validation failures.
- Unit tests for unknown fields.
- Unit tests for unsupported schema version.

### Slice 3: Built-In Module Catalog Loader

**Goal:** Load all built-in module manifests into one immutable catalog.

Implementation tasks:

1. Add `ImportModuleCatalog`.
2. Add `ImportModuleManifestLoader`.
3. Add `ImportModuleManifestValidator`.
4. Add local file loading for tests and development.
5. Add generated-code loading for app runtime as required by ADR-0049.
6. Validate module id uniqueness.
7. Validate extension uniqueness.
8. Validate adapter id references against a known adapter registry.
9. Validate fixture paths.
10. Sort modules deterministically by priority, family, and name.
11. Provide catalog lookup by module id.
12. Provide catalog lookup by extension.
13. Provide catalog lookup by family.
14. Provide catalog lookup by status.

Acceptance criteria:

- Loading the built-in catalog returns every module.
- Duplicate module ids fail.
- Duplicate extensions fail unless explicitly allowed by the ADR.
- Missing adapter references fail for complete modules.
- Planned/deferred modules can use `adapter.kind = "none"`.

Tests:

- Catalog happy-path test.
- Duplicate id test.
- Duplicate extension test.
- Missing adapter test.
- Deterministic sort test.
- Runtime asset loading test if asset packaging is used.

### Slice 4: Convert Current Registry Metadata To Modules

**Goal:** Add module manifests for all current registry entries without changing
runtime behavior.

Implementation tasks:

1. Create module directories for every current `ImportFormatKey`.
2. Add `module.toml` for every current format.
3. Add module README for every current format.
4. Add minimal fixture notes for every current format.
5. Preserve the current support state exactly:
   - `complete`,
   - `partial`,
   - `planned`,
   - `investigate`,
   - `deferred`,
   - `not_started`.
6. Preserve current labels and descriptions unless docs are clearly stale.
7. Declare current implementation paths:
   - DecentDB uses `direct_open`.
   - CSV/TSV/generic delimited use `dart_generic`.
   - JSON/NDJSON/XML use `dart_generic`.
   - HTML tables use `dart_generic`.
   - Excel/SQLite/SQL dump use `legacy_wizard`.
   - ZIP/GZip/BZip2 use `wrapper`.
   - unavailable modules use `none`.
8. Add `type_mappings` where current type inference behavior is known.
9. Add `limitations` for partial `.xls` support.
10. Add `limitations` for deferred formats such as PDF and TOML.

Acceptance criteria:

- There is a module for every current registry key.
- Current user-visible labels remain stable.
- Current support state remains stable.
- No import behavior changes.

Tests:

- Catalog includes every current `ImportFormatKey`.
- Every current implemented extension appears in exactly one complete or
  partial module.
- Current registry snapshot test still passes through compatibility layer.

### Slice 5: Registry Compatibility Layer

**Goal:** Make the current `ImportFormatRegistry` derive metadata from modules
while keeping public callers stable.

Implementation tasks:

1. Add `ImportModuleRegistryAdapter`.
2. Convert `ImportModuleManifest` to `ImportFormatDefinition`.
3. Map module `family` to current `ImportFamily`.
4. Map module `status` to current `ImportSupportState`.
5. Map module `support.implementation` to current `ImportImplementationKind`.
6. Map module `id` to current `ImportFormatKey` for all existing keys.
7. Keep `ImportFormatRegistry.instance` available.
8. Replace hardcoded `_formats` list with module-derived values.
9. Keep `forKey`, `forExtension`, `detectByPath`, and
   `implementedExtensions` behavior stable.

Acceptance criteria:

- No caller outside the registry needs to change in this slice.
- Existing detection behavior remains the same.
- Existing imports still route to the same wizard paths.

Tests:

- Existing registry tests pass.
- Snapshot test compares old expected definitions to module-derived
  definitions.
- `implementedExtensions()` returns the same set as before.
- `.tar.gz` and `.tar.bz2` behavior remains covered through detection tests.

### Slice 6: Module-Driven Detection Service

**Goal:** Move source detection to module-aware matching.

Implementation tasks:

1. Update `ImportDetectionService` to use `ImportModuleCatalog`.
2. Preserve existing `ImportDetectionResult` shape through compatibility.
3. Add compound extension detection for `.tar.gz`, `.tar.bz2`, and future
   `.tar.xz`.
4. Add bounded signature probing framework.
5. Move SQLite signature warning into the SQLite module detection behavior.
6. Move archive candidate detection into wrapper module behavior.
7. Keep current warnings unchanged unless tests are updated intentionally.
8. Return module id in detection internals even if UI still shows format key.

Acceptance criteria:

- Drag/drop detection behavior matches current behavior for all supported
  extensions.
- Archive wrapper behavior matches current behavior.
- SQLite header warnings still appear.
- Unknown files still resolve to unknown source behavior.

Tests:

- Detection tests for every complete, partial, planned, investigate, deferred,
  and unknown extension.
- Compound extension tests.
- SQLite signature warning test.
- Archive candidate tests.
- Ambiguous extension test if any future manifest allows overlap.

### Slice 7: Adapter Registry And Existing Adapter Wrappers

**Goal:** Introduce adapter dispatch without rewriting import implementations.

Implementation tasks:

1. Add `ImportModuleAdapterRegistry`.
2. Register `direct_open_decentdb`.
3. Register `generic_delimited`.
4. Register `generic_structured`.
5. Register `generic_html_table`.
6. Register `legacy_excel`.
7. Register `legacy_sqlite`.
8. Register `legacy_sql_dump`.
9. Register `zip_wrapper`.
10. Register `gzip_wrapper`.
11. Register `bzip2_wrapper`.
12. Wrap existing preview and execution services behind adapter methods.
13. Ensure unavailable modules have no executable adapter.
14. Ensure adapter ids referenced in manifests are validated at startup/tests.

Acceptance criteria:

- Current generic imports still work.
- Current dedicated imports still launch.
- Current archive wrappers still route inner files.
- Unavailable modules show unavailable messaging, not runtime adapter errors.

Tests:

- Adapter registry lookup tests.
- Missing adapter validation tests.
- Generic adapter smoke tests.
- Legacy adapter routing tests.
- Wrapper adapter routing tests.

### Slice 8: Module-Aware Import Wizard Routing

**Goal:** Route wizard decisions through modules and adapters.

Implementation tasks:

1. Update drag/drop and file picker flow to carry module id.
2. Update import manager routing to use module implementation and adapter kind.
3. Keep existing generic import dialog for generic modules.
4. Keep existing dedicated dialogs for legacy modules.
5. Show module name, summary, status, and limitations in unsupported source UI.
6. Show module capability badges where useful.
7. Ensure direct-open DecentDB module still opens `.ddb` files directly.

Acceptance criteria:

- User flow is unchanged for currently supported formats except for more
  consistent unsupported-format explanations.
- Unsupported recognized formats show module docs/limitations.
- Unknown formats remain clear.

Tests:

- UI/application tests for CSV routing.
- UI/application tests for Excel routing.
- UI/application tests for SQLite routing.
- UI/application tests for SQL dump routing.
- UI/application tests for unsupported planned module messaging.
- UI/application tests for unknown file messaging.

### Slice 9: Module Options In Generic Import

**Goal:** Make generic import options module-declared.

Implementation tasks:

1. Map CSV module options to existing `GenericImportOptions`.
2. Map TSV module options to existing `GenericImportOptions`.
3. Map generic delimited module options to existing `GenericImportOptions`.
4. Map JSON module options to structured import options.
5. Map NDJSON module options to structured import options.
6. Map XML module options to structured import options.
7. Map HTML table module options to HTML import options.
8. Ensure option defaults come from manifests.
9. Ensure user overrides still serialize into current request models.
10. Keep existing option UI stable unless a module-declared label is more
    accurate.

Acceptance criteria:

- Existing generic import behavior does not change.
- Module manifests can explain every option shown in the generic wizard.
- Option defaults come from module metadata.

Tests:

- Option default tests per generic module.
- Option override tests.
- Import request serialization tests.
- Backward compatibility tests for existing generic import profiles.

### Slice 10: Documentation Generation Or Validation

**Goal:** Stop import-format docs from drifting.

Implementation tasks:

1. Add a docs validation command or test.
2. Validate that every complete and partial module appears in
   `docs/IMPORT_FORMATS.md`.
3. Validate that every planned/investigate/deferred/candidate module appears in
   the future table or is intentionally hidden with a manifest flag.
4. Validate bundled help docs mention complete and partial import families.
5. Validate module README files exist.
6. Validate module README files include required headings:
   - Status,
   - Extensions,
   - Capabilities,
   - Type Fidelity,
   - Limitations,
   - Fixtures.
7. Update `docs/IMPORT_FORMATS.md` to say the module catalog is the source of
   truth.
8. Update `apps/decent-bench/assets/help/importing-data.md`.
9. Update `apps/decent-bench/assets/help/getting-started.md` only if visible
   import lists change.
10. Update help manifest tags and summaries if needed.

Acceptance criteria:

- Docs validation fails if a supported module is undocumented.
- Docs validation fails if a module README is missing required sections.
- Current docs accurately reflect supported, partial, and future modules.

Tests:

- Docs sync test.
- README required-heading test.
- Help docs coverage test.

### Slice 11: Fixture Contract And Import Module Test Harness

**Goal:** Make module fixtures a repeatable import quality gate.

Implementation tasks:

1. Add `ImportModuleFixtureLoader`.
2. Add fixture metadata parsing from module manifests.
3. Add a test helper that loads a module fixture and executes the declared
   inspection path.
4. Add a test helper that imports fixture data into a temporary `.ddb` file
   when the module is complete.
5. Add expected table validation.
6. Add expected column validation.
7. Add expected warning validation.
8. Add expected row-count validation.
9. Add generated fixture instructions for binary or large sources that should
   not be checked in.

Acceptance criteria:

- Complete modules have executable fixtures or documented fixture-generation
  instructions.
- Generic import modules are covered by fixture tests.
- Legacy modules have at least smoke fixtures if practical.
- Planned modules are allowed to have non-executable fixture notes.

Tests:

- Fixture loader tests.
- CSV fixture import test.
- JSON fixture inspection test.
- HTML fixture inspection test.
- Archive wrapper fixture test.
- Missing fixture validation test.

### Slice 12: Module Status Promotion Workflow

**Goal:** Define and enforce how a module moves from candidate to complete.

Implementation tasks:

1. Add status transition documentation to `import_modules/README.md`.
2. Add validation rules for `complete` modules:
   - adapter exists,
   - docs exist,
   - fixtures exist or generated fixture instructions exist,
   - required capabilities are declared,
   - limitations are clear if support is partial.
3. Add validation rules for `partial` modules:
   - adapter exists,
   - at least one limitation exists,
   - docs explain unsupported cases.
4. Add validation rules for `planned`, `investigate`, `deferred`, and
   `candidate` modules.
5. Update `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md` so new format work
   starts with a module status promotion.

Acceptance criteria:

- A module cannot be marked complete casually.
- A module cannot be partial without limitations.
- A module cannot reference an adapter that is not registered.
- Format-expansion docs point to module status promotion.

Tests:

- Status validation tests.
- Complete-without-fixture failure test.
- Partial-without-limitation failure test.
- Planned-with-adapter-none success test.

### Slice 13: Typed Batch Protocol Placeholder For Future High-Fidelity Formats

**Goal:** Add the internal shape needed for future high-fidelity importers
without converting current importers yet.

Implementation tasks:

1. Add domain models for typed import schema:
   - `ImportTypedSchema`,
   - `ImportTypedTable`,
   - `ImportTypedColumn`,
   - `ImportTypedBatch`,
   - `ImportTypedCellWarning`.
2. Include source type, logical type, target type, nullability, precision,
   scale, timezone, encoding, and metadata fields.
3. Add conversion from current `ImportTableDraft` to typed schema.
4. Add conversion from current materialized row maps to typed batches.
5. Mark current generic conversions as compatibility paths.
6. Do not let adapters write directly into DecentDB unless ADR-0050 is updated
   or superseded and tests cover the new boundary.

Acceptance criteria:

- Future adapters have a typed target to implement.
- Current generic imports can be represented as typed batches.
- SQLite is not introduced as a staging abstraction.

Tests:

- Typed schema serialization tests.
- Current table draft to typed schema conversion tests.
- Row map to typed batch conversion tests.
- Type metadata preservation tests.

### Slice 14: Remove Hardcoded Format Knowledge From Call Sites

**Goal:** Finish the conversion so module metadata is authoritative.

Implementation tasks:

1. Search for hardcoded import format labels outside module manifests.
2. Search for hardcoded extension lists outside module manifests.
3. Search for format-specific support-state descriptions outside module
   manifests and module docs.
4. Replace hardcoded format UI text with module catalog lookups where
   appropriate.
5. Keep adapter-specific logic inside adapters.
6. Keep DecentDB direct-open behavior explicit but module-backed.
7. Delete obsolete duplicated registry data.

Acceptance criteria:

- Format lists come from module catalog.
- Detection metadata comes from module catalog.
- Docs validation protects against drift.
- Adapter code can still have format-specific parsing logic.

Tests:

- Code search based test or scripted validation for forbidden duplicate
  extension lists if feasible.
- Existing import tests still pass.
- Docs sync tests pass.

### Slice 15: Final Compatibility And Migration Verification

**Goal:** Prove users do not lose any current import behavior.

Implementation tasks:

1. Build a current-format manual verification matrix.
2. Verify drag/drop for every complete and partial format.
3. Verify file picker for every complete and partial format.
4. Verify archive wrapper candidate selection.
5. Verify headless import where supported.
6. Verify unsupported recognized formats show correct unavailable messaging.
7. Verify unknown files show correct unknown messaging.
8. Verify help docs and `docs/IMPORT_FORMATS.md` match module catalog.

Acceptance criteria:

- No current supported import regresses.
- No current supported extension disappears.
- No current planned/investigate/deferred format is lost.
- The module catalog is the single source of truth for import metadata.

Tests:

- `flutter analyze`
- `flutter test`
- Any existing import integration tests.
- `git diff --check`

Manual verification:

- Drag a `.csv` file and complete import.
- Drag a `.json` file and complete import.
- Drag an `.html` file with tables and complete import.
- Drag a `.xlsx` file and confirm dedicated wizard routing.
- Drag a `.sqlite` file and confirm dedicated wizard routing.
- Drag a `.sql` dump and confirm dedicated wizard routing.
- Drag a `.zip` containing a `.csv` and confirm archive candidate routing.
- Drag a `.parquet` file and confirm planned/unavailable module messaging.
- Drag an unknown extension and confirm unknown-file messaging.

## Built-In Module Conversion Matrix

| Module ID | Current Format Key | Status | Adapter Kind | Conversion Requirement |
|---|---|---|---|---|
| `decentdb` | `decentDb` | complete | direct open | Preserve direct `.ddb` open/migrate behavior. |
| `csv` | `csv` | complete | dart generic | Preserve comma delimiter defaults and generic wizard behavior. |
| `tsv` | `tsv` | complete | dart generic | Preserve tab delimiter defaults and generic wizard behavior. |
| `generic_delimited` | `genericDelimited` | complete | dart generic | Preserve `.txt`, `.dat`, `.log`, `.psv` behavior. |
| `fixed_width` | `fixedWidth` | planned | none | Add manifest and docs only. |
| `xlsx` | `xlsx` | complete | legacy wizard | Preserve workbook wizard routing. |
| `xls` | `xls` | partial | legacy wizard | Preserve warnings and conversion limitations. |
| `ods` | `ods` | planned | none | Add manifest and docs only. |
| `json` | `json` | complete | dart generic | Preserve structured import behavior. |
| `ndjson` | `ndjson` | complete | dart generic | Preserve line-oriented JSON behavior. |
| `xml` | `xml` | complete | dart generic | Preserve structured XML behavior. |
| `yaml` | `yaml` | investigate | none | Add manifest and docs only. |
| `toml` | `toml` | deferred | none | Add manifest and docs only. |
| `html_table` | `htmlTable` | complete | dart generic | Preserve HTML table selection behavior. |
| `markdown_table` | `markdownTable` | investigate | none | Add manifest and docs only. |
| `sqlite` | `sqlite` | complete | legacy wizard | Preserve SQLite wizard and header warning behavior. |
| `duckdb` | `duckdb` | planned | none | Add manifest and docs only. |
| `access` | `access` | investigate | none | Add manifest and docs only. |
| `dbf` | `dbf` | investigate | none | Add manifest and docs only. |
| `ms_sql_bak` | `msSqlBak` | investigate | none | Add manifest and docs only. |
| `sql_dump` | `sqlDump` | complete | legacy wizard | Preserve MVP-lite SQL dump wizard. |
| `postgres_plain_dump` | `postgresPlainDump` | planned | none | Add manifest and docs only. |
| `parquet` | `parquet` | planned | none | Add manifest and docs only. |
| `json_log_stream` | `jsonLogStream` | planned | none | Add manifest and docs only. |
| `delimited_log` | `delimitedLog` | investigate | none | Add manifest and docs only. |
| `zip_archive` | `zipArchive` | complete | wrapper | Preserve ZIP candidate detection and extraction routing. |
| `gzip_archive` | `gzipArchive` | complete | wrapper | Preserve `.gz`, `.tgz`, `.tar.gz` routing. |
| `bzip2_archive` | `bzip2Archive` | complete | wrapper | Preserve `.bz2`, `.tbz2`, `.tar.bz2` routing. |
| `xz_archive` | `xzArchive` | investigate | none | Add manifest and docs only. |
| `clipboard_table` | `clipboardTable` | investigate | none | Add manifest and docs only. |
| `pdf_tables` | `pdfTables` | deferred | none | Add manifest and docs only. |
| `unknown` | `unknown` | not started | none | Preserve fallback behavior. |

## Future Candidate Module Intake

After the current registry is converted, every new future import idea should be
tracked as a module candidate instead of only as prose in
`docs/IMPORT_FORMATS.md`.

Candidate modules may have:

- `status = "candidate"`,
- `adapter.kind = "none"`,
- no executable fixtures,
- README with use cases and risk notes,
- type mapping placeholders,
- dependency review notes.

Candidate modules must not appear as user-supported import formats in the app
unless the UX explicitly labels them as unavailable roadmap items.

## Testing Strategy

### Unit Tests

Required:

- manifest parsing,
- manifest validation,
- enum mapping,
- catalog loading,
- catalog lookup,
- registry compatibility mapping,
- adapter registry lookup,
- detection matching,
- option default mapping,
- fixture metadata parsing,
- docs sync validation.

### Integration Tests

Required:

- generic module import path,
- dedicated module routing path,
- wrapper module candidate path,
- unsupported module messaging,
- unknown source messaging.

### Regression Tests

Before and after module conversion, assert the same values for:

- implemented extensions,
- support states,
- labels,
- families,
- implementation kinds,
- generic wizard routing,
- legacy wizard routing,
- wrapper routing.

### Documentation Tests

Required:

- complete/partial modules documented in `docs/IMPORT_FORMATS.md`,
- future modules documented in future table or intentionally hidden,
- module README required sections,
- bundled help docs mention supported import families.

## Documentation Checklist

Update these files as part of the relevant slices:

- `design/FUTURE_WINS.md`
- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`
- `docs/IMPORT_FORMATS.md`
- `design/IMPORT_SUPPORT_PLAN.md`
- `apps/decent-bench/assets/help/importing-data.md`
- `apps/decent-bench/assets/help/getting-started.md`
- `apps/decent-bench/assets/help/help_manifest.json`
- `apps/decent-bench/import_modules/README.md`
- every module-local `README.md`

Documentation must state clearly:

- which formats are complete,
- which formats are partial,
- which formats are recognized but unavailable,
- that module manifests are declarative,
- that external modules are not supported yet,
- that SQLite is a source module, not universal staging,
- that future worker-backed modules must preserve DecentDB typed fidelity.

## Completion Checklist

This Future Win is complete when:

- ADR-0049, ADR-0050, ADR-0051, and ADR-0052 are accepted or superseded by
  accepted replacement ADRs.
- Module schema docs exist.
- Built-in module catalog exists.
- Every current registry format has a module.
- Registry compatibility layer is module-backed.
- Detection is module-backed.
- Adapter dispatch exists.
- Current imports still work.
- Docs sync validation exists.
- Fixture test harness exists.
- Hardcoded duplicate format metadata is removed or intentionally adapter-local.
- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md` uses module promotion as the
  first step for new formats.
- `docs/IMPORT_FORMATS.md` reflects module catalog status.
- `flutter analyze` passes.
- `flutter test` passes.
