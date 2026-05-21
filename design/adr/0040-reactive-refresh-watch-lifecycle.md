## Reactive Refresh Watch Lifecycle
**Date:** 2026-05-21
**Status:** Proposed

### Decision

Decent Bench will use DecentDB reactive subscriptions only through a public Dart
API when one is available. Until then, reactive refresh remains blocked. Decent
Bench will not call private Dart binding internals or directly wire C ABI watch
handles without a superseding ADR.

When implemented, reactive subscriptions will be owned by the local gateway and
run off the UI thread. They will be used to:

- refresh schema metadata after committed app-owned writes
- mark result sets stale when watched tables or queries change
- expose watch lag/drop diagnostics from `sys.reactive_metrics`

Reactive events must not silently re-run arbitrary user queries or mix old
result pages with new database state. Result refresh remains an explicit user
or controller action unless a narrower workflow is later specified.

### Rationale

Reactive subscriptions can make Decent Bench feel more accurate after inline
edits, imports, and other app-owned writes. They also provide a cleaner signal
than broad polling once public Dart support exists.

The watch lifecycle is long-lived and cancellation-sensitive. It crosses the
same boundaries as query execution: isolates, native handles, stale event
ordering, and UI state. That makes a deliberate gateway-owned lifecycle safer
than ad hoc widget-level subscriptions.

### Alternatives Considered

- Keep manual refresh only. This is simple but gives users stale schema/results
  after app-owned writes.
- Poll schema and result metadata periodically. Rejected for the first design
  because it wastes work and still needs stale-event handling.
- Call the v2.6.0 C ABI watch handles directly from Decent Bench. Rejected
  unless superseded because ADR-0001 prefers the public upstream Dart binding.
- Automatically re-run affected queries. Rejected because expensive or mutating
  queries could run unexpectedly and obscure result provenance.

### Trade-offs

- This phase is blocked until public Dart APIs exist or a future ADR accepts a
  lower-level bridge.
- The app gains subscription lifecycle state that must be disposed reliably.
- Users get clearer freshness signals, but not fully automatic live query
  behavior.
- Tests must cover stale-event suppression, cancellation, and database-close
  cleanup.

### References

- `design/DECENTDB_2_6_ENHANCEMENT_PLAN.md`
- `design/adr/0001-decentdb-flutter-binding-strategy.md`
- `design/adr/0002-results-paging-and-streaming-contract.md`
- `/home/steven/src/github/decentdb/docs/about/changelog.md`
- `/home/steven/src/github/decentdb/docs/api/c-cpp.md`

