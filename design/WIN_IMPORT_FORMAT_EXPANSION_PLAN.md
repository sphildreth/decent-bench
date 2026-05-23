# Import Format Backlog And Implementation Plan

**Status:** Active backlog
**Last reviewed:** 2026-05-22  
**Source roadmap item:** `design/FUTURE_WINS.md` rank 15, `P1`
**Supported-format documentation:** `apps/decent-bench/assets/help/importing-data.md`
**Module architecture:** `design/WIN_IMPORT_MODULAR_PLAN.md`

## Purpose

This is the single planning document for import formats that users **cannot
import yet**.

If a format works in the app, document it in the in-app help page:

- `apps/decent-bench/assets/help/importing-data.md`

Do not duplicate shipped support tables in this design document. This document
is only for backlog planning, prioritization, implementation gates, and future
format intake.

Every backlog entry exists to answer one product question:

> When do we intend users to be able to import this source into DecentDB?

## Availability Targets

The backlog uses target waves instead of release promises. A wave describes the
intended implementation order once import-format work is funded and scheduled.
User demand, dependency quality, licensing, or representative fixtures can move
an item between waves.

| Target | Meaning |
|---|---|
| `Wave 1` | Highest practical usage potential. Implement first after current import architecture work. |
| `Wave 2` | Broadly useful expansion after Wave 1 or when a nearby adapter is active. |
| `Wave 3` | Domain or ecosystem expansion. Implement with clear user demand and fixtures. |
| `Wave 4` | Specialized or high-risk. Prototype or investigate before committing. |
| `Demand-gated` | Do not schedule until users bring concrete files and workflows. |

## Status Values

| Status | Meaning |
|---|---|
| `Planned` | Accepted direction. Needs implementation, tests, docs, and any required ADR/dependency review before users can import it. |
| `Candidate` | Valuable enough to keep on the backlog, but not accepted for near-roadmap implementation. |
| `Investigate` | Technical fit, dependency path, licensing, data-shape policy, or user demand is not clear yet. |
| `Deferred` | Not a good implementation target now. Revisit only if strong demand or a better dependency/conversion path appears. |

Formats that are deliberately out of scope or not feasible as native imports
are documented in the Help page under **Not Supported** instead of being treated
as backlog items.

## Backlog

Priority is ranked by likely user reach and import frequency first, then by fit
with Decent Bench's local DecentDB import loop. Implementation complexity is
captured in notes and gates, not hidden inside the priority number.

