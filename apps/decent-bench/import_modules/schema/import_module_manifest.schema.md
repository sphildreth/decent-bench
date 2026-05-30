# Import Module Manifest Schema (v1)

This document defines the v1 built-in import module manifest contract used by
Decent Bench.

## Scope

- Schema version: `1`
- Format: TOML
- Module location: `apps/decent-bench/import_modules/builtin/<module_id>/module.toml`
- External modules: not supported

## Declarative-Only Rule

Manifest files are metadata only. They cannot contain executable behavior.

Not allowed in any manifest field:

- shell commands
- scripts or callback-like values
- executable SQL payloads
- dynamic library paths
- package installation instructions
- arbitrary executable or filesystem paths

Import behavior is implemented only by reviewed adapters selected by adapter id.

## Top-Level Fields

| Field | Type | Required | Rules |
|---|---|---:|---|
| `schema_version` | integer | yes | Must be `1`. |
| `id` | string | yes | Lowercase snake_case. Stable after release. |
| `kind` | enum | yes | See `kind` enum. |
| `status` | enum | yes | See `status` enum. |
| `priority` | enum | yes | See `priority` enum. |
| `legacy_format_key` | string | yes | Compatibility key matching the current `ImportFormatKey` enum name. |
| `name` | string | yes | User-visible name. |
| `family` | enum | yes | See `family` enum. |
| `summary` | string | yes | Single-sentence list summary. |
| `description` | string | yes | Longer user-visible description. |
| `note` | string | no | Additional user-visible caveat or workflow hint. |

## Detection Section

Table: `[detection]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `extensions` | string array | yes | Lowercase with leading dot, for example `.csv`. |
| `mime_types` | string array | yes | Advisory until platform MIME coverage is consistent. |
| `filename_patterns` | string array | yes | Simple glob-like patterns in v1, not regex. |
| `magic_numbers` | string array | yes | Use only documented byte-prefix syntax after validator support lands. |
| `priority` | integer | yes | Tie-break when multiple modules match. |

Rules:

- Detection must not read full files on the UI thread.
- Duplicate extension ownership in the catalog fails unless a future ADR adds
  an explicit conflict rule.

## Support Section

Table: `[support]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `implementation` | enum | yes | See `support.implementation` enum. |
| `availability` | string | yes | Must be `builtin` in v1. |
| `min_app_version` | string | yes | Minimum app version string. |
| `requires_dependency_review` | boolean | yes | `true` means module cannot be marked complete until review is documented. |
| `requires_adr` | boolean | yes | `true` means completion requires referenced ADR acceptance. |

Rules:

- `status = "complete"` cannot use `recognized_unsupported` or `unknown`
  implementation.
- `status = "partial"` requires at least one `[[limitations]]` entry.
- `implementation = "worker_backed"` must follow ADR-0051.

## Capabilities Section

Table: `[capabilities]`

All fields are required booleans:

- `detect_by_extension`
- `detect_by_signature`
- `inspect_schema`
- `preview_rows`
- `import_full`
- `import_selected_tables`
- `supports_multiple_tables`
- `supports_archives`
- `supports_streaming_preview`
- `supports_streaming_import`
- `supports_cancellation`
- `supports_rejected_rows`
- `preserves_logical_types`
- `preserves_constraints`
- `preserves_indexes`
- `preserves_relationships`
- `can_export_recipe`

Rules:

- Manifest capabilities declare intended behavior.
- Runtime adapters report actual capabilities at runtime.
- If runtime capability is less than manifest capability, UI must warn and use
  runtime capability.
- If runtime capability is greater than manifest capability, tests should fail
  until manifest metadata is updated.

## Adapter Section

Table: `[adapter]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `id` | string | yes | Adapter id registered by the app. |
| `kind` | enum | yes | See `adapter.kind` enum. |
| `protocol` | string | yes | Protocol id, for example `dart_import_adapter_v1` or `typed_batch_v1`. |
| `entrypoint` | string | no | Identifier only. Not a path, command, or script. |

Rules:

- `kind = "none"` is allowed only for unavailable modules.
- Complete and partial modules must reference a registered adapter id.
- `kind = "worker"` must use the reviewed worker protocol boundary from
  ADR-0051.

## Actions Section

Array of tables: `[[actions]]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `id` | enum | yes | See `actions.id` enum. |
| `label` | string | yes | User-visible action label. |
| `required` | boolean | yes | Marks required action for the module contract. |

Rules:

- Actions are app-dispatched behavior names, not scripts.
- Action ids must be unique within a manifest.
- Every `status = "complete"` source module must include `inspect_schema`,
  `preview_rows`, and `import_full`, except `direct_open` modules.
- Every wrapper module must include `inspect_archive` and
  `extract_inner_source`.

## Options Section

