## DecentDB v2.17.0 upgrade and the format-14 guided in-place migration contract
**Date:** 2026-08-04
**Status:** Accepted

### Decision

Upgrade the pinned DecentDB engine from `v2.14.0` to `v2.17.0` and ship a
guided **in-place** upgrade flow that automatically rewrites every existing
user database from on-disk format 13 to format 14. The upgrade is mandatory,
one-way, and irreversible from inside Decent Bench.

Concretely:

1. The Dart binding ref is bumped to `v2.17.0` in `apps/decent-bench/pubspec.yaml`.
2. The Decent Bench app version is bumped to `3.0.0+1` (per
   `design/VERSIONING_GUIDE.md`: a change that renders every existing user
   file unopenable without a migration is a Major bump).
3. On open, when the engine reports
   `"unsupported database format version: 13"`,
   `DecentDbMigrationService.isUnsupportedFormatVersionMessage` matches and
   the open path routes the user into a new
   `DecentDbInPlaceMigrationDialog` instead of the prior
   destination-picker dialog.
4. The dialog warns that the upgrade is one-way: older Decent Bench builds
   and older DecentDB releases will refuse to open the upgraded file.
5. The user confirms, then `DecentDbMigrationService.migrateInPlace(...)`
   runs end-to-end against the official `decentdb-migrate` CLI.
6. The user's original filename is preserved; the original file is moved
   aside to `<name>.ddb.v13.bak` so it remains an explicit recovery handle
   until the user deletes it.
7. Headless `import_runner.dart` and `quality_runner.dart` catch the same
   error message and emit an actionable invocation hint naming
   `decentdb-migrate`, instead of just logging a failure.

### Rationale

- DecentDB v2.17.0 ships an on-disk format bump (13 → 14) that is enforced
  strictly (`crates/decentdb/src/storage/header.rs:80`):
  `if (header.format_version != DB_FORMAT_VERSION) throw UnsupportedFormatVersion;`.
  There is no read-compatibility shim, no forward compatibility, and no
  per-feature flag to opt out.
- The upstream `decentdb-migrate` tool already ships in the same release
  archive as the CLI and library, so adding the in-place flow does not
  require a new artifact download path.
- The Dart binding's `.dart` files are byte-identical between `v2.14.0` and
  `v2.17.0`; only `bindings/dart/dart/pubspec.yaml` and the vendored
  `bindings/dart/native/decentdb.h` changed. This means existing bridge
  code keeps working without rewrites.
- The backup-then-swap pattern preserves the user's workspace identity
  (recent-files, project TOMLs, etc.) without requiring a file rename.
- The `.v13.bak` suffix keeps the legacy file visually distinct and easy to
  delete on success.

### Sidecar handling (explicit)

`migrate_v13_file` in `crates/decentdb-migrate/src/main.rs` carries the
source `.wal` forward but rejects formats 3/8/9 in the same way; it also
fails if the destination `.wal` already exists. The in-place flow:

- Excludes `.coord` from any carry-forward (it is rebuildable; carrying
  it forward risks stale cross-process coordination state).
- Carries `.wal` and `.sync-journal` aside to `<name>.v13.bak.<ext>` next to
  the original (so they survive if the user ever rolls back).
- Verifies the destination temp path is clean before invoking the tool
  (since `decentdb-migrate` refuses a pre-existing destination `.wal`).

### Failure / rollback

- Pre-migration: any failure leaves the original file untouched and the
  temp destination deleted.
- Mid-migration (after the original moved aside): the swap path attempts to
  restore the original from the `.v13.bak` and surfaces a
  `DecentDbMigrationFailure` describing the restore.
- Final swap failure: the original is moved back from the backup, the new
  file is deleted, and the user is told the original was restored.

The `.v13.bak` is **never** deleted automatically. It is the user's only
recovery handle if a downstream compatibility regression appears.

### Alternatives Considered

- **Out-of-place only.** Preserved as `DecentDbMigrationService.migrate()`.
  Rejected for the default flow because it breaks recent-files and
  workspace project references.
- **Defer the format-14 engine bump.** Rejected; users who upgrade the
  binary without also running `decentdb-migrate` would hit a hard open
  failure with no in-app remediation.
- **Ship a Dart-side format-13 reader.** Rejected; the engine itself
  rejects format 13 at the storage layer and the Dart binding has no
  read-side shim.

### Trade-offs

- Every existing user database becomes inaccessible until the user
  confirms the upgrade. Acceptable because the upgrade is one click and
  one dialog.
- The dialog must clearly warn that downgrade is impossible. We surface
  the warning in red `errorContainer` styling so it is hard to miss.
- The `.v13.bak` consumes disk equal to the database size until deleted.

### References

- Plan: `.kilo/plans/1785879082050-decentdb-2-17-upgrade.md`
- ADR-0003 pinned capability baseline (updated for v2.17.0)
- ADR-0025 git-dependency rationale (updated for v2.17.0)
- ADR-0058 schema-snapshot parity (no change required)
- `crates/decentdb/src/storage/header.rs`
- `crates/decentdb-migrate/src/main.rs`