| Priority | Target | Status | Family | Format / Source | Typical Extensions / Source | Implementation Path | Gates / Notes |
|---:|---|---|---|---|---|---|---|
| 1 | Wave 1 | Planned | Clipboard / Source Adapter | Clipboard table paste | clipboard TSV/CSV/HTML | Source adapter into generic import wizard | Explicit user action only; sanitize HTML; enforce size limits; never monitor clipboard continuously. |
| 2 | Wave 1 | Planned | Analytical / Columnar | Parquet | `.parquet` | New analytical importer | Requires Apache-compatible reader, logical type mapping, nested type policy, and large-file streaming. |
| 3 | Wave 1 | Planned | Spreadsheet | OpenDocument Spreadsheet | `.ods` | Spreadsheet importer extension | Multi-sheet preview, formula policy, date handling, and type inference. |
| 4 | Wave 1 | Planned | Delimited / Text | Fixed-width text | `.txt`, `.dat`, `.fwf` | Generic import extension | Column-boundary editor, layout profiles, encoding, malformed-row handling, and validation. |
| 5 | Wave 1 | Planned | Dump / Backup | PostgreSQL plain SQL dump expansion | `.sql` | SQL dump parser expansion | Add `COPY FROM stdin`, sequences, identity columns, constraints, and PostgreSQL type mapping. |
| 6 | Wave 1 | Planned | Database / Embedded DB | DuckDB | `.duckdb` | Embedded database importer | Table selection, type mapping, dependency/packaging decision, and rich type fidelity. |
| 7 | Wave 1 | Planned | Logs / Events | JSON log stream workflow | `.jsonl`, `.ndjson`, `.log` | Profile over existing NDJSON import | Current NDJSON import works for raw rows; add timestamp extraction, presets, and log-oriented defaults. |
| 8 | Wave 1 | Investigate | Compressed / Archive | Zstandard wrapper | `.zst`, `.tar.zst` | Archive/compression wrapper | Needs cross-platform streaming decompression strategy and safe extraction policy. |
| 9 | Wave 1 | Investigate | Logs / Events | Common web/app log templates | Apache, Nginx, IIS W3C, custom app logs | Template-based structured text importer | W3C `#Fields` and common access-log patterns are highest value; preserve timestamps and request fields. |
| 10 | Wave 2 | Investigate | Database / Embedded DB | Microsoft Access | `.mdb`, `.accdb` | Legacy database importer | High user value, but dependency, driver, and cross-platform packaging are hard. ADR required. |
| 11 | Wave 2 | Investigate | Database / Embedded DB | DBF / FoxPro plus memo files | `.dbf`, `.fpt`, `.dbt` | Legacy table importer | Code pages, deleted-row policy, memo file linking, and GIS bundle use cases. |
| 12 | Wave 2 | Investigate | Web / Markup | Markdown tables | `.md` | Markup table importer | Escaped pipes, malformed tables, multiple tables per document, and header inference. |
| 13 | Wave 2 | Investigate | Structured Document | YAML structured records | `.yaml`, `.yml` | Structured document importer | Only table-like records should import; arbitrary config should not be oversold as tabular data. |
| 14 | Wave 2 | Investigate | Compressed / Archive | XZ wrapper | `.xz`, `.tar.xz` | Archive/compression wrapper | Cross-platform extraction and streaming behavior required. |
| 15 | Wave 2 | Investigate | Compressed / Archive | 7-Zip wrapper | `.7z` | Archive wrapper | Dependency/licensing review and solid-archive extraction safety. |
| 16 | Wave 2 | Candidate | Analytical / Columnar | Apache Avro | `.avro`, `.avsc` | Analytical importer | Schema evolution, logical types, nested records, and dependency review. |
| 17 | Wave 2 | Investigate | Analytical / Columnar | Apache Arrow IPC | `.arrow`, `.ipc` | Analytical importer | Depends on maintained Dart/FFI/worker strategy. |
| 18 | Wave 2 | Investigate | Analytical / Columnar | Feather | `.feather` | Arrow-backed importer | Shares Arrow dependency decisions; important for Python/R dataframe interchange. |
| 19 | Wave 2 | Candidate | Structured Document | Binary JSON family | `.bson`, `.msgpack`, `.cbor` | Binary structured-document adapters | BSON/mongodump, MessagePack, and CBOR need typed value preservation and nested flattening. |
| 20 | Wave 2 | Candidate | Structured Document | Protocol Buffers | `.proto`, `.pb`, `.pbtxt` | Schema-driven binary/text adapter | Binary protobuf requires schemas/descriptors; nested message flattening policy required. |
| 21 | Wave 2 | Investigate | Spreadsheet | SpreadsheetML / Excel XML Spreadsheet | `.xml` | Spreadsheet-specific XML adapter | Signature detection must distinguish from generic XML import. |
| 22 | Wave 2 | Candidate | Spreadsheet | Legacy spreadsheet interchange | `.slk`, `.dif`, `.wk1`, `.wk3`, `.wk4`, `.123` | Spreadsheet importer extension or external conversion | SYLK/DIF are text-based; Lotus formats likely need conversion support. |
| 23 | Wave 2 | Candidate | Open Data / Metadata | Frictionless Data Package / CSVW / JSON Table Schema / dbt seeds | `datapackage.json`, CSVW metadata, schema JSON, dbt files | Profile over CSV/JSON import | Use metadata to improve type inference, naming, validation, and repeatability. |
| 24 | Wave 2 | Candidate | Cloud / SaaS Profiles | Google Takeout bundles | `.zip` with `.json`, `.csv`, `.mbox`, `.vcf`, `.ics` | Archive plus profile set | Treat as reusable profiles over existing and future adapters; avoid implying all Google services work at once. |
| 25 | Wave 2 | Candidate | Cloud / SaaS Profiles | Cloud audit and billing exports | CloudTrail, AWS/GCP/Azure billing, Okta/Azure AD exports | Profiles over JSON/CSV/Parquet/GZip | No live cloud credentials initially; file export profiles only. |
| 26 | Wave 2 | Candidate | Cloud / SaaS Profiles | CRM, marketing, e-commerce, survey, and analytics exports | Salesforce, HubSpot, Marketo, Mailchimp, Shopify, WooCommerce, Magento, Qualtrics, Typeform, SurveyMonkey, GA4, Mixpanel | Profiles over CSV/XLSX/JSON/ZIP | Relationship metadata and column mapping are the value add. |
| 27 | Wave 2 | Candidate | Cloud / SaaS Profiles | Project, chat, developer, and low-code exports | Jira, Trello, Asana, Linear, Monday, Slack, Discord, Teams, GitHub, GitLab, Airtable | Profiles over JSON/CSV/ZIP | Group as source templates, not separate parser engines. |
| 28 | Wave 2 | Planned | Database / Live Source | PostgreSQL read-only live import | connection-based | Live source import | Requires credential storage, connection testing, cancellation, and no admin/live-query scope. ADR required. |
| 29 | Wave 2 | Planned | Database / Live Source | MariaDB / MySQL read-only live import | connection-based | Live source import | May share mapping logic with current SQL dump support. ADR required. |
| 30 | Wave 2 | Planned | Database / Live Source | SQL Server read-only live import | connection-based | Live source import | Authentication and type system complexity. ADR required. |
| 31 | Wave 2 | Candidate | NoSQL / Search / Time-Series | MongoDB / Elasticsearch / Redis / InfluxDB / Prometheus exports | `.bson`, `.json`, `.ndjson`, `.rdb`, line protocol, OpenMetrics | Parser/profile family | BSON and Elasticsearch bulk NDJSON rank highest; RDB/key-value mapping needs explicit table-shape policy. |
| 32 | Wave 2 | Candidate | Network / IT | HAR | `.har` | JSON profile | Browser/devtools HTTP archive; map requests, timings, headers, and responses conservatively. |
| 33 | Wave 3 | Investigate | Data Science / Statistics | Stata | `.dta` | Statistical dataset importer | Preserve variable labels, value labels, missing-value semantics, and encodings. |
| 34 | Wave 3 | Investigate | Data Science / Statistics | SPSS | `.sav`, `.zsav` | Statistical dataset importer | Preserve value labels, encodings, missing values, and survey metadata. |
| 35 | Wave 3 | Investigate | Data Science / Statistics | SAS transport | `.xpt` | Statistical dataset importer | Common regulated/research exchange; dependency review required. |
| 36 | Wave 3 | Candidate | Data Science / Statistics | SAS native dataset | `.sas7bdat` | Statistical dataset importer | Proprietary binary; open-source readers exist but packaging review is required. |
| 37 | Wave 3 | Candidate | Data Science / Statistics | ARFF | `.arff` | Structured text importer | Weka/ML format with typed attributes and dense/sparse rows. |
| 38 | Wave 3 | Candidate | Scientific / Engineering | HDF5 and NeXus | `.h5`, `.hdf5`, `.hdf`, `.nxs` | Worker-backed scientific importer | Hierarchical groups/datasets need table mapping policy and native dependency review. |
| 39 | Wave 3 | Candidate | Scientific / Engineering | NetCDF / CDF | `.nc`, `.nc4`, `.cdf` | Worker-backed scientific importer | Coordinate variables and multidimensional arrays need relational mapping. |
| 40 | Wave 3 | Candidate | Scientific / Engineering | FITS | `.fits`, `.fit` | Scientific binary/table importer | Binary table HDUs map well; image HDUs should be skipped or summarized initially. |
| 41 | Wave 3 | Candidate | Scientific / Engineering | MATLAB MAT-file | `.mat` | Scientific importer | v7.3 can reuse HDF5 path; earlier versions need separate parser. |
| 42 | Wave 3 | Candidate | Weather / Scientific | GRIB / BUFR weather formats | `.grb`, `.grib`, `.grib2`, `.bufr` | Worker-backed scientific importer | Likely requires ecCodes or equivalent; grids need relational mapping. |
| 43 | Wave 3 | Candidate | Bioinformatics | FASTA / FASTQ | `.fa`, `.fasta`, `.fq`, `.fastq`, gzip wrappers | Streaming structured text importer | Sequence plus quality metadata maps naturally to rows; large-file streaming required. |
| 44 | Wave 3 | Candidate | Bioinformatics | Genomics alignment, variant, and annotation formats | `.sam`, `.bam`, `.cram`, `.vcf`, `.bed`, `.gff`, `.gtf` | Structured text plus worker-backed binary adapters | VCF/BED/GFF are text; BAM/CRAM likely need htslib. |
| 45 | Wave 3 | Investigate | Scientific / Lab | Lab and domain instrument formats | `.tdms`, `.las`, `.cif`, `.sdf`, `.mol`, `.pdb`, `.root`, `.asdf` | Domain-specific adapters | Useful in measurement, oil/gas, chemistry, biology, and physics; require concrete fixtures. |
| 46 | Wave 3 | Candidate | Geospatial | GeoJSON | `.geojson` | Spatial profile over JSON import | Geometry mapping, CRS handling, and DecentDB spatial type policy. |
| 47 | Wave 3 | Investigate | Geospatial | Shapefile bundle | `.shp`, `.shx`, `.dbf`, `.prj` | Multi-file spatial importer | Bundle coordination, projection metadata, DBF attributes, and geometry conversion. |
| 48 | Wave 3 | Investigate | Geospatial | GeoPackage | `.gpkg` | SQLite-backed spatial importer | Reuse SQLite path with spatial metadata and geometry mapping. |
| 49 | Wave 3 | Candidate | Geospatial | KML / KMZ / GPX | `.kml`, `.kmz`, `.gpx` | XML/ZIP spatial adapters | Map placemarks, tracks, routes, waypoints, and metadata. |
| 50 | Wave 3 | Candidate | Geospatial | OSM PBF | `.osm.pbf`, `.pbf` | Protobuf streaming importer | Nodes, ways, relations, tags, and large-file streaming policy. |
| 51 | Wave 3 | Candidate | Geospatial | GML / CityGML / TopoJSON / WKT / WKB | `.gml`, `.xml`, `.topojson`, `.wkt`, `.wkb` | Spatial structured-document adapters | Government/spatial standards and geometry interchange; WKT/WKB often appear embedded in other sources. |
| 52 | Wave 3 | Candidate | Geospatial | GeoParquet / GeoArrow | `.parquet`, `.arrow` with geospatial metadata | Profile over Parquet/Arrow | Build after Parquet/Arrow foundations. |
| 53 | Wave 3 | Candidate | Geospatial | SpatiaLite / MBTiles | `.sqlite`, `.db`, `.mbtiles` | SQLite-backed profile | Skip or summarize large tile BLOBs by default. |
| 54 | Wave 3 | Candidate | Financial / Banking | OFX / QFX / QIF | `.ofx`, `.qfx`, `.qif` | Finance transaction importer | Map accounts and transactions; handle OFX SGML and XML variants; privacy care required. |
| 55 | Wave 3 | Candidate | Financial / Banking | MT940 / MT942 / ISO 20022 CAMT / SEPA | `.mt940`, `.sta`, `.camt`, `.xml` | Bank statement importer | Tag-based text and complex XML; strong fintech/treasury use case. |
| 56 | Wave 3 | Candidate | Financial / Accounting | XBRL / iXBRL / XBRL GL | `.xbrl`, `.xml`, inline HTML | Financial reporting importer | Taxonomy/linkbase handling is complex; report and ledger profiles are distinct. |
| 57 | Wave 3 | Candidate | Financial / Messaging | EDI X12 / EDIFACT | `.edi`, `.x12`, `.edifact` | EDI parser | Segment/loop hierarchy and implementation guides matter. |
| 58 | Wave 3 | Candidate | Financial / Trading | FIX / FIXML logs | `.fix`, `.log`, `.txt`, `.xml` | Structured log/message importer | Tag=value parser for FIX; XML profile for FIXML. |
| 59 | Wave 3 | Candidate | Financial / Payments | NACHA ACH and payment processor exports | `.ach`, `.csv`, `.xlsx`, `.json` | Fixed-width plus profile family | ACH is fixed-width; Stripe/PayPal/Square/crypto exports are mostly CSV/JSON profiles. |
| 60 | Wave 3 | Candidate | Financial / Accounting | QuickBooks / Xero / GnuCash / Ledger / Beancount | `.iif`, `.csv`, `.xlsx`, `.gnucash`, `.ledger`, `.beancount` | Accounting importer/profile family | IIF/ledger formats need section/journal parsers; many exports are CSV/XLSX/XML profiles. |
| 61 | Wave 3 | Candidate | Healthcare | FHIR bundles / NDJSON profiles | `.json`, `.ndjson` | Healthcare JSON/NDJSON profile | Raw JSON can import now, but resource-aware table mapping is future work. |
| 62 | Wave 3 | Investigate | Healthcare | HL7 v2 / C-CDA / CDA | `.hl7`, `.xml` | Healthcare message/document importers | HL7 v2 is pipe-delimited with hierarchy; CDA is complex XML. |
| 63 | Wave 3 | Investigate | Healthcare | DICOM metadata | `.dcm`, `.dicom`, `DICOMDIR` | Metadata-only healthcare importer | Skip pixel data; PHI sensitivity and metadata dictionary required. |
| 64 | Wave 3 | Candidate | Healthcare | Clinical terminology and reference datasets | ICD, CPT/HCPCS, NDC, LOINC, SNOMED CT RF2 | Profiles over CSV/TSV/XML | Large reference datasets and vocabulary relationships. |
| 65 | Wave 3 | Candidate | Healthcare | Research and clinical data standards | REDCap, OMOP CDM, CDISC SDTM/ADaM, NCPDP, ASC X12N | Profile families over CSV/SAS/EDI | Domain-specific validation is the hard part. |
| 66 | Wave 3 | Candidate | Email / Communication | MBOX / EML | `.mbox`, `.eml` | Email archive importer | RFC 2822 parsing; attachment metadata/link-only by default. |
| 67 | Wave 3 | Investigate | Email / Communication | Outlook PST / OST / MSG | `.pst`, `.ost`, `.msg` | External-conversion assisted importer | Direct parsing is dependency-heavy; prefer conversion to MBOX/EML first. |
| 68 | Wave 3 | Candidate | Calendar / Contacts | iCalendar / vCard | `.ics`, `.vcf` | Calendar/contact importers | Recurrence, timezones, and multi-value fields need careful mapping. |
| 69 | Wave 3 | Candidate | Security / Logs | CEF / LEEF / auditd / Windows EVTX | `.log`, `.csv`, `.evtx` | Security log importers | CEF/LEEF/auditd are structured text; EVTX likely needs binary/XML parser. |
| 70 | Wave 3 | Candidate | Observability | OpenTelemetry / Prometheus / Splunk / Datadog / New Relic / Loki exports | `.json`, `.jsonl`, `.csv`, OpenMetrics text | Observability profile family | Time-series labels, traces, spans, and metric samples. |
| 71 | Wave 3 | Candidate | Network / IT | PCAP / PCAPNG | `.pcap`, `.pcapng`, `.cap` | Packet summary importer | Packet summary tables only; full protocol dissection out of initial scope. |
| 72 | Wave 3 | Candidate | Network / IT | Nmap / DNS / NetFlow / BGP outputs | `.xml`, `.gnmap`, `.zone`, `.txt`, binary/CSV flow exports | Network diagnostic importers | XML/text profiles first; binary flow/routing formats require specialized parsers. |
| 73 | Wave 3 | Candidate | Industrial / IoT | Time-series and industrial text exports | OPC-UA exports, SCADA historian CSV, MQTT logs, Modbus dumps, telematics CSV | Profiles over CSV/JSON/logs | Timestamp/tag handling and quality-code metadata. |
| 74 | Wave 3 | Investigate | Industrial / IoT | Engineering/automation formats | CAN DBC/ASC, ADS-B/ACARS, AIS, IFC/BIM | Domain adapters | CAN/AIS/ADS-B feasible; IFC is complex and demand-gated. |
| 75 | Wave 3 | Candidate | Government / Public Data | Census, ACS, FEC, HMDA, IPEDS, BLS, BEA, FRED, World Bank, IMF, Comtrade | `.csv`, `.xlsx`, fixed-width, `.fec`, API downloads | Public-data profiles | Mostly CSV/XLSX/fixed-width plus codebooks. |
| 76 | Wave 3 | Candidate | Government / Public Data | Statistical exchange and publication standards | SDMX, DDI, NOAA GRIB/BUFR, USPTO XML, PubMed/MEDLINE XML | Structured/binary public-data profiles | Prioritize with public-sector/research users and fixtures. |
| 77 | Wave 4 | Candidate | Publishing / Bibliographic | BibTeX / RIS / MARC / ONIX / Crossref / DataCite | `.bib`, `.ris`, `.mrc`, `.xml`, `.json` | Bibliographic importers | BibTeX/RIS easier; MARC/ONIX specialized. |
| 78 | Wave 4 | Candidate | Media / Metadata | EXIF / IPTC / XMP / ID3 / subtitles / playlists / GEDCOM | images, audio, `.srt`, `.vtt`, `.m3u`, `.ged` | Metadata-only importers | Avoid becoming a media-management app; import metadata, not media content. |
| 79 | Wave 4 | Candidate | Configuration / Dev Tooling | Terraform state/plan, Ansible facts, HCL, Postman/Insomnia/Bruno collections, package metadata, SARIF | `.tfstate`, `.json`, `.yaml`, `.hcl`, `.sarif`, archives | Developer-data profiles | Mostly profiles over JSON/YAML/archive parsing; SARIF is high-value security results data. |
| 80 | Wave 4 | Candidate | Security / Threat Intel | STIX, CVE/NVD feeds, Nessus/OpenVAS, Sigma, YARA metadata | `.json`, `.xml`, `.nessus`, `.yaml`, `.yar` | Security-data profiles | Mostly JSON/XML/YAML profiles; YARA/Sigma metadata extraction only. |
| 81 | Wave 4 | Investigate | Legacy / Mainframe | EBCDIC files and COBOL copybook data | `.dat`, `.cpy` plus binary/fixed-width data | Legacy record-layout importer | Copybook parsing, packed decimals, zoned decimals, and EBCDIC transcoding. |
| 82 | Demand-gated | Candidate | Data Lake | Delta Lake table folders | `_delta_log` plus Parquet files | Table-directory importer | Depends on Parquet first; transaction log replay and time-travel semantics. |
| 83 | Demand-gated | Candidate | Data Lake | Apache Iceberg table metadata | metadata folder plus data files | Table-directory importer | Depends on Parquet/Avro; manifest/catalog handling. |
| 84 | Demand-gated | Candidate | Data Lake | Apache Hudi table folders | `.hoodie` metadata plus data files | Table-directory importer | Depends on Parquet/Avro/ORC; complex table types. |
| 85 | Demand-gated | Deferred | Analytical / Columnar | ORC | `.orc` | Analytical importer | Lower expected desktop frequency than Parquet; revisit after Parquet/Avro. |
| 86 | Demand-gated | Investigate | Database / Live Source | Oracle read-only live import | connection-based | Live source import | Important in some enterprise shops; high setup and support burden. |
| 87 | Demand-gated | Investigate | Database / Live Source | Generic ODBC/JDBC-like import abstraction | connection-based | Live source framework | Risk of becoming database administration scope; only consider for read-only import. |
| 88 | Demand-gated | Candidate | Dump / Backup | Oracle Data Pump / SQL*Loader | `.dmp`, `.ctl` plus data files | External-tool assisted importer | Likely requires Oracle tooling and companion data handling. |
| 89 | Demand-gated | Candidate | Dump / Backup | DB2 IXF / Teradata exports / Cassandra exports / Neo4j CSV bundles | `.ixf`, CSV/JSON/bundles | Enterprise migration importers | Usually dialect-specific tools, companion metadata, or coordinated files. |
| 90 | Demand-gated | Deferred | Database / Embedded DB | Proprietary desktop databases | FileMaker, Progress OpenEdge, Btrieve/Actian, Lotus Notes NSF, Paradox | External-conversion assisted importer | Vendor tools or drivers usually required; only schedule with representative files and users. |
| 91 | Demand-gated | Deferred | Data Science / Statistics | JMP / Minitab / EViews | `.jmp`, `.mtw`, `.mpj`, `.wf1` | Statistical importer | Concentrated niches; defer until clear demand. |

