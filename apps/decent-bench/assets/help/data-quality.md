# Data Quality

The Quality workspace checks whether imported data is trustworthy before you build queries, exports, or reports on top of it.

Open it from the navigation pane **Quality** tab or from **Tools > Data Quality Dashboard** after opening a DecentDB file.

## Run a quality profile

Click **Run** in the Quality dashboard to scan the current database. The default profile is generated from schema metadata and runs checks such as required values, uniqueness, and referential integrity when those constraints are visible in the schema.

You do not have to create validation rules before using Quality. Custom profiles are optional and are useful when your business rules are stricter than the source schema.

Import summaries also include **Run Quality Profile** after a successful import.
That opens the imported DecentDB file and immediately runs the current/default
quality profile, keeping import success separate from any quality findings.

## What a run includes

A quality run can include:

- Table and column profiling: row counts, null rates, empty-string rates, distinct counts, min/max values, distribution summaries, numeric medians, and outlier summaries where applicable.
- Validation issues: grouped failures from enabled rules, with paged details for row inspection.
- Import reconciliation: source row counts, imported row counts, warning counts, skipped rows, rejected rows, and type-coercion warnings when import metadata is available.
- Duplicate summaries: exact duplicate checks and bounded near-duplicate checks when enabled by the profile.

Quality runs are stored per workspace so recent results remain available after reopening the database.

## Manage validation profiles

Use **Manage Profiles** to create, duplicate, delete, and save quality profiles. A profile stores the run mode, sample size, reconciliation settings, duplicate-check settings, and validation rules.

Rule types include:

- Required values
- Unique keys
- Allowed values
- Regular expressions
- Numeric ranges
- Date ranges
- String length ranges
- Cross-column SQL predicates
- Referential checks
- Custom SQL predicates
- Exact duplicate rows
- Near-duplicate rows

Rules run in the background. SQL-backed rules use DecentDB aggregate/detail queries; rules that cannot be expressed portably in SQL use bounded app-side scans.

Regex and near-duplicate checks run their non-SQL comparison work in background
isolates over bounded inputs. Query-result targets are profiled by materializing
the result into a temporary DecentDB table for the duration of the run.

## Full versus sampled mode

Full mode scans the selected tables completely. Sampled mode scans a bounded number of rows per table and marks sampled metrics as sampled. Use sampled mode for a fast first look at very large tables, then use full mode before making decisions that depend on exact counts.

## Freshness

The dashboard marks the latest run as fresh, stale, running, failed, or no run. A run becomes stale when the loaded schema fingerprint no longer matches the fingerprint captured during the quality run.

## Export reports

Use **Export Report** to write Markdown, HTML, or JSON reports. Reports redact failing row sample values by default. Enable sample values only when the destination is allowed to contain source data.

The headless command can run the same workflow without the desktop UI:

```bash
dbench quality --database /path/to/workspace.ddb \
  --profile /path/to/quality-profile.toml \
  --out /tmp/quality-report.json \
  --format json
```

Use `dbench quality --help` for target table, sampled mode, and privacy options.
