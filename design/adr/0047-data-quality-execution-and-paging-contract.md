## Data Quality Execution And Paging Contract
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench will execute data quality profiling, validation, duplicate
detection, violation browsing, and report preparation through cancellable
background jobs. No heavy data quality operation may run on the Flutter UI
isolate.

The execution model is:

- One active quality run is allowed per workspace.
- A quality run may target a database, one table, or a query result.
- Quality run progress reports the current phase, current table, current rule
  when applicable, rows scanned when available, and whether cancellation is
  available.
- Cancellation is best-effort and must stop after the current DecentDB query,
  page, or isolate batch completes.
- Completed, failed, and cancelled runs all produce persisted run result state
  with explicit status.

Built-in profiling metrics and validation rules compile to DecentDB SQL where
possible. SQL-backed checks must quote identifiers correctly and must not
materialize full tables in Dart. SQL-backed validation issue details are exposed
as paged DecentDB queries.

Rules that cannot be fully SQL-backed may run in Dart only through background
isolate execution over paged or bounded inputs:

- Regex validation may use isolate execution when DecentDB does not expose a
  compatible regex function/operator.
- Near-duplicate matching uses isolate execution after SQL candidate
  generation.

Violation details are always paged:

- SQL-backed issues expose a detail query and page through it.
- Isolate-backed issues store detail rows in JSON Lines and page through that
  file.
- The UI must never load all violation rows into widget state.

Full-table scans are allowed only inside cancellable background jobs. Sampling
mode is explicit:

- `mode = "full"` means the selected target was scanned according to the full
  rule/profile contract.
- `mode = "sampled"` means the selected target was sampled.
- Sampled output, UI labels, and reports must say sampled and include the
  sample row limit.

Fuzzy duplicate detection is bounded:

- Candidate rows must be produced by SQL using configured blocking columns
  where possible.
- If no blocking columns are configured, the candidate set must be capped by
  the configured candidate limit.
- Similarity scoring may only run over the bounded candidate set.
- Unbounded pairwise comparison is not allowed.

### Rationale

Data quality work can require large scans, aggregate queries, duplicate group
construction, and rule evaluation. Running that work directly in the UI would
violate Decent Bench's performance-first contract.

DecentDB SQL is the right execution engine for most metrics and validation
rules because it keeps work close to the database and avoids app-side
materialization. Dart isolate execution is reserved for checks that require
logic not available in DecentDB SQL, and those checks must still operate over
paged or bounded data.

Paged violation browsing is required because a single failed rule can identify
millions of rows. A useful issue summary should not require loading every
failing row.

Explicit sampled mode prevents false confidence. Sampled profiles are useful
for very large data, but every downstream surface must make the sampling clear.

Near-duplicate detection is valuable but naturally expensive. Candidate limits
and blocking columns are mandatory so the feature cannot accidentally trigger
unbounded pairwise comparisons.

### Alternatives Considered

- Compute quality profiles from the currently loaded result-grid rows.
  Rejected because loaded rows are not representative of the full table and
  would produce misleading results.

- Materialize full tables in Dart and compute all metrics in memory.
  Rejected because it violates streaming/paging requirements and would freeze
  or exhaust memory on large data.

- Require all validation rules to be SQL-only.
  Rejected because regex and near-duplicate matching may need non-SQL logic on
  some platforms or engine versions.

- Make fuzzy duplicate detection unbounded for accuracy.
  Rejected because worst-case pairwise matching is not acceptable in a desktop
  workbench that must stay responsive.

- Hide cancelled or failed quality runs.
  Rejected because users need a durable audit trail of attempted quality work
  and clear failure diagnostics.

### Trade-offs

- SQL-first execution requires careful SQL generation and identifier quoting,
  but it preserves performance and avoids unnecessary data transfer.
- Isolate-backed rules introduce more execution paths to test, but they keep
  regex and fuzzy matching available without blocking the UI.
- Paged violations make the UI more complex, but they are required for large
  datasets.
- Bounded near-duplicate detection may miss matches outside the candidate set.
  The UI and reports must disclose candidate limits.
- One active quality run per workspace limits concurrency, but it keeps
  progress, cancellation, database load, and result persistence predictable.

### References

- `design/WIN_DATA_QUALITY_PROFILING_VALIDATION_PLAN.md`
- `design/FUTURE_WINS.md`
- `design/adr/0002-results-paging-and-streaming-contract.md`
- `design/adr/0022-headless-cli-import-mode-and-plan-file.md`
- `design/adr/0046-data-quality-persistence-and-project-contract.md`
- `design/adr/0048-data-quality-report-privacy-contract.md`
