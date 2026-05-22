# Future Win Plan: Data Quality, Profiling, And Validation Suite

**Status:** Planning document  
**Last reviewed:** 2026-05-22  
**Source roadmap item:** `design/FUTURE_WINS.md` rank 2, `P0`
**Target outcome:** 100% completion of the Data Quality, Profiling, and
Validation Suite through explicit implementation slices.

## Purpose

This document turns the Future Win item "Data quality, profiling, and
validation suite" into an implementation-ready plan.

The plan is intentionally verbose. Each slice specifies the product behavior,
data contracts, implementation files, tests, documentation, and acceptance
criteria. A coding agent implementing a slice should not make product,
architecture, persistence, or UX decisions. If a decision appears necessary
while implementing, stop and update this plan or create the required ADR before
coding.

This is a full-completion plan. The slices are sequencing boundaries, not
optional partial product scope. The Future Win is not complete until every
slice in this document is implemented, tested, documented, and validated.

## Product Goal

After a user imports or opens data in Decent Bench, they should be able to
answer these questions without hand-writing diagnostic SQL:

1. Did the import bring in the expected number of rows and tables?
2. Which columns contain nulls, empty strings, malformed values, suspicious
   distributions, duplicates, or outliers?
3. Which user-defined quality rules passed or failed?
4. Which exact rows failed each rule?
5. Is a previous quality report stale because the schema or data changed?
6. Can the same quality checks be rerun later in the GUI, from a project file,
   or from the CLI?
7. Can a quality report be exported for review without exposing sensitive row
   values by default?

## Definition Of 100% Complete

The suite is complete only when all of the following are true:

- A first-class **Quality** area exists in the workspace UI.
- Users can profile an entire database, selected tables, or a query result.
- Users can run all required built-in profiling metrics listed in this plan.
- Users can define, edit, enable, disable, duplicate, delete, import, export,
  and run validation profiles.
- Validation profiles persist with the workspace project format.
- Validation can run after import, on demand from the GUI, and from headless CLI.
- Validation results are persisted with schema/data fingerprints and stale
  result detection.
- Violations are browsable through a paged UI without full materialization.
- Exact duplicate detection is implemented.
- Near-duplicate detection is implemented with deterministic, bounded,
  cancellable behavior.
- Quality reports can be exported as Markdown, HTML, and JSON.
- Report exports omit row values by default unless the user explicitly includes
  sample values.
- All long-running work runs off the UI thread.
- Every scan, profile, validation run, duplicate check, and report export has
  progress, cancellation, and error reporting.
- The suite works with the existing DecentDB-first workspace model and does not
  introduce a live external database workflow.
- Tests cover domain models, serialization, SQL generation, execution paging,
  cancellation, stale detection, UI state, CLI behavior, import integration, and
  report export.
- Help documentation explains the Quality workflow, rule types, report privacy,
  and performance modes.

## Non-Goals

Do not implement these as part of this Future Win:

- Collaborative quality review.
- Cloud-hosted report sharing.
- Live external database quality scans.
- Data repair workflows beyond links/navigation to existing table editing or
  import retry surfaces.
- Automatic mutation of data to "fix" quality issues.
- Machine-learning anomaly detection.
- Unbounded fuzzy matching over large tables.
- Quality rules that execute arbitrary user scripts.
- Quality reports that include full failing datasets by default.

## Required ADRs Before Code

The implementation changes persistent formats, report contracts, execution
contracts, and privacy defaults. Create ADRs before starting code. The ADRs
must not be skipped.

### ADR A: Data Quality Persistence And Project Contract

Use `design/adr/0046-data-quality-persistence-and-project-contract.md`.

It must accept the following decisions:

- Validation profiles are stored in TOML with `config_version = 1`.
- Project files reference a validation profile file by relative path.
- Validation run results are stored in a machine-owned JSON sidecar under the
  workspace state directory, not embedded in the project TOML.
- Validation profiles contain no row data.
- Validation results contain issue summaries and row identity references, but
  no full row values unless the user explicitly includes sample values in an
  exported report.
- Schema and data freshness use schema fingerprint plus table content
  fingerprints described in this plan.
- Stale results are visible but never silently reused as current.

### ADR B: Data Quality Execution And Paging Contract

Use `design/adr/0047-data-quality-execution-and-paging-contract.md`.

It must accept the following decisions:

- Profiling and validation jobs run through the workspace job infrastructure
  and never execute heavy scans on the UI thread.
- Built-in rule checks compile to DecentDB SQL where possible.
- Violation details are exposed as paged query handles or paged query requests.
- Full-table scans are allowed only inside cancellable background jobs.
- Sampling mode is explicit and report output must say `mode = sampled`.
- Fuzzy duplicate detection is bounded by configured candidate keys and maximum
  candidate limits.

### ADR C: Data Quality Report Privacy Contract

Use `design/adr/0048-data-quality-report-privacy-contract.md`.

It must accept the following decisions:

- Markdown, HTML, and JSON report export are required.
- Reports include summary metrics by default.
- Reports exclude raw failing row values by default.
- Reports may include sample values only when the export option
  `include_sample_values = true` is explicitly selected.
- Reports must include source table names, column names, rule names,
  fingerprints, run timestamps, app version, and whether results were full or
  sampled.
- HTML report output must be self-contained and must not load remote assets.

## Implementation Location

Use these paths unless the surrounding code has moved:

- Domain models:
  - `apps/decent-bench/lib/features/workspace/domain/data_quality_models.dart`
  - `apps/decent-bench/lib/features/workspace/domain/data_quality_rules.dart`
  - `apps/decent-bench/lib/features/workspace/domain/data_quality_reports.dart`
- Application orchestration:
  - `apps/decent-bench/lib/features/workspace/application/data_quality_controller.dart`
  - integrate into `apps/decent-bench/lib/features/workspace/application/workspace_controller.dart`
- Infrastructure:
  - `apps/decent-bench/lib/features/workspace/infrastructure/data_quality_repository.dart`
  - `apps/decent-bench/lib/features/workspace/infrastructure/data_quality_runner.dart`
  - `apps/decent-bench/lib/features/workspace/infrastructure/data_quality_report_writer.dart`
- UI:
  - `apps/decent-bench/lib/features/workspace/presentation/quality/data_quality_dashboard.dart`
  - `apps/decent-bench/lib/features/workspace/presentation/quality/table_quality_view.dart`
  - `apps/decent-bench/lib/features/workspace/presentation/quality/validation_profile_editor.dart`
  - `apps/decent-bench/lib/features/workspace/presentation/quality/violation_browser.dart`
  - `apps/decent-bench/lib/features/workspace/presentation/quality/quality_report_export_dialog.dart`
- CLI:
  - extend `apps/decent-bench/bin/headless_import.dart` only if the current
    binary remains the only CLI entry point;
  - otherwise add `apps/decent-bench/bin/dbench_quality.dart` and wire it into
    the packaging scripts.
- Help:
  - `apps/decent-bench/assets/help/data-quality.md`
  - update `apps/decent-bench/assets/help/help_manifest.json`
  - link from `apps/decent-bench/assets/help/importing-data.md`
  - link from `apps/decent-bench/assets/help/results-grid.md`
