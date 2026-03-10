# Decent Bench — Additional Import Format Support Plan

## Purpose

Decent Bench should be positioned as a **practical data intake and conversion workbench** for **DecentDB**.

The product goal is not merely to be a SQL editor. Its larger value is:

1. letting users bring in data from a wide range of external sources,
2. normalizing that data into a **DecentDB `.ddb` file**,
3. using SQL to shape, inspect, and validate the imported data,
4. generating reports and downstream artifacts from that DecentDB-backed workspace.

At this stage, the focus is **extended import support**, not extended export support.

A useful framing is:

> **Decent Bench is the front door into DecentDB.**

That means import support is not a side feature. It is a core product capability and a major differentiator.

---

## Product direction

Decent Bench should treat imported data as belonging to a few broad families:

- **Delimited / text tabular**
- **Spreadsheet**
- **Structured document**
- **Database / embedded database**
- **Database dump / backup**
- **Analytical / columnar**
- **Legacy business / line-of-business**
- **Web / markup tables**
- **Compressed / archived containers**
- **Logs / event streams**

This helps the UX because the import wizard can first identify a **family** and then guide the user through family-specific options such as:

- delimiter detection
- header row detection
- encoding selection
- worksheet selection
- schema/table selection
- flattening nested structures
- mapping repeated elements to child tables
- choosing formula behavior
- type inference and override
- handling malformed rows
- choosing import mode into a DecentDB `.ddb` target

---

## Guiding principles for import support

### 1. DecentDB-first destination
Every import path should ultimately land in a DecentDB `.ddb` file.

### 2. Smart defaults, user override
Imports should make good guesses, but users must be able to override:
- target table names
- column names
- inferred DecentDB types
- null handling
- duplicate handling
- flattening behavior
- date/time parsing
- encoding

### 3. Preserve fidelity where possible
The import process should preserve the original meaning of the source data, even when the source format is messy.

### 4. Prefer transparency over magic
If a file is malformed, partially supported, or ambiguous, the wizard should explain what is happening instead of silently guessing.

### 5. Treat formulas and nested structures explicitly
For formats like Excel, JSON, XML, and HTML, Decent Bench should clearly define whether it imports:
- displayed values,
- source expressions/formulas,
- referenced structure,
- or a combination of these.

### 6. Support reporting and querying after import
Imports should produce a shape that is practical for:
- ad hoc queries,
- report generation,
- data validation,
- repeatable workflows.

---

## Recommended import format status table

Use the following status values consistently:

- **Not Started** — no meaningful implementation exists
- **Planned** — intended and accepted into roadmap
- **In Progress** — active implementation work exists
- **Partial** — some support exists, but important gaps remain
- **Complete** — production-ready for intended MVP / release scope
- **Deferred** — recognized, but intentionally postponed
- **Investigate** — worth exploring, but technical/value fit not yet decided

