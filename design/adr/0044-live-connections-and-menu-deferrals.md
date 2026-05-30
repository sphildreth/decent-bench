## Live Connections And Menu Deferrals
**Date:** 2026-05-21
**Status:** Accepted

### Decision

Decent Bench keeps the following menu commands visible but disabled until their
supporting product contracts exist:

- `Import > Import From Database...`
- `Import > Re-run Last Import`
- `Export > Re-run Last Export`
- `Tools > Manage Connections`

Decent Bench also keeps `Export > Export Results as Parquet...` disabled under
ADR `0031-parquet-excel-export-dependency-strategy.md` until a maintained
Apache-compatible writer is selected and validated for desktop packaging.

This release does implement the related commands that can be completed without
new product contracts:

- `Export > Export Table...` routes a selected table through the existing paged
  query-result export path.
- `Export > Export Schema...` writes SQL DDL from the loaded schema snapshot.
- `Help > Documentation` opens bundled in-app documentation guidance.

### Rationale

Live database import is larger than a menu dialog. It needs source-specific
drivers, connection testing, cancellation, import progress, credential handling,
and clear boundaries between import-only access and live browsing/querying.
Adding a connection manager before those contracts exist would create an
insecure or misleading surface.

Import/export rerun commands require persisted recipe formats. That changes the
workspace/project contract and needs validation for missing files, changed
schemas, stale credentials, and query/table availability. Until that contract is
accepted, disabled menu entries are safer than enabled actions with ambiguous
state.

Parquet remains a Decent Bench import/export concern rather than DecentDB engine
core. The app should add Parquet once a writer can be validated for licensing,
streaming behavior, and Linux/macOS/Windows packaging.

### Alternatives Considered

- Implement connection management with local plaintext connection strings.
  Rejected because it would introduce credential risk and lock in a weak
  storage model.
- Remove the deferred commands from the menu. Rejected because PRD/SPEC include
  these desktop workbench workflows and keeping them disabled preserves product
  discoverability without pretending they are available.
- Add rerun commands that replay only the current in-memory session. Rejected
  because rerun behavior should survive workspace restart or not exist at all.
- Add Parquet support through DecentDB engine core. Rejected because Parquet is
  an application-level interchange format and should not expand the database
  engine API surface.

### Consequences

- The application menu has no enabled placeholder commands.
- Deferred commands remain visible and covered by the menu contract tests.
- Future live connection work must create or update an ADR for credential
  storage, supported sources, connection testing, and import execution.
- Future rerun work must define import/export recipe persistence before enabling
  the commands.

### References

- `design/APPLICATION_MENU_REVIEW.md`
- `design/adr/0031-parquet-excel-export-dependency-strategy.md`
- `design/adr/0029-workspace-project-file-and-query-library.md`
- `design/PRD.md`
- `design/SPEC.md`