- Tests:
  - `apps/decent-bench/test/features/workspace/domain/data_quality_models_test.dart`
  - `apps/decent-bench/test/features/workspace/domain/data_quality_rules_test.dart`
  - `apps/decent-bench/test/features/workspace/infrastructure/data_quality_repository_test.dart`
  - `apps/decent-bench/test/features/workspace/infrastructure/data_quality_runner_test.dart`
  - `apps/decent-bench/test/features/workspace/infrastructure/data_quality_report_writer_test.dart`
  - `apps/decent-bench/test/features/workspace/application/data_quality_controller_test.dart`
  - `apps/decent-bench/test/features/workspace/presentation/data_quality_dashboard_test.dart`
  - `apps/decent-bench/test/features/workspace/presentation/violation_browser_test.dart`
  - `apps/decent-bench/test/app/headless_quality_runner_test.dart`
  - integration test coverage in `apps/decent-bench/integration_test/`.

## Required Domain Vocabulary

Use these exact terms in code, UI labels, docs, and tests:

- **Quality profile**: saved set of validation rules and profiling settings.
- **Quality run**: one execution of profiling and/or validation.
- **Quality result**: persisted summary of a quality run.
- **Profile summary**: table and column statistics produced by profiling.
- **Validation rule**: a reusable rule definition.
- **Validation issue**: grouped result for a failed rule.
- **Violation row**: one row that failed a rule.
- **Import reconciliation**: source row/table counts compared to imported
  row/table counts and import warnings.
- **Fresh**: result fingerprints match the current schema and data.
- **Stale**: result fingerprints no longer match the current schema or data.
- **Sampled**: result was computed from an explicit sample, not the whole
  target.
- **Full**: result was computed from the whole selected target.

## Required Data Contracts

Implement these models exactly. Additional fields require a plan update.

### QualityProfileDocument

Purpose: persisted TOML profile containing validation rules and profiling
defaults.

Required fields:

- `configVersion`: integer, always `1` for this plan.
- `profileId`: UUID v4 string.
- `name`: non-empty string.
- `description`: string, empty allowed.
- `createdAt`: UTC ISO-8601 string.
- `updatedAt`: UTC ISO-8601 string.
- `defaultMode`: enum string: `full` or `sampled`.
- `sampleRowLimit`: positive integer, default `10000`.
- `includeImportReconciliation`: bool.
- `includeDuplicateChecks`: bool.
- `duplicateCandidateLimit`: positive integer, default `50000`.
- `rules`: list of `ValidationRule`.

TOML shape:

```toml
config_version = 1
profile_id = "9b5f2b26-3dd8-46f8-a26a-917f53af20fd"
name = "Default import quality checks"
description = "Rules applied after recurring spreadsheet imports."
created_at = "2026-05-22T12:00:00Z"
updated_at = "2026-05-22T12:00:00Z"
default_mode = "full"
sample_row_limit = 10000
include_import_reconciliation = true
include_duplicate_checks = true
duplicate_candidate_limit = 50000

[[rules]]
id = "f51a59b9-f692-4a76-8b2b-d425f7f3d74b"
name = "Orders require customer id"
description = "Imported orders must be linked to a customer."
enabled = true
severity = "error"
target_table = "orders"
target_column = "customer_id"
rule_type = "required"

[rules.params]
trim_strings = true
```

Validation:

- Reject unsupported `config_version`.
- Reject empty `profile_id`, `name`, rule `id`, rule `name`, `target_table`,
  or `rule_type`.
- Reject duplicate rule IDs.
- Reject unknown enum values.
- Reject rule params not supported by the rule type.
- Reject `sample_row_limit < 1`.
- Reject `duplicate_candidate_limit < 1`.

### ValidationRule

Required fields:

- `id`: UUID v4 string.
- `name`: non-empty string.
- `description`: string, empty allowed.
- `enabled`: bool.
- `severity`: enum string: `info`, `warning`, `error`.
- `targetTable`: non-empty string.
- `targetColumn`: nullable string.
- `ruleType`: enum string from the rule types below.
- `params`: string-keyed map validated by rule type.

Required rule types:

1. `required`
2. `unique`
3. `allowed_values`
4. `regex`
5. `numeric_range`
6. `date_range`
7. `string_length`
8. `cross_column`
9. `referential`
10. `custom_sql_predicate`
11. `exact_duplicate_rows`
12. `near_duplicate_rows`

### Rule Type Parameters

Implement these parameter contracts exactly.

#### required

Fields:

- `trim_strings`: bool, default `true`.
- `treat_empty_string_as_null`: bool, default `true`.

Failure condition:

- value is `NULL`; or
- value is empty string after trimming when
  `treat_empty_string_as_null = true`.

#### unique

Fields:

- `columns`: list of non-empty strings. If omitted, use `target_column`.
- `ignore_nulls`: bool, default `true`.
- `trim_strings`: bool, default `false`.

Failure condition:

- more than one row has the same normalized key.

#### allowed_values

Fields:

- `values`: list of strings, required and non-empty.
- `case_sensitive`: bool, default `true`.
- `trim_strings`: bool, default `true`.
- `allow_null`: bool, default `true`.

Failure condition:

- non-null value is not in the allowed set after configured normalization.

#### regex

Fields:

- `pattern`: non-empty string.
- `case_sensitive`: bool, default `true`.
- `allow_null`: bool, default `true`.

Failure condition:

- non-null value does not match the regex.

Implementation rule:

- If DecentDB exposes a compatible regex operator/function, compile to SQL.
- If DecentDB does not expose compatible regex support, execute in a background
  Dart isolate over paged values.
- Never run regex validation on the UI isolate.

#### numeric_range

Fields:

- `min`: nullable number.
- `max`: nullable number.
- `inclusive_min`: bool, default `true`.
- `inclusive_max`: bool, default `true`.
- `allow_null`: bool, default `true`.

Failure condition:

- value is outside the configured numeric range.

Validation:

- At least one of `min` or `max` is required.

#### date_range

Fields:

- `min`: nullable ISO-8601 date/time string.
- `max`: nullable ISO-8601 date/time string.
- `inclusive_min`: bool, default `true`.
- `inclusive_max`: bool, default `true`.
- `allow_null`: bool, default `true`.

Failure condition:

- parsed date/time value is outside the configured range.
- malformed date/time values fail with issue code `malformed_temporal_value`
  unless `allow_null = true` and value is null.

Validation:

- At least one of `min` or `max` is required.

#### string_length

Fields:

- `min_length`: nullable integer.
- `max_length`: nullable integer.
- `trim_strings`: bool, default `false`.
- `allow_null`: bool, default `true`.

Failure condition:

- normalized string length is outside the configured range.

Validation:

- At least one of `min_length` or `max_length` is required.

#### cross_column

Fields:

- `sql_expression`: non-empty SQL expression string.
- `referenced_columns`: list of non-empty strings, required.

Failure condition:

- expression evaluates to false or null for a row.

SQL generation:

- Compile as:

```sql
SELECT <row_identity_columns>
FROM "<target_table>"
WHERE NOT (<sql_expression>) OR (<sql_expression>) IS NULL
LIMIT <page_size> OFFSET <offset>;
```

Safety:

- Reject expressions containing semicolons.
- Reject expressions containing DDL/DML keywords.
- Reject expressions that reference tables other than the target table.

#### referential

Fields:

