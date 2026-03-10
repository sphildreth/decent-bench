# Decent Bench App Scaffold

This directory contains the hand-authored Phase 1 Flutter app source for
Decent Bench.

## Current state

- `pubspec.yaml`, `lib/`, `test/`, and `integration_test/` are present
- the Phase 1 workspace controller, DecentDB bridge, and desktop UI are in
  place
- desktop runner folders (`linux/`, `macos/`, `windows/`) still need to be
  generated with the Flutter tool once Flutter is installed in the environment

## When Flutter is available

From `apps/decent-bench/`:

```bash
flutter create . --platforms=linux,macos,windows
flutter pub get
flutter analyze
flutter test
flutter test integration_test
```

The app expects the pinned DecentDB v1.6.0 native library to be available via:

1. `DECENTDB_NATIVE_LIB`
2. a bundled desktop runner path
3. a sibling `../decentdb/build/` checkout
