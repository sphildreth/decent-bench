## ERD JPEG Export Image Encoder
**Date:** 2026-05-19
**Status:** Accepted

### Decision

Use the pure-Dart `image` package on the `4.3.x` line to encode ERD raster
exports as JPEG. PNG export continues to use Flutter's built-in PNG encoder.

### Rationale

Flutter exposes PNG encoding for `ui.Image`, but it does not expose a JPEG
encoder. The ERD export scope accepted by ADR-0035 requires JPG/JPEG output, so
Decent Bench needs a small encoder dependency. `image` `4.3.0` is compatible
with the existing `archive` `3.6.1` constraint and is MIT licensed.

### Alternatives Considered

- Upgrade `archive` and use the latest `image` line. Rejected because it would
  expand the dependency blast radius beyond ERD export.
- Add platform-specific JPEG encoding. Rejected because it would increase
  desktop packaging complexity.
- Defer JPG and ship PNG only. Rejected because ADR-0035 and the ERD UI plan
  include PNG and JPG/JPEG as first-slice export formats.

### Trade-offs

JPEG encoding is pure Dart and portable, but it adds one direct dependency.
Large export requests remain guarded by pre-allocation axis and megapixel
limits before any image is rendered or encoded.

### References

- `design/adr/0035-read-only-erd-viewer-and-image-export.md`
- `design/ERD_UI_PLAN.md`