- `source_columns`: list of non-empty strings, required.
- `reference_table`: non-empty string.
- `reference_columns`: list of non-empty strings, required.
- `ignore_nulls`: bool, default `true`.

Failure condition:

- source key does not exist in the reference table.

Validation:

- `source_columns.length == reference_columns.length`.

#### custom_sql_predicate

Fields:

- `predicate_sql`: non-empty SQL predicate.
- `referenced_columns`: list of non-empty strings, required.

Failure condition:

- predicate evaluates to false or null.

Safety:

- Same safety rules as `cross_column`.
- This rule is advanced; UI must label it "Custom SQL predicate".

#### exact_duplicate_rows

Fields:

- `columns`: list of non-empty strings, required.
- `ignore_nulls`: bool, default `false`.
- `trim_strings`: bool, default `false`.

Failure condition:

- more than one row has the same normalized key over the listed columns.

#### near_duplicate_rows

Fields:

- `columns`: list of non-empty strings, required.
- `similarity`: enum string: `normalized_levenshtein` or `token_sort_ratio`.
- `threshold`: number between `0.0` and `1.0`.
- `candidate_limit`: positive integer.
- `blocking_columns`: list of strings, empty allowed.
- `trim_strings`: bool, default `true`.
- `case_sensitive`: bool, default `false`.

Failure condition:

- two candidate rows exceed the similarity threshold.

Execution rule:

- Generate candidates with SQL using `blocking_columns` first.
- If `blocking_columns` is empty, candidate set is limited by
  `candidate_limit`.
- Similarity scoring runs in a background isolate over candidate pairs.
- The UI must show "bounded near-duplicate scan" and the candidate limit.

### QualityRunRequest

Purpose: user or CLI request to run profiling and validation.

Required fields:

- `targetKind`: enum string: `database`, `table`, `query_result`.
- `targetDatabasePath`: string.
- `targetTable`: nullable string.
- `targetQueryId`: nullable string.
- `targetQuerySql`: nullable string.
- `profileId`: nullable string.
- `profilePath`: nullable string.
- `mode`: enum string: `full` or `sampled`.
- `sampleRowLimit`: positive integer.
- `includeProfiling`: bool.
- `includeValidation`: bool.
- `includeImportReconciliation`: bool.
- `includeDuplicateChecks`: bool.
- `requestedAt`: UTC ISO-8601 string.

Validation:

- `database` target must not set table/query fields.
- `table` target must set `targetTable`.
- `query_result` target must set either `targetQueryId` or `targetQuerySql`.
- At least one of `includeProfiling`, `includeValidation`,
  `includeImportReconciliation`, or `includeDuplicateChecks` must be true.

### QualityRunResult

Purpose: persisted summary and detail index for one quality run.

Required fields:

- `runId`: UUID v4 string.
- `profileId`: nullable string.
- `targetKind`: enum string.
- `targetLabel`: human-readable string.
- `databasePath`: string.
- `startedAt`: UTC ISO-8601 string.
- `completedAt`: nullable UTC ISO-8601 string.
- `status`: enum string: `running`, `completed`, `failed`, `cancelled`.
- `mode`: enum string: `full` or `sampled`.
- `sampleRowLimit`: nullable integer.
- `schemaFingerprint`: string.
- `schemaFingerprintAlgorithm`: string.
- `dataFingerprints`: list of `QualityDataFingerprint`.
- `profileSummaries`: list of `TableQualitySummary`.
- `validationIssues`: list of `ValidationIssueSummary`.
- `importReconciliation`: nullable `ImportReconciliationSummary`.
- `duplicateSummaries`: list of `DuplicateSummary`.
- `errorMessage`: nullable string.
- `warningMessages`: list of strings.
- `detailStorePath`: nullable string.

Storage:

- Store one JSON file per run:
  - workspace state directory:
    `quality-runs/<run_id>/quality-result.json`
  - details:
    `quality-runs/<run_id>/violations/<issue_id>.jsonl`
    when details cannot be represented as a DecentDB paged query.
- Do not write run results into `.dbench-project.toml`.

### QualityDataFingerprint

Required fields:

- `tableName`: string.
- `rowCount`: integer.
- `contentFingerprint`: string.
- `contentFingerprintAlgorithm`: string.
- `computedAt`: UTC ISO-8601 string.

Algorithm for `contentFingerprint`:

- Use DecentDB-provided table/content fingerprint if a stable API exists.
- Otherwise compute deterministic fallback:
  - `rowCount`
  - ordered list of column names and type names
  - for each column:
    - null count
    - non-null count
    - min/max for numeric/date-compatible values
    - count distinct estimate if exact distinct is too expensive
  - hash the normalized JSON payload with SHA-256.

The fallback is a freshness signal, not a cryptographic proof that rows are
identical.

### TableQualitySummary

Required fields:

- `tableName`: string.
- `rowCount`: integer.
- `profileMode`: enum string: `full` or `sampled`.
- `sampleRowCount`: nullable integer.
- `columnSummaries`: list of `ColumnQualitySummary`.
- `tableWarnings`: list of strings.

### ColumnQualitySummary

Required fields:

- `columnName`: string.
- `typeName`: string.
- `nativeTypeFamily`: nullable string.
- `rowCount`: integer.
- `sampleRowCount`: nullable integer.
- `nullCount`: integer.
- `nullPercent`: number.
- `emptyStringCount`: integer.
- `emptyStringPercent`: number.
- `nonNullCount`: integer.
- `distinctCount`: integer.
- `distinctPercent`: number.
- `minValueDisplay`: nullable string.
- `maxValueDisplay`: nullable string.
- `meanValueDisplay`: nullable string.
- `medianValueDisplay`: nullable string.
- `stddevValueDisplay`: nullable string.
- `minLength`: nullable integer.
- `maxLength`: nullable integer.
- `topValues`: list of `QualityValueFrequency`.
- `histogramBuckets`: list of `QualityHistogramBucket`.
- `malformedTemporalCount`: integer.
- `potentialKey`: bool.
- `outlierSummary`: nullable `OutlierSummary`.
- `warnings`: list of strings.

### QualityValueFrequency

Required fields:

- `valueDisplay`: string.
- `count`: integer.
- `percent`: number.

Limit:

- Keep at most 10 top values per column in the persisted summary.

### QualityHistogramBucket

Required fields:

- `label`: string.
- `lowerBoundDisplay`: nullable string.
- `upperBoundDisplay`: nullable string.
- `count`: integer.
- `percent`: number.

Required behavior:

- Numeric/date columns get up to 10 buckets.
- Non-numeric/non-date columns do not get histogram buckets.

### OutlierSummary

Required fields:

- `method`: enum string: `iqr`.
- `lowerFenceDisplay`: string.
- `upperFenceDisplay`: string.
- `outlierCount`: integer.
- `outlierPercent`: number.

Required behavior:

- Use IQR only.
- Compute Q1 and Q3 through DecentDB SQL if supported.
- If DecentDB lacks percentile support, compute approximate quartiles in a
  background job using paged sorted values with a hard memory cap.
- Do not implement Z-score in this Future Win.

### ImportReconciliationSummary

Required fields:

- `importJobId`: nullable string.
- `sourcePathDisplay`: string.
- `sourceFormat`: string.
- `sourceFingerprint`: nullable string.
- `startedAt`: nullable UTC ISO-8601 string.
- `completedAt`: nullable UTC ISO-8601 string.
- `tableMappings`: list of `ImportTableReconciliation`.
- `warningCount`: integer.
- `warningsByTable`: map from table name to integer.
- `warningsByCode`: map from warning code to integer.

