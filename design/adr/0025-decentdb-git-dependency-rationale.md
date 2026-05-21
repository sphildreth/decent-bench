## DecentDB Git Dependency Rationale
**Date:** 2026-04-21
**Status:** Accepted

### Decision

Decent Bench depends on the `decentdb` Dart package via a **Git dependency**
pinned to a specific tag, rather than a pub.dev hosted dependency.

```yaml
decentdb:
  git:
    url: https://github.com/sphildreth/decentdb
    path: bindings/dart/dart
    ref: v2.6.0
```

### Rationale

The `decentdb` package is maintained by the same organization as Decent Bench
and is not currently published to pub.dev. Using a Git dependency pinned to a
tag provides:

- Reproducible builds via the locked `ref`
- Direct access to the upstream Dart FFI bindings without a publishing delay
- Alignment between the Dart binding version and the native library version
  staged during CI builds

The `pubspec.lock` file ensures that all CI and developer builds resolve the
same commit. CI extracts the pinned tag from `pubspec.lock` to download the
matching native library release asset.

### Alternatives Considered

- Publish `decentdb` to pub.dev as a hosted dependency
- Use a local path dependency during development and Git for CI
- Vendor the binding source into the Decent Bench repository

### Trade-offs

- Git dependencies resolve more slowly than pub.dev hosted dependencies
- Some tooling (e.g., `dart pub deps --style=compact`) may produce more
  verbose output for Git dependencies
- The project cannot use `pub.dev` automated version solving for `decentdb`

These trade-offs are acceptable because the upstream package is co-maintained
and the tag-pinning strategy provides deterministic resolution.

### References

- `apps/decent-bench/pubspec.yaml`
- `apps/decent-bench/pubspec.lock`
- `.github/workflows/flutter-build.yml`
- `design/adr/0001-decentdb-flutter-binding-strategy.md`
