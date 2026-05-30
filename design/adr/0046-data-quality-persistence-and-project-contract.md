## Data Quality Persistence And Project Contract
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench will persist data quality profiles, quality run results, import
reconciliation metadata, and project references using separate storage contracts
with clear ownership boundaries.

Validation profiles are user-authored, portable TOML documents:

- Profile files use `config_version = 1`.
- Profiles contain validation rules and profiling defaults.
- Profiles contain no row data.
- Profiles use stable UUIDs for profile IDs and rule IDs.
- Profiles may be referenced from a workspace project file by relative path.

Workspace project files may add a `[quality]` section:

```toml
[quality]
profile_path = "quality/default-quality-profile.toml"
default_mode = "full"
```

The project file references the profile but does not embed profile contents,
quality run results, violation details, import warning details, or database
contents. Project-relative paths remain the default for portability.

Quality run results are machine-owned workspace state, not project source:

- Run summaries are stored under the workspace state directory:
  `quality/runs/<run_id>/quality-result.json`.
- Violation details that cannot be represented by a DecentDB paged query are
  stored as JSON Lines:
  `quality/runs/<run_id>/violations/<issue_id>.jsonl`.
- Import reconciliation records are stored under:
  `quality/imports/<import_job_id>.json`.

Validation results may contain issue summaries and row identity references.
They must not persist full failing row values by default. Full or sample row
values may appear only when a user explicitly chooses an option that allows
sample values for the relevant run or report.

Quality freshness is determined from:

- the current schema fingerprint,
- the schema fingerprint recorded on the quality run,
- current table data fingerprints,
- table data fingerprints recorded on the quality run.

If DecentDB exposes a stable table/content fingerprint API, Decent Bench will
use it. Otherwise Decent Bench will use the deterministic fallback described in
`design/WIN_DATA_QUALITY_PROFILING_VALIDATION_PLAN.md`: row count, normalized
column metadata, selected aggregate summaries, and a SHA-256 hash of that
normalized payload. The fallback is a freshness signal, not cryptographic proof
of row identity.

Stale results remain visible for history and comparison, but the UI and report
export must label them as stale. Stale results must never be silently presented
as current.

### Rationale

The data quality suite needs durable validation profiles because users will
rerun the same checks after repeated imports. Those profiles should be portable,
reviewable, and consistent with the repository's TOML-first project convention.

Quality run results are different from profiles. They are generated state,
potentially large, tied to local database contents, and not hand-authored. They
belong beside workspace state rather than inside the project manifest.

Keeping profiles separate from results makes the project file small and
version-control-friendly while still allowing projects to opt into a default
quality profile.

The row-value privacy boundary is part of persistence, not only report export.
Persisting full failing rows by default would create surprise local copies of
potentially sensitive source data. Summary counts, row identity references, and
diagnostic queries are enough for the default workflow.

Freshness detection is required because quality results can become obsolete as
soon as a user edits data, reruns an import, or changes schema. Visible stale
state is safer than deleting old runs or pretending they still describe the
current database.

### Alternatives Considered

- Embed validation profiles directly in `.dbench-project.toml`.
  Rejected because profiles can become long, are independently reusable, and
  need import/export actions of their own.

- Store validation profiles as JSON.
  Rejected because user-authored configuration in Decent Bench is TOML-first
  and project files already use TOML.

- Store quality run results inside the DecentDB file.
  Rejected for the initial contract because quality results are app-owned
  workspace metadata and should not mutate user data files merely because a
  profile was run.

- Store full failing row values by default for convenience.
  Rejected because it creates unnecessary sensitive data copies and conflicts
  with the local privacy model.

- Treat stale quality results as invalid and hide them.
  Rejected because historical runs can still help users compare import quality
  over time. They must be labeled, not hidden.

### Trade-offs

- Separate profile and result storage introduces more files, but it keeps
  source-controlled project data distinct from machine-generated state.
- TOML profiles are easy to review and edit, but strict parsing and validation
  are required to keep automation predictable.
- Fallback data fingerprints may miss some data changes. The UI must describe
  them as freshness signals, not cryptographic guarantees.
- Avoiding full row-value persistence by default means users may need to rerun
  detail queries to inspect current failing rows. That is preferable to
  silently storing sensitive data.

### References

- `design/WIN_DATA_QUALITY_PROFILING_VALIDATION_PLAN.md`
- `design/FUTURE_WINS.md`
- `design/adr/0029-workspace-project-file-and-query-library.md`
- `design/adr/0022-headless-cli-import-mode-and-plan-file.md`
- `design/adr/0047-data-quality-execution-and-paging-contract.md`
- `design/adr/0048-data-quality-report-privacy-contract.md`