### ImportTableReconciliation

Required fields:

- `sourceName`: string.
- `targetTable`: string.
- `sourceRowCount`: nullable integer.
- `importedRowCount`: integer.
- `skippedRowCount`: integer.
- `rejectedRowCount`: integer.
- `transformedRowCount`: integer.
- `typeCoercionFailureCount`: integer.
- `warningCount`: integer.

### ValidationIssueSummary

Required fields:

- `issueId`: UUID v4 string.
- `ruleId`: string.
- `ruleName`: string.
- `ruleType`: string.
- `severity`: enum string.
- `targetTable`: string.
- `targetColumn`: nullable string.
- `issueCode`: non-empty string.
- `message`: non-empty string.
- `failureCount`: integer.
- `sampleViolationRows`: list of `ViolationRowReference`.
- `detailsAvailable`: bool.
- `detailQuerySql`: nullable string.
- `detailStorePath`: nullable string.

### ViolationRowReference

Required fields:

- `rowIdentity`: map from column name to display string.
- `rowNumber`: nullable integer.
- `valueDisplay`: nullable string.
- `message`: string.

Privacy:

- `valueDisplay` may be stored only when the user selected
  `include_sample_values = true` for the run or report. Otherwise store null.

## Required Profiling Metrics

Profiling must produce these metrics for every selected table and column:

- row count,
- null count,
- null percentage,
- empty string count,
- empty string percentage,
- non-null count,
- exact distinct count for tables under the configured exact threshold,
- approximate distinct count or explicit "not computed" warning for very large
  columns when exact distinct would violate performance limits,
- distinct percentage,
- min/max display value,
- numeric mean,
- numeric median,
- numeric standard deviation,
- string min length,
- string max length,
- top 10 values by frequency,
- numeric/date histogram with up to 10 buckets,
- malformed temporal count for columns inferred or typed as temporal,
- IQR outlier summary for numeric columns,
- potential key indicator.

Potential key rule:

- `potentialKey = true` only when:
  - `nullCount == 0`,
  - `distinctCount == rowCount`,
  - `rowCount > 0`.

## Required Import Reconciliation Behavior

Import reconciliation is mandatory for imports launched through Decent Bench.

Each import path must record:

- source path display value,
- source format key,
- source fingerprint if available,
- source table/sheet/object name,
- target table name,
- source row count when known,
- imported row count,
- skipped row count,
- rejected row count,
- transformed row count,
- type coercion failure count,
- warnings with stable warning codes.

Warning code requirements:

- Existing free-form warnings must be mapped to stable codes before they enter
  quality results.
- Unknown warnings use `import_warning_unknown`.
- Type coercion failures use `type_coercion_failed`.
- Skipped malformed rows use `malformed_row_skipped`.
- Truncated or padded malformed rows use `malformed_row_normalized`.
- Unsupported source features use `unsupported_source_feature`.

## Required UI Surfaces

### Workspace Quality Entry Point

Add a top-level Quality entry point in the workspace.

Required behavior:

- The workspace shell exposes a Quality tab/pane reachable from the main
  workspace without opening a modal.
- The command palette includes:
  - `Open Quality Dashboard`
  - `Run Quality Profile`
  - `Manage Validation Profiles`
  - `Export Quality Report`
- The Tools menu includes:
  - `Tools -> Data Quality Dashboard`
  - `Tools -> Manage Validation Profiles`
  - `Tools -> Export Quality Report...`

### Data Quality Dashboard

Required layout:

- Header:
  - current database path or project name,
  - last quality run status,
  - last run timestamp,
  - freshness badge: `Fresh`, `Stale`, `Running`, `Failed`, or `No run`.
- Actions:
  - `Run`
  - `Cancel`
  - `Manage Profiles`
  - `Export Report`
  - `Refresh Status`
- Summary band:
  - tables scanned,
  - rows scanned,
  - rules run,
  - errors,
  - warnings,
  - info issues,
  - duplicate groups,
  - import warnings.
- Table list:
  - table name,
  - row count,
  - null-heavy column count,
  - validation issue count,
  - duplicate issue count,
  - import warning count,
  - freshness status.
- Worst columns list:
  - table,
  - column,
  - metric causing concern,
  - value.
- Recent runs list:
  - run id short display,
  - target,
  - mode,
  - status,
  - started,
  - duration,
  - issue count.

No cards-inside-cards. Use dense, workbench-style rows and panes consistent
with the existing desktop app.

### Table Quality View

Required tabs:

- `Profile`
- `Validation`
- `Duplicates`
- `Import`
- `History`

`Profile` tab:

- column summary table with every `ColumnQualitySummary` field that fits
  reasonably in a grid,
- detail side panel for selected column,
- top values table,
- histogram view,
- outlier summary.

`Validation` tab:

- grouped issues,
- rule severity,
- failure count,
- open violation browser action.

`Duplicates` tab:

- exact duplicate groups,
- near-duplicate groups,
- candidate limit shown for near duplicates.

`Import` tab:

- source/target mapping,
- row reconciliation,
- warning code counts,
- warning details.

`History` tab:

- previous runs for this table,
- freshness state,
- run duration,
- report export action.

### Validation Profile Manager

Required behavior:

- List validation profiles.
- Create profile.
- Rename profile.
- Duplicate profile.
- Delete profile with confirmation.
- Import profile TOML.
- Export profile TOML.
- Set default profile for workspace/project.
- Show validation errors for invalid profile files.

### Validation Rule Editor

Required behavior:

- Add rule.
- Edit rule.
- Duplicate rule.
- Delete rule.
- Enable/disable rule.
- Set severity.
- Select target table from schema.
- Select target column when rule type requires or allows a column.
- Show only parameters supported by the selected rule type.
- Validate fields before saving.
- Show generated SQL preview for SQL-backed rules.
- Show "Runs in background isolate" note for regex and near-duplicate rules
  when they cannot be fully SQL-backed.

### Violation Browser

Required behavior:

- Open from dashboard, table quality view, or issue row.
- Show issue summary header:
  - rule name,
  - rule type,
  - severity,
  - table,
  - column,
  - failure count.
- Show paged violation rows.
- Page size options: `50`, `100`, `500`.
- Actions:
  - copy diagnostic SQL,
  - copy issue summary,
  - open table preview filtered to row identity when possible,
  - export issue details as JSONL.
- If sample values are omitted, show `Values hidden by report privacy setting`.

### Quality Report Export Dialog

Required fields:

- Format: Markdown, HTML, JSON.
- Destination path.
- Include sample values: checkbox, default off.
- Include violation detail rows: checkbox, default off.
- Include import reconciliation: checkbox, default on.
- Include stale runs: checkbox, default off.
- Redaction note shown when sample values are off.

Validation:

- Destination is required.
- Extension must match format:
  - `.md`
  - `.html`
  - `.json`
- If include sample values is on, show a confirmation explaining that report
  output may contain source data.

## Required CLI Behavior

Add a headless quality command.

Preferred command shape:

```text
dbench quality --database <workspace.ddb> \
  --profile <quality-profile.toml> \
  --out <quality-report.json> \
  --format json
```

