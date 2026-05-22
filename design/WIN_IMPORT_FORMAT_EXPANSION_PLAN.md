# Future Win Plan: Continual Import Format Expansion

**Status:** Planning document  
**Last reviewed:** 2026-05-22  
**Source roadmap item:** `design/FUTURE_WINS.md` rank 15, `P1`
**Current implementation index:** `design/IMPORT_FORMATS.md`
**Current registry source of truth:** `apps/decent-bench/lib/features/import/infrastructure/import_format_registry.dart`
**Target registry source of truth:** `design/WIN_IMPORT_MODULAR_PLAN.md`

## Purpose

Decent Bench is the front door into DecentDB. Import formats will keep growing
as users bring new file types, legacy sources, analytical formats, archives,
and operational data into the app.

This document defines the long-running product and engineering plan for adding
import formats over time. It exists so each new format is evaluated and
implemented consistently instead of becoming a one-off connector with unique
UX, validation, docs, and test behavior.

This plan covers:

- recognized-but-not-implemented formats already listed in `design/IMPORT_FORMATS.md`,
- additional import formats from `design/IMPORT_SUPPORT_PLAN.md`,
- future user-requested formats,
- the process for moving a format from request to shipped support,
- required implementation slices,
- required tests and documentation,
- ADR and dependency gates.

Format expansion should build on
`design/WIN_IMPORT_MODULAR_PLAN.md`. New formats should first be represented as
module manifests with documentation, fixture expectations, type-fidelity notes,
and adapter bindings before parser/import code is added.

## Product Goal

Users should be able to bring a growing set of practical source files into a
local DecentDB database without learning a different workflow for every format.

Every import format must fit the same user promise:

1. detect the source clearly,
2. preview what will become DecentDB tables,
3. let the user adjust target table names, column names, and types,
4. run import work off the UI thread,
5. report progress, warnings, skipped rows, and failures,
6. land the result in a DecentDB `.ddb` file,
7. support repeatability through import profiles when the format has stable
   options,
8. update documentation and tests before the format is called supported.

## Relationship To Existing Docs

Use these documents for different purposes:

- `design/IMPORT_FORMATS.md`: current user/developer inventory of what the build
  can import now, what is partial, and what is recognized but unavailable.
- `design/IMPORT_SUPPORT_PLAN.md`: broad product landscape for possible import
  families and format statuses.
- `design/FUTURE_WINS.md`: ranked roadmap index. Modular import architecture is
  the prerequisite Future Win, and connector expansion stays as a separate
  downstream Future Win there.
- `design/WIN_IMPORT_MODULAR_PLAN.md`: module manifest, catalog, adapter,
  fixture, and docs-sync architecture that future formats should use.
- This document: implementation and governance plan for continually adding
  import formats.

When a format ships, update all applicable docs and module manifests.
After the modular import plan is complete, the module catalog should become the
source of truth and these documents should be validated against it instead of
hand-synchronized.

## Current Supported Baseline

Do not reimplement these from scratch. New formats should reuse their
infrastructure where possible.

### Complete Import Or Open Support

| Family | Format | Extensions | Current Path |
|---|---|---|---|
| DecentDB | DecentDB open/migrate | `.ddb` | Direct open, with legacy migration path on format-version failure |
| Delimited text | CSV | `.csv` | Generic import wizard |
| Delimited text | TSV | `.tsv` | Generic import wizard |
| Delimited text | Generic delimited | `.txt`, `.dat`, `.log`, `.psv` | Generic import wizard |
| Structured document | JSON | `.json` | Generic import wizard |
| Structured document | NDJSON / JSONL | `.ndjson`, `.jsonl` | Generic import wizard |
| Structured document | XML | `.xml` | Generic import wizard |
| Web / markup | HTML tables | `.html`, `.htm` | Generic import wizard |
| Spreadsheet | Excel Open XML | `.xlsx` | Dedicated Excel wizard |
| Database | SQLite | `.db`, `.sqlite`, `.sqlite3` | Dedicated SQLite wizard |
| Database dump | MariaDB/MySQL-style SQL dump | `.sql` | Dedicated MVP-lite SQL dump wizard |
| Archive wrapper | ZIP | `.zip` | Extract supported inner file, then route normally |
| Archive wrapper | GZip / Tar+GZip | `.gz`, `.tgz`, `.tar.gz` | Extract supported inner file, then route normally |
| Archive wrapper | BZip2 / Tar+BZip2 | `.bz2`, `.tbz2`, `.tar.bz2` | Extract supported inner file, then route normally |

