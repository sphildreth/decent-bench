## Structured DecentDB Error Diagnostics in Bridge Failure Mapping
**Date:** 2026-06-22
**Status:** Accepted

### Decision

The `DecentDbBridge` worker funnel `_bridgeFailureFromError` now extracts
the structured diagnostic fields exposed by `DecentDbException.diagnostic`
(`subcode`, `retryable`, `permanent`, `sqlstate`, `docAnchor`) and forwards
them into `BridgeFailure` so the rest of the app can surface them to users
without re-parsing `error.toString()`.

It also translates `DecentDbAbiMismatchException` and
`DecentDbNativeLoadException` into `BridgeFailure` with explicit
`code: 'DDB_ERR_ABI_MISMATCH'` and `code: 'DDB_ERR_NATIVE_LOAD'` codes
respectively. Previously these exceptions were not caught and surfaced as
raw `toString()` text.

The bridge failure JSON serialization (`_tryParseDiagnosticJson`) remains
in place as a fallback for the legacy path where the native side returns
the diagnostic as a JSON-encoded `toString()` payload.

### Rationale

The DecentDB v2.5.0 release added structured error diagnostics across Rust,
the C ABI, and the maintained bindings. The Dart binding exposes those
fields on `DecentDbException.diagnostic` (a `DecentDbDiagnostic`) and on
`DecentDbException` itself via `subcode`, `sqlstate`, `retryable`,
`permanent` getters. Without consuming those getters, the bridge was
ignoring a stable, machine-readable contract that other bindings already
expose to their UI layers.

Two failure modes were particularly user-visible:

- A native ABI version mismatch (engine staged at `v2.x` but Dart binding
  at `v2.y`, with `y != x`) surfaced as an opaque stack trace because
  `DecentDbAbiMismatchException` was never caught.
- A failed `DynamicLibrary.open` (missing artifact, wrong platform
  directory, quarantined by the OS) surfaced as an opaque
  `Invalid argument(s)` failure because `DecentDbNativeLoadException` was
  also not caught.

Both are now translated into `BridgeFailure` with stable codes so the
import wizard, schema browser, and results grid can show specific recovery
guidance ("align the Dart binding and native library versions", "re-stage
the native library at `<bundle>/lib/libdecentdb.so`").

### Alternatives Considered

1. Continue parsing `error.toString()` only and ignore
   `DecentDbException.diagnostic`.
   - Rejected: the structured contract is already on the exception object
     and the JSON-parsing path was a stopgap while waiting for the binding
     to expose the typed fields.
2. Re-throw `DecentDbAbiMismatchException` and `DecentDbNativeLoadException`
   unchanged so the UI layer can pattern-match on type.
   - Rejected: the rest of the bridge surface already returns
     `BridgeFailure`; introducing a second error type would force every
     caller to pattern-match on both, which is more invasive than the
     change above.

### Trade-offs

- The bridge worker now catches three exception types instead of one. This
  is contained to `_bridgeFailureFromError` and does not affect the
  per-action handlers.
- `BridgeFailure` already carries `subcode`, `retryable`, `permanent`,
  `sqlstate`, and `docAnchor` fields (defined in
  `query_phase_models.dart`). No model changes are required.

### References

- https://decentdb.org/about/changelog/ (v2.5.0 — structured error
  diagnostics)
- https://decentdb.org/api/dart/ (Dart error classes)
- `apps/decent-bench/lib/features/workspace/infrastructure/decentdb_bridge.dart`
- `apps/decent-bench/lib/features/workspace/domain/query_phase_models.dart`