Required flags:

- `--database <path>`: DecentDB file to open.
- `--profile <path>`: quality profile TOML.
- `--out <path>`: report destination.
- `--format <json|markdown|html>`: report format.

Optional flags:

- `--target-table <name>`: run against one table.
- `--mode <full|sampled>`: override profile default.
- `--sample-row-limit <n>`: override profile sample row limit.
- `--include-sample-values`: include row sample values in report.
- `--include-violation-details`: include detail rows in report.
- `--silent`: suppress non-error output.

Exit codes:

- `0`: run completed and no `error` severity issues were found.
- `1`: run completed and at least one `error` severity issue was found.
- `2`: command usage or profile validation error.
- `3`: database open or schema load failure.
- `4`: quality run failed.
- `5`: report export failed.
- `130`: cancelled by user interrupt.

Console output when not silent:

- Print database path.
- Print profile name.
- Print mode.
- Print started timestamp.
- Print summary counts.
- Print report destination.
- Print stale warning if generated from stale prior run.

## Required Report Formats

### Markdown

Required sections:

1. Title and metadata.
2. Freshness status.
3. Summary counts.
4. Import reconciliation.
5. Table profile summaries.
6. Validation issue summaries.
7. Duplicate summaries.
8. Warnings and limitations.

### HTML

Required behavior:

- Self-contained HTML file.
- No remote CSS, JS, images, or fonts.
- Same sections as Markdown.
- Tables are readable without scripting.
- Include app name/version and generation timestamp.

### JSON

Required behavior:

- Machine-readable export of `QualityRunResult`.
- Include `report_options`.
- Include `report_schema_version = 1`.
- Include or omit sample values based on export options.

## Performance Requirements

The following requirements are mandatory:

- UI remains responsive during every quality operation.
- Any operation expected to scan more than 10,000 rows must run as a background
  job.
- Progress state must include:
  - current phase,
  - current table,
  - current rule when validating,
  - rows scanned when available,
  - cancellable flag.
- Cancellation must stop after the current DecentDB query/page completes.
- Violation rows must be paged.
- Duplicate candidate rows must be paged or bounded.
- Report export must stream output where practical.
- The app must never load all violation rows into widget state.
- The app must not compute top values or histograms from a full table in Dart
  if DecentDB SQL can compute the aggregate.

## Slice Plan

Every slice below is required for 100% completion. Do not mark #1 complete
until the final completion checklist passes.

### Slice 0: ADRs And Plan Alignment

Goal: create required decision records and update references before code.

Implementation steps:

1. Confirm ADR A, ADR B, and ADR C described in this plan are accepted.
2. Update `design/FUTURE_WINS.md` so rank 2 links to this plan.
3. Update `design/SPEC.md` "Next" or post-MVP section to reference this plan
   as accepted future scope if implementation is about to begin.
4. Confirm no ADR conflicts with:
   - ADR-0022 headless import,
   - ADR-0029 project file,
   - ADR-0032 branch/snapshot safety,
   - ADR-0044 menu deferrals.

Tests:

- No Flutter tests required.
- Run `git diff --check`.

Acceptance criteria:

- ADR files exist.
- `design/FUTURE_WINS.md` links to this plan.
- No implementation code has been changed in this slice.

### Slice 1: Domain Models And Serialization

Goal: add all data quality domain models with strict validation and
serialization.

Files:

- Add `data_quality_models.dart`.
- Add `data_quality_rules.dart`.
- Add `data_quality_reports.dart`.
- Add tests listed for domain models.

Implementation steps:

1. Implement enums:
   - `QualityTargetKind`
   - `QualityRunStatus`
   - `QualityRunMode`
   - `QualitySeverity`
   - `ValidationRuleType`
   - `OutlierMethod`
   - `NearDuplicateSimilarity`
   - `QualityFreshnessStatus`
   - `QualityReportFormat`
2. Implement model classes exactly as specified in "Required Data Contracts".
3. Implement `fromJson`, `toJson`, `fromToml`, and `toToml` where required.
4. Implement validation methods that return typed validation errors, not only
   thrown strings.
5. Implement `copyWith` only for models edited in UI:
   - `QualityProfileDocument`
   - `ValidationRule`
   - `QualityRunRequest`
6. Implement equality/hashCode for value models used in tests.
7. Implement redaction helpers:
   - `QualityRunResult.redactedForReport()`
   - `ValidationIssueSummary.redactedForReport()`
   - `ViolationRowReference.redactedForReport()`

Tests:

- Parse valid profile TOML.
- Reject unsupported `config_version`.
- Reject duplicate rule IDs.
- Reject invalid enum values.
- Reject missing required fields.
- Reject invalid params per rule type.
- Round-trip profile TOML.
- Round-trip run result JSON.
- Redaction removes `valueDisplay`.
- Redaction preserves row identity.
- `include_sample_values = true` preserves sample values in report copy.

Acceptance criteria:

- Domain tests pass.
- No UI or database behavior is added yet.
- Public model names match this plan exactly.

### Slice 2: Persistence Repository And Project Integration

Goal: persist quality profiles and run results without executing quality jobs.

Files:

- Add `data_quality_repository.dart`.
- Extend workspace project parsing/export only where needed.
- Add repository tests.

Implementation steps:

1. Implement `DataQualityRepository`.
2. Store profiles in:
   - `<workspace-state-dir>/quality/profiles/<profile_id>.toml`.
3. Store default profile pointer in:
   - `<workspace-state-dir>/quality/default-profile.json`.
4. Store run results in:
   - `<workspace-state-dir>/quality/runs/<run_id>/quality-result.json`.
5. Store violation details in:
   - `<workspace-state-dir>/quality/runs/<run_id>/violations/<issue_id>.jsonl`.
6. Add project manifest support:
   - `[quality]`
   - `profile_path = "quality/default-quality-profile.toml"`
   - `default_mode = "full"`
7. Project export writes a relative `quality.profile_path` only when a default
   profile exists.
8. Project open loads the referenced quality profile and sets it as default.
9. Missing project-referenced quality profile produces a non-fatal workspace
   warning.
10. Invalid project-referenced quality profile produces a non-fatal workspace
    warning with validation details.

Tests:

- Save and load profile.
- Save and load run result.
- Save and read JSONL violation details.
- Default profile pointer survives repository reload.
- Project export includes relative profile path.
- Project open resolves relative profile path.
- Missing profile path returns warning.
- Invalid profile path returns validation warning.
- Repository rejects path traversal profile paths.

Acceptance criteria:

- Persistence works on a temporary filesystem.
- No quality execution is implemented yet.
- Existing project file tests still pass.

### Slice 3: Import Reconciliation Capture

Goal: all import paths produce structured reconciliation data for later quality
runs.

Files:

- Extend import domain models where import results are represented.
- Extend import execution services and workspace import orchestration.
- Add import reconciliation tests.

Implementation steps:

1. Add `ImportReconciliationRecord` domain model or reuse
   `ImportReconciliationSummary` when appropriate.
2. Assign an `importJobId` UUID at the start of every import.
3. Capture source metadata:
   - source path display,
   - source format key,
   - source fingerprint when available,
   - started/completed timestamps.
4. Capture table mappings for every imported source object.
5. Capture row counters:
   - source rows,
   - imported rows,
   - skipped rows,
   - rejected rows,
   - transformed rows,
   - type coercion failures.
