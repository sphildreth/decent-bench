# Import Format Backlog And Implementation Plan

**Status:** Active backlog
**Last reviewed:** 2026-05-23
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
User demand, dependency quality, licensing, implementation complexity, or
representative fixtures can move an item between waves.

| Target | Meaning |
|---|---|
| `Wave 1` | High user value with a clear, bounded implementation path. Implement first after current import architecture work. |
| `Wave 2` | High-value expansion that is useful but depends on an ADR, worker/runtime decision, profile framework, or nearby adapter. |
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

## Testing Tooling Policy

Prefer Dockerized test tooling whenever a future format needs an external
application, database engine, CLI, or language ecosystem to generate fixtures or
validate output.

The goal is to avoid requiring contributors to install a wide collection of
format-specific applications on the host development system. Docker-based
fixture generation also makes cleanup easier and makes test data provenance
more repeatable.

Rules:

- Normal `flutter test` runs must use checked-in fixtures and must not require
  Docker, a running database service, LibreOffice, Python packages, DuckDB,
  PostgreSQL, or other optional tools.
- Fixture-generation scripts may require Docker when a real source application
  is needed.
- Docker image names, tags, commands, generated file paths, and cleanup behavior
  must be documented next to the fixture script or module README.
- Prefer pinned image tags over floating `latest` tags for reproducibility.
- Generated fixtures must be small enough for the repository or explicitly
  documented as non-checked-in local fixtures.
- If a fixture cannot be generated in Docker, document why and list the minimum
  host tool requirement.
- Any Docker image used for fixture generation must still pass dependency and
  license review if it becomes part of the release build or runtime path.
- Docker is allowed for development and fixture generation; it must not become
  an app runtime requirement unless a format-specific ADR explicitly accepts
  that trade-off.

Expected Docker-backed fixture sources for completed near-term formats and
remaining planned or investigated formats:

| Format | Preferred Docker Tooling | Purpose |
|---|---|---|
| PostgreSQL plain dumps | `postgres` image with `pg_dump` | Generate representative plain SQL dumps with `COPY`, sequences, identity columns, quoted identifiers, and common PostgreSQL types. |
| Parquet | Python image with `pyarrow`/`pandas`, or DuckDB image/CLI | Generate and independently validate Parquet fixtures covering primitives, nulls, logical types, decimals, timestamps, binary values, and nested values. |
| DuckDB | DuckDB CLI image or Python image with `duckdb` | Generate `.duckdb` databases and validate table/type expectations without installing DuckDB on the host. |
| ODS | LibreOffice image when practical | Generate and verify `.ods` workbooks with sheets, cached formulas, dates, repeated cells, and sparse rows. Checked-in hand-authored fixtures are acceptable when containerized LibreOffice is too heavy. |
| Fixed-width text | No external tool required | Generate deterministic text fixtures in-repo. |
| JSON log stream | No external tool required | Generate deterministic `.jsonl` and `.log` fixtures in-repo. |
| Clipboard table paste | No external tool required for automated tests | Use synthetic clipboard payloads in tests; browser/spreadsheet manual checks are optional. |
| Microsoft Access | Java/Maven image with Jackcess/UCanAccess; optional MDBTools image for comparison-only `.mdb` probes | Generate tiny `.mdb`/`.accdb` fixtures and compare extracted schema/rows without installing Access, ODBC drivers, Java toolchains, or MDBTools on the host. |
| DBF / FoxPro | GDAL/OGR image, LibreOffice image, or pinned Python image with a DBF writer | Generate DBF tables, code-page variants, deleted-row cases, and optional memo-file fixtures. Normal tests use checked-in fixtures. |
| Markdown tables | No external tool required | Use deterministic text fixtures with pipe tables, escaped pipes, malformed rows, multiple tables, and surrounding prose. |
| YAML structured records | No external tool required | Use deterministic `.yaml`/`.yml` fixtures for top-level lists, maps of records, nested values, and deliberately non-tabular config files. |
| XZ | Debian/Alpine image with `xz-utils` when fixture generation needs real compressor output | Generate `.xz` and `.tar.xz` fixtures without installing `xz` locally. Runtime support should prefer bounded extraction and existing system `tar` behavior for tarballs. |
| 7-Zip | Pinned image with `7z`/`p7zip` for investigation fixtures only | Generate `.7z` fixtures and solid-archive edge cases for compatibility research. Do not make Docker or host `7z` a runtime requirement without ADR approval. |
| Arrow IPC / Feather | Python image with `pyarrow` | Generate `.arrow`, `.ipc`, and `.feather` fixtures covering primitive, nullable, dictionary, timestamp, decimal, binary, and nested values. |
| SpreadsheetML | Hand-authored XML fixtures; LibreOffice/Excel-exported samples only when needed | Verify signature detection and worksheet/table extraction without treating arbitrary XML as SpreadsheetML. |
| Statistical packages | Python image with `pyreadstat`/ReadStat; optional R image with `haven` for comparison | Generate `.dta`, `.sav`, `.zsav`, and `.xpt` fixtures with labels, user missing values, encodings, dates, and wide tables without installing Stata, SPSS, or SAS locally. |
| Shapefile / GeoPackage | GDAL/OGR image with `ogr2ogr`/`ogrinfo` | Generate and validate `.shp` sidecar bundles and `.gpkg` files with points, lines, polygons, projections, attributes, nulls, and encoding metadata. |
| Healthcare messages and metadata | Python image with `hl7apy` and `pydicom`; synthetic fixtures only | Generate HL7 v2 messages and DICOM metadata samples without PHI. Do not check in real patient data or real medical images. |
| Outlook archives | libpff/libpst containers for investigation/conversion experiments only | Convert PST/OST/MSG samples to MBOX/EML-like outputs during research. Do not make GPL conversion tools part of the app runtime without ADR approval. |
| Lab and scientific domain files | Python images with format-specific readers such as `lasio`, `gemmi`, `rdkit`, `asdf`, or candidate TDMS/ROOT readers | Generate tiny fixtures and compare extracted rows/metadata. License review is required before any worker dependency ships. |
| Engineering / automation | Python images with tools such as `cantools` and `pyais`; IFC tools only for research | Generate CAN DBC/ASC, AIS, ADS-B, and IFC fixtures. Prefer permissive dependencies; GPL/LGPL tools are investigation-only until an ADR accepts them. |

## Backlog

Priority is ranked by likely user reach, import frequency, fit with Decent
Bench's local DecentDB import loop, and implementation readiness. High-impact
formats with unresolved runtime, dependency, or scope decisions remain high in
the backlog, but they should not block smaller high-value adapters that can
ship sooner.

The 2026-05-23 review deliberately moved heavy worker-backed, native-runtime,
and live-database work out of Wave 1. Wave 1 is now the practical first batch:
formats and profiles that mostly reuse the existing generic import, structured
document, spreadsheet, archive-wrapper, and SQL-dump paths.

