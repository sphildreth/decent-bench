## Workspace Project File and Query Library
**Date:** 2026-05-19
**Status:** Proposed

### Decision

Decent Bench will introduce two layered persistence features:

1. **Named query library**: Users can save, name, organize, and recall SQL
   queries independently of open tabs. Queries are stored per-workspace as
   TOML.
2. **Workspace project file** (`.dbench-project.toml`): A portable TOML file
   that bundles a reference to a DecentDB database file with a set of named
   queries, import settings, and export defaults.

Both use TOML — consistent with the existing configuration format and the
project's `TOML-first` convention established in the PRD.

With DecentDB v2.5.x, saved queries also store query-contract summaries and the
schema fingerprint observed when the query was saved. These fields let Decent
Bench warn about schema drift before rerunning or exporting a saved query.

### Rationale

The persistence infrastructure is already built. `WorkspaceState` stores
per-tab SQL text, parameters, and export paths. `FileWorkspaceStateStore`
serializes this as JSON to `workspace-state.json`. What's missing is the
user-facing layer: give queries names, organize them into folders or tags, and
make them recallable across sessions without relying on "keep this tab open
forever."

Saved queries also create compounding value with other roadmap items:
parameterized queries become far more useful when the SQL is saved and the user
only needs to fill in parameter values. SDK generation needs named query
contracts as input. Export profiles need queries to export.

### Query Library Format

Named queries are stored in a `queries.toml` file in the workspace state
directory, using this structure:

```toml
config_version = 1

[[queries]]
id = "a1b2c3d4"           # UUID v4, stable across renames
name = "Monthly Sales"
description = "Revenue by region for the current month"
sql = """
SELECT region, SUM(amount) as total
FROM orders
WHERE order_date >= $1
GROUP BY region
ORDER BY total DESC
"""
folder = "reports"          # optional, empty string = root
tags = ["sales", "monthly"] # optional
created_at = "2026-05-18T14:30:00Z"
updated_at = "2026-05-18T14:30:00Z"
schema_fingerprint = "..."
schema_fingerprint_algorithm = "sha256:decentdb-tooling-schema-v1"

[queries.contract]
contract_version = 1
statement_kind = "query"
read_only = true

[[queries.contract.parameters]]
position = 1
name = "$1"
type_name = "DATE"

[[queries.contract.result_columns]]
ordinal = 0
name = "region"
type_name = "TEXT"
```

Key design choices:
- **UUID-based IDs** ensure references survive renames and moves.
- **Inline SQL** in the TOML file. No external SQL files that could become
  detached from the project. The multi-line string literal uses TOML's
  triple-quote syntax for readability.
- **Flat list with optional folder string** rather than a nested hierarchy.
  This keeps the format simple while supporting basic organization. A full tree
  with nested folders can be added later if needed.
- **Tags** are free-form strings for cross-cutting organization.
- **Contract summaries** intentionally persist only the fields Decent Bench
  needs for drift warnings, parameter forms, typed exports, and SDK generation.
  The engine remains the source of truth and queries are re-described on load.

### Workspace Project File Format

A workspace project file (`.dbench-project.toml`) provides portability:

```toml
config_version = 1

[database]
path = "data/sales.ddb"            # relative to project file, or absolute
open_on_load = true

[imports]
# Optional: list of import plan references or inline settings
# Plan files use the existing --plan JSON contract from ADR-0022

[query_library]
path = "queries.toml"              # relative to project file, or inline

[auto_open]
queries = ["a1b2c3d4"]             # query IDs to auto-open on project load

[export_defaults]
format = "csv"
delimiter = ","
include_headers = true
output_dir = "exports/"            # relative to project file

[branch_safety]
preferred_branch = "main"
run_risky_queries_on_branch = true
```

Key design choices:
- **Relative paths by default** to make projects portable across machines.
  Absolute paths are supported for fixed-location databases (e.g., system-wide
  reference data).
- The project file is the sole entry point. Double-clicking a
  `.dbench-project.toml` or passing it via `dbench --project` restores the
  workspace: opens the database, loads the query library, and auto-opens pinned
  queries.
- **No data duplication**. The project file references the database and query
  library by path — it does not embed database contents or query SQL inline by
  default. This keeps project files small and version-control-friendly.
- **Config version** for forward compatibility and migration.
- **Branch safety preferences** reference DecentDB branch names but do not embed
  branch data. Native branch state remains inside the database.

### Auto-Save and Recovery

- Unsaved tab contents are auto-saved to workspace state on tab close and app
  close. Tabs reopen with their last content on workspace restore.
- This applies regardless of whether the tab contains a named saved query or
  ad-hoc SQL. Named queries are an explicit user action; auto-save is a safety
  net.
- The workspace state file (`workspace-state.json`) continues to store per-tab
  ephemeral state (open tabs, cursor position, execution status). The query
  library (`queries.toml`) stores only explicitly saved queries.
- When opening a saved query, Decent Bench compares the saved
  `schema_fingerprint` with the current tooling metadata fingerprint and shows a
  drift warning if they differ.

### Non-Goals

- Query version history beyond what per-tab history provides. The query library
  stores the current version; history is tab-scoped.
- Shared/collaborative query libraries requiring a server or sync infrastructure.
- Query scheduling or automation triggers (cron-style execution).
- Cloud-based project sharing.
- Embedding full database files within project files.

### Trade-offs

- **TOML over SQL files**: Storing SQL inline in TOML adds TOML escaping
  concerns (multi-line strings, special characters) but keeps queries in a
  single discoverable file. SQL files would be cleaner to read individually but
  harder to organize and discover programmatically. TOML is the project's
  established config format.
- **Flat queries list over nested folders**: A flat list with folder strings is
  simpler to implement and validate. Nested folders require tree UI and
  recursive parsing but offer better organization for large query libraries.
  Start flat; add nesting if user demand justifies it.
- **Project file is not a database bundle**: The project file references a DB by
  path rather than embedding it. This keeps project files small but means
  sharing a project requires sharing the DB separately (or agreeing on a shared
  path). Database snapshots (ADR-0032) can complement this for backup/sharing
  use cases.

### References

- ADR-0004 Workspace State Persistence
- ADR-0022 Headless CLI Import Mode and Plan File
- ADR-0032 Native Branch, Snapshot, and Safe-Run Workbench
- `design/PRD.md` section 3.2 (saved queries, workspace projects)
- `design/SPEC.md` section 4.3 (SQL editor and results tabs)
- `design/FUTURE_WINS.md` Priority 4

### Alternatives Considered

**JSON for query library**: Rejected because the project is TOML-first. TOML
is more human-editable and already used for config and themes. Using TOML for
queries maintains consistency.

**SQLite as query library storage**: Store saved queries in a SQLite database
alongside the workspace. Rejected because the query library should be
version-controllable and human-readable. A binary SQLite file defeats both
goals. The existing `WorkspaceState` JSON storage is adequate for machine state;
the query library should be hand-editable.

**Project file embedding query SQL inline**: Rejected because it makes project
files large and mixes concerns. A separate `queries.toml` keeps the project file
as a lightweight manifest and the query library independently editable.
