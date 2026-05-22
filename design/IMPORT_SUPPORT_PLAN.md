# Decent Bench — Additional Import Format Support Plan

## Purpose

Decent Bench should be positioned as a **practical data intake and conversion workbench** for **DecentDB**.

The long-running implementation plan for adding import formats over time is
`design/WIN_IMPORT_FORMAT_EXPANSION_PLAN.md`. The target architecture for
scaling that work is the module catalog described in
`design/WIN_IMPORT_MODULAR_PLAN.md`. This document remains the broader product
landscape and status table for import source families.

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
- **Data lake table directories**
- **Legacy business / line-of-business**
- **Web / markup tables**
- **Compressed / archived containers**
- **Logs / event streams**
- **Scientific / engineering / lab**
- **Bioinformatics**
- **Geospatial**
- **Finance / banking / accounting**
- **Healthcare**
- **Cloud / SaaS export profiles**
- **Network / IT / security diagnostics**
- **Email / calendar / contacts**
- **Document, media, and metadata extraction**
- **Government / public data profiles**
- **Legacy / mainframe extracts**

This helps the UX because the import wizard can first identify a **family** and then guide the user through family-specific options such as:

- delimiter detection
- header row detection
- encoding selection
- worksheet selection
- schema/table selection
- source profile selection when the file is a known export shape
- flattening nested structures
- mapping repeated elements to child tables
- preserving source type and logical type metadata where available
- choosing formula behavior
- type inference and override
- handling malformed rows
- handling companion metadata files or multi-file bundles
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
- **Candidate** — worth tracking, but not yet accepted into the registry or
  implementation roadmap
- **Planned** — intended and accepted into roadmap
- **In Progress** — active implementation work exists
- **Partial** — some support exists, but important gaps remain
- **Complete** — production-ready for intended MVP / release scope
- **Deferred** — recognized, but intentionally postponed
- **Investigate** — worth exploring, but technical/value fit not yet decided

Use the following priority values consistently:

- **P0** — current core support or highest-value near-roadmap work
- **P1** — broad user value and strong fit for the DecentDB import loop
- **P2** — valuable domain expansion or profile family after core formats
- **P3** — specialized, high-risk, or dependency-sensitive
- **P4** — defer unless strong user demand appears

Rows are intentionally grouped when several sources are the same implementation
problem. For example, many SaaS exports are CSV/JSON/XLSX plus reusable import
profiles, not separate parser engines.