| Priority | Target | Status | Family | Format / Source | Typical Extensions / Source | Implementation Path | Gates / Notes |
|---:|---|---|---|---|---|---|---|
| 11 | Wave 2 | Investigate | Analytical / Columnar | Parquet | `.parquet` | Worker-backed analytical importer | Still one of the highest-impact formats, but ADR-0054 keeps it dependency-gated until a reader/runtime path, logical type mapping, nested type policy, and large-file streaming plan are accepted. |
| 12 | Wave 2 | Candidate | Database / Embedded DB | DuckDB | `.duckdb` | Embedded database importer | High local-analytics value, but native dependency and packaging decisions are unresolved. Promote to `Planned` after dependency ADR and fixture strategy are accepted. |
| 13 | Wave 2 | Investigate | Compressed / Archive | Zstandard wrapper | `.zst`, `.tar.zst` | Archive/compression wrapper | Common and valuable, but keep below XZ until cross-platform streaming decompression and safe extraction policy are clear. |
| 14 | Wave 2 | Candidate | Structured Document | YAML structured records | `.yaml`, `.yml` | Structured document importer | Feasible with the existing `yaml` dependency path, but only record-shaped YAML should route to import. Arbitrary config files must produce a clear "not tabular" result. |
| 15 | Wave 2 | Candidate | Open Data / Metadata | Frictionless Data Package / CSVW / JSON Table Schema / dbt seeds | `datapackage.json`, CSVW metadata, schema JSON, dbt files | Profile over CSV/JSON import | Strong fit because metadata improves current imports. Use schemas to improve type inference, naming, validation, and repeatability. |
| 16 | Wave 2 | Candidate | Cloud / SaaS Profiles | Cloud audit and billing exports | CloudTrail, AWS/GCP/Azure billing, Okta/Azure AD exports | Profiles over JSON/CSV/Parquet/GZip | High practical value as file exports. No live cloud credentials initially; file export profiles only. |
| 17 | Wave 2 | Candidate | Cloud / SaaS Profiles | CRM, marketing, e-commerce, survey, and analytics exports | Salesforce, HubSpot, Marketo, Mailchimp, Shopify, WooCommerce, Magento, Qualtrics, Typeform, SurveyMonkey, GA4, Mixpanel | Profiles over CSV/XLSX/JSON/ZIP | Relationship metadata and column mapping are the value add; most files reuse existing parsers. |
| 18 | Wave 2 | Candidate | Cloud / SaaS Profiles | Project, chat, developer, and low-code exports | Jira, Trello, Asana, Linear, Monday, Slack, Discord, Teams, GitHub, GitLab, Airtable | Profiles over JSON/CSV/ZIP | Group as source templates, not separate parser engines. Useful after profile infrastructure exists. |
| 19 | Wave 2 | Candidate | Cloud / SaaS Profiles | Google Takeout bundles | `.zip` with `.json`, `.csv`, `.mbox`, `.vcf`, `.ics` | Archive plus profile set | High user reach but uneven source shapes. Treat as reusable profiles over existing and future adapters; avoid implying all Google services work at once. |
| 20 | Wave 2 | Candidate | Database / Embedded DB | DBF / FoxPro plus memo files | `.dbf`, `.fpt`, `.dbt` | Legacy table importer | Core DBF is feasible and unlocks Shapefile attributes. Memo files, code pages, deleted-row policy, and Shapefile coordination remain gates. |
| 21 | Wave 2 | Candidate | Geospatial | GeoJSON | `.geojson` | Spatial profile over JSON import | Common and close to existing JSON support, but requires geometry mapping, CRS handling, and DecentDB spatial type policy. |
| 22 | Wave 2 | Candidate | Geospatial | GeoPackage | `.gpkg` | SQLite-backed spatial importer | Good fit because it is SQLite-backed. Feature tables should be first; tile/raster BLOB tables should be skipped or summarized until raster policy exists. |
| 23 | Wave 2 | Candidate | Geospatial | Shapefile bundle | `.shp`, `.shx`, `.dbf`, `.prj` | Multi-file spatial importer | Very common, but requires sidecar bundle handling, DBF attributes, spatial type policy, projection metadata, and GDAL-backed fixture validation. |
| 24 | Wave 2 | Candidate | Analytical / Columnar | Apache Avro | `.avro`, `.avsc` | Analytical importer | Important in data pipelines, but requires schema evolution, logical type, nested record, and dependency review. |
| 25 | Wave 2 | Candidate | Structured Document | Binary JSON family | `.bson`, `.msgpack`, `.cbor` | Binary structured-document adapters | BSON/mongodump, MessagePack, and CBOR need typed value preservation and nested flattening. |
| 26 | Wave 2 | Candidate | Structured Document | Protocol Buffers | `.proto`, `.pb`, `.pbtxt` | Schema-driven binary/text adapter | Binary protobuf requires schemas/descriptors; nested message flattening policy required. |
| 27 | Wave 2 | Candidate | NoSQL / Search / Time-Series | MongoDB / Elasticsearch / Redis / InfluxDB / Prometheus exports | `.bson`, `.json`, `.ndjson`, `.rdb`, line protocol, OpenMetrics | Parser/profile family | BSON and Elasticsearch bulk NDJSON rank highest; RDB/key-value mapping needs explicit table-shape policy. |
| 28 | Wave 2 | Investigate | Analytical / Columnar | Apache Arrow IPC | `.arrow`, `.ipc` | Analytical importer | Keep investigating. Arrow is strategically useful, but the accepted worker protocol intentionally avoids requiring Arrow IPC until dependency and payload strategy are reviewed. |
| 29 | Wave 2 | Investigate | Analytical / Columnar | Feather | `.feather` | Arrow-backed importer | Treat as an Arrow IPC profile, not an independent parser. Implement only after the Arrow IPC dependency and typed-batch strategy are accepted. |
| 30 | Wave 2 | Candidate | Spreadsheet | Legacy spreadsheet interchange | `.slk`, `.dif`, `.wk1`, `.wk3`, `.wk4`, `.123` | Spreadsheet importer extension or external conversion | SYLK/DIF are text-based; Lotus formats likely need conversion support and demand validation. |
| 31 | Wave 3 | Candidate | Database / Live Source | PostgreSQL read-only live import | connection-based | Live source import | Demoted from `Planned`: useful but expands credential, connection, cancellation, and live-source scope. ADR required. |
| 32 | Wave 3 | Candidate | Database / Live Source | MariaDB / MySQL read-only live import | connection-based | Live source import | Demoted from `Planned`: may share mapping logic with SQL dump support, but still needs secure credentials and connection lifecycle. |
| 33 | Wave 3 | Candidate | Database / Live Source | SQL Server read-only live import | connection-based | Live source import | Demoted from `Planned`: authentication, driver, and type-system complexity are high. ADR required. |
| 34 | Wave 3 | Investigate | Database / Embedded DB | Microsoft Access | `.mdb`, `.accdb` | Legacy database importer | Moved down after investigation. High user value, but JVM/worker packaging, Access type fidelity, dependency tree review, fixtures, and ADR approval are required. |
| 35 | Wave 3 | Candidate | Data Science / Statistics | Stata | `.dta` | Statistical dataset importer | Feasible through a shared ReadStat/pyreadstat-style worker. Preserve labels, formats, extended missing values, encodings, and version-specific limits. |
| 36 | Wave 3 | Candidate | Data Science / Statistics | SPSS | `.sav`, `.zsav` | Statistical dataset importer | Feasible through the same statistical worker family. Preserve labels, user-missing values, encodings, multiple-response metadata when available, and compression/version warnings. |
| 37 | Wave 3 | Candidate | Data Science / Statistics | SAS transport | `.xpt` | Statistical dataset importer | Feasible through the same statistical worker family. Prioritize XPORT v5/v8, regulated/research fixtures, labels, date/time conversion, and field-name warnings. |
| 38 | Wave 3 | Candidate | Data Science / Statistics | SAS native dataset | `.sas7bdat` | Statistical dataset importer | Proprietary binary; open-source readers exist but packaging review is required. |
| 39 | Wave 3 | Candidate | Data Science / Statistics | ARFF | `.arff` | Structured text importer | Weka/ML format with typed attributes and dense/sparse rows; simpler than statistical binary formats. |
| 40 | Wave 3 | Candidate | Scientific / Engineering | HDF5 and NeXus | `.h5`, `.hdf5`, `.hdf`, `.nxs` | Worker-backed scientific importer | Hierarchical groups/datasets need table mapping policy and native dependency review. |
| 41 | Wave 3 | Candidate | Scientific / Engineering | NetCDF / CDF | `.nc`, `.nc4`, `.cdf` | Worker-backed scientific importer | Coordinate variables and multidimensional arrays need relational mapping. |
| 42 | Wave 3 | Candidate | Scientific / Engineering | FITS | `.fits`, `.fit` | Scientific binary/table importer | Binary table HDUs map well; image HDUs should be skipped or summarized initially. |
| 43 | Wave 3 | Candidate | Scientific / Engineering | MATLAB MAT-file | `.mat` | Scientific importer | v7.3 can reuse HDF5 path; earlier versions need separate parser. |
| 44 | Wave 3 | Candidate | Weather / Scientific | GRIB / BUFR weather formats | `.grb`, `.grib`, `.grib2`, `.bufr` | Worker-backed scientific importer | Likely requires ecCodes or equivalent; grids need relational mapping. |
| 45 | Wave 3 | Candidate | Bioinformatics | FASTA / FASTQ | `.fa`, `.fasta`, `.fq`, `.fastq`, gzip wrappers | Streaming structured text importer | Sequence plus quality metadata maps naturally to rows; large-file streaming required. |
| 46 | Wave 3 | Candidate | Bioinformatics | Genomics alignment, variant, and annotation formats | `.sam`, `.bam`, `.cram`, `.vcf`, `.bed`, `.gff`, `.gtf` | Structured text plus worker-backed binary adapters | VCF/BED/GFF are text; BAM/CRAM likely need htslib. |
| 47 | Wave 3 | Candidate | Scientific / Lab | Lab and domain instrument formats | `.tdms`, `.las`, `.cif`, `.sdf`, `.mol`, `.pdb`, `.root`, `.asdf` | Domain-specific adapters | Candidate family but must split before implementation. LAS, CIF, SDF/MOL/PDB metadata, and ASDF are more tractable; TDMS and ROOT need stronger review. |
| 48 | Wave 3 | Candidate | Geospatial | KML / KMZ / GPX | `.kml`, `.kmz`, `.gpx` | XML/ZIP spatial adapters | Map placemarks, tracks, routes, waypoints, and metadata; depends on spatial type policy. |
| 49 | Wave 3 | Candidate | Geospatial | OSM PBF | `.osm.pbf`, `.pbf` | Protobuf streaming importer | Nodes, ways, relations, tags, and large-file streaming policy. |
| 50 | Wave 3 | Candidate | Geospatial | GML / CityGML / TopoJSON / WKT / WKB | `.gml`, `.xml`, `.topojson`, `.wkt`, `.wkb` | Spatial structured-document adapters | Government/spatial standards and geometry interchange; WKT/WKB often appear embedded in other sources. |
| 51 | Wave 3 | Candidate | Geospatial | GeoParquet / GeoArrow | `.parquet`, `.arrow` with geospatial metadata | Profile over Parquet/Arrow | Build after Parquet/Arrow foundations. |
| 52 | Wave 3 | Candidate | Geospatial | SpatiaLite / MBTiles | `.sqlite`, `.db`, `.mbtiles` | SQLite-backed profile | Skip or summarize large tile BLOBs by default. |
| 53 | Wave 3 | Candidate | Financial / Banking | OFX / QFX / QIF | `.ofx`, `.qfx`, `.qif` | Finance transaction importer | Broad personal/business finance use. Map accounts and transactions; handle OFX SGML/XML variants; privacy care required. |
| 54 | Wave 3 | Candidate | Financial / Banking | MT940 / MT942 / ISO 20022 CAMT / SEPA | `.mt940`, `.sta`, `.camt`, `.xml` | Bank statement importer | Tag-based text and complex XML; strong fintech/treasury use case. |
| 55 | Wave 3 | Candidate | Financial / Accounting | QuickBooks / Xero / GnuCash / Ledger / Beancount | `.iif`, `.csv`, `.xlsx`, `.gnucash`, `.ledger`, `.beancount` | Accounting importer/profile family | Many exports reuse CSV/XLSX/XML; IIF/ledger formats need section/journal parsers. |
| 56 | Wave 3 | Candidate | Financial / Payments | NACHA ACH and payment processor exports | `.ach`, `.csv`, `.xlsx`, `.json` | Fixed-width plus profile family | ACH is fixed-width; Stripe/PayPal/Square/crypto exports are mostly CSV/JSON profiles. |
| 57 | Wave 3 | Candidate | Financial / Accounting | XBRL / iXBRL / XBRL GL | `.xbrl`, `.xml`, inline HTML | Financial reporting importer | Taxonomy/linkbase handling is complex; report and ledger profiles are distinct. |
| 58 | Wave 3 | Candidate | Financial / Messaging | EDI X12 / EDIFACT | `.edi`, `.x12`, `.edifact` | EDI parser | Segment/loop hierarchy and implementation guides matter. |
| 59 | Wave 3 | Candidate | Financial / Trading | FIX / FIXML logs | `.fix`, `.log`, `.txt`, `.xml` | Structured log/message importer | Tag=value parser for FIX; XML profile for FIXML. |
| 60 | Wave 3 | Candidate | Healthcare | FHIR bundles / NDJSON profiles | `.json`, `.ndjson` | Healthcare JSON/NDJSON profile | Raw JSON can import now, but resource-aware table mapping is future work. |
| 61 | Wave 3 | Candidate | Healthcare | HL7 v2 / C-CDA / CDA | `.hl7`, `.xml` | Healthcare message/document importers | Candidate, but split before implementation. HL7 v2 is first; CDA/C-CDA needs template-aware XML mapping. Synthetic fixtures only. |
| 62 | Wave 3 | Candidate | Healthcare | DICOM metadata | `.dcm`, `.dicom`, `DICOMDIR` | Metadata-only healthcare importer | Metadata-only extraction. Never import pixel data by default; private tags, PHI warnings, dictionary coverage, and de-identification guidance are required. |
| 63 | Wave 3 | Candidate | Healthcare | Clinical terminology and reference datasets | ICD, CPT/HCPCS, NDC, LOINC, SNOMED CT RF2 | Profiles over CSV/TSV/XML | Large reference datasets and vocabulary relationships. |
| 64 | Wave 3 | Candidate | Healthcare | Research and clinical data standards | REDCap, OMOP CDM, CDISC SDTM/ADaM, NCPDP, ASC X12N | Profile families over CSV/SAS/EDI | Domain-specific validation is the hard part. |
| 65 | Wave 3 | Candidate | Email / Communication | MBOX / EML | `.mbox`, `.eml` | Email archive importer | Better first email path than Outlook archives. RFC 2822 parsing; attachment metadata/link-only by default. |
| 66 | Wave 3 | Candidate | Calendar / Contacts | iCalendar / vCard | `.ics`, `.vcf` | Calendar/contact importers | Recurrence, timezones, and multi-value fields need careful mapping. |
| 67 | Wave 3 | Candidate | Security / Logs | CEF / LEEF / auditd / Windows EVTX | `.log`, `.csv`, `.evtx` | Security log importers | CEF/LEEF/auditd are structured text; EVTX likely needs binary/XML parser. |
| 68 | Wave 3 | Candidate | Observability | OpenTelemetry / Prometheus / Splunk / Datadog / New Relic / Loki exports | `.json`, `.jsonl`, `.csv`, OpenMetrics text | Observability profile family | Time-series labels, traces, spans, and metric samples. |
| 69 | Wave 3 | Candidate | Network / IT | PCAP / PCAPNG | `.pcap`, `.pcapng`, `.cap` | Packet summary importer | Packet summary tables only; full protocol dissection is out of initial scope. |
| 70 | Wave 3 | Candidate | Network / IT | Nmap / DNS / NetFlow / BGP outputs | `.xml`, `.gnmap`, `.zone`, `.txt`, binary/CSV flow exports | Network diagnostic importers | XML/text profiles first; binary flow/routing formats require specialized parsers. |
| 71 | Wave 3 | Candidate | Industrial / IoT | Time-series and industrial text exports | OPC-UA exports, SCADA historian CSV, MQTT logs, Modbus dumps, telematics CSV | Profiles over CSV/JSON/logs | Timestamp/tag handling and quality-code metadata. |
| 72 | Wave 3 | Candidate | Industrial / IoT | Engineering/automation formats | CAN DBC/ASC, ADS-B/ACARS, AIS, IFC/BIM | Domain adapters | Candidate family, but split before implementation. CAN DBC/ASC and AIS are practical; ADS-B and IFC need stricter review. |
| 73 | Wave 3 | Candidate | Government / Public Data | Census, ACS, FEC, HMDA, IPEDS, BLS, BEA, FRED, World Bank, IMF, Comtrade | `.csv`, `.xlsx`, fixed-width, `.fec`, API downloads | Public-data profiles | Mostly CSV/XLSX/fixed-width plus codebooks. Strong fit once profiles and fixed-width support exist. |
| 74 | Wave 3 | Candidate | Government / Public Data | Statistical exchange and publication standards | SDMX, DDI, NOAA GRIB/BUFR, USPTO XML, PubMed/MEDLINE XML | Structured/binary public-data profiles | Prioritize with public-sector/research users and fixtures. |
| 75 | Wave 3 | Candidate | Configuration / Dev Tooling | Terraform state/plan, Ansible facts, HCL, Postman/Insomnia/Bruno collections, package metadata, SARIF | `.tfstate`, `.json`, `.yaml`, `.hcl`, `.sarif`, archives | Developer-data profiles | Moved up from Wave 4 because most are profiles over JSON/YAML/archive parsing; SARIF is high-value security results data. |
| 76 | Wave 3 | Candidate | Security / Threat Intel | STIX, CVE/NVD feeds, Nessus/OpenVAS, Sigma, YARA metadata | `.json`, `.xml`, `.nessus`, `.yaml`, `.yar` | Security-data profiles | Moved up from Wave 4 because most are JSON/XML/YAML profiles; YARA/Sigma metadata extraction only. |
| 77 | Wave 4 | Candidate | Publishing / Bibliographic | BibTeX / RIS / MARC / ONIX / Crossref / DataCite | `.bib`, `.ris`, `.mrc`, `.xml`, `.json` | Bibliographic importers | BibTeX/RIS easier; MARC/ONIX specialized. |
| 78 | Wave 4 | Candidate | Media / Metadata | EXIF / IPTC / XMP / ID3 / subtitles / playlists / GEDCOM | images, audio, `.srt`, `.vtt`, `.m3u`, `.ged` | Metadata-only importers | Avoid becoming a media-management app; import metadata, not media content. |
| 79 | Wave 4 | Investigate | Legacy / Mainframe | EBCDIC files and COBOL copybook data | `.dat`, `.cpy` plus binary/fixed-width data | Legacy record-layout importer | Copybook parsing, packed decimals, zoned decimals, and EBCDIC transcoding. |
| 80 | Demand-gated | Candidate | Data Lake | Delta Lake table folders | `_delta_log` plus Parquet files | Table-directory importer | Depends on Parquet first; transaction log replay and time-travel semantics. |
| 81 | Demand-gated | Candidate | Data Lake | Apache Iceberg table metadata | metadata folder plus data files | Table-directory importer | Depends on Parquet/Avro; manifest/catalog handling. |
| 82 | Demand-gated | Candidate | Data Lake | Apache Hudi table folders | `.hoodie` metadata plus data files | Table-directory importer | Depends on Parquet/Avro/ORC; complex table types. |
| 83 | Demand-gated | Investigate | Database / Live Source | Oracle read-only live import | connection-based | Live source import | Important in some enterprise shops; high setup, driver, credential, and support burden. |
| 84 | Demand-gated | Investigate | Database / Live Source | Generic ODBC/JDBC-like import abstraction | connection-based | Live source framework | Risk of becoming database administration scope; only consider for read-only import. |
| 85 | Demand-gated | Candidate | Dump / Backup | Oracle Data Pump / SQL*Loader | `.dmp`, `.ctl` plus data files | External-tool assisted importer | Likely requires Oracle tooling and companion data handling. |
| 86 | Demand-gated | Candidate | Dump / Backup | DB2 IXF / Teradata exports / Cassandra exports / Neo4j CSV bundles | `.ixf`, CSV/JSON/bundles | Enterprise migration importers | Usually dialect-specific tools, companion metadata, or coordinated files. |
| 87 | Demand-gated | Deferred | Analytical / Columnar | ORC | `.orc` | Analytical importer | Lower expected desktop frequency than Parquet; revisit after Parquet/Avro. |
| 88 | Demand-gated | Deferred | Compressed / Archive | 7-Zip wrapper | `.7z` | Archive wrapper | Deferred after investigation. No accepted Dart runtime path exists; external 7-Zip introduces licensing, packaging, and solid-archive safety concerns. |
| 89 | Demand-gated | Deferred | Email / Communication | Outlook PST / OST / MSG | `.pst`, `.ost`, `.msg` | External-conversion assisted importer | Deferred after investigation. Mature paths are GPL-heavy or forensic/conversion-oriented; prefer MBOX/EML first. |
| 90 | Demand-gated | Deferred | Database / Embedded DB | Proprietary desktop databases | FileMaker, Progress OpenEdge, Btrieve/Actian, Lotus Notes NSF, Paradox | External-conversion assisted importer | Vendor tools or drivers usually required; only schedule with representative files and users. |
| 91 | Demand-gated | Deferred | Data Science / Statistics | JMP / Minitab / EViews | `.jmp`, `.mtw`, `.mpj`, `.wf1` | Statistical importer | Concentrated niches; defer until clear demand. |

