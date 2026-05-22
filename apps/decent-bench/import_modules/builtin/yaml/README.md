# YAML Import Module

## Status

- Status: `investigate`
- Priority: `P2`
- Adapter: `none` (`none`)

## Extensions

`.yaml`, `.yml`

## Capabilities

- `detect_by_extension`: `true`

## Type Fidelity

This module declares type mapping behavior in `module.toml`. Current built-in adapters preserve values according to the existing Decent Bench import path and surface warnings when conversion is lossy or unsupported.

## Limitations

- YAML parsing is not implemented and arbitrary config is not always tabular.

## Fixtures

Fixture metadata is declared in `module.toml`. See `fixtures/README.md` for executable fixtures or deterministic generation notes.
