# PostgreSQL Plain SQL Dump Import Module

## Status

- Status: `complete`
- Priority: `P1`
- Adapter: `legacy_sql_dump` (`legacy_wizard`)

## Extensions

No filename or signature-based detection is registered. The module is routed through the existing SQL dump wizard when the payload is identified as a PostgreSQL plain dump.

## Capabilities

- `detect_by_extension`: `false`
- `detect_by_signature`: `false`
- `inspect_schema`: `true`
- `preview_rows`: `true`
- `import_full`: `true`
- `import_selected_tables`: `true`
- `supports_multiple_tables`: `true`
- `supports_cancellation`: `true`
- `preserves_logical_types`: `true`
- `preserves_constraints`: `true`
- `can_export_recipe`: `true`

## Type Fidelity

PostgreSQL column declarations are mapped into DecentDB-compatible target types and can be overridden.

## Limitations

- COPY FROM stdin and PostgreSQL identifier/type handling are covered by the SQL dump wizard, but this is still not a standalone file detector.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
