# Native Branch, Snapshot, and Safe-Run Workbench

**Date:** 2026-05-19
**Status:** Proposed

## Context

ADR-0032 originally treated snapshots as file copies. That was the safest
available model before DecentDB v2.5.x, but it is no longer the primary design.
DecentDB v2.5.x exposes native named snapshots, branches, branch-local
execution, branch diffs, guarded restore, constrained merge, and a C ABI JSON
bridge for branch operations.

Decent Bench should build its safety workflow on those native database
primitives. File-copy snapshots remain useful as an exportable fallback, but
they should not define the main workbench model.

As of DecentDB `v2.5.1`, the Dart binding exposes `Database.saveAs()` for
file-level copies and the C ABI exposes `ddb_db_branch_execute_json`, but the
Dart package does not yet expose a public branch/snapshot API. Decent Bench must
not hard-wire a private binding detail. The first implementation slice should
therefore add the app-facing model and keep native branch execution behind a
gateway boundary that can be wired once the Dart API is public.

## Decision

Decent Bench will model database safety around native DecentDB branches and
snapshots:

- Named snapshots are retained engine snapshots, not ordinary `.ddb` copies.
- Branches are isolated workspaces for risky SQL, imports, and edits.
- Destructive SQL and large imports should offer "Run on New Branch" before
  mutating the main branch.
- Branch diffs are the review surface before restore or merge.
- Restore is guarded by an automatic pre-restore snapshot and a dry-run result.
- Merge is constrained to the engine-supported branch merge semantics.

The bridge contract will expose branch/snapshot operations through
`WorkspaceDatabaseGateway` rather than through UI code directly. Until the Dart
binding exposes native branch operations, Decent Bench may expose read-only
status and design-owned placeholders, but must not pretend branch execution is
available.

## App-Facing Operations

The eventual gateway surface should cover:

- `listSnapshots()`
- `createSnapshot(name)`
- `deleteSnapshot(name)`
- `listBranches()`
- `createBranch(name, fromRef)`
- `deleteBranch(name)`
- `runQueryOnBranch(sql, branchName, params, pageSize)`
- `branchDiff(leftRef, rightRef)`
- `restoreBranch(branchName, targetRef, dryRun)`
- `mergeBranch(sourceBranch, targetBranch, dryRun)`

These operations map to DecentDB's native branch JSON operations where
available:

- `snapshot_create`
- `snapshot_list`
- `snapshot_delete`
- `branch_create`
- `branch_list`
- `branch_delete`
- `branch_diff`
- `branch_restore`
- `branch_merge`

## UI Model

The first user-facing workbench should include:

- A branch/snapshot pane showing current branch context, named snapshots, and
  branch list.
- "Create Snapshot" and "Create Branch" commands.
- A destructive-statement prompt with "Run on New Branch" when the query
  contract reports a non-read-only statement or the SQL keyword is known risky.
- A branch diff viewer grouped by table and primary-key row change.
- A guarded restore flow that always offers a pre-restore snapshot and requires
  dry-run review before applying.
- A constrained merge flow that requires diff review before merge.

## File-Copy Fallback

`Database.saveAs()` remains valuable, but only as "Export Database Copy" or as a
fallback safety option when native branches are unavailable. It is not the
primary rollback model.

## Non-Goals

- Multi-user branch collaboration.
- Remote branch storage.
- Conflict-resolution UI beyond the constrained merge surface exposed by
  DecentDB.
- Reimplementing branch storage in Decent Bench.
- Calling private Dart binding internals to reach the C ABI.

## Consequences

- Decent Bench can present a safer mental model for risky operations once the
  Dart binding exposes branch operations.
- Table editing, import safety, saved queries, and schema drift workflows can
  all share the same branch/snapshot safety state.
- The initial UI may need to show "native branch operations unavailable in this
  binding" until the public Dart API is available.
- File-copy snapshots remain available without blocking native branch design.

## Validation

- Unit tests should cover SQL risk classification and branch/snapshot model
  decoding without requiring a native branch binding.
- Bridge smoke tests should be added once the Dart binding exposes public
  branch operations.
- Full branch diff, restore, and merge tests should use small primary-key
  fixtures and verify dry-run behavior before destructive apply paths.

## References

- `design/FUTURE_WINS.md` priority 4
- `design/adr/0002-results-paging-and-streaming-contract.md`
- `design/PRD.md` section 9.2
- `design/PRD.md` section 9.4
- DecentDB `v2.5.1` C ABI branch JSON entry point:
  `ddb_db_branch_execute_json`
