# XZ Wrapper Import Module

## Status

- Status: `complete`
- Priority: `P2`
- Adapter: `xz_wrapper` (`wrapper`)

## Extensions

`.tar.xz`, `.txz`, `.xz`

## Capabilities

- `detect_by_extension`: `true`
- `inspect_schema`: `true`
- `supports_archives`: `true`
- `supports_cancellation`: `true`

## Type Fidelity

This wrapper does not import rows directly. It inspects the archive wrapper and hands the extracted inner source off to the normal import flow.

## Limitations

- No direct preview or import path is exposed for the wrapper itself.

## Fixtures

The manifest declares a generated smoke fixture for catalog validation. See `fixtures/README.md` for the fixture contract and any future executable sample data.
