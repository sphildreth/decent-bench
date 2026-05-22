# Decent Bench — Application Menu Review Remediation Plan

**Status:** Completed  
**Last updated:** 2026-05-21  
**Primary references:** `design/PRD.md`, `design/SPEC.md`, `design/adr/`

This document records the findings from the application menu audit and defines
a phased plan to make every visible menu item either fully functional,
intentionally disabled, or explicitly removed/deferred.

## Phase Map

| Phase | Status | Goal | Primary Output |
|---|---|---|---|
| Phase 0 — Menu Contract Baseline | Completed | Establish a testable inventory and policy for all menu commands. | Menu command manifest, automated audit coverage, deferred-command classification. |
| Phase 1 — Menu Exposure and Label Fixes | Completed | Fix commands that exist but are not visible in the menu bar. | `Command Palette...` and `Open Web Console` appear in the appropriate menus. |
| Phase 2 — Remove or Disable Placeholder Actions | Completed | Stop presenting unfinished actions as available commands. | Deferred commands disabled; implemented commands no longer use placeholder menu handlers. |
| Phase 3 — File Lifecycle Decisions | Completed | Define and implement `Save`, `Save As`, and `Close` semantics. | ADR plus implemented file lifecycle behavior or deliberate removal. |
| Phase 4 — Import and Export Workflow Completion | Completed | Resolve import/export placeholder commands. | Live DB import/rerun workflows deferred by ADR; table/schema export implemented; Parquet remains dependency-gated. |
| Phase 5 — Branch Workflow Boundary | Completed | Align branch menu behavior with the DecentDB Dart binding surface. | Native branch/snapshot commands enabled behind gateway capability checks. |
| Phase 6 — Documentation and Connections | Completed | Resolve help/docs and connection-management menu entries. | In-app documentation dialog plus deferred connection policy. |
| Phase 7 — Regression and Acceptance Sweep | Completed | Prove the final menu surface is coherent. | Passing automated menu audit and manual desktop checklist. |

## Audit Summary

The application menu system has two important surfaces:

- `MenuCommandRegistry` in `WorkspaceScreen`, which defines command IDs,
  labels, enabled state, shortcuts, and handlers.
- `AppMenuBar` and `NativeAppMenuHost`, which expose a subset of those commands
  through in-app and platform menus.

The audit found three classes of problems:

1. Some registered commands are not exposed in either menu bar.
2. Several visible menu items were placeholders but still appeared enabled.
3. Branch workflow commands required DecentDB Dart branch APIs. This is now
   resolved by the local DecentDB binding updates and Decent Bench gateway
   integration.

## Findings

### Commands Registered But Not Visible

| Command ID | Label | Finding |
|---|---|---|
| `view_command_palette` | Command Palette... | Registered and shortcut-backed, but missing from both in-app and native `View` menus. |
| `tools_open_web_console` | Open Web Console | Registered and implemented, but missing from both in-app and native `Tools` menus. |

### Placeholder or Not Implemented Menu Items

| Menu Item | Current Behavior | Required Decision |
|---|---|---|
| File > Save | Implemented. Persists workspace state, query library, and config metadata. | Resolved by ADR `0043-file-lifecycle-semantics.md`. |
| File > Save As... | Implemented. Copies the `.ddb` plus recognized sidecars and opens the copy. | Resolved by ADR `0043-file-lifecycle-semantics.md`. |
| File > Close | Implemented. Persists app state, cancels active work, and returns to the empty shell. | Resolved by ADR `0043-file-lifecycle-semantics.md`. |
| Import > Import From Database... | Disabled/deferred. | Requires live connection and secret-storage model; deferred by ADR `0044-live-connections-and-menu-deferrals.md`. |
| Import > Re-run Last Import | Disabled/deferred. | Requires import recipe persistence contract; deferred by ADR `0044-live-connections-and-menu-deferrals.md`. |
| Export > Export Results as Parquet... | Disabled/deferred. | Dependency-gated by ADR `0031-parquet-excel-export-dependency-strategy.md`. |
| Export > Export Table... | Implemented. Uses a transient paged `SELECT * FROM <table>` result and existing export dialogs. | Resolved. |
| Export > Export Schema... | Implemented. Writes SQL DDL from the schema snapshot. | Resolved. |
| Export > Re-run Last Export | Disabled/deferred. | Requires export recipe persistence contract; deferred by ADR `0044-live-connections-and-menu-deferrals.md`. |
| Tools > Manage Connections | Disabled/deferred. | Requires live connection and secret-storage model; deferred by ADR `0044-live-connections-and-menu-deferrals.md`. |
| Help > Documentation | Implemented. Opens bundled in-app documentation guidance. | Resolved. |

