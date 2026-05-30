# Generic Delimited Text Import Module

## Status

- Status: `complete`
- Priority: `P0`
- Adapter: `generic_delimited` (`dart_generic`)

## Extensions

`.txt`, `.dat`, `.log`, `.psv`

## Capabilities

- `detect_by_extension`: `true`
- `inspect_schema`: `true`
- `preview_rows`: `true`
- `import_full`: `true`
- `supports_cancellation`: `true`
- `supports_rejected_rows`: `true`
- `can_export_recipe`: `true`

## Type Fidelity

This module declares type mapping behavior in `module.toml`. Current built-in adapters preserve values according to the existing Decent Bench import path and surface warnings when conversion is lossy or unsupported.

## Limitations

- Use delimiter and malformed-row options to adapt messy exports.

## Fixtures

Fixture metadata is declared in `module.toml`. See `fixtures/README.md` for executable fixtures or deterministic generation notes.
