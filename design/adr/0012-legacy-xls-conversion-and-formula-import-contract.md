## Legacy XLS Conversion And Formula Import Contract
**Date:** 2026-03-10
**Status:** Accepted

### Decision

Decent Bench now accepts both `.xlsx` and legacy `.xls` workbook imports.

The Excel import path continues to use the Dart `excel` package for workbook
inspection and row-copy logic, but legacy `.xls` files are first converted to a
temporary `.xlsx` file through a local LibreOffice-compatible CLI (`soffice` /
`libreoffice`) inside the background inspection/import path. If a checked-in or
user-provided `.xlsx` workbook is rejected by the direct parser, the same local
normalization path is retried before the import fails.

The formula-handling contract remains conservative:

- imports must succeed even when a workbook contains formulas
- formula cells are imported as formula text
- the wizard and summary surface warnings when a workbook was converted from
  `.xls` or when formula cells were detected
- computed-column translation remains out of scope for MVP and is deferred to a
  later slice, potentially through companion views rather than automatic
  read-only sheet imports

This decision updates the legacy-workbook portion of ADR 0007.

### Rationale

The product requirements already advertise Excel import for both `.xls` and
`.xlsx`, and the checked-in fixture pack includes legacy `.xls` workbooks that
must import successfully into DecentDB files.

The existing parser stack can read normal `.xlsx` workbooks but not binary
`.xls`, and some real-world `.xlsx` files can still fail parser validation
because of workbook metadata such as styles. Converting workbooks to temporary
`.xlsx` files keeps the existing parser, inspection flow, warnings model, and
worker architecture intact without adding another bundled parsing dependency.

Preserving the current formula-as-text behavior keeps imports deterministic and
ensures mixed workbooks do not fail while formula translation remains undefined.

### Alternatives Considered

- Keep rejecting `.xls` and require manual resave to `.xlsx`
- Add a separate `.xls` parser dependency
- Evaluate workbook formulas during import
- Turn any sheet with calculated columns into a view automatically

### Trade-offs

- Legacy workbook support now depends on a local LibreOffice-compatible CLI
  being available at runtime. When it is missing, the failure mode is explicit.
- Temporary conversion adds startup cost for `.xls` imports, but the work
  remains off the UI thread.
- Formula expressions still land as text instead of evaluated or translated SQL,
  so calculated-column semantics are preserved only as import metadata/warnings
  for now.

### References

- [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
- [design/adr/0007-excel-import-parser-and-legacy-workbook-handling.md](/home/steven/source/decent-bench/design/adr/0007-excel-import-parser-and-legacy-workbook-handling.md)
- [test-data/excel-test-pack/README.txt](/home/steven/source/decent-bench/test-data/excel-test-pack/README.txt)
- [apps/decent-bench/lib/features/workspace/infrastructure/excel_import_support.dart](/home/steven/source/decent-bench/apps/decent-bench/lib/features/workspace/infrastructure/excel_import_support.dart)