### Branch Workflow Boundary

The following menu items were blocked because public DecentDB Dart branch APIs
were not exposed when the audit was written:

- Tools > Branch & Snapshots
- Tools > Create Snapshot...
- Tools > Create Branch...
- Tools > Branch Diff...
- Tools > Restore Branch...
- Tools > Merge Branch...

Resolution: DecentDB now exposes the needed Dart branch workflow APIs, and
Decent Bench routes these menu actions through the workspace gateway with
capability checks. The risky SQL confirmation path can now be backed by
`runQueryOnBranch` when that workflow is enabled in the UI.

## Phase 0 — Menu Contract Baseline

### Objective

Create a durable menu contract so command drift is caught automatically.

### Tasks

1. Add a menu command manifest or structured test helper that enumerates:
   - command ID
   - visible menu location
   - enabled preconditions
   - expected behavior class
2. Add tests that compare `MenuCommandRegistry` against `AppMenuBar` and
   `NativeAppMenuHost`.
3. Classify each command as one of:
   - implemented
   - disabled by state
   - intentionally unavailable due external API/dependency
   - removed/deferred
4. Add regression coverage for deferred command detection so enabled deferred
   commands do not reappear without an explicit test update.

### Exit Criteria

- Every registered command has an expected menu exposure status.
- Both menu bar implementations are tested against the same command list.
- The audit can be rerun without creating temporary tests.

### ADR Need

No ADR required unless this phase changes menu architecture. Tests and a command
manifest are implementation hygiene.

### Completion Notes

- Added a shared menu command contract helper and deferred-command classification at
  `apps/decent-bench/test/features/workspace/presentation/shell/menu_command_contract.dart`.
- Added permanent audit coverage against both `AppMenuBar` and
  `NativeAppMenuHost` at
  `apps/decent-bench/test/features/workspace/presentation/shell/app_menu_command_audit_test.dart`.

## Phase 1 — Menu Exposure and Label Fixes

### Objective

Expose implemented commands that are currently registered but missing from the
menus.

### Tasks

1. Add `View > Command Palette...` to `AppMenuBar`.
2. Add `View > Command Palette...` to `NativeAppMenuHost`.
3. Add `Tools > Open Web Console` to `AppMenuBar`.
4. Add `Tools > Open Web Console` to `NativeAppMenuHost`.
5. Verify shortcut labels and disabled state render correctly.

### Exit Criteria

- `Command Palette...` is visible in the `View` menu.
- `Open Web Console` is visible in the `Tools` menu when a database is open and
  disabled otherwise.
- Widget tests cover both items.

### ADR Need

No ADR required. These commands already exist and this phase only fixes menu
exposure.

### Completion Notes

- Added `View > Command Palette...` and `Tools > Open Web Console` to both menu
  implementations.

## Phase 2 — Remove or Disable Placeholder Actions

### Objective

Ensure the menu does not present unfinished features as available actions.

### Tasks

1. Convert known placeholder commands to disabled menu items with clear labels
   or remove them from menus.
2. Keep command-palette discoverability only when it helps communicate planned
   work; otherwise remove the command entirely.
3. Replace placeholder dialogs with one of:
   - implemented workflow
   - disabled state
   - feature removed from visible menu
4. Update tests to assert no enabled command invokes `_showPlaceholderNotice`
   for planned/deferred work.

### Candidate Commands

- `file_save`
- `file_save_as`
- `file_close`
- `import_from_database`
- `import_rerun_last`
- `export_table`
- `export_schema`
- `export_rerun_last`
- `tools_manage_connections`
- `help_docs`

### Exit Criteria

- No visible enabled menu item is a pure placeholder.
- Disabled items have an understandable reason in the UI or are omitted.

### ADR Need

ADR likely required only if commands are removed from the product surface or if
the disabled/hidden policy changes product scope.

### Completion Notes

- Implemented file lifecycle, table export, schema export, and documentation
  menu commands.