## 2026-05-23 Full-Table Reprioritization

This review happened after the Wave 2 and Wave 3 investigation passes. The
table above is the current source of truth for target waves and priority order.
The investigation sections below explain the dependency and scope reasoning, but
some target waves changed during this full-table pass.

Main adjustments:

- The completed Wave 1 implementation has been removed from the Backlog table
  and is documented in the in-app help page instead:
  - clipboard table paste,
  - fixed-width text,
  - JSON log stream workflow,
  - common web/app log templates,
  - Markdown tables,
  - SpreadsheetML,
  - XZ wrapper,
  - ODS,
  - PostgreSQL plain dump expansion,
  - HAR.
- Parquet moved from `Planned` to `Investigate` under ADR-0054 because the
  reader/runtime path, logical type mapping, packaging, and streaming behavior
  need a separate accepted implementation decision.
- DuckDB moved from `Planned` to `Candidate` until the native/worker packaging
  decision is accepted.
- PostgreSQL, MariaDB/MySQL, and SQL Server read-only live imports moved from
  `Planned` to `Candidate` and from Wave 2 to Wave 3 because secure
  credentials, connection lifecycle, and driver packaging are larger product
  surfaces than file import.
- Common web/app log templates and HAR moved into Wave 1 because they are
  high-value developer workflows that can reuse existing structured text/JSON
  paths.
