# MS SQL Server Backup Import Module

## Status

- Status: `investigate`
- Priority: `P2`
- Adapter: `none` (`none`)

## Extensions

`.bak`

## Capabilities

- `detect_by_extension`: `true`

## Type Fidelity

This module declares type mapping behavior in `module.toml`. Current built-in adapters preserve values according to the existing Decent Bench import path and surface warnings when conversion is lossy or unsupported.

## Limitations

- SQL Server restore tooling and licensing need review.

## Fixtures

Fixture metadata is declared in `module.toml`. See `fixtures/README.md` for executable fixtures or deterministic generation notes.
