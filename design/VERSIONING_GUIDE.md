# Decent Bench Versioning Guide

This guide defines how Decent Bench version bumps work, which files must be
updated, and how to choose the right SemVer increment.

## 1. Versioning policy

Decent Bench uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- **Major (`X.0.0`)** for breaking changes to the workspace file contract,
  user-facing workflow, configuration format, export format defaults, or the
  pinned DecentDB compatibility line.
- **Minor (`X.Y.0`)** for backwards-compatible feature additions, new import
  formats, new export formats, new editor capabilities, schema browser
  expansion, or UI additions that do not remove or alter existing behavior.
- **Patch (`X.Y.Z`)** for backwards-compatible bug fixes, packaging adjustments,
  CI fixes, dependency version bumps that do not change behavior, performance
  improvements without API changes, and documentation updates.

### Choosing the bump when a branch has mixed changes

Pick the **highest-impact** change class in the branch:

1. Any breaking change => **Major**
2. Otherwise, any new user-visible feature or capability => **Minor**
3. Otherwise (fixes, tooling, docs, refactors, perf only) => **Patch**

Examples:
- New import format + bug fix in one branch => **Minor** (not Patch)
- Docs + CI + dependency bump only => **Patch**
- Config schema migration required + new export format => **Major** (even though
  there's a feature addition, the breaking config change dominates)
- Refactored isolate worker with no behavior change + test reorganization =>
  **Patch**

### What counts as breaking for a desktop application

Since Decent Bench is a desktop app (not a library with a public API), breaking
changes are defined in terms of user-facing compatibility:

| Change | Version impact |
|---|---|
| Workspace state file format changes that prevent loading old state | Major |
| Configuration TOML schema migration required (config_version bump) | Major |
| Pinned DecentDB engine version changes across a compatibility boundary (e.g., v2.x → v3.x with different SQL surface) | Major |
| Removal of a supported import or export format | Major |
| Export CSV defaults change (different delimiter, quote behavior) | Major |
| Menu shortcuts or command IDs change (breaks muscle memory / automation) | Major |
| Theme file format changes that reject old themes | Major |
| Headless CLI flag removal or semantics change | Major |
| New import format added | Minor |
| New export format added | Minor |
| New editor feature (autocomplete source, snippet, formatter improvement) | Minor |
| Schema browser expansion to new object kinds | Minor |
| Data visualization or charting added | Minor |
| New CLI flag added (backwards-compatible) | Minor |
| Command palette added | Minor |
| Bug fix preserving intended behavior | Patch |
| Performance improvement with no API change | Patch |
| Test reorganization or coverage improvement | Patch |
| Dependency version bump (compatible range) | Patch |
| CI pipeline fix | Patch |
| Documentation update | Patch |

### Pinned engine version vs. Decent Bench version

Decent Bench pins a specific DecentDB version via git ref in `pubspec.yaml`:

```yaml
decentdb:
  git:
    url: https://github.com/sphildreth/decentdb
    path: bindings/dart/dart
    ref: v2.3.0
```

The DecentDB engine version and the Decent Bench application version are
independent. Updating the pinned engine version within the same major line
(v2.x → v2.y) is a **Patch** bump for Decent Bench if no Decent Bench behavior
changes are required. If the engine update enables new features that Decent
Bench exposes to users (new SQL syntax, new functions), that is a **Minor** bump.

Changing the pinned engine across a major version boundary (v2.x → v3.x) is
a **Major** bump for Decent Bench because the SQL surface, type system, or file
format may be incompatible.

## 2. Where version numbers live

### Source of truth

The authoritative version is in **two places** that must stay synchronized:

1. **`apps/decent-bench/lib/app/app_metadata.dart`** — The `kDecentBenchVersion`
   constant. This is the canonical version surfaced to users in the About dialog,
   CLI `--version` output, and theme compatibility checks. **All Dart code
   references this constant** rather than hard-coding version strings.

   ```dart
   const String kDecentBenchVersion = '1.1.0';
   const String kDecentBenchDisplayName = 'Decent Bench';
   ```

2. **`apps/decent-bench/pubspec.yaml`** — The `version` field. Uses the
   `X.Y.Z+BUILD` format where `+BUILD` is the Flutter build number (incremented
   on each release, not semantically meaningful).

   ```yaml
   version: 1.1.0+2
   ```

### Files that auto-update (no manual edit needed)

These files consume `kDecentBenchVersion` and automatically reflect the new
version:

| File | How it references the version |
|---|---|
| `lib/app/startup_launch_options.dart` | `'$kDecentBenchDisplayName $kDecentBenchVersion'` for `--version` and `--help` |
| `lib/features/workspace/presentation/workspace_screen.dart` | `applicationVersion: kDecentBenchVersion` in About dialog |
| `lib/app/theme_system/theme_validator.dart` | `appVersion = kDecentBenchVersion` for theme compatibility checking |
| `lib/app/theme_system/theme_presets.dart` | `minDecentBenchVersion: kDecentBenchVersion` for emergency fallback theme |

### Files that need manual version bumps

These files have hard-coded version strings that must be updated:

| File | What to update | Impact if missed |
|---|---|---|
| `apps/decent-bench/lib/app/app_metadata.dart` | `kDecentBenchVersion` constant | Users see wrong version; theme compat checks break |
| `apps/decent-bench/pubspec.yaml` | `version` field (both X.Y.Z and +BUILD) | pub downgrade warnings; packaging metadata wrong |
| `CHANGELOG.md` | Move `[UNRELEASED]` content to a new version heading; add date | Release notes missing or misattributed |

### Files that do NOT need a version bump

These files reference versions but are not part of the release version surface:

- **`apps/decent-bench/pubspec.lock`** — Managed by `flutter pub get`; reflects
  resolved dependency versions, not the app version.
- **ADRs** — ADRs reference app versions in their context ("as of v1.1.0") but
  these are historical records, not release metadata. Do not retroactively edit
  ADRs to update version references.
- **Test fixtures** — Test TOML/JSON files may contain example `version` or
  `min_decent_bench_version` fields. These are test data, not release metadata.
- **`docs/THEME_CATALOG.md`** — Contains example theme metadata. Update only if
  the theme file format version changes, not on every app version bump.
- **`.github/workflows/flutter-build.yml`** — Resolves the DecentDB engine
  version from `pubspec.lock` at runtime. No hard-coded app version.
- **`.github/workflows/release.yml`** — Driven by the Git tag (`v*`), not a
  hard-coded version. Artifact names are computed from `github.ref_name`.

### DecentDB dependency version

The pinned DecentDB engine version lives in:

```yaml
# apps/decent-bench/pubspec.yaml
decentdb:
  git:
    ref: v2.3.0
```

The `pubspec.lock` file records the resolved version automatically. CI workflows
read the lock file to download the correct native assets. When updating the
pinned engine:

1. Change the `ref` in `pubspec.yaml`.
2. Run `flutter pub get` to refresh `pubspec.lock`.
3. Verify the lock file's `decentdb` entry shows the expected version.
4. Verify the tagged release exists on the DecentDB repository.
5. Note the engine version change in `CHANGELOG.md`.
6. If the new engine version enables features Decent Bench exposes to users,
   bump the app version accordingly.

### Config schema version (separate from app version)

The TOML configuration file uses `config_version` in `AppConfig` — an integer
that tracks the configuration schema format, NOT the application version. This
is bumped independently when the config format changes and a migration is
required. It is defined as `AppConfig.currentConfigVersion` in
`lib/features/workspace/domain/app_config.dart`.

## 3. Version-bump procedure

**Step-by-step checklist.** Run these in order.

### 3.1 Before the bump

- [ ] All changes for this release are merged to the release branch.
- [ ] `flutter analyze` passes with no errors.
- [ ] `flutter test` passes with no failures.
- [ ] Integration tests pass (`flutter test integration_test`).
- [ ] `CHANGELOG.md` has entries under `[UNRELEASED] [WIP]` describing all
  changes in this release.

### 3.2 Determine the new version

- [ ] Review the change set and identify the highest-impact change class.
- [ ] Apply the rule from section 1: breaking → Major, feature → Minor,
  fix-only → Patch.
- [ ] If the highest-impact change is in doubt, pick the larger bump.
- [ ] Record the decision rationale: which specific change drove the bump.

### 3.3 Update the source-of-truth files

- [ ] Update `apps/decent-bench/lib/app/app_metadata.dart`:
  ```dart
  const String kDecentBenchVersion = 'X.Y.Z';
  ```

- [ ] Update `apps/decent-bench/pubspec.yaml`:
  ```yaml
  version: X.Y.Z+BUILD
  ```
  Increment `BUILD` by 1 from the previous release. The build number resets to
  `+1` on a major or minor bump. On a patch bump, increment from the previous
  patch's build number.

  Examples:
  - `1.1.0+2` → `1.2.0+1` (minor bump, reset to +1)
  - `1.1.0+2` → `1.1.1+3` (patch bump, increment to +3)
  - `1.1.0+2` → `2.0.0+1` (major bump, reset to +1)

### 3.4 Update the changelog

- [ ] In `CHANGELOG.md`, create a new version section from the `[UNRELEASED]`
  content:
  ```markdown
  ## [X.Y.Z] - YYYY-MM-DD

  ### Added / Changed / Fixed

  (move content from [UNRELEASED] here)
  ```
- [ ] Add date in `YYYY-MM-DD` format.
- [ ] Ensure the `[UNRELEASED]` section is empty or contains only truly
  unreleased work. If the current unreleased section has mixed content, move
  only the content for this release.
- [ ] Add a comparison link at the bottom:
  ```markdown
  [X.Y.Z]: https://github.com/sphildreth/decent-bench/releases/tag/vX.Y.Z
  ```
- [ ] Update the `[unreleased]` link to point at the new tag:
  ```markdown
  [unreleased]: https://github.com/sphildreth/decent-bench/compare/vX.Y.Z...HEAD
  ```

### 3.5 Create the release tag

- [ ] Create an annotated Git tag with a leading `v`:
  ```bash
  git tag -a vX.Y.Z -m "Decent Bench vX.Y.Z"
  ```
- [ ] Push the tag:
  ```bash
  git push origin vX.Y.Z
  ```

The `release.yml` workflow triggers on `v*` tags and:
1. Builds for Linux, macOS, and Windows.
2. Downloads the pinned DecentDB native assets matching the engine version in
   `pubspec.lock`.
3. Stages the native library into each platform bundle.
4. Packages archives named `decent-bench-vX.Y.Z-{OS}-{arch}.{ext}`.
5. Creates a GitHub Release with auto-generated release notes.

Release candidates use `-rc.N` suffix:
```bash
git tag -a vX.Y.Z-rc.1 -m "Decent Bench vX.Y.Z Release Candidate 1"
```

The `release.yml` workflow treats any tag containing `-` as a pre-release.

### 3.6 Post-release verification

- [ ] Verify the GitHub Release was created with all three platform artifacts.
- [ ] Download and run at least one platform artifact to confirm the bundled
  native library loads correctly.
- [ ] Confirm the About dialog shows the new version.
- [ ] Confirm `dbench --version` outputs the new version.
- [ ] Confirm `CHANGELOG.md` on the main branch has the new version section.

### 3.7 Stale version detection

After a bump, scan for stale old-version strings:

```bash
# In apps/decent-bench/
rg '1\.1\.0' --type dart --type yaml lib/ pubspec.yaml
```

Replace `1\.1\.0` with the version you are replacing. Only `kDecentBenchVersion`
and `pubspec.yaml` version should match. If other files match, investigate
whether they need updating or are historical references that should remain
unchanged (test fixtures, comments, ADRs).

### 3.8 When a version bump spans multiple packages

The `decent_bench` pubspec is the only package in this repository that carries a
release version. There are no additional Dart packages, bindings, or example
projects that need synchronous version bumps. The app is self-contained.

## 4. Release tag rules

All release tags use a leading `v`:

- Stable release: `v1.2.0`
- Release candidate: `v1.2.0-rc.1`

The `release.yml` workflow:
- Reads `github.ref_name` for the tag.
- Strips no prefix — artifact names include `v` (e.g.,
  `decent-bench-v1.2.0-Linux-x64.tar.gz`).
- Treats tags containing `-` as pre-releases.

## 5. Version compatibility across workspace state and config

### Config versioning (`config_version`)

The TOML configuration file has an independent integer schema version
(`config_version` in `AppConfig`). This is bumped when the config format changes
in a way that requires migration. This integer is unrelated to the SemVer
application version.

Examples of when to bump `config_version`:
- New required config key added (old configs are invalid without it)
- Config key renamed or semantics changed
- Config format changed (e.g., TOML → something else, or structural reorg)

Examples of when NOT to bump:
- New optional config key added (old configs are still valid)
- Config value default changed
- Config key removed (old configs silently ignore the unknown key)

### Workspace state persistence (`workspace-state.json`)

The workspace state file stores per-tab SQL, parameters, export paths, and
query history. As of v1.1.0, this file does not carry an explicit schema version.
The `WorkspaceStateController` handles state loading and gracefully degrades on
unrecognized fields. If the state format changes:

- **Adding fields**: Backwards-compatible. No version action needed.
- **Removing or renaming fields**: Add a `workspace_state_version` field and
  migration logic before shipping.
- **Changing field semantics**: Treat as breaking. Add a version field and
  migration logic.

### Theme compatibility

Themes declare a `min_decent_bench_version` in their TOML metadata. The
`ThemeValidator` compares this against `kDecentBenchVersion` at load time.
Themes from older Decent Bench versions remain loadable as long as their minimum
version is satisfied. A major Decent Bench version bump should include a theme
format review to ensure bundled and external themes remain compatible.

## 6. Validation checklist

After completing a version bump:

- [ ] `kDecentBenchVersion` matches the intended release version.
- [ ] `pubspec.yaml` version matches and build number is correct.
- [ ] `CHANGELOG.md` has the new version heading with date and accurate change
  descriptions.
- [ ] The `[unreleased]` comparison link points at the new tag.
- [ ] A version link exists for the new release.
- [ ] No stale old-version strings remain in release-facing Dart or YAML files.
- [ ] The Git tag exists and matches the version.
- [ ] The release workflow completed and artifacts are downloadable.
- [ ] `flutter analyze` still passes (in case version strings are referenced in
  unexpected places).
- [ ] `flutter test` still passes.

## 7. Common scenarios and examples

### Scenario A: Bug fix release (Patch)

Branch has: one SQLite import fix, one test improvement, one CI cache change.

**Decision**: Patch bump. No new features, no breaking changes, bug fixes only.

`1.1.0+2` → `1.1.1+3`

### Scenario B: Feature release with bug fixes (Minor)

Branch has: JSON export (new format), schema browser trigger support (new UI),
three import bug fixes.

**Decision**: Minor bump. Features dominate the change set; fixes ride along.
The highest-impact change is the JSON export feature addition.

`1.1.0+2` → `1.2.0+1`

### Scenario C: Config format migration (Major)

Branch has: Parquet export added (new format), config_version bumped from 1 to 2
with required migration, old config is rejected without migration.

**Decision**: Major bump. Even though Parquet export is a feature addition, the
config format breakage is the highest-impact change. Users with un-migrated
configs will see errors on startup.

`1.2.0+1` → `2.0.0+1`

### Scenario D: Refactor with no behavior change (Patch)

Branch has: `DecentDbBridge` worker isolate refactored into a state class, tests
reorganized with `group()` blocks, removed unused function.

**Decision**: Patch bump. No user-visible behavior change, no new features, no
breaking changes. This is a code quality improvement.

`1.1.0+2` → `1.1.1+3` (or this could be rolled into the next release)

### Scenario E: Pinned DecentDB engine update (dependent on content)

Branch has: DecentDB pinned from v2.3.0 to v2.4.0, which adds one new SQL
function. Decent Bench exposes this in autocomplete and documentation.

**Decision**: Minor bump. The new SQL function is a user-visible capability,
even though the implementation is in the engine. Decent Bench is surfacing it.

Branch has: DecentDB pinned from v2.3.0 to v2.3.1 (bug fix release). No new SQL
surface, no Decent Bench behavior changes.

**Decision**: Patch bump. Engine bug fix, no user-visible capability change in
Decent Bench.

## 8. References

- [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)
- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [`design/SPEC.md`](../design/SPEC.md) — Implementation scope and acceptance
  criteria
- [`design/PRD.md`](../design/PRD.md) — Product requirements and scope matrix
- [`design/FUTURE_WINS.md`](../design/FUTURE_WINS.md) — Future roadmap and
  priority index
- [`design/adr/0004-workspace-state-persistence.md`](../design/adr/0004-workspace-state-persistence.md) — Workspace state storage
- [`design/adr/0023-external-toml-theme-system.md`](../design/adr/0023-external-toml-theme-system.md) — Theme file format and compatibility
- [DecentDB Versioning Guide](https://github.com/sphildreth/decentdb/blob/main/design/VERSIONING_GUIDE.md) — Reference document for the pinned engine versioning