6. Convert all import warnings to stable warning codes listed in this plan.
7. Persist import reconciliation records under:
   - `<workspace-state-dir>/quality/imports/<import_job_id>.json`.
8. Link target tables to the latest relevant import reconciliation record.
9. Expose latest import reconciliation record to quality runner.

Tests:

- Delimited import records source/imported/skipped row counts.
- Structured import records table mappings.
- Excel import warning maps to stable warning code.
- SQLite import warning maps to stable warning code.
- SQL dump warning maps to stable warning code.
- Unknown warning maps to `import_warning_unknown`.
- Latest import reconciliation is returned for imported target table.
- Reconciliation persistence survives app restart.

Acceptance criteria:

- Existing import UI behavior is unchanged except richer internal records.
- Existing import tests pass.
- Quality runner can read reconciliation records.

### Slice 4: Profiling SQL Planner And Metric Engine

Goal: compute profile summaries from DecentDB using SQL-backed aggregation and
background execution.

Files:

- Add `data_quality_runner.dart`.
- Add SQL planner helpers inside the same infrastructure area.
- Add runner tests with fake gateway/query adapter.

Implementation steps:

1. Implement `DataQualitySqlPlanner`.
2. Generate SQL for:
   - row count,
   - null count,
   - empty string count,
   - non-null count,
   - distinct count,
   - min/max,
   - numeric average,
   - numeric standard deviation,
   - top values,
   - histogram buckets,
   - malformed temporal count.
3. Implement median and IQR:
   - use DecentDB percentile/median functions if available;
   - otherwise use paged sorted values in a background job with memory cap.
4. Implement `DataQualityRunner.runProfiling()`.
5. Implement full mode.
6. Implement sampled mode.
7. Implement per-table progress events.
8. Implement cancellation token checks between tables and between metric
   queries.
9. Implement warnings when a metric cannot be computed.
10. Reuse existing schema/native type metadata for type-aware metrics.

Tests:

- SQL planner quotes identifiers correctly.
- SQL planner handles table and column names containing quotes.
- Null count SQL is generated correctly.
- Empty string count applies only to string-compatible columns.
- Top values SQL includes count and ordering.
- Histogram planner rejects unsupported type families with warning.
- Full profiling returns expected summaries for fixture rows.
- Sampled profiling marks `profileMode = sampled`.
- Cancellation before table 2 stops run.
- Metric failure records warning and continues other metrics.

Acceptance criteria:

- Profiling can run without validation rules.
- Profiling does not depend on UI.
- Profiling never requires all rows in memory except bounded fallback
  percentile logic.

### Slice 5: Validation SQL Planner And Rule Execution Engine

Goal: execute every required validation rule type and produce issue summaries
plus paged violation details.

Files:

- Extend `data_quality_runner.dart`.
- Add rule-specific planner/executor classes if needed.
- Add validation runner tests.

Implementation steps:

1. Implement `ValidationRulePlanner`.
2. Implement SQL-backed execution for:
   - `required`,
   - `unique`,
   - `allowed_values`,
   - `numeric_range`,
   - `date_range`,
   - `string_length`,
   - `cross_column`,
   - `referential`,
   - `custom_sql_predicate`,
   - `exact_duplicate_rows`.
3. Implement isolate-backed execution for:
   - `regex` when SQL regex is unavailable,
   - `near_duplicate_rows`.
4. Implement issue codes:
   - `required_value_missing`
   - `unique_value_duplicated`
   - `allowed_value_unmatched`
   - `regex_unmatched`
   - `numeric_value_out_of_range`
   - `date_value_out_of_range`
   - `malformed_temporal_value`
   - `string_length_out_of_range`
   - `cross_column_predicate_failed`
   - `referential_value_missing`
   - `custom_sql_predicate_failed`
   - `exact_duplicate_group`
   - `near_duplicate_group`
5. Implement detail query SQL for SQL-backed issues.
6. Implement JSONL detail storage for isolate-backed issues.
7. Implement paging API:
   - `loadViolationPage(runId, issueId, pageSize, pageIndex)`.
8. Implement cancellation between rules and between pages/candidate batches.
9. Implement progress events per rule.

Tests:

- Each rule type passes valid fixture rows.
- Each rule type fails invalid fixture rows.
- Severity is preserved in issue summary.
- Disabled rules do not run.
- SQL predicate safety rejects semicolon.
- SQL predicate safety rejects DDL/DML.
- Referential rule validates matching column counts.
- Near duplicate candidate limit is enforced.
- Violation page returns requested page size.
- Violation page does not load all details.
- Cancellation stops after current rule/page.

Acceptance criteria:

- All required rule types work.
- Rule execution produces stable issue codes.
- Detail paging works for SQL-backed and JSONL-backed issues.

### Slice 6: Quality Run Orchestration And Freshness

Goal: connect profiling, validation, reconciliation, persistence, progress,
cancellation, and stale detection into one quality run flow.

Files:

- Add `data_quality_controller.dart`.
- Integrate with `workspace_controller.dart`.
- Add application/controller tests.

Implementation steps:

1. Implement `DataQualityController`.
2. Controller state includes:
   - current profile,
   - current run,
   - recent runs,
   - progress,
   - selected table,
   - selected issue,
   - freshness state.
3. Implement `startRun(QualityRunRequest)`.
4. Implement `cancelRun()`.
5. Implement `loadRecentRuns()`.
6. Implement `computeFreshness(QualityRunResult)`.
7. Compute schema fingerprint from existing schema metadata.
8. Compute data fingerprints as specified in this plan.
9. Include import reconciliation when requested.
10. Persist result at the end of completed, failed, and cancelled runs.
11. Surface errors through workspace message/error patterns.
12. Ensure only one quality run executes per workspace at a time.

Tests:

- Start run transitions idle -> running -> completed.
- Failed runner transitions to failed result with error message.
- Cancel transitions to cancelled.
- Recent runs load newest first.
- Freshness is `Fresh` when fingerprints match.
- Freshness is `Stale` when schema fingerprint differs.
- Freshness is `Stale` when table row count differs.
- Starting a second run while running is rejected.
- Import reconciliation appears when requested.

Acceptance criteria:

- GUI can bind to controller without knowing runner internals.
- Run result persistence is automatic.
- Stale detection is deterministic in tests.

### Slice 7: Quality Dashboard UI

Goal: add the first-class Quality workspace surface.

Files:

- Add `data_quality_dashboard.dart`.
- Integrate into workspace shell/menu/command palette.
- Add widget tests.

Implementation steps:

1. Add Quality tab/pane to workspace shell.
2. Add command palette commands listed in this plan.
3. Add Tools menu commands listed in this plan.
4. Implement dashboard header.
5. Implement action row.
6. Implement summary band.
7. Implement table list.
8. Implement worst columns list.
9. Implement recent runs list.
10. Bind run/cancel/profile/export actions to controller.
11. Show empty state when no run exists.
12. Show stale state when freshness check fails.
13. Show running state with progress.
14. Show failed state with error details.

Tests:

- Dashboard empty state renders.
- Run button calls controller.
- Cancel button calls controller only when running.
- Summary counts render.
- Table issue counts render.
- Stale badge renders.
- Failed run message renders.
- Command palette contains Quality commands.
- Tools menu contains Quality commands.

