# ZIP Wrapper Import Module

## Status

- Status: `complete`
- Priority: `P0`
- Adapter: `zip_wrapper` (`wrapper`)

## Extensions

`.zip`

## Capabilities

- `detect_by_extension`: `true`
- `inspect_schema`: `true`
- `supports_archives`: `true`
- `supports_cancellation`: `true`

## Type Fidelity

This module declares type mapping behavior in `module.toml`. Current built-in adapters preserve values according to the existing Decent Bench import path and surface warnings when conversion is lossy or unsupported.

## Limitations

- No module-specific limitations beyond normal import validation.

## Fixtures

Fixture metadata is declared in `module.toml`. See `fixtures/README.md` for executable fixtures or deterministic generation notes.
