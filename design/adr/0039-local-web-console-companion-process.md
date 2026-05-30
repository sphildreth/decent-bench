## Local Web Console Companion Process
**Date:** 2026-05-21
**Status:** Accepted

### Decision

Decent Bench may expose DecentDB v2.6.0's `decentdb serve` Web Console as an
optional companion process launched explicitly by the user, for example through
`Tools -> Open Web Console`.

The first implementation must:

- launch the official `decentdb` CLI, not replace the app's FFI query path
- default to `--read-only`
- keep localhost auth enabled
- bind only to localhost
- avoid exposing `--no-auth`, remote binding, broad CORS controls, or
  write-enabled console mode in the first UI
- manage process lifecycle, port selection, stdout/stderr capture, and shutdown
- package or locate the CLI through the same native-artifact discipline used
  for the DecentDB library and migration tool

The Web Console is a companion inspection surface, not the primary Decent Bench
workspace.

Implementation note: the v2.6.0 adoption slice includes CLI resolution/caching,
the Web Console process service, and `Tools -> Open Web Console`. The command
uses `decentdb serve --db=<current.ddb> --read-only --open` by default and does
not expose no-auth, remote binding, or CORS controls.

### Rationale

The official Web Console provides quick schema, SQL, EXPLAIN, history, limits,
and CSV export functionality that can help power users inspect a local database.
Using the upstream CLI avoids reimplementing the console inside Flutter.

Running a companion server changes security, packaging, and lifecycle behavior.
Conservative defaults preserve Decent Bench's local-first/privacy-first product
promise and avoid surprising users with a remotely reachable API.

### Alternatives Considered

- Do not expose the Web Console. This avoids process and auth complexity but
  leaves a useful upstream capability disconnected from the desktop workbench.
- Embed the Web Console in a Flutter WebView. Rejected for the first slice
  because it adds platform complexity and still needs a server/runtime boundary.
- Replace Decent Bench's native FFI path with `decentdb serve`. Rejected because
  ADR-0001 chooses official Dart FFI bindings for the desktop app.
- Launch write-enabled or unauthenticated by default. Rejected because it
  weakens local safety and increases accidental mutation risk.

### Trade-offs

- Packaging must include or locate an additional executable.
- The app must handle port conflicts, process crashes, browser launch failures,
  and shutdown races.
- Users may see two SQL surfaces with overlapping capabilities.
- Manual verification must include auth, read-only enforcement, and localhost
  binding behavior.

### References

- `design/DECENTDB_2_6_ENHANCEMENT_PLAN.md`
- `design/adr/0001-decentdb-flutter-binding-strategy.md`
- `design/adr/0009-desktop-native-library-packaging-and-resolution.md`
- `/home/steven/src/github/decentdb/docs/api/cli-reference.md`
