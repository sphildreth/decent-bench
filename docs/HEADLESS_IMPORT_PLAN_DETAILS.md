# Headless Import Plan Details

This document is the reference for the JSON plan file consumed by the future
headless import CLI:

```text
dbench --in <source-path> --out <target.ddb>
dbench --in <source-path> --out <target.ddb> --plan <plan.json>
```

The headless CLI is not implemented yet. When it is implemented, it must follow
this document.

## Command Boundaries

- `dbench /path/to/workspace.ddb`
  - opens an existing DecentDB workspace in the desktop UI
- `dbench --import <path>`
  - launches the desktop UI and opens the matching import wizard
- `dbench --in <path> --out <path.ddb>`
  - runs a headless import without showing the UI
- `--plan <plan.json>`
  - is only valid with `--in` and `--out`

The plan file defines import behavior and overrides. It does not replace the
command line as the source of the input or output file paths.

## Contract Principles

- Headless import must work without a plan file for the default case.
- `--import` is reserved for the interactive import wizard.
- `--in` and `--out` define the execution context for a single run.
- Plan files must be portable across machines.
- Unknown or invalid plan fields must fail validation.
- The plan format must be versioned.

## Required Fields

Every plan document must contain these fields.

### `plan_version`

- type: integer
- required: yes
- supported value in the first version: `1`

Minimal valid plan:

```json
{
  "plan_version": 1
}
```

That minimal plan means:

- detect the source format automatically
- import all discovered objects
- use default names, default selection rules, and inferred types
- apply the same default import behavior as the interactive workflow when no
  overrides are provided

## Conditionally Required Fields

These fields are required when the plan chooses non-default behavior.

### `format`

- type: string
- required when:
  - importer-specific `source_options` are present
  - the caller wants to pin the importer family instead of using auto-detection
- default when omitted: `auto`

Supported values:

- `auto`
- `delimited`
- `json`
- `ndjson`
- `xml`
- `html`
- `excel`
- `sqlite`
- `sql_dump`

### `tables[].source_name`

- type: string
- required for every entry in `tables`
- identifies the discovered source object being configured

Examples:

- an Excel sheet name
- a SQLite table name
- an HTML table identifier such as `table[0]`

### `tables[].columns[].source_name`

- type: string
- required for every entry in `tables[].columns`
- identifies the discovered source column being configured

## Recommended Fields For Automation

These fields are optional, but they should be used for deterministic scripted
imports, external regression packs, and CI-style batch runs.

### `format`

Do not rely on `auto` when stable behavior matters.

### `on_warning`

- type: string
- default: `continue`
- recommended value for automation: `fail`

Supported values:

- `continue`
- `fail`

### `table_selection_mode`

- type: string
- default: `all_discovered`

Supported values:

- `all_discovered`
- `listed_only`

Use `listed_only` when a script must fail safe against newly discovered tables,
sheets, or HTML tables appearing in the source.

### `column_selection_mode`

- type: string
- default: `all_discovered`

Supported values:

- `all_discovered`
- `listed_only`

Use `listed_only` when only explicitly listed columns should be imported for a
configured table.

### `tables[].target_name`

Set this whenever downstream code depends on stable target table names.

### `tables[].include`

- type: boolean
- default: `true`

This field is mainly useful when `table_selection_mode` is
`all_discovered` and the caller wants to exclude specific discovered objects.

### `tables[].columns[].target_name`

Set this whenever downstream code depends on stable target column names.

### `tables[].columns[].target_type`

Set this whenever a column must not rely on inference alone.

Examples of valid DecentDB target types:

- `INT64`
- `FLOAT64`
- `DECIMAL(18, 6)`
- `TEXT`
- `TIMESTAMP`
- `BOOL`
- `UUID`

### `source_options`

Use this whenever parser behavior affects table shape, row shape, or inferred
types.

## Optional Fields

These fields are part of the reference contract, but they are not required in
every plan.

### `notes`

- type: string
- optional
- free-form human description of why the plan exists

### `null_values`

- type: object
- optional
- maps column identifiers to source string values that should be treated as
  nulls

### `date_formats`

- type: object
- optional
- maps column identifiers to parse hints for non-ISO date or datetime text

### `locale`

- type: string
- optional
- parse locale hint for numbers or dates when the importer supports it

## Fields That Must Not Appear In A Plan

These values belong on the CLI or in a separate manifest, not in a single-plan
document.

- the input path
  - use `--in`
- the output `.ddb` path
  - use `--out`
- progress display preferences
  - use CLI flags such as `--silent`
- transient preview data
  - inferred schema snapshots
  - sampled rows
  - warning logs from earlier runs
- batch job arrays
  - batch execution must use a separate manifest that references one plan per
    job
- remote URL fetch instructions
  - out of scope for the first headless import contract

## Top-Level Shape

```json
{
  "plan_version": 1,
  "format": "excel",
  "on_warning": "fail",
  "table_selection_mode": "listed_only",
  "column_selection_mode": "all_discovered",
  "tables": [
    {
      "source_name": "Orders",
      "target_name": "sales_orders",
      "include": true,
      "columns": [
        {
          "source_name": "Order Date",
          "target_name": "order_date",
          "target_type": "TIMESTAMP"
        }
      ]
    }
  ],
  "source_options": {
    "excel": {
      "header_row_index": 1,
      "summary_sheets_as_views": true
    }
  }
}
```