- GeoJSON, GeoPackage, and Shapefile moved into Wave 2 because geospatial import
  has broad user value and clear next steps once spatial type policy and DBF
  support are ready.
- Configuration/dev-tooling and security/threat-intel profiles moved from
  Wave 4 to Wave 3 because most are profiles over existing JSON, YAML, XML, or
  archive parsing rather than entirely new parser engines.
- Direct Outlook PST/OST/MSG and 7-Zip remain demand-gated deferred items after
  investigation because the likely runtime paths are not compatible with a
  clean bundled implementation yet.

## Wave 2 Investigation Results

This section records the 2026-05-23 investigation pass for Wave 2 entries that
were previously marked `Investigate`. These findings do not make a format
supported. They only clarify whether a format is ready to plan, should remain
under investigation, or should be deferred.

### Summary

| Item | Result | Updated Backlog Status | Main Reason |
|---|---|---|---|
| Microsoft Access | Keep under investigation | `Investigate` | There are promising Apache-compatible Java readers, but shipping an Access importer means accepting a JVM/worker packaging strategy and reviewing a non-trivial dependency tree. |
| DBF / FoxPro plus memo files | Promote to candidate | `Candidate` | Core DBF table import is feasible, but full FoxPro/memo/code-page behavior still needs scope control and fixtures. |
| Markdown tables | Implemented in Wave 1 | Complete; removed from Backlog | Low-risk adapter over deterministic text fixtures; dependency path already exists through the app's help Markdown stack. |
| YAML structured records | Promote to candidate | `Candidate` | Parser path exists, but the product boundary must reject arbitrary non-tabular config files cleanly. |
| XZ wrapper | Implemented in Wave 1 | Complete; removed from Backlog | Existing archive/tar wrapper patterns can support it, but large-file extraction must avoid full in-memory decode. |
| 7-Zip wrapper | Defer | `Deferred` | Runtime extraction would require a new dependency or external tool with licensing, packaging, and solid-archive safety concerns. |
| Apache Arrow IPC | Keep under investigation | `Investigate` | Strategically useful, but it should not become a required payload/runtime dependency until the worker-backed import path is proven. |
| Feather | Keep under investigation | `Investigate` | Feather v2 is effectively an Arrow IPC profile, so it depends on the Arrow decision. |
| SpreadsheetML / Excel XML Spreadsheet | Implemented in Wave 1 | Complete; removed from Backlog | Existing XML parser is enough for a strict SpreadsheetML adapter, provided signature detection prevents conflict with generic XML import. |

### Microsoft Access (`.mdb`, `.accdb`)

Access remains valuable because many small businesses, schools, local agencies,
and legacy departmental systems still exchange `.mdb` or `.accdb` files. It
should not be dismissed, but it is not ready for straightforward Dart-native
implementation.

Findings:

- Jackcess is a pure Java Microsoft Access library with Apache 2.0 licensing
  and broad Access version coverage.
- UCanAccess is a Java JDBC driver built on Jackcess. Current upstream
  documentation says versions from 3.0.0 onward are Apache 2.0, but older
  releases were LGPL 2.1, so the exact version and dependency tree must be
  pinned and reviewed before use.
- MDBTools is useful for compatibility comparison and `.mdb` export research,
  but its project has LGPL libraries and GPL utilities. That makes it a poor
  default bundled runtime dependency for a desktop app unless a specific ADR
  accepts the license and packaging consequences.
- Host ODBC drivers should not be the primary strategy. They create platform
  setup differences, bitness issues, and a poor first-run import experience.

Recommended implementation shape:

- Use a built-in worker-backed adapter only after ADR-0051 is proven by a
  simpler worker module.
- Prefer a reviewed Java worker path using Jackcess or UCanAccess over ODBC.
- Keep DecentDB writing inside the app. The worker should only emit schemas,
  typed previews, warnings, and typed batches.
