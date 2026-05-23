# Fixed-width Text Import Module

## Status

- Status: `complete`
- Priority: `P1`
- Adapter: `generic_fixed_width` (`dart_generic`)

## Extensions

`.fwf`

## Capabilities

- `detect_by_extension`: `true`
- `inspect_schema`: `true`
- `preview_rows`: `true`
- `import_full`: `true`
- `supports_cancellation`: `true`
- `supports_rejected_rows`: `true`
- `can_export_recipe`: `true`

## Type Fidelity

Column boundaries are inferred from whitespace-aligned samples, and cell values are coerced into the normal DecentDB import types.

## Limitations

- Single-table fixed-width files only; malformed rows can be rejected when they do not fit the inferred boundaries.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