Array of tables: `[[options]]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `id` | string | yes | Lowercase snake_case, unique within manifest. |
| `label` | string | yes | User-visible option label. |
| `type` | enum | yes | See `options.type` enum. |
| `default` | scalar or array | conditional | Explicitly required when `required = true`. |
| `required` | boolean | yes | Whether option must be provided. |

Rules:

- Options describe serializable module behavior for future recipe support.
- Options must not include code or callbacks.
- `allowed_values` is required when `type = "enumeration"`.

## Type Mappings Section

Array of tables: `[[type_mappings]]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `source_type` | string | yes | Source type identifier. |
| `target_type` | string | yes | Target DecentDB type identifier. |
| `fidelity` | enum | yes | See `type_mappings.fidelity` enum. |
| `notes` | string | yes | User-visible type mapping note. |

Rules:

- Complete modules should declare important preserve/coerce/stringify/reject
  mappings.
- Modules without native source type systems may declare inferred source types.
- Type mapping notes should be surfaced in module help.

## Checks Section

Array of tables: `[[checks]]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `id` | string | yes | Stable check id. |
| `name` | string | yes | User-visible name. |
| `description` | string | yes | User-visible description. |
| `default_enabled` | boolean | yes | Default enable state. |
| `severity` | string | yes | Severity label, for example `warning`. |
| `quality_profile` | string | no | Referenced quality profile id. |

Rules:

- Checks declare module-specific quality checks.
- Execution ownership belongs to the Data Quality, Profiling, and Validation
  suite.
- Checks may be declared before runtime check execution is implemented.
- Checks must not run module-provided code.

## Limitations Section

Array of tables: `[[limitations]]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `id` | string | yes | Stable limitation id. |
| `severity` | string | yes | User-visible severity, for example `warning`. |
| `message` | string | yes | User-visible and testable message. |

Rules:

- `status = "partial"` requires at least one limitation.
- Deferred modules should explain deferral reasons.

## Documentation Section

Table: `[documentation]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `help_topic` | string | yes | Stable help topic id. |
| `format_docs` | string | yes | Must point to module-local `README.md`. |
| `fixture_notes` | string | yes | Fixture notes path, typically under `fixtures/`. |

Rules:

- Complete and partial modules must include documentation references.
- Docs synchronization tests should ensure complete and partial modules are
  present in user-facing documentation.

## Fixtures Section

Array of tables: `[[fixtures]]`

| Field | Type | Required | Rules |
|---|---|---:|---|
| `id` | string | yes | Fixture id unique within manifest. |
| `path` | string | yes | Relative path under the module directory. |
| `purpose` | string | yes | Human-readable fixture intent. |
| `expected_tables` | string array | yes | Expected imported table names. |
| `expected_warnings` | string array | yes | Expected warning ids/messages. |

Rules:

- Complete modules should include at least one fixture.
- Planned and investigate modules may include placeholder fixture notes without
  binary fixtures.
- If fixture binaries cannot be committed, module docs should provide
  deterministic generation steps.

## Enum Reference

### `kind`

- `source`
- `wrapper`
- `direct_open`
- `template`
- `profile`

### `status`

- `complete`
- `partial`
- `planned`
- `investigate`
- `deferred`
- `candidate`
- `not_started`

### `priority`

- `P0`
- `P1`
- `P2`
- `P3`
- `P4`
- `none`

### `family`

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

### `support.implementation`

- `direct_open`
- `generic_wizard`
- `dedicated_wizard`
- `wrapper`
- `recognized_unsupported`
- `worker_backed`
- `unknown`

### `adapter.kind`

- `none`
- `dart_builtin`
- `dart_generic`
- `legacy_wizard`
- `worker`
- `wrapper`

### `actions.id`

- `detect`
- `inspect_archive`
- `extract_inner_source`
- `inspect_schema`
- `preview_rows`
- `import_full`
- `import_selected_tables`
- `open_database`
- `recognize_source`
- `show_unknown_source_message`

### `options.type`

- `boolean`
- `integer`
- `string`
- `enumeration`
- `string_list`

### `type_mappings.fidelity`

- `exact`
- `lossless_with_metadata`
- `lossless_with_timezone_note`
- `coerced`
- `stringified`
- `unsupported`

## Global Validation Rules

- Unknown fields fail validation.
- Missing required fields fail validation.
- Unknown enum values fail validation.
- Duplicate module ids fail catalog validation.
- Duplicate action ids fail manifest validation.
- Duplicate option ids fail manifest validation.
- Unsupported `schema_version` fails validation.
- Complete modules must provide documentation and fixture coverage, or
  deterministic fixture generation notes in module docs.
- Built-in catalog is the only supported module source in v1.

## SQLite Boundary

SQLite is a source module only. It is not a universal staging database for
other format imports.