- Converted live database import, rerun import/export, connection management,
  and Parquet export into disabled/deferred commands rather than enabled
  placeholder actions.
- Updated the permanent menu audit so fallback `Missing` entries and enabled
  deferred commands fail tests.

## Phase 3 — File Lifecycle Decisions

### Objective

Resolve desktop file lifecycle semantics instead of shipping placeholder file
commands.

### Decisions Needed

1. What does `Save` mean for DecentDB files when writes already persist
   immediately?
2. Does `Save As...` duplicate the current `.ddb`, export a project, or create a
   migrated/copy-on-write workspace?
3. What does `Close` do when the app can show an empty shell and maintains
   recent files?

### Tasks

1. Create or update an ADR for file lifecycle semantics.
2. Implement selected behavior:
   - `Save`: persists workspace, query library, and config metadata; database
     writes are already durable.
   - `Save As...`: duplicate current `.ddb` plus recognized sidecars and open
     the copy.
   - `Close`: persist workspace state/query-library/config, cancel active work,
     and return to an empty shell.
3. Add tests for database state, recent files, and UI transitions.

### Completion Notes

- Implemented `Save`, `Save As...`, and `Close` in
  `WorkspaceController` and bound them in `WorkspaceScreen`.
- Added `design/adr/0043-file-lifecycle-semantics.md`.
- Updated `menu_command_contract` and contract-related tests for implemented
  status.
- Added focused controller tests for save/save-as/close state transitions.

### Exit Criteria

- `Save`, `Save As...`, and `Close` are either implemented with clear semantics
  or removed/disabled.
- No placeholder file lifecycle dialogs remain.

### ADR Need

ADR required. File lifecycle behavior is user-visible and has lasting product
impact.

## Phase 4 — Import and Export Workflow Completion

### Objective

Resolve menu items that advertise import/export workflows not yet delivered.

### Tasks

1. `Import From Database...`
   - Decide whether live DB imports are in scope for the current release.
   - If in scope, define supported sources, credentials storage, connection
     testing, and import execution model.
   - If out of scope, remove or disable until the connection model exists.
2. `Re-run Last Import`
   - Use existing import/export profile work if sufficient.
   - Persist the last import recipe and add safe rerun confirmation.
3. `Export Table...`
   - Reuse the results export pipeline by generating a paged
     `SELECT * FROM <table>` query.
   - Require table selection when no table is selected.
4. `Export Schema...`
   - Define supported outputs: SQL DDL, JSON metadata, or project manifest.
   - Implement through schema snapshot metadata.
5. `Re-run Last Export`
   - Persist last export recipe per workspace or per tab.
   - Add validation when query/table/schema no longer exists.
6. `Export Results as Parquet...`
   - Revisit ADR `0031-parquet-excel-export-dependency-strategy.md`.
   - Either select and validate a dependency or keep the item disabled with a
     tracked dependency decision.

### Exit Criteria

- Import/export placeholder commands are implemented, disabled with rationale,
  or removed from visible menus.
- Export workflows remain paged/streaming and do not materialize full results.

### ADR Need

ADRs required for:

- Live database connection/import model.
- Parquet dependency selection if implemented.
- Export recipe persistence if it changes workspace/project file contracts.

### Completion Notes

- `Import From Database...` and `Tools > Manage Connections` remain visible but
  disabled until Decent Bench has an accepted live-connection, credential, and
  import execution model.
- `Re-run Last Import` and `Re-run Last Export` remain visible but disabled
  until import/export recipe persistence is added to the workspace/project
  contract.
- `Export Table...` is implemented by opening a transient query tab for the
  selected schema table, executing `SELECT * FROM <table>`, and routing the
  result through the existing paged export flow.
- `Export Schema...` is implemented as a SQL DDL export built from the loaded
  schema snapshot.
- `Export Results as Parquet...` remains disabled under ADR
  `0031-parquet-excel-export-dependency-strategy.md`; Decent Bench will add a
  maintained Apache-compatible Parquet writer in a future slice without moving
  Parquet into DecentDB engine core.
- ADR `0044-live-connections-and-menu-deferrals.md` records the deferral
  policy for live connections and rerun recipe persistence.

## Phase 5 — Branch Workflow Boundary

### Objective

Make branch-related menu items accurately reflect the public DecentDB Dart API.

