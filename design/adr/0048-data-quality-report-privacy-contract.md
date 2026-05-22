## Data Quality Report Privacy Contract
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench will export data quality reports in three formats:

- Markdown (`.md`)
- self-contained HTML (`.html`)
- machine-readable JSON (`.json`)

Reports include summary metrics by default:

- database/project metadata,
- quality run metadata,
- freshness status,
- full or sampled mode,
- schema and data fingerprints,
- import reconciliation summary,
- table and column profile summaries,
- validation issue summaries,
- duplicate summaries,
- warnings and limitations.

Reports exclude raw failing row values by default. Report export may include
sample values only when the user explicitly selects
`include_sample_values = true`. In the GUI, enabling sample values requires a
confirmation that explains the report may contain source data. In CLI mode,
sample values are included only when the user supplies the explicit
`--include-sample-values` flag.

Reports may include violation detail rows only when the user explicitly selects
the relevant export option. Including detail rows does not automatically imply
including row values; detail rows still follow the sample-value setting.

Every report must include:

- app name and version,
- report generation timestamp,
- quality run ID,
- quality profile ID and name when available,
- target database path display value,
- target table or query label when applicable,
- source table names,
- column names,
- rule names,
- issue codes,
- severity counts,
- schema fingerprint and algorithm,
- data fingerprints and algorithms,
- whether results were full or sampled,
- stale/fresh status.

HTML reports must be self-contained:

- no remote CSS,
- no remote JavaScript,
- no remote images,
- no remote fonts,
- no network-loading assets of any kind.

Report writers must escape user-controlled strings for the target format. HTML
output must HTML-escape table names, column names, values, rule names, warning
messages, and error messages. Markdown output must avoid emitting raw HTML.
JSON output must include `report_schema_version = 1` and must be valid UTF-8.

### Rationale

Quality reports are meant to be shared with teammates, attached to tickets, or
used by automation. They need stable formats and predictable privacy behavior.

Data quality failures often involve sensitive values: names, emails, customer
IDs, financial amounts, health fields, or operational identifiers. Including
raw failing rows by default would create surprise data copies. Summary-first
reports preserve usefulness while respecting Decent Bench's local-first and
privacy-first stance.

Markdown is useful for human-readable notes and version control. HTML is useful
for self-contained review outside the app. JSON is required for automation and
CI workflows.

Self-contained HTML keeps reports portable and prevents accidental network
access when a report is opened.

### Alternatives Considered

- Export only JSON and let users transform it themselves.
  Rejected because users need human-readable reports without writing scripts.

- Export only HTML.
  Rejected because automation needs a machine-readable contract and Markdown is
  useful for documentation workflows.

- Include sample row values by default.
  Rejected because reports can leave the local workspace and may expose
  sensitive source data.

- Allow remote assets in HTML reports for richer styling.
  Rejected because reports should be portable, deterministic, and local-only.

- Add PDF export in the first report contract.
  Rejected for this Future Win because Markdown, HTML, and JSON cover the core
  needs without introducing rendering or packaging dependencies.

### Trade-offs

- Privacy-first defaults make reports less immediately detailed, but users can
  opt into sample values when needed.
- Self-contained HTML is less flexible than asset-based reports, but it is
  safer and easier to share.
- Supporting three formats increases test coverage requirements, but each
  format serves a distinct workflow.
- Excluding PDF avoids dependency risk now but may require a later ADR if PDF
  becomes necessary.

### References

- `design/WIN_DATA_QUALITY_PROFILING_VALIDATION_PLAN.md`
- `design/FUTURE_WINS.md`
- `design/adr/0046-data-quality-persistence-and-project-contract.md`
- `design/adr/0047-data-quality-execution-and-paging-contract.md`
