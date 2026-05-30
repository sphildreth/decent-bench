# Markdown Tables Import Module

## Status

- Status: `complete`
- Priority: `P2`
- Adapter: `generic_markdown_table` (`dart_generic`)

## Extensions

`.md`

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

Markdown pipe-table cells are inferred from samples and imported with the normal DecentDB type coercion rules.

## Limitations

- Only Markdown pipe tables are imported; non-table markdown is ignored by the extractor.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
