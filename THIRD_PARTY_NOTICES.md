# Third-Party Notices

All third-party dependencies used by Decent Bench must be compatible with
Apache 2.0 distribution. This file tracks attributions and license details.

## Dependencies

- `decentdb`
  - Version/source: Git dependency from `https://github.com/sphildreth/decentdb`,
    path `bindings/dart/dart`, ref `v2.7.0`
  - License: Apache License 2.0
  - Upstream project: `https://github.com/sphildreth/decentdb`

- `desktop_drop` `0.7.0`
  - License: Apache License 2.0
  - Copyright: package contributors
  - Source: `https://pub.dev/packages/desktop_drop`

- `archive` `3.6.1`
  - License: MIT
  - Copyright: Brendan Duncan
  - Source: `https://pub.dev/packages/archive`

- `crypto` `3.0.6`
  - License: MIT
  - Copyright: Dart project authors
  - Source: `https://pub.dev/packages/crypto`

- `excel` `4.0.6`
  - License: MIT
  - Copyright: package contributors
  - Source: `https://pub.dev/packages/excel`

- `file_selector` `1.1.0`
  - License: BSD-style Flutter Authors license
  - Copyright: The Flutter Authors
  - Source: `https://pub.dev/packages/file_selector`

- `flutter_markdown_plus` `1.0.7`
  - License: BSD-3-Clause
  - Copyright: package contributors
  - Source: `https://pub.dev/packages/flutter_markdown_plus`

- `html` `0.15.6`
  - License: MIT
  - Copyright: package contributors and Google LLC
  - Source: `https://pub.dev/packages/html`

- `image` `4.3.0`
  - License: MIT
  - Copyright: Brendan Duncan
  - Source: `https://pub.dev/packages/image`

- `sqlite3` `3.1.7`
  - License: MIT
  - Copyright: Simon Binder
  - Source: `https://pub.dev/packages/sqlite3`

- `xml` `6.6.1`
  - License: MIT
  - Copyright: Lukas Renggli
  - Source: `https://pub.dev/packages/xml`

- `path` `^1.9.0`
  - License: BSD-style license (Dart project)
  - Copyright: Dart project authors
  - Source: `https://pub.dev/packages/path`
  - Note: `path` is a Dart SDK team package; attribution included for
    completeness.

## Transitive dependency notes

The following transitive dependencies are brought in by direct dependencies.
Their licenses are compatible with Apache 2.0 distribution:

- `archive` brings `convert` (BSD-style, Dart project authors) and also uses
  `crypto`, which is listed above as a direct dependency.
- `flutter_markdown_plus` brings `markdown` and `args` (BSD-style, Dart
  project authors) and reuses `meta` and `path` from the Dart project
  dependency set
- `sqlite3` brings `collection` and `meta` (BSD-style, Dart project authors)
- `excel` brings `equatable` (MIT), `ffi` (BSD-style), and `recase` (MIT)