- Start with table data, columns, primary keys, indexes, and relationships.
  Access forms, reports, macros, modules, saved queries, and VBA are metadata
  only or explicitly out of scope for the first importer.
- Handle Access-specific types deliberately: `YESNO`, `BYTE`, `INTEGER`,
  `LONG`, `SINGLE`, `DOUBLE`, `NUMERIC`, `CURRENCY`, `COUNTER`, `TEXT`, `OLE`,
  `MEMO`, `GUID`, and `DATETIME`.

Required gates before implementation:

- Create an Access import ADR that chooses the Java worker, rejects ODBC as the
  default path, and documents `.mdb`/`.accdb` coverage.
- Complete license review for the exact Jackcess/UCanAccess artifact set and
  update `THIRD_PARTY_NOTICES.md` if accepted.
- Document Java/JVM packaging for Linux, macOS, and Windows or choose a
  bundled worker distribution that avoids a host Java requirement.
- Build Dockerized fixture generation using a pinned Java/Maven image so the
  repository does not require Microsoft Access, MDBTools, LibreOffice, or Java
  installed on the developer host.

### DBF / FoxPro Plus Memo Files (`.dbf`, `.fpt`, `.dbt`)

DBF is a good candidate because it is an old but still recurring interchange
format. It also appears as the attribute table in Shapefile bundles, which makes
it valuable even before full spatial import exists.

Findings:

- A BSD-3-Clause Dart `dbf_reader` package exists, but it has very low adoption.
  Do not add it automatically. Evaluate it against fixtures or write a small
  in-repo parser for the subset Decent Bench intends to support.
- Core DBF table reading is much more tractable than full FoxPro behavior.
- Memo files are a distinct second layer: `.dbt` and `.fpt` need linkage,
  missing-file warnings, corruption handling, and type mapping.
- Code pages and deleted rows are product decisions, not just parser details.

Recommended implementation shape:

- Start with dBase III/IV-style `.dbf` table import without memo fields.
- Expose deleted-row behavior as an import option with a conservative default
  of excluding deleted rows while reporting how many were skipped.
- Preserve field names, source field type codes, field widths, decimal counts,
  and source code-page metadata in provenance.
- Add memo-file support only after core DBF works and fixtures cover `.dbt` and
  `.fpt` variants.
- Keep Shapefile bundle import separate. DBF support should make Shapefile
  easier later, but it should not pull geometry parsing into this item.

Required gates before implementation:

- If using a dependency, perform license, maintenance, streaming, and fixture
  review first.
- Add checked-in fixtures for numeric, logical, date, character, deleted-row,
  null/blank, code-page, and malformed-header cases.
- Use Dockerized GDAL/OGR, LibreOffice, or a pinned Python image only for
  generating fixtures. Normal unit tests must use checked-in files.

### Markdown Tables (`.md`)

Markdown table import was completed in the Wave 1 import expansion and removed
from the Backlog table. It is useful for developer workflows, README data
tables, exported reports, and copied web/documentation data.

Implementation scope:

- Import pipe tables only.
- Ignore prose, headings, lists, code fences, and non-table Markdown blocks.
- Detect multiple tables and let the user pick one or import each table as a
  separate target table.
- Require a header row and separator row for automatic table detection.
- Preserve source row numbers for warnings.
- Treat alignment markers as metadata only.
- Route the extracted rows through the same type inference and transform flow as
  delimited text.

Required parser behavior:

- Handle leading/trailing pipes.
- Handle escaped pipes inside cell text.
- Do not parse tables inside fenced code blocks.
- Warn on ragged rows and use the same malformed-row policy as delimited text.
- Reject documents with no table using a clear "no Markdown tables found"
  message.

Dependency and ADR position:

- The app already uses Markdown rendering for Help, and the resolved dependency
  graph includes the Dart `markdown` package.
- If implementation imports `package:markdown` directly, add it as an explicit
  direct dependency and update third-party notices as needed.
- No ADR is required if the adapter reuses existing dependency families and
  follows the generic import contract.

Testing:

- Use text fixtures only.
- Include multiple tables, escaped pipes, code fences, ragged rows, empty cells,
  alignment markers, and a no-table document.

### YAML Structured Records (`.yaml`, `.yml`)

YAML import is feasible, but the app must avoid implying that every YAML file is
meaningful tabular data. Most YAML files are configuration documents, not record
sets.

Accepted data shapes for a future importer:

- Top-level list of maps:
  `[{name: Alice, amount: 10}, {name: Bob, amount: 12}]`
- Top-level map of records:
  `{customer_1: {name: Alice}, customer_2: {name: Bob}}`
- A user-selected list path inside a larger YAML document, if the preview can
  identify candidate record collections safely.

Rejected or warning-only data shapes:

- Scalar-only documents.
- Deep arbitrary configuration trees with no repeated record shape.
- Mixed lists where most items are not maps.
- Anchors, aliases, merge keys, and custom YAML tags that cannot be resolved
  safely into plain import values.

Recommended implementation shape:

- Normalize YAML through the same structured-document flatten/normalize policy
  used by JSON and XML after a valid record collection is selected.
- Do not execute or interpret custom tags.
- Preserve the selected YAML path in provenance.
- Show a clear "YAML was parsed, but no tabular record set was found" result
  when the document is valid YAML but not importable.

Dependency and ADR position:

- The resolved dependency graph already includes the Dart `yaml` package, which
  is MIT licensed.
- If implementation imports `package:yaml` directly, add it as a direct
  dependency and update third-party notices as needed.
- No ADR is required if YAML stays a structured-document adapter and does not
  introduce custom tag execution or new transform semantics.

Testing:

- Use deterministic text fixtures only.
- Cover top-level lists, map-of-records, nested selected lists, invalid YAML,
  scalar YAML, config-shaped YAML, anchors/aliases, mixed lists, and large-file
  preview limits.

### XZ Wrapper (`.xz`, `.tar.xz`)

XZ wrapper import was completed in the Wave 1 import expansion and removed from
the Backlog table. It fits the existing archive wrapper model; the main risk
remains memory behavior for huge single-file `.xz` payloads.

Findings:

- The current `archive` package dependency exposes XZ decoding, but the decoded
  output is accumulated in memory.
- ADR-0026 already chose system `tar` for `.tar.gz` and `.tar.bz2` because
  large tar archives must not be fully loaded into memory.
- Most desktop platforms provide a `tar` command capable of handling `.tar.xz`
  through `-J`, but the implementation must report a clear error when system
  support is missing.

Recommended implementation shape:

- Add `.tar.xz` and `.txz` detection to the existing tar wrapper path using
  system `tar` list/extract commands.
- Add single-file `.xz` only with an explicit size policy, cancellation policy,
  and warning that huge single-file decompression may not be supported until a
  streaming decoder exists.
- Preserve the archive-candidate workflow used by ZIP/GZip/BZip2 wrappers.
- Treat `.xz` as a wrapper, not as a standalone data format.

ADR position:

- No new ADR is required if implementation extends ADR-0026's system `tar`
  wrapper approach.
- Update ADR-0026 or add a short superseding ADR only if implementation uses a
  new external tool, changes wrapper UX, or accepts non-streaming large-file
  behavior.

Testing:

- Generate `.xz`, `.tar.xz`, and `.txz` fixtures with a pinned Docker image
  containing `xz-utils`.
- Keep small checked-in fixtures for normal tests.
- Cover missing `tar`/unsupported `-J`, archive with no importable entries,
  extensionless tar entries, cancellation, corrupt XZ stream, and path traversal
  attempts inside tar entries.

### 7-Zip Wrapper (`.7z`)

7-Zip should move to deferred status. It is common enough to keep in mind, but
not a good native import target right now.

Findings:

- The current Dart `archive` dependency does not provide a release-ready 7-Zip
  decoder path for Decent Bench.
- The official 7-Zip distribution uses LGPL as its main license with additional
  unRAR restriction language for some code. That may be acceptable in some
  distributions, but it needs explicit review before bundling.
- Depending on a host `7z` executable would create platform setup and support
  issues similar to host ODBC drivers.
- Solid archives complicate bounded extraction, progress, cancellation, and
  preview because extracting one member may require scanning substantial archive
  content.

Revisit only if one of these becomes true:

- A maintained, compatible Dart/Rust/native library gives bounded extraction
  and clear license terms.
- Users bring strong demand and representative `.7z` files.
- A broader archive-worker ADR accepts bundling an extraction runtime.

Testing if revisited:

- Use Dockerized `7z`/`p7zip` only for fixture generation and compatibility
  research.
- Include solid archives, encrypted archives, nested paths, empty archives,
  unsupported compression methods, path traversal attempts, and huge-member
  cancellation cases.

