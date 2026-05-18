## Database Snapshot and Safe-Run Operations
**Date:** 2026-05-18
**Status:** Proposed

### Decision

Decent Bench will provide a one-click database snapshot mechanism: create a
timestamped copy of the current `.ddb` file, optionally checkpointing the WAL
before the copy. The feature will also support an opt-in auto-snapshot mode
that automatically snapshots the database before executing any statement
containing `DROP`, `DELETE FROM`, `ALTER`, or `INSERT INTO` (configurable
destroy-operation set).

### Rationale

Decent Bench users perform irreversible database operations regularly: dropping
tables, deleting rows, importing data that may overwrite existing tables, or
experimenting with schema changes whose consequences aren't fully understood.
In every other tool domain dealing with mutable content — photo editors, CAD,
IDEs with refactoring — "save a copy" or "snapshot" is a one-click action.
Database tools have been slow to adopt this pattern.

A one-click snapshot changes the user's relationship with the tool. Instead of
hesitating before a risky query, users snapshot first and proceed with
confidence. If the result is bad, they restore the snapshot. This removes fear
from the workflow and encourages experimentation — the defining value of a
workbench.

### Implementation Strategy

DecentDB is an embedded, single-file database. Taking a snapshot is a file-level
operation:

1. **Optional WAL checkpoint**: If WAL mode is active, issue `PRAGMA
   wal_checkpoint(TRUNCATE)` to flush the WAL into the main database file before
   copying. Without this step, the snapshot would miss recent committed writes
   still in the WAL.
2. **File copy**: Copy the `.ddb` file using `dart:io` `File.copy()` to a
   timestamped path.
3. **Report**: Show the snapshot path and file size to the user.

No SQL-level export, no format conversion, no data transformation. The snapshot
is a valid DecentDB file openable directly in Decent Bench.

### Snapshot Naming Convention

```
<dbname>-<ISO8601-UTC>.snapshot.ddb
```

Example: `sales-2026-05-18T14-30-00Z.snapshot.ddb`

Key decisions:
- **ISO 8601 UTC** timestamps to avoid timezone ambiguity and locale-dependent
  formatting.
- **Colons replaced with hyphens** in the time portion. ISO 8601 uses `:`
  separators (`T14:30:00`) but colons are invalid in Windows filenames and
  problematic in some Linux contexts. Hyphens are universally safe.
- **`.snapshot.ddb` suffix** so snapshot files are distinguishable from live
  databases in file listings and can be associated with Decent Bench for
  double-click opening.

### Snapshot Storage

- Default directory: alongside the original `.ddb` file (same parent directory).
- Configurable snapshot directory in preferences (relative or absolute path).
- Snapshot list: recent snapshots shown in the workspace with timestamp and file
  size. Read from the snapshot directory by matching the `<dbname>-*.snapshot.ddb`
  pattern.

### Restore Workflow

"Restore Snapshot" opens the selected snapshot as the active database:
1. Warns about discarding current changes since the snapshot was taken.
2. Offers to snapshot the current state first ("Take one last snapshot before
   restoring?").
3. Opens the snapshot file as the new active database (equivalent to File → Open).
4. Optionally, after confirming the restore was correct, the user can manually
   delete or archive the old database file.

Restore is not an "overwrite in place" operation. It opens a new file. This is
safer: if the restore was a mistake, the original file is still intact.

### Auto-Snapshot Before Destructive Operations

**Opt-in** preference (off by default):

```toml
[snapshots]
auto_snapshot_enabled = true
auto_snapshot_triggers = ["DROP", "DELETE FROM", "ALTER", "INSERT INTO"]
auto_snapshot_max_count = 20
```

When enabled, before executing any SQL statement containing a trigger keyword,
the app:
1. Checkpoints the WAL.
2. Creates a snapshot.
3. Proceeds with execution.
4. If the snapshot fails (disk full, permission error), execution is blocked
   with a clear error — never silently skipped.

### Cleanup Policy

- Configurable maximum snapshot count (default: 20 per database).
- Configurable maximum snapshot age (default: none — keep forever).
- On snapshot creation, if the configured limits are exceeded, the oldest
  snapshots are deleted.
- Deletion requires confirmation unless the user enables "auto-cleanup without
  confirmation."
- Snapshots are never deleted automatically for databases in an error or
  recovery state. Only healthy databases with successful snapshots older than
  the limit are eligible.

### Non-Goals

- Incremental or differential snapshots (only full file copies). DecentDB is
  single-file; incremental snapshots add complexity with no proportional benefit.
- Snapshot encryption or compression.
- Cloud/remote snapshot storage.
- Point-in-time recovery chains (sequence of snapshots + WAL replay).
- Snapshotting databases that are not local files (future external connector
  scenario). When live database connectors are implemented, this feature will
  have a natural scope boundary: snapshots only for local `.ddb` files.

### Trade-offs

- **File copy size**: For large databases (GB+), the file copy can be
  time-consuming on slow disks. This is acceptable because snapshots are
  on-demand and user-initiated. The tool shows copy progress. For very large
  databases, users can use OS-level backup tools instead.
- **WAL checkpoint before snapshot**: Flushing the WAL syncs recent writes to
  disk, which is a minor performance hit but ensures the snapshot is complete.
  Without it, a snapshot of a database with a large WAL would be missing
  committed data, making it unreliable as a restore target. The checkpoint is
  required.
- **Auto-snapshot false positives**: A query containing `DELETE` as a keyword
  but not as a destructive operation (e.g., a comment `-- note: DROP is not
  safe here`) would trigger auto-snapshot. This is a minor annoyance, not a
  correctness issue — better to snapshot unnecessarily than to miss a
  destructive operation. A more sophisticated parser could be added later.
- **No restore-in-place**: Opening a snapshot as a new file rather than
  overwriting the original means the old file path is still occupied. Users who
  want the original path back must rename files. This is safer behavior but
  slightly less convenient. A "Replace with Snapshot" action can be added if
  user feedback demands it.

### References

- ADR-0002 Results Paging and Streaming Contract
- `design/PRD.md` section 9.2 (reliability)
- `design/PRD.md` section 9.4 (local-first, privacy-first)
- `design/FUTURE_WINS.md` Priority 6

### Alternatives Considered

**SQL-level export as snapshot**: Instead of copying the file, export the entire
database as SQL (`.sql` dump) and use that as the snapshot format. Rejected
because:
- SQL export is slow for large databases (must read every table and serialize as
  text).
- SQL re-import for restore is orders of magnitude slower than opening a `.ddb`
  file.
- File copy is instantaneous for small-to-medium databases and preserves exact
  engine state including indexes, WAL, and internal structures that SQL export
  cannot represent.

**Transaction-based rollback instead of snapshots**: Run all destructive queries
in a transaction, show results, and rollback if the user doesn't confirm.
Rejected because:
- Not all DDL can be rolled back in all engine modes.
- Imports that modify the database file outside explicit transactions cannot be
  rolled back.
- Snapshots work at the file level and are universally applicable regardless of
  engine transaction support.

**Git-based versioning of `.ddb` files**: Encourage users to use git to version
their `.ddb` files. Rejected because:
- Binary database files in git produce large diffs and bloat repository size.
- This assumes git knowledge that many target users (power users / data
  wranglers, not all of whom are developers) may not have.
- Snapshots are a one-click in-app feature; git is an external tool with a
  learning curve.
