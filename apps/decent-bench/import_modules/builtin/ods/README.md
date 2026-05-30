# OpenDocument Spreadsheet Import Module

## Status

- Status: `complete`
- Priority: `P1`
- Adapter: `generic_ods` (`dart_generic`)

## Extensions

`.ods`

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

ODS cell values are read from cached XML data. Text, number, boolean, and date/time cells are inferred from samples and can be overridden before import. Formula cells import cached values when present.

## Limitations

- Styling, macros, and workbook metadata are not imported as data rows.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
