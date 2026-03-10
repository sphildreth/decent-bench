# Native Library Packaging

Phase 1 development resolves the DecentDB native library in this order:

1. `DECENTDB_NATIVE_LIB`
2. Bundled desktop-app locations for Linux, macOS, or Windows
3. A sibling `../decentdb/build/` checkout
4. Local `build/` or `native/` fallbacks while developing

For local development in this workspace, the expected native library is:

- Linux: `/home/steven/source/decentdb/build/libc_api.so`

When Flutter is available and desktop runners are generated, bundle the native
library into the platform-specific app locations described in the upstream
DecentDB Dart binding docs.
