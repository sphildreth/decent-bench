# Clipboard Table Import Module

## Status

- Status: `complete`
- Priority: `P1`
- Adapter: `clipboard_table_source` (`dart_builtin`)

## Extensions

No extension-based detection. This module is reached through the explicit clipboard capture flow for tabular clipboard payloads.

## Capabilities

- `detect_by_extension`: `false`
- `detect_by_signature`: `false`
- `inspect_schema`: `true`
- `preview_rows`: `true`
- `import_full`: `true`
- `supports_multiple_tables`: `true`
- `supports_cancellation`: `true`
- `supports_rejected_rows`: `true`
- `can_export_recipe`: `true`

## Type Fidelity

Clipboard table values are routed through the generic wizard flow and inferred with the normal DecentDB import rules.

## Limitations

- No filename or signature-based auto-detection is registered.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
