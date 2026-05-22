# PDF Tables Import Module

## Status

- Status: `deferred`
- Priority: `P3`
- Adapter: `none` (`none`)

## Extensions

`.pdf`

## Capabilities

- `detect_by_extension`: `true`

## Type Fidelity

This module declares type mapping behavior in `module.toml`. Current built-in adapters preserve values according to the existing Decent Bench import path and surface warnings when conversion is lossy or unsupported.

## Limitations

- PDF extraction quality and correction UX are not good enough yet.

## Fixtures

Fixture metadata is declared in `module.toml`. See `fixtures/README.md` for executable fixtures or deterministic generation notes.
