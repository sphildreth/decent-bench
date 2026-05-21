## Lua Extension Management Trust Model
**Date:** 2026-05-21
**Status:** Proposed

### Decision

Decent Bench may start with read-only Lua extension discovery through
DecentDB's `sys.extension_*` inspection views. Any extension validation,
install, enable, disable, purge, rebuild, or execution-trust workflow must use
an explicit trust model and must not run enabled extension code unless the
current connection was opened with an exact trusted package identity.

The first lifecycle UI, if implemented, must:

- use official DecentDB CLI commands or future public Dart APIs
- validate packages before install
- require signed packages or an exact `name@sha256:<hash>` trust entry for
  execution
- keep unsigned-development overrides hidden from normal users unless an
  explicit debug/development setting is enabled
- show package name, version, content hash, signature/trust state, enabled
  state, and declared SQL objects before execution is allowed
- avoid automatic trust of newly installed packages

Decent Bench will not implement a package registry, dependency resolver, or
native-code extension loading model as part of this phase.

### Rationale

DecentDB v2.6.0 Lua extensions are intentionally sandboxed, but they still add
SQL-visible code execution. Decent Bench must preserve local safety and make
trust explicit. Read-only discovery is useful and low risk; lifecycle and trust
controls are security-sensitive and need a durable decision record.

The engine's package hash and signature model provides a concrete boundary that
the app can surface instead of inventing its own trust semantics.

### Alternatives Considered

- Do not expose extensions at all. This is safest but hides useful metadata for
  databases that already use extensions.
- Install and enable unsigned packages for convenience. Rejected because it
  weakens the trust boundary and normalizes development-only behavior.
- Trust packages automatically after install. Rejected because install and
  execution trust are separate DecentDB concepts.
- Call private C ABI lifecycle bridges directly. Rejected unless superseded by
  a future ADR, because the app should prefer official CLI or public Dart APIs.
- Build a package manager. Rejected as a separate product surface outside the
  current workbench scope.

### Trade-offs

- Extension lifecycle UI will be more deliberate than a simple install button.
- Users may need to understand content hashes and trust entries before running
  extension code.
- The app gains security-sensitive state that must be tested carefully.
- Autocomplete can only suggest extension functions confidently after trusted
  package metadata is loaded.

### References

- `design/DECENTDB_2_6_ENHANCEMENT_PLAN.md`
- `design/PRD.md` section 9.4
- `design/SPEC.md` section 9
- `/home/steven/src/github/decentdb/docs/user-guide/lua-extensions.md`
- `/home/steven/src/github/decentdb/docs/api/cli-reference.md`