### Apache Arrow IPC (`.arrow`, `.ipc`)

Arrow IPC remains under investigation. It is strategically important, but it
should not be rushed into the runtime path.

Findings:

- Apache Arrow defines a random-access IPC file format with `ARROW1` magic and
  record batches. The same file format is also used by Feather V2.
- Arrow can preserve richer logical types than CSV/JSON and would be a strong
  internal or external typed-batch format in the future.
- ADR-0051 intentionally rejected requiring Arrow IPC for the first worker
  protocol until dependency and license review proves a stable cross-platform
  path.
- Dart-native Arrow support remains the key uncertainty. Worker-backed Python,
  Rust, or C++ support is plausible, but each introduces packaging and runtime
  costs.

Recommended implementation shape:

- Do not make Arrow IPC a prerequisite for Wave 1 planned formats.
- Revisit after the first worker-backed import module proves the packaging,
  cancellation, fixture, and typed-batch workflow.
- If Arrow becomes a source importer, it should emit Decent Bench typed batches
  through ADR-0051 first, not write directly into DecentDB.
- If Arrow becomes an internal payload format, update ADR-0051 before using it
  across worker boundaries.

Required gates:

- Create or update an ADR choosing a Dart-native, Python, Rust, or C++ Arrow
  path.
- Review exact dependency licenses and binary packaging for Linux, macOS, and
  Windows.
- Define mapping for nullable values, dictionary encoding, timestamps with time
  zones, decimals, binary values, nested structs/lists, extension types, and
  metadata.

Testing:

- Generate fixtures with a pinned Python `pyarrow` image.
- Cover IPC file and stream variants, multiple record batches, dictionary
  batches, nullable values, timestamps, decimals, binary values, nested values,
  unsupported extension types, corrupt footer, and cancellation.

### Feather (`.feather`)

Feather remains under investigation because modern Feather is coupled to Arrow
IPC.

Findings:

- Feather V2 files are Arrow IPC files with the `.feather` extension.
- Older Feather V1 exists and may appear in legacy Python/R workflows, but it
  should not drive the initial implementation.

Recommended implementation shape:

- Treat Feather V2 as an Arrow IPC profile once Arrow IPC is accepted.
- Detect `.feather` separately for user-facing clarity, but route through the
  Arrow adapter internally.
- For Feather V1, either reject with a clear message or convert through a
  worker-backed Arrow library that can read it.

Required gates:

- Same gates as Arrow IPC.
- Add dedicated fixtures from Python and R ecosystems if demand appears.

### SpreadsheetML / Excel XML Spreadsheet (`.xml`)

SpreadsheetML import was completed in the Wave 1 import expansion and removed
from the Backlog table. It uses existing XML infrastructure with strict
signature detection before generic XML routing.

Findings:

- Excel XML Spreadsheet files are XML documents, but they are not generic XML
  record documents.
- The adapter must detect SpreadsheetML signatures before generic XML import
  routing. Otherwise `.xml` files will be ambiguous.
- Basic worksheet/table/row/cell/value extraction is achievable with the
  existing XML parser dependency.

Recommended implementation shape:

- Detect the Microsoft Office SpreadsheetML namespace and workbook structure
  before selecting this adapter.
- Support workbook, worksheet, table, row, cell, and data elements.
- Use worksheet names as default table names.
- Treat formulas as metadata unless a cached scalar value exists.
- Preserve source cell type metadata where available.
- Reuse the spreadsheet import preview, target naming, type inference, and
  transform flow.

Explicit non-goals for the first implementation:

- Do not parse arbitrary XML as SpreadsheetML.
- Do not implement all Excel formatting semantics.
- Do not evaluate formulas.
- Do not treat SpreadsheetML as a replacement for `.xlsx`/`.xls` support.

Testing:

- Use hand-authored XML fixtures for deterministic coverage.
- Add exported real-world samples only if they are license-clean and small.
- Cover multiple worksheets, sparse rows, explicit cell indexes, text, numbers,
  dates, booleans, formulas with cached values, invalid XML, and generic XML
  files that must not be detected as SpreadsheetML.

## Wave 3 Investigation Results

This section records the 2026-05-23 investigation pass for Wave 3 entries that
were previously marked `Investigate`. These findings do not make a format
supported. They clarify which entries are credible backlog candidates, which
need to be split before implementation, and which should be deferred.

### Summary

| Item | Result | Updated Backlog Status | Main Reason |
|---|---|---|---|
| Stata | Promote to candidate | `Candidate` | A shared statistical-file worker can cover Stata, SPSS, and SAS transport with strong type/metadata preservation. |
| SPSS | Promote to candidate | `Candidate` | Same statistical-worker path; preserve labels, user-missing values, and encoding metadata. |
| SAS transport | Promote to candidate | `Candidate` | Same statistical-worker path; XPORT is common in regulated/research data exchange. |
| Lab and domain instrument formats | Promote to candidate family | `Candidate` | Several text or Python-readable formats are tractable, but the row must be split before implementation. |
| Shapefile bundle | Promote to candidate | `Candidate` | High geospatial value, but depends on DBF support, spatial type mapping, and multi-file bundle handling. |
| GeoPackage | Promote to candidate | `Candidate` | Strong fit because it is SQLite-backed; feature tables can build on SQLite import with spatial metadata handling. |
| HL7 v2 / C-CDA / CDA | Promote to candidate | `Candidate` | HL7 v2 is practical; CDA/C-CDA is XML but template-heavy. Healthcare privacy warnings are mandatory. |
| DICOM metadata | Promote to candidate | `Candidate` | Metadata-only extraction is feasible; pixel data and PHI handling must be out of default scope. |
| Outlook PST / OST / MSG | Defer | `Deferred` | Mature parser/conversion paths are GPL-heavy or forensic-tool oriented; MBOX/EML should come first. |
| Engineering / automation formats | Promote to candidate family | `Candidate` | CAN DBC/ASC and AIS are practical; ADS-B and IFC need stricter dependency and scope review. |

### Statistical Dataset Family: Stata, SPSS, SAS Transport

Stata (`.dta`), SPSS (`.sav`, `.zsav`), and SAS transport (`.xpt`) should be
treated as one statistical dataset import family. Implementing them separately
would duplicate dependency review, worker packaging, type mapping, and metadata
preservation work.

Findings:

- ReadStat is a mature C library and command-line tool for SAS, Stata, and SPSS
  files with MIT licensing.
- `pyreadstat` wraps ReadStat, is Apache 2.0 licensed, and can read/write common
  Stata, SPSS, and SAS transport files.
- The statistical formats carry user-facing metadata that CSV cannot preserve:
  variable labels, value labels, display formats, encodings, missing-value
  semantics, and sometimes survey-oriented metadata.
- The right product value is not merely "convert rows." Users importing these
  files expect Decent Bench to retain labels and provenance so the imported
  DecentDB data remains interpretable.

Recommended implementation shape:

- Create a shared `statistical_dataset` worker-backed adapter family rather
  than three unrelated parser paths.
- Use one worker contract and module option set for Stata, SPSS, SAS transport,
  and eventually SAS native `.sas7bdat` if accepted later.
- Emit one primary table per source dataset.
- Preserve statistical metadata in Decent Bench import provenance and, where
  useful, optional sidecar metadata tables:
  - variable labels,
  - value label dictionaries,
  - display formats,
  - source encoding,
  - source file version,
  - user/system missing-value metadata,
  - original source column order.
- Do not silently rewrite labeled categorical values into display text. Default
  behavior should preserve the stored value and attach labels as metadata; users
  can opt into label expansion later.
- Keep row parsing in the worker and DecentDB writes inside the app-owned import
  writer.

Required ADR:

- Create a statistical dataset import worker ADR before implementation. It must
  choose the dependency path, define the metadata preservation contract, define
  how labels are stored, and document packaging for Linux, macOS, and Windows.
- If the implementation uses `pyreadstat`, the ADR must cover Python runtime
  packaging, native wheel availability, startup overhead, cancellation, and
  third-party notices.

Docker fixture strategy:

- Use a pinned Python image with `pyreadstat` to generate `.dta`, `.sav`,
  `.zsav`, and `.xpt` fixtures.
- Optionally use a pinned R image with `haven` only for cross-validation.
- Normal tests must use checked-in fixtures and must not require Python, R,
  Stata, SPSS, SAS, or Docker.

Shared testing requirements:

