# Headless Import Profile Details

This document describes the versioned JSON profile document accepted by the
headless import CLI:

```text
dbench --in <source-path> --out <target.ddb>
dbench --in <source-path> --out <target.ddb> --plan <profile.json>
```

`--plan` is valid only with `--in` and `--out`. The profile file defines
repeatable import/export preferences; the input and output paths stay on the
command line.

## Current Profile Shape

The current profile document uses `config_version: 1`:

```json
{
  "config_version": 1,
  "import": {
    "name": "Customers CSV",
    "source_format": "csv",
    "header_row": true,
    "delimiter": ",",
    "native_type_mappings": {
      "created_at": "TIMESTAMPTZ"
    },
    "table_targets": {
      "Customers": "customers"
    }
  },
  "exports": [
    {
      "id": "json-lossless",
      "name": "JSON Lossless",
      "format": "json",
      "output_dir": "exports",
      "include_headers": true,
      "delimiter": ",",
      "include_metadata": true,
      "native_type_mode": "lossless"
    }
  ]
}
```

## Top-Level Fields

### `config_version`

- type: integer
- required: no
- default: `1`
- supported value: `1`

Unsupported versions fail before import work starts.

### `import`

- type: object
- required: no

Current import profile fields:

- `name`: human-readable profile name
- `source_format`: optional source family hint such as `csv`, `excel`,
  `sqlite`, or `sql_dump`
- `header_row`: optional boolean
- `delimiter`: optional delimiter string for delimited imports
- `native_type_mappings`: object mapping column names to DecentDB target types
- `table_targets`: object mapping source object names to target table names

The current headless runner loads and validates this profile, reports the
profile name, and then runs the existing import path. Unsupported profile
versions or malformed exports fail with exit code `2`.

### `exports`

- type: array
- required: no

Each export profile requires:

- `id`
- `name`
- `format`

Optional export profile fields:

- `output_dir`
- `include_headers`
- `delimiter`
- `include_metadata`
- `native_type_mode`

## Boundaries

These values belong on the CLI, not in the profile:

- input path (`--in`)
- output `.ddb` path (`--out`)
- progress display preferences such as `--silent`
- batch job arrays
- remote URL fetch instructions

## Future Transform Details

Generic import drafts now have a serializable row-local transform plan in code.
When the GUI exposes transform-plan editing and profile export, the profile
schema should be extended from the current compact import/export profile into a
full table/column transform manifest. That future schema must remain versioned
and must fail fast on unknown fields or unsupported transform operations.
