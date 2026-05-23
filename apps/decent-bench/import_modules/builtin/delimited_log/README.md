# Delimited Log File Import Module

## Status

- Status: `complete`
- Priority: `P1`
- Adapter: `generic_delimited_log` (`dart_generic`)

## Extensions

No filename extensions are registered. The module is selected by the structured-log import flow for template-driven log formats.

## Capabilities

- `detect_by_extension`: `false`
- `inspect_schema`: `true`
- `preview_rows`: `true`
- `import_full`: `true`
- `supports_cancellation`: `true`
- `supports_rejected_rows`: `true`
- `can_export_recipe`: `true`

## Type Fidelity

Recognized template fields are parsed as text or numbers and can be overridden before import.

## Limitations

- Template selection is required for IIS W3C, Apache/Nginx access, and key=value app logs; no filename extensions are registered.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
