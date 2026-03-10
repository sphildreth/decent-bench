# Decent Bench App Scaffold

This directory contains the hand-authored Phase 2 Flutter app source for
Decent Bench.

## Current state

- `pubspec.yaml`, `lib/`, `test/`, and `integration_test/` are present
- the Phase 2 workspace controller, multi-tab UI, and desktop bridge are in
  place
- reopening the same DecentDB file restores persisted query tabs for that
  workspace
- desktop runner folders (`linux/`, `macos/`, `windows/`) are checked in
- the DecentDB Dart package is consumed from a local sibling checkout at
  `../../../decentdb/bindings/dart/dart`

## Validation

From `apps/decent-bench/`:

```bash
flutter pub get
flutter analyze
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter test
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter test integration_test
DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so flutter run -d linux
```

The app expects a compatible DecentDB v1.6.x native library to be available via:

1. `DECENTDB_NATIVE_LIB`
2. a bundled desktop runner path
3. a sibling `../decentdb/build/` checkout

Workspace tab drafts are stored separately from `config.toml` under the
platform-specific `workspaces/` directory documented in the root
[README.md](/home/steven/source/decent-bench/README.md).