### Partial Support

| Family | Format | Extensions | Current Path |
|---|---|---|---|
| Spreadsheet | Legacy Excel | `.xls` | Dedicated Excel path with conversion/normalization warnings |

## Recognized But Not Implemented Yet

The current registry and docs recognize these unavailable formats. They should
remain honest unavailable states until the implementation and validation gates
in this document are complete.

| Format | Extensions / Source | Current Status | Priority Bucket | Recommended Path |
|---|---|---|---|---|
| Fixed-width text | usually `.txt`, `.dat` | Planned | Near | Generic import extension |
| OpenDocument Spreadsheet | `.ods` | Planned | Near | Spreadsheet importer extension |
| Parquet | `.parquet` | Planned | Near | New analytical importer |
| DuckDB | `.duckdb` | Planned | Near | Embedded database importer |
| PostgreSQL plain SQL dump expansion | `.sql` | Planned | Near | SQL dump parser expansion |
| YAML / YML | `.yaml`, `.yml` | Investigate | Later | Structured document importer |
| Markdown tables | `.md` | Investigate | Later | Markup table importer |
| XZ wrapper | `.xz` | Investigate | Later | Archive wrapper |
| Clipboard table capture | clipboard | Investigate | Later | Source adapter into generic importer |
| Microsoft Access | `.mdb`, `.accdb` | Investigate | Specialized | Legacy database importer |
| DBF / FoxPro | `.dbf` | Investigate | Specialized | Legacy table importer |
| MS SQL Server backup | `.bak` | Investigate | Specialized | Container-assisted source conversion |
| PDF table extraction | `.pdf` | Deferred | Defer | Extraction-quality gated importer |
| TOML | `.toml` | Deferred | Defer | Structured key/value importer only if demand appears |

## Priority Model

Rank future import formats by these criteria. The highest-value format is not
always the easiest one; use the score to decide roadmap order, not to skip ADRs
or tests.

| Criterion | Weight | How To Score |
|---|---:|---|
| User frequency | 30 | How often likely users receive this format |
| DecentDB fit | 20 | How naturally the format becomes DecentDB tables |
| Implementation confidence | 15 | Availability of stable parsers, fixtures, and platform support |
| Streaming feasibility | 15 | Ability to preview/import without full materialization |
| Licensing/package fit | 10 | Apache-compatible dependency path and notices |
| Support burden | 10 | Low ambiguity, low platform fragility, clear failure modes |

Scoring rule:

- `80-100`: near-roadmap candidate.
- `60-79`: backlog candidate after near-roadmap formats.
- `40-59`: investigate only; gather user demand or prototype first.
- `< 40`: defer unless a specific user need justifies it.

## Recommended Roadmap Order

### Wave 1: Highest Practical Value

Implement these first unless user demand strongly changes the order:

1. Fixed-width text.
2. OpenDocument Spreadsheet (`.ods`).
3. Parquet import.
4. DuckDB import.
5. PostgreSQL plain SQL dump expansion.

Rationale:

- Fixed-width text covers legacy enterprise, payroll, banking, government, and
  batch exports.
- ODS closes a common spreadsheet gap for LibreOffice/OpenOffice users.
- Parquet covers modern analytics and data engineering workflows.
- DuckDB overlaps strongly with local analytics users who are likely DecentDB
  adopters.
- PostgreSQL plain dumps are common developer and migration handoff artifacts.

### Wave 2: Practical Niche Expansion

Implement after Wave 1 or when user demand is clear:

1. Markdown table import.
2. YAML import for structured records.
3. XZ wrapper.
4. Clipboard table capture.
5. Log templates for Apache/Nginx/common app logs.

### Wave 3: Specialized Legacy And Enterprise

Implement only with clear demand, strong fixtures, and dependency confidence:

1. Access (`.mdb`, `.accdb`).
2. DBF / FoxPro (`.dbf`).
3. SQL Server BCP / bulk export files.
4. PostgreSQL custom/binary backup.
5. MS SQL Server backup (`.bak`).
6. Stata/SPSS/SAS transport.