| Priority | Family | Format / Source | Typical Extensions / Source | Why It Matters | Notes / Import Considerations | Status |
|---|---|---|---|---|---|---|
| P0 | Delimited / Text | CSV | `.csv` | One of the most common business and developer interchange formats | Header detection, delimiter options, quoting, encoding, malformed rows | Complete |
| P0 | Delimited / Text | TSV | `.tsv` | Common where commas conflict with text payloads | Similar to CSV but simpler delimiter rules | Complete |
| P0 | Delimited / Text | Generic custom-delimited text | `.txt`, `.dat`, `.log`, `.psv` | Covers pipe-separated, semicolon-separated, and other CSV-like business exports | Import wizard supports manual delimiter, quote, escape, newline handling | Complete |
| P0 | Delimited / Text | Fixed-width text | `.txt`, `.dat`, `.fwf` | Very common in legacy enterprise, banking, payroll, government, mainframe, and batch systems | Needs column boundary editor, copybook-like layout hints, preview, and row validation | Planned |
| P0 | Spreadsheet | Excel Open XML | `.xlsx` | Essential real-world business import source | Sheets, header detection, formulas, dates, merged cells, formatting noise | Complete |
| P0 | Spreadsheet | Legacy Excel | `.xls` | Still appears in many old workflows | Routed through the legacy conversion/normalization path and may surface warnings | Partial |
| P1 | Spreadsheet | OpenDocument Spreadsheet | `.ods` | Important for LibreOffice/OpenOffice users | Multi-sheet import, formulas, data typing | Planned |
| P2 | Spreadsheet | Legacy spreadsheet interchange | `.slk`, `.dif`, `.wk1`, `.wk3`, `.wk4`, `.123` | Useful for archival business/government data | SYLK and DIF are text-based; Lotus formats likely need external conversion | Candidate |
| P2 | Spreadsheet | SpreadsheetML / XML Spreadsheet | `.xml` | Shows up in older Office-generated exports | XML-based parsing with spreadsheet semantics; signature detection must distinguish from generic XML | Investigate |
| P0 | Structured Document | JSON | `.json` | Extremely common for APIs, exports, and app data | Flattening nested objects, arrays, repeated structures, table mapping | Complete |
| P0 | Structured Document | NDJSON / JSONL | `.ndjson`, `.jsonl` | Very common for logs, streaming exports, and data pipelines | Row-wise JSON import, schema drift detection, large-file streaming | Complete |
| P0 | Structured Document | XML | `.xml` | Common in enterprise, reporting, integrations, and data exchange | Repeated element mapping, attributes vs elements, namespaces, flattening rules | Complete |
| P2 | Structured Document | YAML | `.yaml`, `.yml` | Common in technical workflows and config-driven data | Better for structured records than arbitrary configs; flattening may be required | Investigate |
| P4 | Structured Document | TOML / INI / properties / JSON5 | `.toml`, `.ini`, `.properties`, `.json5` | Occasionally useful for key/value technical datasets | Usually config, not tabular; track as structured key/value import only if demand appears | Deferred |
| P1 | Structured Document | Binary JSON family | `.bson`, `.msgpack`, `.cbor` | BSON supports MongoDB/mongodump; MessagePack and CBOR appear in APIs, mobile, embedded, and IoT | Binary-to-typed-record adapters; preserve ObjectId, binary values, and nested structures | Candidate |
| P1 | Structured Document | Protocol Buffers and schema-driven app messages | `.proto`, `.pb`, `.pbtxt` | Protobuf is common in gRPC, microservices, and app pipelines | Requires schemas for binary data; nested record flattening and descriptor handling | Candidate |
| P3 | Structured Document | Niche schema-driven serialization | `.thrift`, `.capnp`, FlatBuffers, SBE binaries | Used in some high-performance systems, finance, games, and embedded workflows | Schema required; multiple protocols; likely lower demand than Avro/protobuf | Deferred |
| P0 | Web / Markup | HTML tables | `.html`, `.htm` | Many reports and copied datasets exist as HTML tables | Detect one or more tables, choose table(s), infer headers, handle nested tables conservatively | Complete |
| P1 | Web / Report Capture | Clipboard table paste | clipboard TSV/CSV/HTML | Very practical for users copying from spreadsheets, portals, web reports, and terminals | Explicit paste/import action only; sanitize HTML; size limits | Investigate |
| P2 | Web / Markup | Markdown tables | `.md` | Useful for documentation-driven datasets | Good niche support; simpler than HTML tables | Investigate |
| P3 | Web / Markup | Other document table extraction | `.tex`, `.rst`, `.adoc`, `.org`, `.wiki`, `.rtf`, `.docx`, `.odt`, `.epub` | Captures tables embedded in docs, papers, wikis, and office documents | Treat as markup table extraction profiles; DOCX/ODT/EPUB are archive plus XML/HTML | Candidate |
| P4 | Web / Report Capture | PDF extracted tables | `.pdf` | Attractive in concept, but extraction quality can be poor | Only worth doing if correction UX and extraction quality are acceptable | Deferred |
| P0 | Database / Embedded DB | SQLite | `.db`, `.sqlite`, `.sqlite3` | One of the highest-value import sources | Schema extraction, table selection, type mapping, views, indexes metadata | Complete |
| P1 | Database / Embedded DB | DuckDB | `.duckdb` | Increasingly common in modern local analytics | Strong DecentDB migration/comparison path; preserve rich types where possible | Planned |
| P2 | Database / Embedded DB | SpatiaLite / MBTiles | `.sqlite`, `.db`, `.mbtiles` | SQLite-based spatial/map containers are common in GIS workflows | Reuse SQLite adapter with spatial/tile metadata profiles; skip or summarize large tile BLOBs by default | Candidate |
| P2 | Database / Embedded DB | Microsoft Access | `.mdb`, `.accdb` | Still heavily used in corporate legacy workflows | High value but cross-platform driver/dependency support is difficult | Investigate |
| P2 | Database / Embedded DB | dBase / FoxPro / DBF plus memo files | `.dbf`, `.fpt`, `.dbt` | Seen in GIS, government, and legacy business systems | Needs code page handling, deleted-row policy, and memo-file linking | Investigate |
| P3 | Database / Embedded DB | Enterprise/proprietary desktop databases | FileMaker, Progress OpenEdge, Btrieve/Actian, Lotus Notes NSF, Paradox | Legacy migration use cases in business, manufacturing, and enterprise archives | Usually requires external tools, vendor drivers, or container-assisted conversion | Deferred |
| P2 | Database / Live Source | PostgreSQL live import | connection-based | Common enterprise and developer source system | Read-only source import, schema selection, type mapping, secure credential storage | Planned |
| P2 | Database / Live Source | MariaDB / MySQL live import | connection-based | Common for web apps and business systems | Read-only import flow; may share logic with SQL dump support | Planned |
| P2 | Database / Live Source | SQL Server live import | connection-based | Important in enterprise environments | Authentication complexity, type system nuances | Planned |
| P3 | Database / Live Source | Oracle live import | connection-based | Important in some enterprise shops | Higher complexity, lower initial priority unless audience demands it | Investigate |
| P4 | Database / Live Source | Generic ODBC / JDBC-like abstraction | connection-based | Broad compatibility play | Attractive long-term, but can become a support burden and drift toward database administration | Investigate |
| P0 | Dump / Backup | MySQL / MariaDB SQL dump | `.sql` | Very common in real-world handoffs | Current wizard supports common MariaDB/MySQL-style `CREATE TABLE` plus `INSERT ... VALUES` patterns | Complete |
| P0 | Dump / Backup | Plain SQL dump, broad dialect scope | `.sql` | Broadly useful for migrations and one-off imports | Current scope is MVP-lite; broader SQL dialect handling remains partial | Partial |
| P1 | Dump / Backup | PostgreSQL plain SQL dump | `.sql` | Common for backup/export workflows | Add `COPY FROM stdin`, sequences, identity columns, constraints, and PostgreSQL type mapping | Planned |
| P2 | Dump / Backup | PostgreSQL custom / binary backup | `.backup`, `.dump`, `.tar` | Valuable but more complex than plain SQL | Likely requires external tooling or staged conversion | Investigate |
| P2 | Dump / Backup | SQL Server BCP / bulk export and backup | `.bcp`, `.fmt`, `.txt`, `.bak` | Common in enterprise data pipelines and migrations | BCP needs format files; `.bak` likely requires container-assisted extraction | Investigate |
| P3 | Dump / Backup | Enterprise database exports | Oracle Data Pump, SQL*Loader, DB2 IXF, Teradata exports, Cassandra exports, Neo4j CSV bundles | High-value in some migrations | Usually requires dialect-specific tools, companion metadata, or multiple coordinated files | Candidate |
| P2 | Dump / Backup | NoSQL/search/time-series exports | MongoDB BSON/mongodump, Elasticsearch bulk NDJSON, Redis RDB, Influx line protocol, Prometheus/OpenMetrics | Common in modern app and observability migrations | BSON and bulk NDJSON rank highest; RDB/key-value mapping is less natural | Candidate |
| P1 | Analytical / Columnar | Parquet | `.parquet` | The most important analytical/data-engineering file format | Strong candidate; schema mapping, nested types, large-file streaming, logical type fidelity | Planned |
| P1 | Analytical / Columnar | Apache Avro | `.avro`, `.avsc` | Foundational data-pipeline interchange with schemas and evolution | Needs schema handling, logical type mapping, nested record flattening | Candidate |
| P1 | Analytical / Columnar | Arrow IPC / Feather | `.arrow`, `.ipc`, `.feather` | Strong Python/R/dataframe interoperability and potential worker payload path | Depends on stable Dart/FFI/worker strategy | Investigate |
| P2 | Analytical / Columnar | ORC | `.orc` | Seen in big-data ecosystems | Lower expected desktop demand than Parquet; likely worker-backed | Deferred |
| P2 | Data Lake | Delta Lake / Apache Iceberg / Apache Hudi | `_delta_log`, Iceberg metadata, `.hoodie`, table folders | Dominant modern lakehouse table formats | Depends on Parquet/Avro/ORC readers and table-log/manifest interpretation; track as table-directory modules, not single files | Candidate |
| P2 | Data Lake | Data package metadata | `datapackage.json`, CSVW metadata, JSON Table Schema, dbt seeds/snapshots | Open data and analytics projects often ship CSV plus schema metadata | Profile over CSV/JSON import that improves type inference, naming, and validation | Candidate |
| P1 | Compressed / Archive | ZIP wrapper of supported formats | `.zip` | Very practical and high-value | Detect importable files inside archive and route normally | Complete |
| P1 | Compressed / Archive | GZip / Tar+GZip wrapper | `.gz`, `.tgz`, `.tar.gz` | Common for large CSV/JSON/NDJSON exports | Single-file gzip unwrap and tar+gzip archive inspection/extraction | Complete |
| P2 | Compressed / Archive | BZip2 / Tar+BZip2 wrapper | `.bz2`, `.tbz2`, `.tar.bz2` | Less common, but still useful | Single-file bzip2 unwrap and tar+bzip2 archive inspection/extraction | Complete |
| P1 | Compressed / Archive | Zstandard wrapper | `.zst`, `.tar.zst` | Modern high-performance compression, growing in data pipelines | Needs cross-platform streaming decompression strategy | Candidate |
| P2 | Compressed / Archive | XZ wrapper | `.xz`, `.tar.xz` | Common in Linux/data engineering contexts | Cross-platform extraction strategy required | Investigate |
| P3 | Compressed / Archive | LZ4 / Snappy / Brotli wrappers | `.lz4`, `.snappy`, `.sz`, `.br` | Appears in logs, Hadoop, Kafka, and web/data exports | Compression-only wrappers that route inner files after decompression | Candidate |
| P3 | Compressed / Archive | 7-Zip wrapper | `.7z` | Common on Windows and in archived data handoffs | Dependency/licensing and solid archive extraction need review | Investigate |
| P4 | Compressed / Archive | Low-value or platform archive containers | `.rar`, `.cab`, `.dmg`, `.iso`, `.zpaq` | Sometimes encountered, but rarely a data format in itself | Defer unless users provide concrete data workflows; RAR/licensing and disk-image support are high burden | Deferred |
| P2 | Data Science / Statistics | Stata / SPSS / SAS transport | `.dta`, `.sav`, `.zsav`, `.xpt` | Common in research, survey, government, pharma, and regulated datasets | Preserve value labels, missing-value codes, encodings, and metadata | Investigate |
| P1 | Data Science / Statistics | SAS native dataset | `.sas7bdat` | More common than `.xpt` in pharma, government, and clinical-trial workflows | Proprietary binary; open-source readers exist but dependency/packaging review is required | Candidate |
| P2 | Data Science / Statistics | R data | `.rds`, `.rdata` | Useful for R users | Often arbitrary object graphs; support only table-like objects if implemented | Deferred |
| P2 | Data Science / Statistics | ARFF | `.arff` | Weka/ML data-mining format with typed attributes | Text-based header plus dense/sparse data sections; good fit for a structured text adapter | Candidate |
| P3 | Data Science / Statistics | JMP / Minitab / EViews | `.jmp`, `.mtw`, `.mpj`, `.wf1` | Important in concentrated manufacturing/statistics/econometrics niches | Proprietary or niche; defer until clear demand | Deferred |
| P1 | Scientific / Engineering | HDF5 and HDF5-based formats | `.h5`, `.hdf5`, `.hdf`, `.nxs` | Major scientific, engineering, ML, and facility-data container | Hierarchical groups/datasets; needs native/worker-backed parser and table mapping policy | Candidate |
| P1 | Scientific / Engineering | NetCDF / CDF | `.nc`, `.nc4`, `.cdf` | Climate, weather, oceanography, and NASA/space-science data | Coordinate variables and multidimensional arrays need relational mapping | Candidate |
| P2 | Scientific / Engineering | FITS | `.fits`, `.fit` | Astronomy standard; binary table HDUs map well to tables | Skip or summarize image HDUs unless a raster policy exists | Candidate |
| P2 | Scientific / Engineering | MATLAB MAT-file | `.mat` | Common in engineering, academia, and signal processing | v7.3 can reuse HDF5 path; earlier versions need separate parser | Candidate |
| P2 | Scientific / Engineering | GRIB / BUFR weather formats | `.grb`, `.grib`, `.grib2`, `.bufr` | Weather/climate model and observation data | Likely worker-backed through ecCodes or equivalent; multidimensional grids | Candidate |
| P2 | Scientific / Engineering | FASTA / FASTQ | `.fa`, `.fasta`, `.fq`, `.fastq`, `.gz` wrappers | Core genomics sequence formats | Streaming required; sequence plus quality metadata maps naturally to rows | Candidate |
| P2 | Scientific / Engineering | Genomics alignment and annotation | `.sam`, `.bam`, `.cram`, `.vcf`, `.bed`, `.gff`, `.gtf` | Common bioinformatics and clinical genomics data | VCF/BED/GFF are structured text; BAM/CRAM likely require htslib worker path | Candidate |
| P3 | Scientific / Engineering | Lab and domain instrument formats | `.tdms`, `.las`, `.cif`, `.sdf`, `.mol`, `.pdb`, `.root`, `.asdf` | Valuable in measurement, oil/gas, chemistry, biology, and physics niches | Many need domain-specific parsing; ROOT/PDB/CIF should wait for user demand | Investigate |
| P4 | Scientific / Engineering | Highly specialized binary science formats | SEG-Y, IDL save, Mathematica notebooks, WDX, SPICE kernels | Real formats but narrow audiences and high parser burden | Defer unless a specific user workflow appears | Deferred |
| P1 | Geospatial | GeoJSON / GeoPackage / Shapefile | `.geojson`, `.gpkg`, `.shp` bundle | Most common practical GIS exchange formats | Geometry mapping, CRS/projection metadata, and multi-file bundle handling | Candidate |
| P2 | Geospatial | GeoParquet / GeoArrow | `.parquet`, `.arrow` with geospatial metadata | Emerging geospatial columnar standards | Build as profiles over Parquet/Arrow with geometry metadata and CRS handling | Candidate |
| P2 | Geospatial | KML / KMZ / GPX | `.kml`, `.kmz`, `.gpx` | Common web mapping, GPS, and personal geospatial exports | XML/ZIP-based; maps to points, tracks, routes, and placemarks | Candidate |
| P2 | Geospatial | OSM PBF | `.osm.pbf`, `.pbf` | OpenStreetMap regional and planet data | Protobuf-based streaming; nodes/ways/relations mapping | Candidate |
| P2 | Geospatial | GML / CityGML / TopoJSON / WKT / WKB | `.gml`, `.xml`, `.topojson`, `.wkt`, `.wkb` | Government/spatial standards and geometry interchange | XML/JSON/binary geometry-specific mapping; WKT/WKB often appears embedded in CSV/DB exports | Candidate |
| P3 | Geospatial | File Geodatabase / MapInfo / E00 | `.gdb`, `.tab`, `.mif`, `.mid`, `.e00` | Legacy and ArcGIS/government spatial archives | Proprietary or multi-file dependency risk; likely external-tool assisted | Investigate |
| P3 | Geospatial | Raster/elevation/tile metadata | GeoTIFF, COG, DTED, DEM, LAS/LAZ lidar, MBTiles | Remote sensing, elevation, lidar, and map-tile metadata | Import metadata/point records first; full raster/image workflows are not tabular | Candidate |
| P4 | Geospatial | Nautical/CAD-like spatial formats | S-57, S-100, SDTS, DXF/DWG attribute extraction, STEP/IGES | Specialized domains with limited tabular overlap | Defer until targeted demand appears | Deferred |
| P1 | Financial / Banking | OFX / QFX / QIF | `.ofx`, `.qfx`, `.qif` | Personal/business bank and credit-card statement downloads are common | OFX has SGML and XML variants; map accounts and transactions | Candidate |
| P1 | Financial / Banking | MT940 / MT942 / ISO 20022 CAMT / SEPA | `.mt940`, `.sta`, `.camt`, `.xml` | Bank statement and payment standards in treasury/fintech | Tag-based text and complex XML; strong candidate for finance users | Candidate |
| P2 | Financial / Banking | XBRL / iXBRL / XBRL GL | `.xbrl`, `.xml`, inline HTML | SEC/public-company filings and accounting/tax reporting | Taxonomy/linkbase handling is complex; report XBRL and ledger XBRL are distinct profiles | Candidate |
| P2 | Financial / Banking | EDI X12 / EDIFACT / healthcare EDI | `.edi`, `.x12`, `.edifact` | Supply chain, finance, logistics, and claims data | Segment/loop hierarchy; implementation guides matter | Candidate |
| P2 | Financial / Banking | FIX / FIXML logs | `.fix`, `.log`, `.txt`, `.xml` | Trading systems and financial message logs | Tag=value parser for FIX; XML profile for FIXML | Candidate |
| P2 | Financial / Banking | NACHA ACH and payment processor exports | `.ach`, `.csv`, `.xlsx`, `.json` | Payroll, ACH, Stripe, PayPal, Square, crypto exchange, and e-commerce payment analysis | ACH is fixed-width; processor and exchange exports are mostly CSV/JSON profiles | Candidate |
| P2 | Financial / Accounting | QuickBooks / Xero / GnuCash / Ledger / Beancount | `.iif`, `.csv`, `.xlsx`, `.gnucash`, `.ledger`, `.beancount` | Common small-business and plaintext accounting workflows | IIF/ledger formats need section/journal parsers; many exports are profiles over CSV/XLSX/XML | Candidate |
| P3 | Financial / Market Data | Bloomberg / Refinitiv / Capital IQ exports | `.csv`, `.xlsx`, vendor exports | Professional financial data often arrives as spreadsheet exports | Mostly profile over existing spreadsheet/delimited support; API access is out of scope without credential model | Deferred |
| P2 | Healthcare | FHIR bundles / NDJSON profiles | `.json`, `.ndjson` | Modern healthcare exchange and bulk export | JSON/NDJSON exists; value is resource-aware table mapping | Candidate |
| P2 | Healthcare | HL7 v2 / C-CDA / CDA | `.hl7`, `.xml` | Common EHR and hospital interoperability artifacts | HL7 v2 is pipe-delimited with hierarchy; CDA is complex XML | Investigate |
| P2 | Healthcare | DICOM metadata | `.dcm`, `.dicom`, `DICOMDIR` | Medical imaging headers contain rich structured study/patient/series metadata | Metadata-only; skip pixel data; high PHI sensitivity | Investigate |
| P2 | Healthcare | Clinical terminology and reference datasets | ICD, CPT/HCPCS, NDC, LOINC, SNOMED CT RF2 | Healthcare analytics often needs code/reference tables | Mostly profiles over CSV/TSV/XML with large reference datasets | Candidate |
| P3 | Healthcare | Research and clinical data standards | REDCap, OMOP CDM, CDISC SDTM/ADaM, NCPDP, ASC X12N | Important in academic, claims, and clinical-trial domains | Many are profiles over CSV/SAS/EDI; domain-specific validation is the hard part | Candidate |
| P1 | Logs / Events | JSON log streams | `.jsonl`, `.ndjson`, `.log` | Strong fit for operational analysis | NDJSON support exists; explicit log workflow can add timestamp extraction and presets | Planned |
| P1 | Logs / Events | Delimited and common web logs | `.log`, `.txt` | Apache, Nginx, IIS W3C, and custom app logs are frequent local analysis sources | Template-based structured text importer; W3C `#Fields` header is high value | Investigate |
| P2 | Logs / Events | Security event log standards | CEF, LEEF, auditd, syslog, Windows EVTX | Security/compliance/SOC users need local audit analysis | EVTX likely needs binary/XML parser; CEF/LEEF/auditd are structured text | Candidate |
| P2 | Logs / Events | Observability traces and metrics | OpenTelemetry JSON, Prometheus/OpenMetrics, Splunk/Datadog/New Relic/Loki exports | Developers often export telemetry for local analysis | Mostly profiles over JSON/NDJSON/CSV plus time-series/label handling | Candidate |
| P2 | Network / IT | HAR | `.har` | Standard browser/devtools HTTP archive; very common for web debugging | JSON profile over existing structured import with request/response timing tables | Candidate |
| P2 | Network / IT | PCAP / PCAPNG | `.pcap`, `.pcapng`, `.cap` | Universal network capture for security and operations | Packet summary import only; full protocol dissection is out of scope initially | Investigate |
| P2 | Network / IT | Nmap / DNS / NetFlow / BGP outputs | `.xml`, `.gnmap`, `.zone`, `.txt`, binary/CSV flow exports | Common security and network-engineering diagnostics | XML/text profiles first; binary NetFlow/BGP requires specialized parser | Candidate |
| P2 | Cloud / SaaS Profiles | Cloud audit and billing exports | CloudTrail, AWS/GCP/Azure billing, Okta/Azure AD audit/user exports | Cloud security and cost analysis are common local workflows | Usually JSON/CSV/Parquet/GZip profiles; do not require live cloud credentials initially | Candidate |
| P2 | Cloud / SaaS Profiles | Google Takeout and personal data bundles | `.zip` with `.json`, `.csv`, `.mbox`, `.vcf`, `.ics` | Broad personal-data export source with many reusable profiles | Archive plus format profiles; MBOX/vCard/iCalendar become important companion modules | Candidate |
| P2 | Cloud / SaaS Profiles | CRM, marketing, e-commerce, survey, and analytics exports | Salesforce, HubSpot, Marketo, Mailchimp, Shopify, WooCommerce, Magento, Qualtrics, Typeform, SurveyMonkey, GA4, Mixpanel | Very common business data sources | Mostly reusable profiles over CSV/XLSX/JSON/ZIP; relationship metadata and column mapping add value | Candidate |
| P2 | Cloud / SaaS Profiles | Project, chat, developer, and low-code exports | Jira, Trello, Asana, Linear, Monday, Slack, Discord, Teams, GitHub, GitLab, Airtable | Useful for workflow and operations analytics | Mostly profiles over JSON/CSV/ZIP; group as source templates, not distinct engines | Candidate |
| P2 | Email / Communication | MBOX / EML | `.mbox`, `.eml` | Email archives are common in Google Takeout, e-discovery, and personal data portability | RFC 2822 parsing; attachment handling should be metadata/link-only by default | Candidate |
| P3 | Email / Communication | Outlook PST / OST / MSG | `.pst`, `.ost`, `.msg` | Very common enterprise archives | Direct parsing is dependency-heavy; prefer external conversion path first | Investigate |
| P2 | Calendar / Contacts | iCalendar / vCard | `.ics`, `.vcf` | Calendar/contact exports from Google/Apple/Microsoft and personal data portability | Recurrence, timezones, and multi-value fields need careful mapping | Candidate |
| P3 | Industrial / IoT | Time-series and industrial text exports | OPC-UA exports, SCADA historian CSV, MQTT logs, Modbus dumps, telematics CSV | Manufacturing, telemetry, fleet, and IoT data often arrives as CSV/JSON/logs | Mostly profiles over delimited/JSON plus timestamp/tag handling | Candidate |
| P3 | Industrial / IoT | Engineering/automation formats | CAN DBC/ASC logs, ADS-B/ACARS, AIS, IFC/BIM | Useful in automotive, aviation, maritime, and AEC domains | DBC/ASC and AIS/ADS-B are feasible profiles; IFC is complex and should be investigated only with demand | Investigate |
| P3 | Government / Public Data | Census, ACS, FEC, HMDA, IPEDS, BLS, BEA, FRED, World Bank, IMF, Comtrade | `.csv`, `.xlsx`, fixed-width, `.fec`, API downloads | Public data is a strong source of repeatable import profiles | Mostly profiles over CSV/XLSX/fixed-width with codebook metadata | Candidate |
| P3 | Government / Public Data | Statistical exchange standards | SDMX, DDI, SAS datasets, NOAA GRIB/BUFR, USPTO XML, PubMed/MEDLINE XML | Important for public-sector/research users | Structured XML/binary/statistical profiles; prioritize when user personas demand | Candidate |
| P3 | Publishing / Bibliographic | BibTeX / RIS / MARC / ONIX / Crossref / DataCite | `.bib`, `.ris`, `.mrc`, `.xml`, `.json` | Academic, library, publisher, and DOI metadata | BibTeX/RIS are easier; MARC/ONIX are specialized | Candidate |
| P3 | Media / Metadata | EXIF / IPTC / XMP / ID3 / subtitles / playlists / GEDCOM | images, audio, `.srt`, `.vtt`, `.m3u`, `.ged` | Structured metadata hidden in media and personal archives | Metadata-only extraction; avoid becoming a media-management app | Candidate |
| P3 | Configuration / Dev Tooling | Terraform state/plan, Ansible facts, HCL, Postman/Insomnia/Bruno collections, package metadata, SARIF | `.tfstate`, `.json`, `.yaml`, `.hcl`, `.sarif`, archives | Useful for developer/security/local analysis workflows | Mostly profiles over JSON/YAML/archive parsing; SARIF is a high-value security results profile | Candidate |
| P3 | Security / Threat Intel | STIX, CVE/NVD feeds, Nessus/OpenVAS, Sigma, YARA metadata | `.json`, `.xml`, `.nessus`, `.yaml`, `.yar` | Security teams often need local searchable threat/vulnerability data | Mostly structured JSON/XML/YAML profiles; YARA/Sigma metadata extraction only | Candidate |
| P3 | Legacy / Mainframe | EBCDIC files and COBOL copybook data | `.dat`, `.cpy` plus binary/fixed-width data | Banking, insurance, government, and healthcare still carry legacy files | Copybook parsing, packed decimals, zoned decimals, and EBCDIC transcoding are valuable but complex | Investigate |
| P4 | Legacy / Mainframe | VSAM / IMS / IDMS / Adabas / MultiValue PICK | various exports | Real enterprise systems, but rarely importable as local files without migration tools | Treat as external-tool assisted only; too broad for near-term native parsing | Deferred |