**Status:** Completed on 2026-05-21.

### Tasks

1. Keep `Branch & Snapshots` available as a diagnostic read-only view only if it
   adds value.
2. Disable or hide mutation commands when `canUseNativeBranchWorkflow` is false:
   - Create Snapshot
   - Create Branch
   - Branch Diff
   - Restore Branch
   - Merge Branch
3. Keep unavailable messaging centralized in the workbench rather than opening
   the same unavailable view for every command.
4. When public Dart branch APIs become available, re-enable commands behind
   gateway capability checks.
5. Update risky SQL confirmation copy so disabled branch execution is concise
   and not presented as a selectable workflow.

### Completion Notes

- `DecentDbBridge` now implements native branch and snapshot operations through
  the DecentDB Dart binding.
- Branch and snapshot refs stay compatible with the existing workbench UI while
  passing DecentDB-native refs to the engine.
- Smoke coverage verifies snapshot creation/deletion, branch creation/deletion,
  branch-scoped SQL execution, diff, restore preview, and merge preview/apply.

### Exit Criteria

- Branch mutation commands are not shown as available when the binding cannot
  perform them.
- Users see one clear explanation of the binding boundary.
- When the binding is available, branch mutation commands execute native
  DecentDB operations successfully.

### ADR Need

ADR update required if this changes ADR `0032-database-snapshot-and-safe-run`
or any accepted branch/safe-run decision.

## Phase 6 — Documentation and Connections

### Objective

Resolve help and connection-related menu ambiguity.

### Tasks

1. Replace `Help > Documentation` placeholder with one of:
   - local documentation viewer
   - browser launch to project docs
   - bundled `README`/manual dialog
2. Decide whether `Tools > Manage Connections` belongs in the product before
   live database import exists.
3. If connections remain, define:
   - supported connection types
   - secret storage policy
   - test connection behavior
   - import-only vs query/live browsing boundaries

### Exit Criteria

- `Help > Documentation` opens real documentation.
- `Manage Connections` is either implemented, disabled pending live DB import,
  or removed.

### ADR Need

ADR required for connection/secret storage. Documentation entry-point changes do
not require an ADR unless they change distribution packaging.

### Completion Notes

- `Help > Documentation` now opens a real in-app documentation dialog that
  points users to the bundled project docs and summarizes core desktop
  workflows.
- `Tools > Manage Connections` stays disabled and deferred because implementing
  it before live database import would require premature credential storage,
  connection testing, and source-driver commitments.
- ADR `0044-live-connections-and-menu-deferrals.md` records this product
  boundary.

## Phase 7 — Regression and Acceptance Sweep

### Objective

Prove the final menu surface works as a coherent product feature.

### Tasks

1. Add a permanent automated menu audit test:
   - opens each top-level menu
   - verifies every expected item is present
   - verifies disabled items are disabled for the correct state
   - invokes deterministic non-file-picker commands
2. Add integration smoke coverage for:
   - command palette visibility
   - Web Console menu visibility
   - preferences/snippets/help dialogs
   - branch disabled state
3. Manual desktop checklist:
   - Linux in-app menu
   - Linux native menu plugin path if enabled
   - Windows menu/icon behavior
   - macOS native menu behavior
4. Update `CHANGELOG.md` with the final menu cleanup summary.

### Exit Criteria

- No enabled menu item is a placeholder.
- No implemented registered command is missing from visible menus unless
  intentionally hidden and covered by tests.
- All menu tests pass.
- Manual checklist is recorded in the implementation PR or final task summary.

### ADR Need

No ADR required for test coverage. ADRs should already have been created in the
relevant product-decision phases.

### Completion Notes

- Added a permanent automated menu audit across both menu surfaces, including
  state-sensitive checks for `Command Palette...` and `Open Web Console`.
- Added fallback-entry checks so missing command IDs cannot silently render as
  `Missing` menu items.
- Updated `CHANGELOG.md` with the final menu cleanup summary.
- Desktop checklist recorded for this implementation:
  - Linux in-app menu: covered by widget menu audit.
  - Linux native menu path: covered by `NativeAppMenuHost` widget audit.
  - Windows and macOS native menus: not executable in this Linux workspace;
    behavior is covered by the shared platform menu model tests and should be
    smoke-tested in release packaging.