Acceptance criteria:

- Quality is reachable without a modal.
- UI uses existing design tokens and workbench density.
- No nested cards.

### Slice 8: Table Quality View And Violation Browser UI

Goal: users can inspect a table, column profile, validation issue, duplicate
group, import reconciliation, and violation rows.

Files:

- Add `table_quality_view.dart`.
- Add `violation_browser.dart`.
- Add widget tests.

Implementation steps:

1. Implement table quality tabs:
   - Profile,
   - Validation,
   - Duplicates,
   - Import,
   - History.
2. Implement column summary grid.
3. Implement selected-column detail panel.
4. Implement top values table.
5. Implement histogram display using existing chart primitives where practical.
6. Implement outlier summary.
7. Implement validation issue list.
8. Implement duplicate group list.
9. Implement import reconciliation view.
10. Implement table run history.
11. Implement violation browser.
12. Implement page size switcher.
13. Implement next/previous page.
14. Implement copy diagnostic SQL.
15. Implement copy issue summary.
16. Implement export issue JSONL.
17. Implement "open table preview filtered to row identity" only when row
    identity contains enough columns to build a safe filter; otherwise disable
    with explanatory tooltip.

Tests:

- All table quality tabs render.
- Column details update when selected column changes.
- Histogram renders no-data state.
- Validation issue opens violation browser.
- Violation browser requests page 0 initially.
- Page size switch requests new page.
- Next page increments page index.
- Copy diagnostic SQL uses issue detail SQL.
- Hidden sample values message renders when values are redacted.
- Open filtered preview disabled when row identity is insufficient.

Acceptance criteria:

- Users can inspect every detail in a persisted quality result.
- Violation rows remain paged.

### Slice 9: Validation Profile Manager And Rule Editor UI

Goal: users can create and maintain validation profiles without hand-editing
TOML.

Files:

- Add `validation_profile_editor.dart`.
- Add widget tests.

Implementation steps:

1. Implement profile list.
2. Implement create profile.
3. Implement rename profile.
4. Implement duplicate profile.
5. Implement delete profile confirmation.
6. Implement import profile TOML.
7. Implement export profile TOML.
8. Implement set default profile.
9. Implement rule list.
10. Implement add/edit/duplicate/delete/enable/disable rule.
11. Implement dynamic parameter form for every rule type.
12. Implement generated SQL preview for SQL-backed rules.
13. Implement validation errors next to fields.
14. Prevent saving invalid profiles.
15. Preserve rule IDs on edit.
16. Generate new rule IDs on duplicate.

Tests:

- Create profile writes repository.
- Rename profile updates `updatedAt`.
- Duplicate profile creates new profile ID and new rule IDs.
- Delete profile asks confirmation.
- Import invalid TOML shows validation error.
- Export profile writes expected TOML.
- Required rule editor shows required params.
- Numeric range editor requires min or max.
- Referential editor enforces matching source/reference column counts.
- Custom SQL editor rejects unsafe predicate.
- Save disabled while form invalid.

Acceptance criteria:

- Users can configure all required rule types in UI.
- No rule type requires hand-editing TOML.

### Slice 10: Report Export

Goal: export quality reports as Markdown, HTML, and JSON with privacy defaults.

Files:

- Add `data_quality_report_writer.dart`.
- Add `quality_report_export_dialog.dart`.
- Add writer and widget tests.

Implementation steps:

1. Implement `QualityReportOptions`.
2. Implement Markdown writer.
3. Implement HTML writer.
4. Implement JSON writer.
5. Implement report redaction based on options.
6. Implement self-contained HTML styles.
7. Implement export dialog.
8. Add export action from dashboard.
9. Add export action from table history.
10. Add warning confirmation when sample values are included.
11. Add report generation errors to workspace errors.

Tests:

- Markdown includes required sections.
- HTML includes required sections.
- HTML contains no `http://` or `https://` asset references.
- JSON includes `report_schema_version = 1`.
- Default report omits sample values.
- Include-sample-values report includes sample values.
- Export dialog validates file extension.
- Export dialog shows sample value confirmation.
- Writer handles stale run and marks stale status.

Acceptance criteria:

- All three formats export.
- Default exports preserve privacy.
- Report output is deterministic in tests except timestamps/run IDs.

### Slice 11: Headless CLI Quality Command

Goal: run quality profiles and export reports without the desktop UI.

Files:

- Add or extend CLI entry point as specified.
- Add `headless_quality_runner_test.dart`.
- Update CLI docs.

Implementation steps:

1. Parse required and optional flags exactly as specified.
2. Validate incompatible flags.
3. Open DecentDB database.
4. Load quality profile TOML.
5. Build `QualityRunRequest`.
6. Run quality profiling/validation.
7. Write requested report format.
8. Print required console output when not silent.
9. Return required exit codes.
10. Handle interrupt cancellation if supported by current CLI harness.

Tests:

- Missing database returns exit code 2.
- Missing profile returns exit code 2.
- Invalid profile returns exit code 2.
- Database open failure returns exit code 3.
- Quality run failure returns exit code 4.
- Report write failure returns exit code 5.
- Error severity issue returns exit code 1.
- Warning-only issues return exit code 0.
- Silent mode suppresses normal output.
- JSON report file is written.

Acceptance criteria:

- CLI uses the same runner and report writer as GUI.
- CLI behavior is documented.

### Slice 12: Post-Import Automatic Quality Runs

Goal: users can choose to run quality checks automatically after import.

Files:

- Integrate import wizard summary and quality controller.
- Update import/profile docs.
- Add tests.

Implementation steps:

1. Add import wizard summary action:
   - `Run Quality Profile`.
2. Add import profile setting:
   - `run_quality_after_import`: bool, default `false`.
3. Add import profile setting:
   - `quality_profile_id`: nullable string.
4. After successful import, if `run_quality_after_import = true`, start a
   quality run targeting imported tables.
5. If selected quality profile is missing, show warning and do not run.
6. If quality run starts, show progress in Quality dashboard and import summary.
7. Import completion must not be marked failed because quality validation found
   issues. Import success and quality findings are separate statuses.

Tests:

- Import summary Run Quality Profile action starts quality run.
- Profile setting false does not run quality.
- Profile setting true starts quality run.
- Missing profile warning is shown.
- Quality error issues do not change import job success status.
- Quality run targets imported tables only.

Acceptance criteria:

- Quality suite is integrated into import workflow.
- Automatic validation remains opt-in.

### Slice 13: Duplicate And Near-Duplicate Completion

Goal: complete exact and near-duplicate workflows with bounded behavior.

Files:

- Extend runner and UI duplicate tab.
- Add duplicate tests.

Implementation steps:

1. Implement exact duplicate grouping over configured columns.
2. Implement exact duplicate group paging.
3. Implement near-duplicate candidate generation.
4. Implement normalized Levenshtein scorer.
5. Implement token sort ratio scorer.
6. Implement candidate limit enforcement.
7. Implement blocking column support.
8. Persist duplicate summaries.
9. Display duplicate groups in table quality view.
10. Export duplicate summaries in reports.

Tests:

- Exact duplicates found over one column.
- Exact duplicates found over composite columns.
- Null handling follows rule params.
- Near duplicates found with normalized Levenshtein.
- Near duplicates found with token sort ratio.
- Candidate limit enforced.
- Blocking columns reduce candidate pairs.
- Cancellation stops near-duplicate scoring.
- Duplicate report section renders.