- Empty file, corrupt header, unsupported version, and wrong-extension tests.
- Preview limit tests that prove large files do not materialize all rows.
- Labels and value-label round-trip tests.
- Encoding tests with non-ASCII text.
- Null, system missing, and user missing tests.
- Date, time, datetime, numeric precision, boolean/logical, and categorical
  mapping tests.
- Wide table and long text tests.
- Cancellation tests for large generated fixtures.

#### Stata (`.dta`)

Stata should be a candidate under the statistical dataset family.

Implementation-specific scope:

- Cover common modern `.dta` versions first.
- Preserve variable labels and value labels.
- Preserve Stata display formats.
- Preserve Stata missing semantics, including extended missing values where the
  parser exposes them.
- Warn when a source Stata feature cannot be preserved exactly.
- Preserve original variable names and a sanitized DecentDB column name mapping.

Explicit non-goals for the first implementation:

- Do not execute Stata `.do` files.
- Do not import Stata graphs, logs, or project files.
- Do not require Stata to be installed.

#### SPSS (`.sav`, `.zsav`)

SPSS should be a candidate under the same statistical dataset worker.

Implementation-specific scope:

- Cover `.sav` and `.zsav` when the chosen dependency supports them.
- Preserve variable labels, value labels, user missing values, and encoding.
- Preserve multiple-response metadata if exposed by the parser, but do not block
  initial support on rendering specialized survey UI.
- Warn when compressed or encrypted variants cannot be read.

Explicit non-goals for the first implementation:

- Do not import SPSS syntax files.
- Do not import SPSS output viewer files.
- Do not require SPSS to be installed.

#### SAS Transport (`.xpt`)

SAS transport should be a candidate under the statistical dataset worker.

Implementation-specific scope:

- Prioritize XPORT v5 and v8 fixtures because they are common in regulated
  exchange workflows.
- Preserve labels, formats, field order, source dataset name, and source member
  metadata where available.
- Convert SAS dates/times/datetimes with explicit warnings about timezone and
  epoch behavior.
- Warn on source name truncation or legacy field-name limitations.

Explicit non-goals for the first implementation:

- Do not require SAS to be installed.
- Do not execute SAS programs.
- Do not promise full SAS catalog support.

### Lab And Domain Instrument Format Family

The "lab and domain instrument formats" row is useful as a backlog placeholder,
but it is too broad to implement as one feature. It should remain a candidate
family and be split into smaller format-specific work before coding.

Recommended split:

| Sub-format | Recommendation | Reason |
|---|---|---|
| LAS well logs (`.las`) | Candidate | Text-oriented, tabular curve data plus metadata; feasible with a small parser or reviewed Python reader. |
| CIF (`.cif`) | Candidate | CIF loops map naturally to tables; Gemmi provides a strong parser path if a worker is accepted. |
| SDF/MOL (`.sdf`, `.mol`) | Candidate | SDF records expose molecule properties as tabular metadata; RDKit is BSD licensed but packaging is non-trivial. |
| PDB (`.pdb`) | Candidate | Fixed-column ATOM/HETATM records and metadata tables are feasible; scientific semantics should remain limited. |
| ASDF (`.asdf`) | Candidate | Python implementation is BSD-3-Clause and metadata/tree extraction can be useful, but binary array policy is needed. |
| TDMS (`.tdms`) | Keep investigating | Common in LabVIEW/test measurement, but the obvious Python reader path uses LGPL/GPL licensing. |
| ROOT (`.root`) | Keep investigating / demand-gated | Valuable in high-energy physics, but the data model and dependency choices are heavy; only flat TTree extraction should be considered first. |

Implementation principles:

- Do not build a single "scientific files" adapter that tries to handle all of
  these at once.
- Each accepted sub-format needs its own module row, fixtures, type mapping,
  user documentation, and dependency review.
- Prioritize formats with clear table shape:
  LAS curves, CIF loops, SDF property blocks, PDB ATOM/HETATM rows, and ASDF
  metadata trees.
- Treat large arrays, images, spectra, and arbitrary object graphs as metadata
  summaries until a separate array/raster import policy exists.
- Use worker-backed adapters only when the dependency ecosystem is clearly
  better outside Dart.

Required ADRs:

- Add a worker-backed scientific/domain-file ADR before accepting any Python or
  native scientific parser as a bundled runtime dependency.
- TDMS specifically needs an ADR or explicit rejection if the only viable
  dependency remains LGPL/GPL.
- ROOT needs an ADR if Decent Bench ever bundles a ROOT/uproot-based reader,
  because the data model can quickly exceed tabular import scope.

Docker fixture strategy:

- Use pinned Python images for fixture generation and independent validation:
  - `lasio` for LAS well-log fixtures,
  - `gemmi` for CIF fixtures,
  - `rdkit` for SDF/MOL fixtures,
  - `asdf` for ASDF fixtures,
  - candidate TDMS/ROOT tooling only for investigation until dependencies are
    accepted.
- Normal tests must use checked-in tiny fixtures.

Testing requirements:

- Format detection tests for each sub-format once it receives a module.
- Valid tiny fixture, malformed fixture, unsupported-version fixture, and
  wrong-extension fixture.
- Metadata preservation tests.
- Multi-table extraction tests where a file naturally contains multiple record
  collections.
- Large-file preview and cancellation tests for any array/channel/record stream.

### Shapefile Bundle (`.shp`, `.shx`, `.dbf`, `.prj`)

Shapefile should move to candidate status. It is still common in GIS,
government, real estate, logistics, public-data portals, and environmental
workflows, but it must be treated as a multi-file bundle rather than a single
file.

Findings:

- GDAL's Shapefile driver is built in by default, supports reading and writing,
  treats a directory of sidecar files as a dataset, and can also handle
  standalone DBF files.
- Shapefile attributes live in a DBF file, so DBF import is a prerequisite for
  a high-confidence native implementation.
- Shapefile geometry has constraints and edge cases that matter:
  - one geometry type per layer,
  - optional measured coordinates,
  - `.prj` coordinate reference metadata,
  - code-page metadata through `.cpg` or DBF header values,
  - practical size limits around large `.shp`/`.dbf` files.

Recommended implementation shape:

- Treat `.shp`, `.shx`, `.dbf`, `.prj`, `.cpg`, and zipped shapefile bundles as
  one import source.
- Require the app to locate sidecar files before preview.
- Use layer name as the default table name.
- Import one row per feature.
- Preserve attributes as normal DecentDB columns.
- Store geometry in the DecentDB spatial type if available and accepted by the
  spatial type policy; otherwise store WKB/WKT plus metadata.
- Preserve CRS/projection metadata from `.prj` and source encoding metadata
  from `.cpg`/DBF.
- Warn when required sidecars are missing.
- Warn on mixed or unsupported geometry types.

Required gates:

- Complete DBF core support first or choose a Shapefile worker that handles DBF
  internally.
- Create or update a spatial import ADR covering geometry storage, CRS metadata,
  WKT/WKB fallback behavior, invalid geometry warnings, and map-preview scope.
- Decide whether GDAL is only a fixture/validation tool or a bundled worker
  dependency. Bundling GDAL requires a major ADR and packaging plan.

Docker fixture strategy:

- Use a pinned GDAL/OGR image to generate and validate fixtures with `ogr2ogr`
  and `ogrinfo`.
- Include points, lines, polygons, null geometries, `.prj`, `.cpg`, zipped
  bundles, and missing-sidecar cases.
- Keep tiny checked-in fixtures for normal tests.

### GeoPackage (`.gpkg`)

GeoPackage should move to candidate status. It is one of the best geospatial
fits for Decent Bench because it is a SQLite-backed single-file container.

Findings:

- GDAL's GeoPackage vector driver is available and validates GeoPackage files.
- A GeoPackage is SQLite-based, so the current SQLite import path can provide
  low-level table access.
- The product value requires more than raw SQLite import: Decent Bench should
  understand GeoPackage metadata tables and feature-table geometry columns.

Recommended implementation shape:

- Detect GeoPackage by SQLite header plus GeoPackage metadata tables, not just
  `.gpkg` extension.
- Reuse SQLite inspection and table selection where possible.
- Identify feature tables through GeoPackage metadata.
- Import feature tables first.
- Skip, summarize, or require explicit opt-in for tile/raster BLOB tables until
  a raster/tile import policy exists.
- Preserve:
  - `gpkg_contents`,
  - `gpkg_geometry_columns`,
  - spatial reference metadata,
  - geometry column type,
  - source table names,
  - source row identifiers.
- Store geometry using the same policy chosen for Shapefile and GeoJSON.

Required gates:

- Create or update a spatial import ADR before implementation if no accepted
  geometry/CRS policy exists.
