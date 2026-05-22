# OpenDocument Spreadsheet Import Module

## Status

- Status: `planned`
- Priority: `P1`
- Adapter: `none` (`none`)

## Extensions

`.ods`

## Capabilities

- `detect_by_extension`: `true`

## Type Fidelity

This module declares type mapping behavior in `module.toml`. Current built-in adapters preserve values according to the existing Decent Bench import path and surface warnings when conversion is lossy or unsupported.

## Limitations

- ODS workbook parsing has not been implemented yet.

## Fixtures

Fixture metadata is declared in `module.toml`. See `fixtures/README.md` for executable fixtures or deterministic generation notes.
