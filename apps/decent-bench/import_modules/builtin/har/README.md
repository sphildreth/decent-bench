# HAR Import Module

## Status

- Status: `complete`
- Priority: `P1`
- Adapter: `generic_har` (`dart_generic`)

## Extensions

`.har`

## Capabilities

- `detect_by_extension`: `true`
- `inspect_schema`: `true`
- `preview_rows`: `true`
- `import_full`: `true`
- `supports_multiple_tables`: `true`
- `supports_cancellation`: `true`
- `supports_rejected_rows`: `true`
- `can_export_recipe`: `true`

## Type Fidelity

HAR request, response, timing, and header scalar values are mapped into linked tables and inferred from samples.

## Limitations

- Response bodies and POST bodies are summarized by size and MIME metadata instead of being imported as full payload tables.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
