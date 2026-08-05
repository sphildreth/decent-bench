## Worker isolate restart on bridge timeout
**Date:** 2026-08-04
**Status:** Accepted

### Decision

The DecentDB bridge (`DecentDbBridge`) now (1) short-circuits control
requests (`openDatabase`, `loadSchema`, `getToolingMetadata`,
`loadOperationalMetrics`, `saveAs`, `evictSharedWal`, `listBranches`,
`listSnapshots`) when the worker isolate is already busy, returning a
fast `DDB_ERR_WORKER_BUSY` failure instead of queueing behind the
in-flight op; and (2) restarts the worker isolate (kill + respawn) when
any request times out, failing all other pending completers with
`DDB_ERR_WORKER_RESTARTED`.

The workspace controller additionally wraps `describeQueryContract` in a
short 10s timeout and falls back to running the query without a
parameter contract when describe returns `DDB_ERR_TIMEOUT`,
`DDB_ERR_WORKER_BUSY`, or `DDB_ERR_WORKER_RESTARTED`, so a stuck
metadata call cannot wedge a query.

### Rationale

The worker isolate processes requests **serially** in a single
`await for` loop and every native call (`Db::open`,
`describeQueryContract`, `runQuery`, `listBranches`, ...) runs
synchronously on that isolate and cannot be interrupted. The Dart-side
`completer.future.timeout()` only abandons the awaiting caller; the
native call inside the isolate keeps running. A wedged op therefore
blocks every subsequent request — including `openDatabase` for an
unrelated file — until it returns, which surfaced as a misleading
"openDatabase timed out after 30-60s" error that blamed the file being
opened rather than the prior stuck operation.

Observed in production logs: a `run_query` on `musicbrainz.ddb` whose
`describeQueryContract` step hung caused three consecutive
`openDatabase` attempts for `artistSearchEngine.ddb` to time out at
30-60s each, because each was queued behind the still-running musicbrainz
query on the shared isolate. Standalone, `openDatabase` for
`artistSearchEngine.ddb` completes in ~25ms.

### Alternatives Considered

- **Native cancellation hook.** Add a `ddb_cancel_pending` C ABI call
  that interrupts the in-flight native op. Rejected for now: it requires
  engine-side cooperative cancellation support that does not exist in
  the v2.17 binding, and most stuck ops are in non-cancellable code
  paths (storage replay, plan analysis). Killing the isolate is the
  only reliable interrupt today. Revisit when the engine exposes an
  interrupt primitive.
- **Per-request isolate pool.** Spawn a fresh isolate per request so a
  stuck op cannot block others. Rejected: the engine handle is owned by
  the isolate and expensive to recreate (re-open + re-load schema); a
  pool would multiply that cost and complicate cursor/cursor-id
  ownership.
- **Do nothing / raise timeouts.** Rejected: the symptom is not a slow
  engine but a wedged isolate; raising `DECENT_BENCH_OPEN_TIMEOUT_MS`
  only makes the user wait longer before the same failure.

### Trade-offs

- After a restart the worker has no open database handle; callers must
  re-open before further schema/query ops. The controller's
  `openDatabase` flow already re-opens, and the restart error message
  instructs the user to reopen the workspace.
- A timed-out request that would have completed a moment after the
  timeout is abandoned (its result is dropped). This is intentional: the
  user has already waited the full timeout and the operation is treated
  as failed.
- The busy short-circuit can refuse a legitimate concurrent control
  request during a brief normal op. In practice the worker is idle
  between requests (`_inFlight == 0`), so the short-circuit only fires
  when a prior op has genuinely not returned.

### References

- `apps/decent-bench/lib/features/workspace/infrastructure/decentdb_bridge.dart`
  — `_request`, `_restartWorker`, `_controlActions`, `_inFlight`
- `apps/decent-bench/lib/features/workspace/application/workspace_controller.dart`
  — `_describeQueryContractSafe`, `_describeQueryContractTimeout`
- `apps/decent-bench/test/features/workspace/infrastructure/decentdb_bridge_worker_recovery_test.dart`
- `apps/decent-bench/test/features/workspace/application/workspace_controller_test.dart`
  — "runTab still executes SQL when describeQueryContract times out"