### Deferred Until Extraction Quality Or Product Fit Is Proven

- PDF table extraction.
- TOML import.
- ORC.
- R data files.
- Generic ODBC/JDBC-like source abstraction.

## Standard Format Addition Lifecycle

Every new import format must move through these stages.

### Stage 1: Request Intake

Create or update a short issue/design note with:

- format name,
- extensions,
- sample files,
- user workflow,
- expected DecentDB output shape,
- whether source data is tabular, nested, relational, archival, or binary,
- whether the source can be streamed,
- whether the user expects one table or many tables,
- whether preserving formulas, constraints, indexes, metadata, or nested
  relationships matters.

Do not implement from a vague request like "support format X" without at least
one representative sample or a documented source specification.

### Stage 2: Product Classification

Classify the format as one of:

- delimited/text tabular,
- spreadsheet,
- structured document,
- web/markup table,
- embedded database,
- database dump/backup,
- analytical/columnar,
- archive/compression wrapper,
- logs/events,
- legacy business/data science,
- clipboard/source adapter,
- live source import.

Record this classification in `design/IMPORT_SUPPORT_PLAN.md` and
`ImportFormatRegistry`.

### Stage 3: Dependency And License Review

Before adding any package or native tool:

- verify license compatibility with Apache 2.0 distribution,
- verify desktop platform support for Linux, macOS, and Windows,
- verify maintenance status,
- verify whether the package can stream or requires full-file reads,
- identify native binary packaging needs,
- identify notices required in `THIRD_PARTY_NOTICES` or equivalent repo policy,
- decide whether a dependency ADR is required.

If dependency status is uncertain, the format remains `Investigate`.

### Stage 4: ADR Gate

Create an ADR before implementation when the format:

- adds a major dependency,
- adds a native binary or external CLI requirement,
- changes import profile format,
- changes generic import transform behavior,
- adds credential storage,
- adds a live source connection,
- adds a source conversion/container workflow,
- cannot preserve streaming/paging expectations,
- introduces security-sensitive parsing or extraction.

Minor parser additions that reuse existing dependencies and contracts may not
need a new ADR, but the implementation PR must explicitly state why no ADR was
required.

### Stage 5: Registry And Detection

Update `ImportFormatRegistry`:

- add or update `ImportFormatKey`,
- set `label`,
- set `family`,
- set `supportState`,
- set `extensions`,
- set `implementationKind`,
- write a truthful `description`,
- write a `note` when behavior is partial or warning-prone.

Update `ImportDetectionService` when extension-only detection is not enough.

Detection requirements:

- known unsupported formats must show a clear unavailable state,
- implemented formats must route to the correct wizard/importer,
- wrappers must expose supported inner candidates and not pretend unsupported
  inner files are importable,
- ambiguous extensions must use safe signature/header checks where practical,
- failure to inspect a file must produce a user-facing warning or error.

### Stage 6: Preview Contract

Every implemented format needs an import preview.

Preview must show:

- detected tables or source objects,
- target table names,
- source column names,
- target column names,
- inferred DecentDB types,
- sample rows,
- warnings,
- unsupported source features,
- format-specific options.

Preview must not:

- import data before user confirmation,
- block the UI thread,
- silently drop source structures,
- load large files into widget state.

### Stage 7: Import Execution Contract

Every implemented format must:

- run off the UI thread,
- write to DecentDB through a transactional or rollback-safe path where
  possible,
- provide progress updates,
- support cancellation when feasible,
- report rows copied by target table,
- report warnings with stable codes where possible,
- surface unsupported source features,
- write post-import summaries,
- integrate with import/export profile persistence when stable options exist.

### Stage 8: Test Fixtures

Each format must include fixtures before being marked supported.

Minimum fixture set:

- one clean happy-path source,
- one messy source with warnings,
- one empty or nearly empty source,
- one malformed source,
- one source with non-ASCII text,
- one source with null/empty values,
- one source with type edge cases,
- one large or generated fixture for performance-sensitive formats.

Binary or large fixtures should be generated in tests when practical instead of
checked in.

### Stage 9: Documentation

When a format changes status, update:

