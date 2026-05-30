## Desktop Window Placement Persistence
**Date:** 2026-05-23
**Status:** Accepted

### Decision

Decent Bench persists desktop window placement in the application TOML config
under `[window]`.

The persisted placement includes:

- normal restore bounds (`x`, `y`, `width`, `height`)
- window state (`normal`, `maximized`, or `fullscreen`)
- best-effort display identity and display work-area bounds

Flutter owns the config model and persistence cadence. Each desktop runner
implements a small `decent_bench/window_placement` platform channel for native
window capture and restore.

Native restore must clamp stale coordinates to a current display work area. If
the saved display cannot be found, the runner restores on the nearest available
display instead of allowing an off-screen window.

### Rationale

Flutter does not expose a stable, built-in cross-platform desktop API for
reading and restoring host-window placement, especially monitor identity and
maximized/fullscreen state. Decent Bench already owns desktop runner code for
native menus, so a small first-party channel keeps the behavior dependency-free
and aligned with the existing runner architecture.

Persisting normal restore bounds separately from state preserves the expected
desktop behavior: if the app closes maximized, reopening maximizes on the saved
display while retaining the user's prior normal window size for later restore.

### Alternatives Considered

- Add a third-party window-management package. Rejected because the required
  surface is small, native runner code already exists, and new dependencies
  require license and packaging review.
- Persist only width and height in Flutter. Rejected because it does not solve
  multi-monitor placement or maximized-state restoration.
- Persist workspace-specific window placement. Rejected because window geometry
  is an application preference, not a DecentDB-file-specific workspace state.

### Trade-offs

- Linux Wayland compositors may ignore programmatic window moves. The Linux
  runner still captures and requests placement, but monitor restoration is
  best-effort under compositor policy.
- Monitor identifiers vary by platform. The config stores native display ids
  plus work-area bounds and always validates against the current display layout.
- The config format version advances to `3` when placement is saved.

### References

- `apps/decent-bench/lib/app/window_placement/window_placement_service.dart`
- `apps/decent-bench/lib/features/workspace/domain/app_config.dart`
- `apps/decent-bench/linux/runner/window_placement_plugin.cc`
- `apps/decent-bench/macos/Runner/MainFlutterWindow.swift`
- `apps/decent-bench/windows/runner/window_placement_plugin.cpp`