## Not Supported In The App

Some source types are deliberately not backlog items for native import because
they are installer/disk containers, arbitrary object graphs, binary systems
that need migration tooling, or content types where tabular import would be
misleading. These are documented for users in:

- `apps/decent-bench/assets/help/importing-data.md`

Use that Help section to point users toward external conversion into supported
formats such as CSV, TSV, JSON, NDJSON, XML, HTML tables, Excel, SQLite, or SQL
dumps.

## Format Addition Lifecycle

Every new import format must move through these stages before it is described
as supported.

### 1. Request Intake

Capture:

- format name and extensions,
- sample files,
- user workflow,
- expected DecentDB output shape,
- expected table count,
- source data model,
- streaming requirements,
- metadata or type-fidelity requirements,
- privacy/security concerns.

Do not implement from a vague request like "support format X" without at least
one representative sample or a documented source specification.

### 2. Product Classification

Classify the source family:

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
- live source import,
- domain-specific profile.

Add or update the backlog row in this document.

### 3. Dependency And License Review

Before adding any package, native library, or external tool:

- verify Apache 2.0-compatible distribution,
- verify Linux, macOS, and Windows support,
- verify maintenance status,
- verify streaming or bounded-memory behavior,
- identify native packaging needs,
- identify third-party notice requirements,
- decide whether an ADR is required.

