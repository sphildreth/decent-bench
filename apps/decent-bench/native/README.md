# Native Library Packaging

The shipped desktop app resolves the DecentDB native library in this order:

1. Bundled with the app (Linux: `lib/`, macOS: `Contents/Frameworks/`, Windows: root)
2. System library paths (`/usr/local/lib/`, `/usr/lib/`, `~/.local/lib/`)
3. Local `build/` or `native/` fallbacks while developing

When Flutter is available and desktop runners are generated, bundle the native
library into the platform-specific app locations described in the upstream
DecentDB Dart binding docs.
