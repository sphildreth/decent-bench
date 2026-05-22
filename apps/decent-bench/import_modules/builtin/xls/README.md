# Excel (.xls) Import Module

## Status

- Status: `partial`
- Priority: `P1`
- Adapter: `legacy_excel` (`legacy_wizard`)

## Extensions

`.xls`

## Capabilities

- `detect_by_extension`: `true`
- `inspect_schema`: `true`
- `preview_rows`: `true`
- `import_full`: `true`
- `import_selected_tables`: `true`
- `supports_multiple_tables`: `true`
- `supports_cancellation`: `true`
- `preserves_logical_types`: `true`
- `can_export_recipe`: `true`

## Type Fidelity

This module declares type mapping behavior in `module.toml`. Current built-in adapters preserve values according to the existing Decent Bench import path and surface warnings when conversion is lossy or unsupported.

## Limitations

- Legacy workbook conversion can surface runtime warnings.

## Fixtures

Fixture metadata is declared in `module.toml`. See `fixtures/README.md` for executable fixtures or deterministic generation notes.