- Decide whether GeoPackage is a profile over the SQLite adapter or a distinct
  geospatial adapter. The preferred first implementation is a distinct module
  that reuses SQLite internals but presents geospatial defaults.

Docker fixture strategy:

- Use a pinned GDAL/OGR image to generate feature-only GeoPackages and
  tile/raster-containing GeoPackages.
- Validate fixtures with `ogrinfo` and `gpkg validate` where available.
- Keep tiny checked-in fixtures for normal tests.

### Healthcare Message And Metadata Family

HL7 v2, CDA/C-CDA, and DICOM metadata should stay grouped at the roadmap level
but must be split before implementation. Healthcare importers require extra
privacy language even though Decent Bench remains local-first.

Shared healthcare rules:

- Use synthetic fixtures only.
- Do not check in real patient data, medical images, or production messages.
- Add user-facing warnings that healthcare files may contain PHI.
- Do not promise HIPAA compliance, GDPR compliance, de-identification, or
  clinical validation.
- Importers must be local-only and must not call remote terminology or
  validation services.
- Keep raw source values available in provenance where practical, because
  healthcare message semantics can be profile-specific.

#### HL7 v2 (`.hl7`)

HL7 v2 should be a candidate, with HL7 v2 messages as the first healthcare
message slice.

Findings:

- HL7 v2 is pipe-delimited but hierarchical: messages, segments, fields,
  repetitions, components, and subcomponents.
- MIT and Apache-friendly parser options exist in Python and Java ecosystems,
  but a simple first adapter can also parse ER7 text directly if it does not
  attempt full conformance validation.
- The most useful first import shape is often normalized, not wide:
  messages, segments, fields, and selected common segment tables.

Recommended implementation shape:

- Start with ER7 file import, not MLLP live connections.
- Import one or more messages per file.
- Preserve message control id, timestamp, message type, version, segment order,
  raw segment text, and parsed fields.
- Provide two initial output shapes:
  - normalized message/segment/field tables,
  - optional common profile tables for MSH, PID, PV1, ORC, OBR, OBX when
    detected.
- Warn on malformed segments and continue when possible.

Explicit non-goals:

- No live HL7 listener.
- No MLLP server/client.
- No clinical validation.
- No remote terminology lookup.

#### CDA / C-CDA (`.xml`)

CDA/C-CDA should remain candidate-level but not first in the healthcare family.

Findings:

- CDA/C-CDA documents are XML, but generic XML flattening is not enough.
- Useful import requires template-aware extraction for document header,
  patient, author, encounter, sections, entries, codes, and references.
- C-CDA validation commonly uses schemas, Schematron, implementation guides,
  and value sets. Decent Bench should not promise full conformance validation in
  the first import pass.

Recommended implementation shape:

- Detect CDA/C-CDA by namespace/template signatures before generic XML import.
- Extract document metadata and section/entry tables.
- Preserve raw XML path/source identifiers for traceability.
- Warn when a document is valid XML but not recognized as CDA/C-CDA.

#### DICOM Metadata (`.dcm`, `.dicom`, `DICOMDIR`)

DICOM metadata should be a candidate. It is useful for audit, research,
inventory, de-identification planning, and study/series discovery, but pixel
data should remain out of default scope.

Findings:

- `pydicom` is MIT licensed and can read DICOM datasets.
- DICOM files may contain PHI in standard tags, private tags, burned-in image
  flags, free text, and nested sequences.
- Importing pixel data would move Decent Bench toward image/raster processing,
  which is outside the first metadata importer.

Recommended implementation shape:

- Metadata-only import by default.
- Skip Pixel Data and large binary elements.
- Import one row per instance plus optional normalized tables for:
  - study,
  - series,
  - instance,
  - tags,
  - sequences,
  - private tags if explicitly enabled.
- Preserve tag number, VR, keyword, display name, value preview, source path,
  and whether a value was omitted/truncated.
- Read `DICOMDIR` as an index/manifest when present.
- Add clear PHI warnings and avoid claiming de-identification.

Required ADR:

- Add a healthcare import privacy/scope ADR before implementing HL7, CDA/C-CDA,
  or DICOM. It should define PHI warnings, synthetic fixture policy, no remote
  validation, and the non-goal of clinical/compliance certification.

Docker fixture strategy:

- Use pinned Python images with `hl7apy` and `pydicom` for fixture generation.
- Fixtures must be synthetic and small.
- Normal tests use checked-in synthetic files only.

### Outlook PST / OST / MSG (`.pst`, `.ost`, `.msg`)

Direct Outlook archive/message import should move to deferred status.

Findings:

- Mature PST/OST tooling exists, but common paths are forensic/conversion
  focused and often GPL-heavy.
- `libpst` is GPL-2.0 and is best treated as an external conversion tool, not a
  bundled runtime dependency.
- `extract-msg` is GPL-2.0-only, so it is not an attractive bundled parser for
  Decent Bench's distribution goals.
- PST/OST archives can be huge, corrupt, encrypted, or legally sensitive.
- Email import already has a cleaner path through MBOX/EML candidates.

Recommended product position:

- Defer direct PST/OST/MSG support.
- Implement MBOX/EML first if email import becomes a priority.
- Document Outlook archives as external-conversion-assisted only until a
  permissive, maintainable parser path appears.
- Revisit `.msg` separately only if users provide strong demand and a compatible
  parser path; it should not be blocked by full PST/OST archive support.

Revisit gates:

- Representative user files.
- A permissive dependency or accepted external conversion ADR.
- Security review for attachments, embedded messages, path traversal,
  compressed bodies, and malformed/corrupt archives.
- Privacy guidance for email bodies, attachments, contacts, calendar entries,
  and legal/e-discovery workflows.

Docker fixture strategy:

- Use libpff/libpst containers only for research and conversion experiments.
- Do not make Docker, Outlook, libpst, libpff, or host converter tools a runtime
  requirement unless an ADR explicitly accepts that trade-off.

### Engineering And Automation Format Family

The engineering/automation row should become a candidate family, but it is too
broad to implement as one item. It should be split into smaller adapters before
coding.

Recommended split:

| Sub-format | Recommendation | Reason |
|---|---|---|
| CAN DBC (`.dbc`) | Candidate | Text-based signal dictionary; `cantools` is MIT licensed and widely used. |
| CAN ASC logs (`.asc`) | Candidate | Text log format that can be parsed into timestamped frames; DBC decoding can be optional. |
| AIS (`AIVDM`/`AIVDO`, CSV/log) | Candidate | `pyais` has an MIT-licensed path and AIS messages map to vessel/time/position tables. |
| ADS-B / Mode-S | Keep investigating | Useful, but common Python decoder paths include GPL licensing; permissive alternatives must be reviewed. |
| ACARS | Keep investigating | Message formats and source logs vary; needs concrete fixtures and domain scope. |
| IFC/BIM (`.ifc`, `.ifczip`) | Demand-gated / deferred for full import | IfcOpenShell is powerful but LGPL/GPL-heavy, and full BIM import is a large object graph, not a simple tabular source. |

Implementation principles:

- Do not implement a single "engineering automation" adapter.
- Prioritize text/log formats with clear row shapes:
  - DBC message/signal definitions,
  - ASC timestamped CAN frames,
  - decoded AIS position/message tables.
- Treat packet/radio decoding as out of scope unless users provide already
  captured text/CSV/log files.
- For IFC, start only with metadata/property extraction if demand is strong.
  Geometry import, 3D meshes, and BIM validation are out of scope unless a
  separate Future Win accepts them.

Required ADRs:

- CAN/AIS text adapters may not need ADRs if they use no new major dependency
  and follow generic structured-text import rules.
- ADS-B decoder support needs dependency/license ADR if the best parser remains
  GPL.
- IFC requires an ADR before any implementation because it introduces a large
  domain model, heavy dependencies, and potential geometry scope creep.

Docker fixture strategy:

- Use pinned Python images with `cantools` for DBC/ASC fixture generation.
- Use pinned Python images with `pyais` for AIS fixture generation.
- Use ADS-B and IFC tooling only for investigation fixtures until dependency
  decisions are accepted.
- Normal tests use checked-in small text fixtures.

Testing requirements:

- DBC parser tests for messages, signals, scaling, units, choices/enums,
  multiplexing warnings, comments, and malformed definitions.
- ASC log tests for timestamp precision, channel, id, direction, DLC, payload,
  malformed rows, and optional DBC decode.
- AIS tests for valid/invalid checksums, multipart messages, message types,
  vessel identifiers, coordinates, timestamps, and malformed payloads.
- IFC tests only after a narrowed metadata scope is accepted.

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
