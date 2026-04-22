## Tar+BZip2 and Tar+GZip Archive Import
**Date:** 2026-04-21
**Status:** Accepted

### Decision

Decent Bench supports `.tar.bz2` and `.tar.gz` archive wrappers for import.
These formats are common for PostgreSQL data dumps and other large tabular
datasets distributed as compressed tar archives.

The implementation uses the **system `tar` command** for listing and extracting
archive contents rather than the Dart `archive` package. This avoids loading
entire compressed archives into memory, which is essential for files that can
range from hundreds of megabytes to several gigabytes compressed.

BZip2 single-file decompression (non-tar `.bz2` files) uses the Dart `archive`
package's `BZip2Decoder` for small files, consistent with the existing GZip
single-file path.

### Rationale

PostgreSQL dump archives like MusicBrainz `mbdump.tar.bz2` contain many
tab-separated value files without extensions inside a tar archive compressed
with bzip2. These files can exceed 1 GB compressed and 10 GB uncompressed.

The `archive` package's `TarDecoder` and `BZip2Decoder` both require the full
decompressed data in memory, making them impractical for large archives. The
system `tar` command streams extraction and can handle arbitrary sizes.

The system command approach is consistent with the existing LibreOffice
conversion pattern in `excel_source_preparer.dart`, which also uses
`Process.runSync` for native tool integration.

### Inner file handling

Files inside tar archives may lack file extensions (e.g., `mbdump/artist`).
The detection service infers the format for extensionless entries by defaulting
to TSV (tab-separated values), which is the standard format for PostgreSQL
dump files. When extracting, a `.tsv` extension is appended to the temp file
so that downstream detection routes it to the generic import wizard.

### Alternatives Considered

- Use the `archive` package for full in-memory decompression and tar parsing
- Implement a streaming tar parser in Dart
- Require users to extract tar.bz2 externally before importing
- Support only small archives with an in-memory approach

### Trade-offs

- Requires the `tar` command to be available on the host system (available on
  Linux, macOS, and Windows 10+)
- Single-file bzip2 decompression for large files still uses in-memory
  `BZip2Decoder`; this is acceptable for non-tar use cases which are typically
  smaller
- Extensionless inner files default to TSV inference, which may not match
  all tar archive contents; users can adjust delimiter settings in the
  generic import wizard
- The `tar -tjf` listing step decompresses the full archive to read the file
  list; this is unavoidable with bzip2's block structure but tar's streaming
  output keeps memory bounded on the tar side

### References

- `apps/decent-bench/lib/features/import/infrastructure/import_detection_service.dart`
- `apps/decent-bench/lib/features/import/infrastructure/import_format_registry.dart`
- `apps/decent-bench/lib/features/workspace/infrastructure/excel_source_preparer.dart`
- `design/adr/0019-import-format-registry-and-generic-wizard.md`
- `design/adr/0024-import-scope-expansion-beyond-prd-mvp.md`
