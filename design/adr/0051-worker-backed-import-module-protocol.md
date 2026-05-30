## Worker-Backed Import Module Protocol
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench may use worker-backed import adapters for built-in modules when a
format needs parser ecosystems, native libraries, or runtime isolation that are
not practical in Dart.

Worker-backed modules are built-in only. This ADR does not allow third-party
external workers, user-authored workers, runtime package installation, or
marketplace modules.

The first supported worker shape is a child process launched by Decent Bench
from a reviewed adapter entrypoint id. Module manifests may name the entrypoint
id, but they may not name executable paths, shell commands, command-line
fragments, or package installation instructions.

The worker protocol is named `typed_batch_v1`.

`typed_batch_v1` uses:

- a JSON Lines control plane over worker stdin/stdout,
- app-owned temporary job directories for large payloads,
- structured JSON envelopes for requests, progress, warnings, errors, and
  completion,
- typed batch payload files referenced from JSON envelopes.

The initial payload encoding for typed batches is a manifest JSON file plus
typed JSON Lines batch files. Arrow IPC or another binary columnar payload may
be added only after dependency and license review proves a stable
Apache-compatible path for all supported desktop platforms.

Workers support these request types:

- `hello`,
- `capabilities`,
- `probe`,
- `inspect`,
- `preview`,
- `import_batches`,
- `cancel`.

Workers emit these response/event types:

- `ready`,
- `capabilities`,
- `probe_result`,
- `inspection_result`,
- `preview_batch`,
- `typed_batch`,
- `progress`,
- `warning`,
- `error`,
- `completed`,
- `cancelled`.

Every worker job receives:

- module id,
- job id,
- selected source path or source URI,
- validated module options,
- app-created temporary job directory,
- requested action,
- size and row limits for preview actions,
- protocol version.

Workers must not write directly into the user's DecentDB database. Workers
parse source data and emit typed schemas, previews, warnings, and typed batch
payloads. The Decent Bench app writes the DecentDB file through the shared
adapter/writer path.

Cancellation is cooperative first:

1. The app sends a `cancel` message.
2. The worker should stop after the current bounded read, batch, or parser
   unit.
3. If the worker does not exit within the configured timeout, the app may
   terminate the child process.
4. Cancelled jobs must clean up temporary payloads best-effort.

Worker stderr is diagnostic logging only. Machine-readable protocol messages
must use stdout JSON Lines. A worker that writes malformed protocol messages is
treated as failed.

No worker may install dependencies at runtime. Worker dependencies must be
bundled with the app or resolved through an explicitly documented local runtime
contract accepted for that worker. All worker dependencies require
Apache-compatible license review and third-party notice updates before the
worker-backed module is marked complete.

Python is an allowed worker runtime for future built-in modules because of its
strong data-file ecosystem. Adding any concrete Python-backed module still
requires:

- dependency review,
- packaging plan for Linux, macOS, and Windows,
- startup/performance tests,
- cancellation tests,
- fixture tests,
- third-party notices.

Additional worker runtimes require an ADR update or a new ADR.

### Rationale

Some high-value formats have mature Python, native, or process-oriented parser
ecosystems but weak Dart support. A worker protocol lets Decent Bench use those
ecosystems without moving the entire import engine out of Dart.

Using a JSON Lines control plane keeps progress, errors, and cancellation easy
to inspect and test. Using app-owned temporary payload files avoids pushing
large data through stdout and leaves room for a future binary columnar payload
after dependency review.

Keeping DecentDB writes inside the app preserves transaction semantics,
rollback behavior, provenance integration, quality checks, and consistent
type-mapping policy.

Prohibiting runtime dependency installation avoids non-reproducible imports,
network requirements, packaging surprises, and licensing ambiguity.

### Alternatives Considered

- Move the full import engine to Python.
  Rejected because current Dart import paths work, Flutter integration and
  DecentDB writing are app-owned, and a full migration would create packaging
  and dependency risk for simple formats.

- Forbid non-Dart import workers entirely.
  Rejected because formats such as Parquet, Avro, statistical packages, and
  specialized legacy formats may be much more practical through external parser
  ecosystems.

- Use SQLite files as the worker output format.
  Rejected because SQLite does not preserve enough source type fidelity for the
  long-term import goals.

- Stream all row data as JSON over stdout.
  Rejected for large imports because stdout becomes a bottleneck and makes
  cancellation/recovery harder.

- Require Arrow IPC immediately.
  Rejected for the initial protocol because the Dart-side dependency path must
  be reviewed before committing to Arrow as a required runtime format.

- Allow module manifests to name arbitrary worker executables.
  Rejected because it would turn metadata into an execution surface.

### Trade-offs

- JSON Lines plus file-backed payloads are less efficient than a mature binary
  columnar protocol, but they are simple, testable, and dependency-light for
  the first worker contract.
- Process workers add startup overhead, but they isolate native/parser failures
  and allow cancellation by process termination when cooperative cancellation
  fails.
- Python support can unlock many formats, but packaging Python and native
  wheels across platforms is a real maintenance cost. Each concrete worker
  still needs dependency and packaging review.
- Keeping workers away from direct DecentDB writes may require extra data
  transfer, but it keeps write safety and transaction behavior centralized.

### References

- `design/WIN_IMPORT_MODULAR_PLAN.md`
- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`
- `design/adr/0049-built-in-import-module-manifest-contract.md`
- `design/adr/0050-import-adapter-and-typed-batch-contract.md`
- `design/adr/0052-external-import-module-trust-boundary.md`

