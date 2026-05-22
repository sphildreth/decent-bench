## Built-In Import Module Manifest Contract
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench will introduce a built-in import module catalog. Each built-in
import source, wrapper, direct-open path, planned format, investigated format,
deferred format, and accepted future candidate will be represented by a module
manifest.

Module manifests are TOML documents stored under:

```text
apps/decent-bench/import_modules/builtin/<module_id>/module.toml
```

Every built-in module directory also contains module documentation and fixture
metadata:

```text
apps/decent-bench/import_modules/builtin/<module_id>/
  module.toml
  README.md
  fixtures/
```

The manifest contract is versioned with `schema_version = 1`. The first schema
version includes declarative metadata for:

- stable module id,
- module kind,
- support status,
- roadmap priority,
- display name,
- import family,
- summary and description,
- detection rules,
- support and implementation metadata,
- capabilities,
- adapter binding,
- supported action ids,
- user-configurable options,
- type mapping and fidelity notes,
- module-contributed quality check declarations,
- limitations,
- documentation references,
- fixture references.

Module manifests are declarative metadata only. They must not contain scripts,
shell commands, executable SQL, dynamic library paths, package installation
instructions, arbitrary file-system paths, or callback-like values.

The module catalog becomes the source of truth for import format metadata. The
existing `ImportFormatRegistry` remains available only as a compatibility layer
while call sites migrate. Its format definitions must be generated from or
loaded from module manifests, not independently maintained.

The app runtime will consume generated Dart catalog constants derived from the
TOML manifests. Tests and development tooling may load TOML files directly from
disk. The TOML manifests remain the source of truth, and tests must fail if the
generated catalog is stale.

Manifest validation is strict:

- Unknown required fields fail.
- Missing required fields fail.
- Unknown enum values fail.
- Duplicate module ids fail.
- Duplicate extension ownership fails unless an explicit conflict rule is
  added through a later ADR.
- Complete and partial modules must reference a registered adapter id.
- Complete modules must provide documentation and fixture coverage or
  deterministic fixture generation notes.
- Partial modules must provide at least one limitation.

Debug, test, and generator flows fail fast when the module catalog is invalid.
Release builds should be produced only from a validated generated catalog. If a
release build detects an impossible catalog or adapter mismatch at startup, it
must disable the affected module and surface a clear diagnostic rather than
launching a broken import workflow.

### Rationale

Import support is expected to grow well beyond the current set of implemented
formats. A hardcoded registry and scattered documentation will become brittle
as Decent Bench adds analytical, geospatial, archive, legacy business, log,
finance, healthcare, and data-science sources.

A built-in module manifest gives each format one authoritative home for the
metadata that users, docs, tests, detection, and routing all need. TOML matches
the repository's existing preference for user-reviewable configuration.

Keeping manifests declarative preserves security and maintainability. A module
can describe that it uses a reviewed adapter, but it cannot itself execute code
or smuggle runtime behavior through the manifest.

Generated Dart constants give the runtime a predictable catalog without
depending on Flutter asset directory traversal or runtime TOML parsing. Direct
TOML loading remains available to tests and tooling so the source manifests can
be validated and kept authoritative.

Strict validation is required because the module catalog will drive import
routing and user-visible format claims. Bad metadata should fail before a
release is produced.

### Alternatives Considered

- Continue using the hardcoded Dart `ImportFormatRegistry`.
  Rejected because it requires code changes for every metadata update and
  leaves docs, fixtures, and future format status disconnected.

- Store module metadata only in Markdown documentation.
  Rejected because docs are not structured enough to drive detection, routing,
  capability checks, and test validation.

- Load arbitrary module manifests from user directories.
  Rejected for this ADR because external modules require a separate trust,
  signing, sandboxing, and dependency policy.

- Let TOML manifests contain executable actions.
  Rejected because it would create a script/plugin system without the required
  security model.

- Bundle TOML files as Flutter assets and parse them at runtime.
  Rejected for the initial implementation because generated constants provide
  a stronger build-time validation point and simpler packaged-app behavior.

- Use JSON or YAML for module manifests.
  Rejected because Decent Bench already uses TOML for project/config style
  documents and TOML is readable for long-lived reviewable metadata.

### Trade-offs

- Generated catalog constants add a tooling step, but they make release builds
  deterministic and avoid runtime asset discovery issues.
- Strict validation may slow casual metadata edits, but it prevents stale,
  contradictory, or unsafe import claims from reaching users.
- TOML manifests duplicate some information currently present in Dart. During
  migration the compatibility layer will temporarily bridge both shapes, but
  the module catalog is the long-term source of truth.
- Keeping modules built-in limits extensibility at first, but avoids a plugin
  trust problem while the core catalog and adapter contracts stabilize.

### References

- `design/WIN_IMPORT_MODULAR_PLAN.md`
- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`
- `design/IMPORT_FORMATS.md`
- `apps/decent-bench/lib/features/import/infrastructure/import_format_registry.dart`
- `design/adr/0050-import-adapter-and-typed-batch-contract.md`
- `design/adr/0051-worker-backed-import-module-protocol.md`
- `design/adr/0052-external-import-module-trust-boundary.md`