If dependency status is uncertain, the format remains `Investigate`.

### 4. Module Manifest And Fixtures

Add or update a built-in module manifest under:

- `apps/decent-bench/import_modules/builtin/`

The module must declare:

- source family,
- status,
- extensions or signatures,
- implementation kind,
- adapter binding,
- limitations,
- user-facing documentation,
- fixture expectations.

Add representative fixtures before calling the format supported.

### 5. Adapter Implementation

Implementation must:

- run heavy work off the UI thread,
- stream or page large files,
- expose preview before import,
- let users adjust table and column names,
- preserve source types and logical metadata where practical,
- report warnings and skipped rows,
- support cancellation where practical,
- land data in a DecentDB `.ddb` file.

### 6. Validation And Documentation

Before marking a format supported:

- detection tests pass,
- unsupported/invalid-file tests pass,
- preview tests pass,
- import round-trip tests pass,
- large-file behavior is bounded,
- warning/error behavior is tested,
- docs are updated in `apps/decent-bench/assets/help/importing-data.md`,
- changelog is updated,
- any dependency notices are updated.

## ADR Gates

Create or update an ADR when a format:

- adds a major dependency,
- adds a native binary or external CLI,
- changes import profile format,
- changes generic import transform behavior,
- adds credential storage,
- adds live source import,
- adds source conversion/container workflow,
- cannot preserve streaming/paging expectations,
- introduces security-sensitive parsing or extraction.

Small adapters that reuse existing dependencies and contracts may not need a
new ADR, but the implementation notes must explicitly state why.