| Family | Format / Source | Typical Extensions | Why It Matters | Notes / Import Considerations | Status |
|---|---|---|---|---|---|
| Delimited / Text | CSV | `.csv` | One of the most common business and developer interchange formats | Header detection, delimiter options, quoting, encoding, malformed rows | Planned |
| Delimited / Text | TSV | `.tsv` | Common where commas conflict with text payloads | Similar to CSV but simpler delimiter rules | Planned |
| Delimited / Text | Pipe-separated | `.psv`, `.txt` | Common in line-of-business exports | Detect and allow custom delimiter selection | Investigate |
| Delimited / Text | Semicolon-separated | `.csv`, `.txt` | Common in some locales and enterprise exports | Locale-aware delimiter detection | Investigate |
| Delimited / Text | Fixed-width text | `.txt`, `.dat` | Very common in legacy enterprise, banking, payroll, and batch systems | Needs column boundary definition, preview, and row validation | Planned |
| Delimited / Text | Generic custom-delimited text | `.txt`, `.dat`, `.log` | Broadly useful because many “CSV-like” files are custom | Import wizard should support manual delimiter, quote, escape, newline handling | Planned |
| Spreadsheet | Excel Open XML | `.xlsx` | Essential real-world business import source | Sheets, header detection, formulas, dates, merged cells, formatting noise | Planned |
| Spreadsheet | Legacy Excel | `.xls` | Still appears in many old workflows | Legacy parser compatibility, formulas, mixed types | Planned |
| Spreadsheet | OpenDocument Spreadsheet | `.ods` | Important for LibreOffice/OpenOffice users | Multi-sheet import, formulas, data typing | Planned |
| Spreadsheet | SpreadsheetML / XML Spreadsheet | `.xml` | Shows up in older Office-generated exports | XML-based parsing with spreadsheet semantics | Investigate |
| Structured Document | JSON | `.json` | Extremely common for APIs, exports, and app data | Flattening nested objects, arrays, repeated structures, table mapping | Planned |
| Structured Document | NDJSON / JSONL | `.ndjson`, `.jsonl` | Very common for logs, streaming exports, and data pipelines | Row-wise JSON import, schema drift detection, large-file streaming | Planned |
| Structured Document | XML | `.xml` | Common in enterprise, reporting, integrations, and data exchange | Repeated element mapping, attributes vs elements, namespaces, flattening rules | Planned |
| Structured Document | YAML | `.yaml`, `.yml` | Common in technical workflows and config-driven data | Better for structured records than arbitrary configs; flattening may be required | Investigate |
| Structured Document | TOML | `.toml` | Useful for config-like datasets and examples | Usually not tabular; best for niche structured import | Deferred |
| Structured Document | INI / properties-like files | `.ini`, `.properties` | Occasionally useful in technical workflows | Usually key/value import, niche value | Deferred |
| Web / Markup | HTML tables | `.html`, `.htm` | Very useful because many reports and copied datasets exist as HTML tables | Must detect one or more tables, choose table(s), infer headers, handle nested tables | Planned |
| Web / Markup | HTML fragments pasted from clipboard / source | pasted content, `.html` | Useful for users copying report tables from web apps and portals | Requires sanitization and table extraction UX | Investigate |
| Web / Markup | Markdown tables | `.md` | Useful for documentation-driven datasets | Good niche support; simpler than HTML tables | Investigate |
| Database / Embedded DB | SQLite | `.db`, `.sqlite`, `.sqlite3` | One of the highest-value import sources | Schema extraction, table selection, type mapping, views, indexes metadata | Planned |
| Database / Embedded DB | DuckDB | `.duckdb`, `.db` | Increasingly common in modern local analytics | Similar positioning to DecentDB users; strong candidate | Planned |
| Database / Embedded DB | Microsoft Access | `.mdb`, `.accdb` | Still heavily used in corporate legacy workflows | High value but potentially painful technically | Investigate |
| Database / Embedded DB | dBase / FoxPro / DBF | `.dbf` | Still seen in GIS, government, and legacy systems | Valuable niche legacy support | Investigate |
| Database / Embedded DB | Paradox / legacy desktop DBs | various | Legacy migration use cases | Likely niche and high-effort | Deferred |
| Database / Live Source | PostgreSQL live import | connection-based | Common enterprise and developer source system | Read-only source import, schema selection, type mapping | Planned |
| Database / Live Source | MariaDB / MySQL live import | connection-based | Common for web apps and business systems | Read-only import flow; may share logic with SQL dump support | Planned |
| Database / Live Source | SQL Server live import | connection-based | Important in enterprise environments | Authentication complexity, type system nuances | Planned |
| Database / Live Source | Oracle live import | connection-based | Important in some enterprise shops | Higher complexity, lower initial priority unless audience demands it | Investigate |
| Database / Live Source | Generic ODBC / JDBC-like abstraction | connection-based | Broad compatibility play | Attractive long-term, but can become a support burden | Investigate |
| Dump / Backup | Plain SQL dump | `.sql` | Broadly useful for migrations and one-off imports | Statement parsing, partial support messaging, import of DDL+DML | Planned |
| Dump / Backup | MySQL / MariaDB dump | `.sql` | Very common in real-world handoffs | Shared with plain SQL support, but needs dialect handling | Planned |
| Dump / Backup | PostgreSQL plain SQL dump | `.sql` | Common for backup/export workflows | Dialect-specific parsing, sequences, COPY handling | Planned |
| Dump / Backup | PostgreSQL custom / binary backup | `.backup`, `.dump`, `.tar` | Valuable but more complex than plain SQL | May require external tooling or staged conversion | Investigate |
| Dump / Backup | SQL Server BCP / bulk export files | `.bcp`, `.txt`, `.fmt` | Useful in enterprise data pipelines | Often tied to format metadata | Investigate |
| Analytical / Columnar | Parquet | `.parquet` | Very important for analytics/data engineering users | Strong candidate; schema mapping, nested types, large-file streaming | Planned |
| Analytical / Columnar | Arrow IPC | `.arrow` | Useful in modern data tooling | Efficient interchange but less common for non-technical users | Investigate |
| Analytical / Columnar | Feather | `.feather` | Common in Python/R ecosystems | Similar value proposition to Arrow | Investigate |
| Analytical / Columnar | ORC | `.orc` | Seen in big data ecosystems | Valuable but likely lower priority than Parquet | Deferred |
| Data Science / Statistics | Stata | `.dta` | Common in research/economics/government | Niche but valuable in certain verticals | Investigate |
| Data Science / Statistics | SPSS | `.sav` | Common in surveys and research | Niche but useful | Investigate |
| Data Science / Statistics | SAS transport | `.xpt` | Common in regulated/reporting environments | Specialized but real | Investigate |
| Data Science / Statistics | R data | `.rds`, `.rdata` | Useful for R users | Niche, but meaningful if targeting analysts | Deferred |
| Logs / Events | JSON log streams | `.jsonl`, `.ndjson`, `.log` | Strong fit for operational analysis | Often covered by NDJSON, but worth explicit workflow | Planned |
| Logs / Events | Delimited log files | `.log`, `.txt` | Common in operational support cases | Custom parsing templates may be needed | Investigate |
| Logs / Events | Apache / Nginx access logs | `.log` | Very common web operations data source | Could be implemented as a template-based structured text importer | Investigate |
| Compressed / Archive | ZIP wrapper of supported formats | `.zip` | Very practical and high-value | Automatically detect importable files inside archive | Planned |
| Compressed / Archive | GZip wrapper | `.gz` | Common for large CSV/JSON/NDJSON exports | Stream decompression to importer | Planned |
| Compressed / Archive | BZip2 wrapper | `.bz2` | Less common, but still useful | Nice-to-have wrapper support | Investigate |
| Compressed / Archive | XZ wrapper | `.xz` | Common in some Linux/data engineering contexts | Nice-to-have wrapper support | Investigate |
| Web / Report Capture | Clipboard table paste | clipboard | Very practical for business users copying from apps/spreadsheets/websites | Could become a major convenience feature | Investigate |
| Web / Report Capture | PDF extracted tables | `.pdf` | Attractive in concept, but accuracy can be poor | Only worth doing if extraction quality is acceptable | Deferred |