---

## Recommended implementation priority

If the product vision is "bring almost anything in, convert to DecentDB, then query/report," the import roadmap should be staged.

The modular import architecture in `design/WIN_IMPORT_MODULAR_PLAN.md` should
come before large new parser families. After that, new formats should generally
start as module manifests and fixture plans, then become adapters only when the
implementation path is clear.

### Tier 1 - already core or highest practical value
These formats cover a huge percentage of real-world user needs and should
remain the compatibility baseline:

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
- ZIP / GZip / BZip2 wrappers for supported files

### Tier 2 - next parser and wrapper modules
These extend Decent Bench into a broader and more valuable ingestion tool:

- ODS
- fixed-width text
- Parquet
- Avro
- DuckDB
- PostgreSQL plain dump expansion
- Zstandard wrapper
- clipboard table paste
- Arrow IPC / Feather if dependency review is favorable
- BSON / MessagePack / CBOR as a binary structured-document family

### Tier 3 - high-value profile families
These are mostly profiles over existing CSV, JSON, XML, HTML, archive, or
spreadsheet adapters. They are high leverage because they improve import
quality without always requiring a new parser engine:

- AWS CloudTrail and cloud billing exports
- Google Takeout bundles
- Salesforce/HubSpot/CRM export bundles
- project-management exports such as Jira, Asana, Linear, and Monday
- Slack/Discord/Teams exports
- Stripe/PayPal/Square and crypto exchange exports
- QuickBooks/Xero/GnuCash/Ledger accounting exports
- government/open-data packages such as Census, ACS, FEC, HMDA, SDMX, and
  Frictionless Data Packages
