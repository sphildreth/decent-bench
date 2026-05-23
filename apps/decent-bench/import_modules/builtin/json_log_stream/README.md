# JSON Log Stream Import Module

## Status

- Status: `complete`
- Priority: `P1`
- Adapter: `generic_json_log_stream` (`dart_generic`)

## Extensions

No filename extensions are registered. The module is selected through the log-stream import flow for JSON line payloads.

## Capabilities

- `detect_by_extension`: `false`
- `inspect_schema`: `true`
- `preview_rows`: `true`
- `import_full`: `true`
- `supports_cancellation`: `true`
- `supports_rejected_rows`: `true`
- `can_export_recipe`: `true`

## Type Fidelity

JSON log scalar fields are flattened and inferred from sampled values, and detected timestamps are copied into `_event_timestamp`.

## Limitations

- No filename or signature-based auto-detection is registered.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