- `design/IMPORT_FORMATS.md`,
- `design/IMPORT_SUPPORT_PLAN.md`,
- `design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md` if priority/status changes,
- `README.md`,
- `apps/decent-bench/README.md`,
- `apps/decent-bench/assets/help/importing-data.md`,
- `apps/decent-bench/assets/help/getting-started.md`,
- `apps/decent-bench/assets/help/help_manifest.json` when search tags or
  summary should change.

The docs must distinguish:

- complete support,
- partial support,
- recognized but not implemented,
- deferred,
- wrapper support,
- live source import.

### Stage 10: Release Readiness

Do not mark a format complete until:

- registry state is `complete`,
- UI flow works,
- headless flow works when applicable,
- tests pass,
- docs are updated,
- dependency/license review is done,
- import warnings are understandable,
- cancellation/progress behavior is verified,
- archive/wrapper interaction is tested if applicable.

## Common Implementation Paths

### Generic Import Extension

Use for:

- fixed-width text,
- Markdown tables,
- YAML when it maps to records,
- log templates after parsing into records.

Expected files:

- `apps/decent-bench/lib/features/import/domain/import_models.dart`
- `apps/decent-bench/lib/features/import/infrastructure/import_format_registry.dart`
- `apps/decent-bench/lib/features/import/infrastructure/import_preview_service.dart`
- `apps/decent-bench/lib/features/import/infrastructure/import_execution_service.dart`
- a format-specific support file under
  `apps/decent-bench/lib/features/import/infrastructure/`.

Requirements:

- materialize source into `MaterializedImportSource`,
- reuse generic import options where possible,
- add format-specific options only when needed,
- support generic transforms after preview.

### Spreadsheet Import Extension

Use for:

- ODS,
- future SpreadsheetML if accepted,
- legacy Excel improvements.

Requirements:

- support multi-sheet preview,
- preserve sheet names as source names,
- infer headers,
- infer types,
- warn on formulas and unsupported workbook features,
- avoid full workbook UI-thread parsing.

### Embedded Database Importer

Use for:

- DuckDB,
- Access,
- DBF where it behaves as table files,
- future local database sources.

Requirements:

- inspect schema and tables,
- preview rows,
- map source types to DecentDB types,
- preserve table names,
- preserve indexes/constraints only when product contract accepts it,
- run source reads off the UI thread,
- never treat the source database as a live query target.

### Database Dump Parser Expansion

Use for:

- PostgreSQL plain SQL dumps,
- broader MySQL/MariaDB dump support,
- SQL Server BCP/bulk metadata if accepted.

Requirements:

- explicit dialect scope,
- warning-first unsupported statement behavior where safe,
- clear parser limitations,
- fixtures for common dump constructs,
- no silent execution of unsupported DDL/DML.

### Analytical / Columnar Importer

Use for:

- Parquet,
- Arrow IPC,
- Feather,
- ORC if ever accepted.

Requirements:

- dependency/license ADR,
- streaming or chunked row-group import,
- nested type mapping plan,
- binary metadata preview,
- large-file tests,
- typed DecentDB native type mapping.

### Archive Wrapper

Use for:

- XZ,
- additional tar wrappers,
- future compressed wrappers.

Requirements:

- wrapper detects supported inner files,
- wrapper does not claim unsupported inner files are importable,
- extraction is safe against path traversal,
- extraction uses temp directories and cleans them up,
- large archive behavior is documented,
- system-tool dependency is documented when used.

### Source Adapter

Use for:

- clipboard table capture,
- URL import if accepted,
- cloud object pre-signed URL import if accepted.

Requirements:

- source adapter produces a temporary local source or stream,
- user explicitly initiates capture/fetch,
- no continuous clipboard monitoring,
- network/cloud imports require a separate ADR,
- source metadata avoids storing sensitive payloads by default.

## Per-Format Plans

### Fixed-Width Text

Priority: Wave 1.

Implementation path: Generic import extension.

Required options:

- column boundary mode:
  - manual widths,
  - start/end positions,
  - infer from header ruler if present,
- encoding,
- header row on/off,
- skip leading rows,
- trim fields,
- pad short rows,
- reject short rows,
- reject long rows,
- table name.

Preview:

- show ruler/position view,
- show parsed columns,
- show malformed row count,
- show sample rows.

Tests:

