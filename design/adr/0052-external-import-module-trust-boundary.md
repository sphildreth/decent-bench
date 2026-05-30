## External Import Module Trust Boundary
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench will not load external third-party import modules as part of the
modular import architecture Future Win.

Only built-in modules bundled with the application are supported:

```text
apps/decent-bench/import_modules/builtin/
```

The app will ignore module manifests from user directories, project
directories, workspace directories, downloaded packages, shared folders, or
environment-configured paths.

External module support is deferred until a future PRD/SPEC update and ADR
define a complete trust model. That future trust model must decide:

- whether external modules are supported at all,
- manifest signing,
- publisher identity,
- local trust prompts,
- module disable and removal flows,
- sandboxing limits,
- dependency installation policy,
- runtime permission model,
- compatibility versioning,
- review and marketplace rules if any.

Current built-in module manifests remain declarative. They cannot declare
arbitrary executable paths or package installation commands. Worker-backed
behavior is allowed only through reviewed built-in adapter entrypoint ids as
defined by the worker-backed import module protocol ADR.

Project files and import recipes may reference built-in module ids and module
options. They may not reference external module locations or custom executable
adapters.

Documentation may discuss future external modules only as deferred strategic
work. User-facing app surfaces must not imply that external import modules can
be installed or loaded.

### Rationale

A module catalog is needed now to scale built-in import support. A third-party
module ecosystem is a different product and security problem.

Import modules can process sensitive local files. If external modules were
loadable, they could potentially read data, execute code, exfiltrate content,
install dependencies, or alter import outputs. That requires a real trust and
sandbox model, not an incidental extension of the built-in catalog.

Keeping the first modular import implementation built-in lets Decent Bench get
the immediate benefits:

- consistent format metadata,
- docs synchronization,
- fixture validation,
- adapter routing,
- future high-fidelity worker support,
- safer connector expansion.

Those benefits do not require external module loading.

### Alternatives Considered

- Support external modules immediately.
  Rejected because there is no accepted signing, sandboxing, dependency, or
  trust prompt model.

- Allow user-authored TOML manifests for metadata-only formats.
  Rejected for now because metadata-only modules would still affect detection,
  routing, docs, and recipe behavior, and could mislead users into believing an
  unsupported parser exists.

- Allow project-local modules.
  Rejected because project files should remain portable workflow metadata, not
  executable extension bundles.

- Allow external modules only when they point to installed Python packages.
  Rejected because that still creates runtime dependency, code execution, and
  licensing problems.

- Hide the external module question entirely.
  Rejected because the module architecture naturally raises plugin/marketplace
  expectations. The boundary should be explicit.

### Trade-offs

- Users and teams cannot add custom importers without changing the app, but
  the built-in catalog can still track candidate formats and accept new
  built-in adapters through normal development.
- Deferring external modules slows ecosystem extensibility, but avoids creating
  a security-sensitive plugin platform before the core import contract is
  stable.
- Import recipes are less flexible without external module references, but they
  remain safe, reviewable, and compatible across installations.

### References

- `design/WIN_IMPORT_MODULAR_PLAN.md`
- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`
- `design/FUTURE_WINS.md`
- `design/adr/0049-built-in-import-module-manifest-contract.md`
- `design/adr/0050-import-adapter-and-typed-batch-contract.md`
- `design/adr/0051-worker-backed-import-module-protocol.md`
- `design/adr/0042-lua-extension-management-trust-model.md`