Acceptance criteria:

- Exact duplicate and bounded near-duplicate workflows are complete.
- Large tables cannot trigger unbounded pairwise comparison.

### Slice 14: Documentation And Help

Goal: document the feature for users and contributors.

Files:

- Add `apps/decent-bench/assets/help/data-quality.md`.
- Update help manifest.
- Update importing/results help pages.
- Update `docs/HEADLESS_IMPORT_PLAN_DETAILS.md` or add a new CLI doc if CLI
  documentation lives elsewhere.
- Update `design/FUTURE_WINS.md` if status changes.

Required user documentation:

- What the Quality dashboard is for.
- Difference between profiling and validation.
- Full vs sampled mode.
- How freshness/staleness works.
- How to create validation profiles.
- Explanation of every rule type.
- How to read violation counts.
- Why report exports hide sample values by default.
- How to include sample values intentionally.
- How to run quality from CLI.
- Performance expectations for large tables.

Required contributor documentation:

- Model file locations.
- Persistence locations.
- How to add a new rule type.
- How to add a new report field.
- How to test a rule.
- Privacy requirements for report output.

Tests:

- Help manifest includes Data Quality page.
- Help repository loads Data Quality page.
- Links from importing/results help pages are valid if link validation exists.

Acceptance criteria:

- Feature is documented in-app.
- CLI behavior is documented.
- Contributor path for new rule types is documented.

### Slice 15: Integration, Performance, And Final Hardening

Goal: verify the complete suite end to end and close all quality gaps.

Implementation steps:

1. Add integration test: import fixture -> run default quality profile -> open
   dashboard -> inspect issue -> export report.
2. Add integration test: open existing `.ddb` fixture -> run profiling only ->
   inspect table profile.
3. Add integration test: create validation profile -> save -> reload app state
   -> run profile.
4. Add performance fixture with at least 100,000 rows.
5. Verify profiling progress appears for large fixture.
6. Verify cancellation works for large fixture.
7. Verify violation paging does not load all rows into UI state.
8. Verify report export works for large fixture.
9. Run full validation commands.
10. Fix any analyzer/test failures.

Required validation commands:

```text
cd apps/decent-bench
flutter analyze
flutter test
flutter test integration_test
```

Manual verification checklist:

- Open Decent Bench.
- Import a CSV fixture with nulls, malformed dates, duplicates, and outliers.
- Run the default quality profile.
- Confirm dashboard summary counts match fixture expectations.
- Open a table quality view.
- Inspect column profile metrics.
- Open a validation issue.
- Page through violation rows.
- Export Markdown report with default privacy settings.
- Confirm report omits sample values.
- Export HTML report with sample values enabled.
- Confirm confirmation appears and report includes selected samples.
- Save validation profile.
- Close and reopen workspace.
- Confirm profile and last run load.
- Modify data or schema.
- Confirm previous run becomes stale.
- Run CLI quality command and confirm exit code behavior.

Acceptance criteria:

- `flutter analyze` passes.
- `flutter test` passes.
- `flutter test integration_test` passes, or skipped integration tests have a
  documented environment reason.
- Manual checklist passes.
- No known UI-thread jank remains.
- No unbounded row materialization remains.
- Documentation is complete.

## Default Built-In Quality Profile

Implement one built-in profile named `Default Import Quality`.

Rules generated automatically per table:

- For every column marked non-null in schema metadata:
  - `required`
  - severity `error`.
- For every primary key or unique constraint:
  - `unique`
  - severity `error`.
- For every foreign key constraint exposed by schema metadata:
  - `referential`
  - severity `error`.
- For every column whose native type or inferred type is date/time:
  - malformed temporal profiling enabled.
- For every table:
  - exact duplicate row check disabled by default but available.

The default profile must not add regex, numeric range, date range,
cross-column, custom SQL, or near-duplicate rules automatically.

## Test Fixtures Required

Create fixture data covering:

### `quality_clean_orders`

Tables:

- `customers`
- `orders`
- `order_items`

Properties:

- no validation failures,
- valid referential relationships,
- no duplicate primary keys,
- predictable row counts.

### `quality_messy_orders`

Tables:

- `customers`
- `orders`
- `order_items`

Required issues:

- missing required customer email,
- duplicate customer id,
- order referencing missing customer,
- malformed order date string,
- amount outside numeric range,
- status outside allowed values,
- duplicate order item row,
- near-duplicate customer names.

### `quality_large_metrics`

Tables:

- `events`

Properties:

- at least 100,000 rows,
- numeric metric column with outliers,
- nullable text column,
- timestamp column,
- category column with top-value distribution.

Use generated fixtures where large checked-in files would be inappropriate.

## Required Rule Test Matrix

Each rule type must have tests for:

- valid configuration,
- invalid configuration,
- pass result,
- fail result,
- null handling,
- generated SQL or isolate execution path,
- violation paging,
- report serialization.

Matrix:

| Rule type | Config test | Pass test | Fail test | Null test | Paging test | Report test |
|---|---:|---:|---:|---:|---:|---:|
| `required` | yes | yes | yes | yes | yes | yes |
| `unique` | yes | yes | yes | yes | yes | yes |
| `allowed_values` | yes | yes | yes | yes | yes | yes |
| `regex` | yes | yes | yes | yes | yes | yes |
| `numeric_range` | yes | yes | yes | yes | yes | yes |
| `date_range` | yes | yes | yes | yes | yes | yes |
| `string_length` | yes | yes | yes | yes | yes | yes |
| `cross_column` | yes | yes | yes | yes | yes | yes |
| `referential` | yes | yes | yes | yes | yes | yes |
| `custom_sql_predicate` | yes | yes | yes | yes | yes | yes |
| `exact_duplicate_rows` | yes | yes | yes | yes | yes | yes |
| `near_duplicate_rows` | yes | yes | yes | yes | yes | yes |

## Final Completion Checklist

The Future Win is 100% complete only when every checkbox below is true:

- [ ] Required ADRs are accepted.
- [ ] Domain models implemented and tested.
- [ ] Profile TOML persistence implemented and tested.
- [ ] Run result JSON persistence implemented and tested.
- [ ] Project manifest integration implemented and tested.
- [ ] Import reconciliation capture implemented and tested.
- [ ] Profiling engine implements every required metric.
- [ ] Validation engine implements every required rule type.
- [ ] Duplicate and near-duplicate detection implemented.
- [ ] Paged violation browser implemented.
- [ ] Quality dashboard implemented.
- [ ] Table quality view implemented.
- [ ] Validation profile manager implemented.
- [ ] Rule editor implemented for every rule type.
- [ ] Markdown report export implemented.
- [ ] HTML report export implemented.
- [ ] JSON report export implemented.
- [ ] Report privacy defaults enforced.
- [ ] Headless CLI quality command implemented.
- [ ] Post-import quality run integration implemented.
- [ ] Fresh/stale detection implemented.
- [ ] Cancellation implemented.
- [ ] Large-table performance verified.
- [ ] In-app help documentation added.
- [ ] CLI documentation added.
- [ ] Contributor documentation added.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] `flutter test integration_test` passes or has documented environment
  reason.
- [ ] Manual verification checklist passes.