- fixed widths,
- start/end positions,
- short row pad,
- short row reject,
- long row reject,
- non-ASCII text,
- generated large file.

ADR need: no ADR if implemented with standard Dart IO and existing generic
import contracts. ADR required if a new parser dependency is added.

### OpenDocument Spreadsheet (`.ods`)

Priority: Wave 1.

Implementation path: Spreadsheet import extension.

Required options:

- sheet selection,
- header row on/off,
- formula handling:
  - displayed values only for first implementation,
  - formula metadata warning when available,
- type overrides,
- table naming.

Dependency gate:

- must verify parser license and desktop support,
- must update notices if required.

Tests:

- single sheet,
- multi-sheet,
- formulas,
- blank rows,
- merged cells if parser exposes them,
- mixed types,
- non-ASCII text.

ADR need: required if adding a new ODS parser dependency.

### Parquet Import

Priority: Wave 1.

Implementation path: Analytical / columnar importer.

Required options:

- row group selection if available,
- nested strategy:
  - flatten,
  - JSON text fallback,
  - child-table normalization only if explicitly accepted,
- logical type mapping,
- table name,
- column selection.

Dependency gate:

- must use an Apache-compatible maintained parser or validated FFI path,
- must validate Linux/macOS/Windows packaging,
- must document whether import is streaming or chunked.

Tests:

- primitive columns,
- nullable columns,
- decimals,
- timestamps,
- nested lists/structs,
- multiple row groups,
- large generated file.

ADR need: required.

### DuckDB Import

Priority: Wave 1.

Implementation path: Embedded database importer.

Required options:

- table selection,
- view import decision:
  - materialize selected views as tables only for first implementation,
- type mapping,
- table renaming,
- column renaming.

Dependency gate:

- decide between DuckDB CLI, native library, or file parser approach,
- validate license and packaging,
- document version compatibility.

Tests:

- table import,
- view materialization if accepted,
- decimals,
- timestamps,
- list/struct columns with fallback mapping,
- empty table,
- large table.

ADR need: required.

### PostgreSQL Plain SQL Dump Expansion

Priority: Wave 1.

Implementation path: Database dump parser expansion.

Required scope for first accepted implementation:

- `CREATE TABLE`,
- `ALTER TABLE ... ADD CONSTRAINT` for primary keys, unique constraints, and
  foreign keys when safely translatable,
- `COPY ... FROM stdin`,
- `INSERT ... VALUES`,
- sequences represented as DecentDB-compatible defaults only when safe,
- unsupported statements reported as warnings.

Non-goals:

- custom-format `.backup`,
- binary dumps,
- executing arbitrary PostgreSQL functions,
- full stored procedure support.

Tests:

- common `pg_dump --format=plain`,
- COPY data,
- quoted identifiers,
- schemas,
- sequences,
- foreign keys,
- unsupported extensions.

ADR need: required because parser scope affects user-visible migration
behavior.

### Markdown Tables

Priority: Wave 2.

Implementation path: Generic import extension or HTML/markup importer.

Required options:

- table selection,
- header row detection,
- alignment row handling,
- escaped pipe handling,
- table name.

Tests:

- one table,
- multiple tables,
- escaped pipes,
- malformed alignment row,
- surrounding prose.

ADR need: not required if no new dependency is added.

### YAML / YML

Priority: Wave 2 after user demand.

Implementation path: Structured document importer.

Required decision:

- YAML is supported only for structured records, not arbitrary config
  semantics.

Required options:

- flatten,
- normalize,
- table name,
- repeated object path selection.

Dependency gate:

- YAML parser license and maintenance review.

Tests:

- list of objects,
- nested objects,
- mixed scalar/list values,
- anchors/aliases warning behavior,
- malformed YAML.

ADR need: required if dependency or YAML semantic scope is non-trivial.

### XZ Wrapper

Priority: Wave 2.

Implementation path: Archive wrapper.

Required options:

- single-file unwrap,
- tar+xz support only if extraction path is accepted.

Dependency gate:

- decide Dart package versus system `xz`/`tar`,
- validate Windows behavior.

Tests:

- `.xz` wrapping CSV,
- `.tar.xz` if supported,
- unsupported inner file,
- corrupt archive,
- cleanup temp directory.