---

## Recommended implementation priority

If the product vision is “bring almost anything in, convert to DecentDB, then query/report,” the import roadmap should be staged.

### Tier 1 — highest practical value
These formats should be prioritized first because they cover a huge percentage of real-world user needs:

- CSV
- TSV
- generic delimited text
- Excel `.xlsx`
- Excel `.xls`
- JSON
- NDJSON / JSONL
- XML
- HTML tables
- SQLite
- plain SQL dump
- ZIP / GZip wrappers for supported files

### Tier 2 — strong expansion formats
These extend Decent Bench into a broader and more valuable ingestion tool:

- ODS
- fixed-width text
- Parquet
- DuckDB
- PostgreSQL live import
- MariaDB / MySQL live import
- SQL Server live import

### Tier 3 — important specialized or legacy support
These are valuable, but usually after core import capabilities feel solid:

- Access
- DBF
- PostgreSQL custom backup
- Arrow / Feather
- Stata / SPSS / SAS transport
- log templates
- Markdown tables
- clipboard HTML / pasted table capture

---

## Special notes by format family

## HTML tables

HTML tables should absolutely be included.

This is more important than many tools realize because users frequently obtain data from:
- internal portals,
- reporting sites,
- exported web reports,
- copied tables from browser content,
- saved report pages.

HTML table support should include:
- detect one or more `<table>` elements,
- preview each detected table,
- let the user choose one or many tables,
- infer headers from `<th>` or first row,
- optionally preserve table captions or IDs as metadata,
- handle nested tables conservatively,
- warn when visual formatting does not reflect underlying structure.

This is a very practical feature and aligns well with the “practical, not perfect” DecentDB philosophy.

## Excel formulas and calculated sheets

For Excel-family imports, Decent Bench should eventually support multiple import modes:

- **Displayed values only**
- **Source formulas preserved as metadata**
- **Formula-to-view translation when practical**
- **Cross-sheet references captured as lineage metadata**

In many cases, importing formulas directly as DecentDB views will be attractive, but it should be treated carefully because:
- spreadsheet semantics are not always relational semantics,
- some formulas are row-local and easy to translate,
- some formulas are workbook-global or layout-dependent and much harder to model.

A good product direction is:

1. import the values reliably,
2. preserve formulas and source-sheet metadata,
3. later introduce optional formula-to-view translation for a supported subset.

## Nested formats: JSON and XML

JSON and XML should not be treated as simple “single table” imports in all cases.

The import wizard should support strategies such as:
- flatten to one table,
- split repeated arrays/elements into child tables,
- preserve parent-child IDs,
- normalize nested documents into multiple DecentDB tables,
- show a preview of how the structure will become relational.

This will become one of the most important quality-of-life areas in the importer.

## Compressed wrappers

Compressed wrappers should be treated as convenience layers around the actual source format.

Examples:
- `customers.csv.gz`
- `orders.jsonl.gz`
- `report.zip` containing multiple `.csv` and `.xlsx` files

The UX should:
- open the archive,
- detect supported inner files,
- allow the user to choose the file(s),
- then continue into the normal import flow.

---

## Suggested document/process conventions

To make this actionable for development, consider keeping this table in a project document such as:

- `docs/IMPORT_FORMATS.md`

and tracking the current implementation state over time.

It would also be useful to add columns later for:
- **Priority**
- **Wizard complexity**
- **Streaming required**
- **Type inference complexity**
- **Nested structure support**
- **Test fixture coverage**
- **ADR required**

A future expanded tracking table could look like:

| Format | Family | Priority | Complexity | Status | Notes |
|---|---|---|---|---|---|

That version would be better for engineering execution, while the current table is better for product planning.

---

## Recommendation

Decent Bench should deliberately lean into being a **wide-ingestion data workbench** for DecentDB.

That means the product should proudly support a broad range of source formats, especially:

- spreadsheets,
- delimited text,
- structured documents,
- HTML tables,
- embedded databases,
- SQL dumps,
- analytical data files,
- compressed wrappers.

If done well, this becomes one of the strongest reasons to use Decent Bench at all:

> bring messy external data in, convert it to a clean DecentDB file, then use SQL to make it useful.
