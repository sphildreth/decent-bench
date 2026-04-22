## Import Scope Expansion Beyond PRD MVP
**Date:** 2026-04-21
**Status:** Accepted

### Decision

Decent Bench v1.0.0 ships with import support for formats beyond those listed
in the original PRD MVP scope. The PRD specified Excel, SQLite, and
MariaDB/MySQL `.sql` dumps. The shipped product additionally supports:

- CSV, TSV, and generic delimited text (PSV, custom delimiters)
- JSON and NDJSON/JSONL
- XML
- HTML tables
- ZIP and GZip archive wrapper routing

These formats route through the generic import wizard pipeline introduced by
ADR-0019 rather than the legacy per-format wizards. The PRD MVP formats
(Excel, SQLite, SQL dump) continue using their existing dedicated wizards.

### Rationale

The import format registry (ADR-0019) established a shared detection and
routing architecture that made adding new format families low-risk. The
generic import pipeline handles preview, type inference, and execution for
text, structured, and web-markup formats through a single wizard, avoiding
the need for per-format UI code.

The supported test-data fixtures already included CSV, JSON, XML, and HTML
samples for validation purposes. Extending import support to these formats
was a natural fit for the registry architecture and did not destabilize the
existing MVP import wizards.

### Alternatives Considered

- Ship v1.0.0 with only the three PRD MVP formats and defer all others
- Add formats incrementally in minor releases after v1.0.0
- Rewrite existing MVP wizards into the generic pipeline before shipping

### Trade-offs

- The app has two import implementation paths (legacy wizards and generic
  wizard) as documented in ADR-0019
- Documentation must reflect the broader format support matrix
- The PRD import scope section (8.3) does not list these additional formats,
  creating a documentation gap that this ADR addresses

These trade-offs are acceptable because the generic wizard provides a uniform
user experience for the new formats and the legacy wizards remain stable.

### References

- `design/PRD.md` (Section 8.3: Supported imports for MVP)
- `design/SPEC.md` (Section 7: Import specifications)
- `design/adr/0019-import-format-registry-and-generic-wizard.md`
- `apps/decent-bench/lib/features/import/infrastructure/import_format_registry.dart`
- `docs/IMPORT_FORMATS.md`
