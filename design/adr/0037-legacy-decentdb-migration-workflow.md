## Legacy DecentDB Migration Workflow
**Date:** 2026-05-19
**Status:** Accepted

### Decision

When opening a `.ddb` file fails because the file uses an unsupported legacy
DecentDB format version, Decent Bench will offer a guided migration path that
runs the official `decentdb-migrate` executable.

The workflow is copy-based:

- keep the source database untouched
- suggest a unique `*_migrated.ddb` destination beside the source file
- reject in-place or overwrite destinations
- run `decentdb-migrate --source <legacy.ddb> --dest <new.ddb>`
- open the migrated copy after a successful migration

Decent Bench resolves `decentdb-migrate` from an explicit
`DECENTDB_MIGRATE_PATH`/`DECENTDB_MIGRATE` override, PATH, a bundled packaged
tool, or the pinned DecentDB full release asset. The native-library staging
helper must stage both the DecentDB library and the migration tool for packaged
desktop builds.

### Rationale

The DecentDB documentation states that modern DecentDB intentionally does not
bundle legacy file parsers into the core engine and that older files should be
upgraded with the standalone official migration tool. It also documents the
safe copy-based `--source`/`--dest` workflow and says the tool does not
overwrite the source file in place.

Using the official tool keeps Decent Bench aligned with the pinned engine and
avoids maintaining file-format migration logic in the Flutter app.

### Alternatives Considered

- **Show only the raw engine error.** Simple, but it leaves users stuck at
  `unsupported database format version` with no path forward.
- **Implement migration in Dart.** Rejected because legacy DecentDB file parsing
  is engine-owned behavior and would be high risk for data correctness.
- **Auto-migrate in place.** Rejected because user data must not be overwritten
  without explicit review, and the official tool is designed to write a new
  file.

### Trade-offs

- The migration workflow depends on the `decentdb-migrate` executable being
  available or downloadable from the pinned release asset.
- Migration progress is currently process-level rather than per-table progress;
  richer progress can be added if the tool exposes structured output later.
- This is not general-purpose schema migration tooling. It only wraps the
  official legacy-file upgrade path.

### References

- DecentDB migration guide:
  https://decentdb.org/user-guide/migration/?h=decentdb+migration
- `design/SPEC.md`
- `design/PRD.md`
