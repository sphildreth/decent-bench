## In-App Help Center
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench will provide a first-class in-app Help Center backed by bundled
Markdown articles, a small manifest, and an internal local search index.

The Help Center is opened from **Help > Documentation** and the existing `F1`
shortcut. It starts at the **Getting Started** article in the **Start Here**
category so users have a predictable entry point. It replaces the previous
static documentation dialog while preserving the command id and menu entry.

The implementation will use `flutter_markdown_plus` for rendering bundled help
articles. Search remains app-owned instead of adding a separate search package.

### Rationale

Decent Bench is a desktop data workbench, and users need practical workflow
guidance without leaving the app or reading repository design documents. The
previous dialog pointed users at developer-oriented files and did not offer
search, task-oriented articles, or a clear starting point.

Bundled Markdown keeps content easy to review and update with code changes.
The manifest gives the app stable article ids, categories, tags, summaries, and
asset paths. A local search index is enough for the expected documentation size
and avoids taking a low-adoption search dependency.

`flutter_markdown_plus` is the maintained continuation of the discontinued
`flutter_markdown` package and is BSD-3-Clause licensed.

### Alternatives Considered

- Keep the static dialog. Rejected because it does not meet the product need
  for robust, searchable, user-facing help.
- Build a custom Markdown renderer. Rejected because it would add maintenance
  risk with no product benefit.
- Add a third-party search package. Rejected for the first implementation
  because the documentation corpus is small and app-owned ranking/snippets are
  straightforward.
- Use guided-tour packages as the primary help system. Rejected because tours
  are useful onboarding aids but are not a documentation browser.

### Trade-offs

- Bundled docs are available offline and versioned with the app, but content
  updates require an app release.
- Internal search is easy to control, but it is intentionally simple and may
  need replacement if the help corpus grows substantially.
- Markdown keeps authoring approachable, but advanced interactive help content
  should be implemented as Flutter UI when needed.

### References

- `apps/decent-bench/assets/help/help_manifest.json`
- `apps/decent-bench/lib/features/workspace/presentation/help/help_center_dialog.dart`
- `https://pub.dev/packages/flutter_markdown_plus`