- HAR files
- common web/server/security logs such as Apache, Nginx, IIS W3C, CEF, LEEF,
  auditd, and Windows EVTX

### Tier 4 - important domain parser families
These are valuable, but should usually follow the module catalog, typed-batch
contract, worker protocol, and core expansion formats:

- Access
- DBF
- PostgreSQL custom backup
- Stata / SPSS / SAS transport
- SAS7BDAT
- HDF5 / NetCDF / CDF / NeXus
- FITS and MATLAB MAT-files
- FASTA / FASTQ / VCF / BAM / CRAM / BED / GFF / GTF
- GeoPackage / Shapefile / GeoJSON / OSM PBF
- OFX / QFX / QIF / MT940 / CAMT / XBRL / EDI
- FHIR / HL7 / DICOM metadata
- MBOX / EML / iCalendar / vCard

### Tier 5 - strategic or defer-until-demand
These are real formats, but should not distract from the main import loop
unless users bring concrete files and workflows:

- Delta Lake / Iceberg / Hudi before Parquet/Avro/ORC foundations exist
- ORC before Parquet and Avro
- Oracle Data Pump, DB2 IXF, Teradata, FileMaker, Progress OpenEdge, Btrieve,
  Lotus Notes NSF, and other vendor-specific sources
- PCAP/PCAPNG beyond packet summary tables
- ROOT, SEG-Y, IDL saves, Mathematica notebooks, SPICE kernels
- CAD and nautical formats such as DXF/DWG, STEP/IGES, S-57, S-100
- RAR, CAB, DMG, ISO, ZPAQ, and other low-value archive containers
- full PDF table extraction without a strong correction workflow

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

To make this actionable for development, keep user-facing support state in:

- `design/IMPORT_FORMATS.md`

and keep the broader product planning view in this document. After
`design/WIN_IMPORT_MODULAR_PLAN.md` is implemented, both documents should be
validated against import module manifests instead of being maintained as
independent lists.

Future module manifests should continue to track:

- **Wizard complexity**
- **Streaming required**
- **Type inference complexity**
- **Nested structure support**
- **Test fixture coverage**
- **ADR required**
- **Dependency/license review required**
- **Profile-only versus parser-required implementation**

The engineering execution view should eventually be generated from module
metadata with a shape similar to:

| Module | Family | Priority | Complexity | Status | Adapter | Fixtures | ADR |
|---|---|---|---|---|---|---|---|

The table in this document is intentionally product-planning oriented. The
module catalog should become the implementation source of truth.

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
- scientific and engineering containers,
- geospatial sources,
- finance and healthcare standards,
- logs, telemetry, and security exports,
- cloud/SaaS export profiles,
- public-data profile packs.

If done well, this becomes one of the strongest reasons to use Decent Bench at all:

> bring messy external data in, convert it to a clean DecentDB file, then use SQL to make it useful.