ADR need: required if system tool dependency is introduced.

### Clipboard Table Capture

Priority: Wave 2, but high UX value.

Implementation path: Source adapter into generic importer.

Required options:

- TSV clipboard,
- CSV-like clipboard,
- HTML table clipboard,
- explicit paste/import action,
- no background clipboard monitoring.

Tests:

- TSV from spreadsheet,
- HTML table fragment,
- empty clipboard,
- large clipboard bounded behavior,
- sensitive payload not persisted by default.

ADR need: required if clipboard metadata becomes persistent or HTML sanitization
rules are accepted.

### Microsoft Access (`.mdb`, `.accdb`)

Priority: Wave 3.

Implementation path: Legacy database importer.

Dependency gate:

- parser/driver support is the main blocker,
- cross-platform behavior must be proven before implementation.

Required scope:

- table import first,
- views/queries only if safely materializable,
- relationships only if parser exposes stable metadata.

ADR need: required.

### DBF / FoxPro

Priority: Wave 3.

Implementation path: Legacy table importer.

Required options:

- code page/encoding,
- deleted row handling,
- memo file handling when available,
- table name.

Tests:

- DBF without memo,
- DBF with memo if supported,
- code page variations,
- deleted rows.

ADR need: required if dependency is added.

### MS SQL Server Backup (`.bak`)

Priority: Wave 3.

Implementation path: Container-assisted conversion or external tool workflow.

Current stance:

- recognized, not implemented.
- do not fake support.

Required decisions:

- whether Docker/container assistance is acceptable,
- whether SQL Server tooling license/distribution is acceptable,
- whether this remains local-first enough for the product.

ADR need: required.

### PDF Table Extraction

Priority: deferred.

Implementation path: none until extraction quality is acceptable.

Required decision before implementation:

- acceptable extraction quality threshold,
- supported PDF classes,
- user correction workflow.

ADR need: required.

## Registry Status Rules

Use registry statuses consistently:

- `complete`: production-ready for the intended scope.
- `partial`: user can import, but important limitations are expected and
  surfaced.
- `planned`: accepted into roadmap, not implemented.
- `investigate`: value or technical fit is not clear.
- `deferred`: intentionally not planned until conditions change.
- `notStarted`: no meaningful implementation or roadmap commitment.

Do not set `complete` until docs, tests, and user-visible flows are done.

## Required Test Matrix For Every New Format

Each new format must have:

- detection test,
- unsupported/invalid file test,
- preview test,
- import execution test,
- warning test,
- headless import test if the format is file-based and non-interactive,
- docs/update test where applicable,
- fixture manifest entry if fixture infrastructure covers it,
- large-file or generated performance test when the format is expected to be
  used with large data.

Wrapper formats additionally require:

- supported inner file test,
- unsupported inner file test,
- multiple inner candidate behavior,
- path traversal safety test,
- temp cleanup test.

## Documentation Sync Checklist

When any import format changes status, update:

- [ ] `ImportFormatRegistry`
- [ ] `design/IMPORT_FORMATS.md`
- [ ] `design/IMPORT_SUPPORT_PLAN.md`
- [ ] this plan, if priority/status changed
- [ ] `design/FUTURE_WINS.md`, if roadmap rank/scope changed
- [ ] root `README.md`
- [ ] `apps/decent-bench/README.md`
- [ ] in-app help pages
- [ ] import fixture manifest/tests
- [ ] ADR references, if an ADR was required
- [ ] third-party notices, if dependency changed

## Completion Definition For This Future Win

This Future Win is not a one-time feature. It remains active as a roadmap
program until the product no longer intends to add import formats.

For a single format to be complete:

- the format is detected correctly,
- unavailable states are honest,
- preview works,
- import execution works,
- progress and cancellation behave as documented,
- warnings are stable and understandable,
- tests cover clean, messy, malformed, and large cases,
- docs are updated,
- dependency/license review is complete,
- ADRs are accepted where required.

For the import expansion program to be healthy:

- `design/IMPORT_FORMATS.md` matches the registry,
- user-requested formats are triaged through this plan,
- recognized unavailable formats stay visible but are not oversold,
- no import path silently materializes large data on the UI thread,
- no new dependency enters without license review,
- wrappers never pretend unsupported inner files are importable.