## Field Reference

### `plan_version`

- type: integer
- required: yes
- validation:
  - must exactly match a supported plan version
  - unknown versions must fail before import work starts

### `format`

- type: string
- required: no
- default: `auto`
- validation:
  - must be one of the supported importer-family values
  - when present, it must be compatible with the source file
  - when `source_options` is present, `format` must also be present

Importer-family values are used instead of file-extension values. For example,
use `excel`, not `xlsx`.

### `on_warning`

- type: string
- required: no
- default: `continue`
- validation:
  - must be `continue` or `fail`

Headless reporting behavior stays on CLI flags and output files. The plan only
controls import semantics.

### `table_selection_mode`

- type: string
- required: no
- default: `all_discovered`
- validation:
  - must be `all_discovered` or `listed_only`

Behavior:

- `all_discovered`
  - import all discovered source objects unless a specific table entry excludes
    them
- `listed_only`
  - import only the objects named in `tables`

### `column_selection_mode`

- type: string
- required: no
- default: `all_discovered`
- validation:
  - must be `all_discovered` or `listed_only`

Behavior:

- `all_discovered`
  - import all discovered columns for an included table unless a specific
    column entry excludes them
- `listed_only`
  - import only the columns named in `tables[].columns` for a configured table

### `tables`

- type: array
- required: no

Each entry configures one discovered source object.

If `tables` is omitted:

- all discovered source objects are imported

If `tables` is present:

- behavior still depends on `table_selection_mode`
- duplicate `source_name` entries are not allowed

### `tables[].source_name`

- type: string
- required: yes, when the table entry exists
- validation:
  - must be non-empty
  - must uniquely identify one discovered source object

### `tables[].target_name`

- type: string
- required: no
- validation:
  - must be non-empty when present

### `tables[].include`

- type: boolean
- required: no
- default: `true`

### `tables[].columns`

- type: array
- required: no
- duplicate `source_name` entries are not allowed inside the same table entry

### `tables[].columns[].source_name`

- type: string
- required: yes, when the column entry exists
- validation:
  - must be non-empty
  - must uniquely identify one discovered source column within its table

### `tables[].columns[].target_name`

- type: string
- required: no
- validation:
  - must be non-empty when present

### `tables[].columns[].target_type`

- type: string
- required: no
- validation:
  - must match a supported DecentDB target type name

### `source_options`

- type: object
- required: no

Importer-specific settings live under one matching family section.

Allowed sections:

- `source_options.delimited`
- `source_options.json`
- `source_options.xml`
- `source_options.html`
- `source_options.excel`
- `source_options.sqlite`
- `source_options.sql_dump`

Validation:

- only one family section may appear in a single plan
- the family section must match `format`
- unknown family sections must fail validation

## Importer-Specific Options

These are the first supported option names for each importer family.

### `source_options.delimited`

- `delimiter`
- `quote`
- `escape`
- `encoding`
- `header_row_index`

### `source_options.html`

- `table_selector`
- `table_index`
- `header_row_index`

### `source_options.excel`

- `header_row_index`
- `selected_sheets`
- `summary_sheets_as_views`

### `source_options.sqlite`

- `selected_tables`
- `type_inference_sample_rows`

### `source_options.sql_dump`

- `include_schema`
- `include_data`
- `stop_on_unsupported_statement`

## Validation Rules

The implementation must validate these conditions before import work starts:

- the plan parses as JSON
- `plan_version` exists and is supported
- unknown top-level keys fail validation
- unknown nested keys fail validation
- unknown enum values fail validation
- duplicate `tables[].source_name` entries fail validation
- duplicate `tables[].columns[].source_name` entries inside the same table fail
  validation
- `target_name` values must be non-empty when present
- `target_type` values must match supported DecentDB target types when present
- importer-specific options must only appear under the matching family section
- when `format` is `auto`, `source_options` must not be present

## Example: Minimal Deterministic HTML Plan

```json
{
  "plan_version": 1,
  "format": "html",
  "on_warning": "fail",
  "table_selection_mode": "listed_only",
  "tables": [
    {
      "source_name": "table[0]",
      "target_name": "top_albums"
    }
  ],
  "source_options": {
    "html": {
      "table_index": 0
    }
  }
}
```

## Example: SQLite Plan With Type Overrides

```json
{
  "plan_version": 1,
  "format": "sqlite",
  "on_warning": "fail",
  "table_selection_mode": "listed_only",
  "tables": [
    {
      "source_name": "datetime_types",
      "target_name": "datetime_types",
      "columns": [
        {
          "source_name": "natural_language_col",
          "target_name": "natural_language_col",
          "target_type": "TEXT"
        }
      ]
    }
  ],
  "source_options": {
    "sqlite": {
      "selected_tables": [
        "basic_types",
        "datetime_types"
      ],
      "type_inference_sample_rows": 64
    }
  }
}
```

## Batch Guidance

Batch execution must use a separate manifest document. Each batch job should
reference one plan file rather than embedding plan JSON inline. This keeps
single-run plans reusable and keeps batch manifests focused on orchestration.
