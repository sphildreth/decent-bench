## Stable Desktop Application Identity
**Date:** 2026-05-22
**Status:** Accepted

### Decision

Decent Bench will use `com.decentdb.bench` as its stable desktop application
identifier across supported desktop platforms.

Platform metadata must use this identifier instead of Flutter template
placeholders:

- macOS main bundle identifier: `com.decentdb.bench`
- macOS test bundle identifier prefix: `com.decentdb.bench`
- Linux GTK/freedesktop application id: `com.decentdb.bench`
- Windows company metadata: `com.decentdb.bench`

Future DecentDB database file association work will use these related stable
identifiers:

- DecentDB database extension: `.ddb`
- DecentDB database MIME type: `application/vnd.decentdb.database`
- macOS DecentDB database UTI: `com.decentdb.database`
- Windows DecentDB database ProgID: `DecentDB.Bench.ddb`

This ADR only establishes stable identifiers. It does not implement file
association registration or default-app behavior.

### Rationale

Desktop operating systems use application identifiers as durable identity for
bundle registration, window grouping, MIME/default-app associations, Open With
menus, code signing, installer ownership, and upgrade behavior.

The previous metadata still used Flutter template placeholder identifiers.
Shipping file association or installer behavior with placeholder identifiers
would create stale registrations and confusing upgrade paths when the
identifiers are later corrected.

Using one reverse-DNS application identifier now gives future `.ddb` file
association work a stable target.

### Alternatives Considered

- Keep template placeholder identifiers until release packaging. Rejected
  because file association planning and desktop metadata should not depend on
  placeholder identities.
- Use platform-specific identifiers such as `com.decentdb.Bench` on Linux and
  `com.decentdb.bench` on macOS. Rejected because one exact identifier is easier
  to document and audit.
- Use `io.decentdb.bench`. Rejected in favor of the user-selected
  `com.decentdb.bench` identifier.

### Trade-offs

- Existing local development builds may appear to the host OS as a different app
  after the identifier change. This is acceptable before release packaging and
  file association support.
- The app identifier and the `.ddb` file type identifier are intentionally
  different. This avoids conflating "Decent Bench application" with "DecentDB
  database file type".
- Windows executable version metadata does not have a dedicated reverse-DNS app
  id field, so the stable identifier is used in the company field until a
  future installer or MSIX manifest owns the Windows package/app identity.
  Copyright fields remain copyright-holder text and must not use placeholder
  identities.

### References

- `apps/decent-bench/macos/Runner/Configs/AppInfo.xcconfig`
- `apps/decent-bench/linux/CMakeLists.txt`
- `apps/decent-bench/windows/runner/Runner.rc`
- `design/adr/0013-desktop-cli-import-launch-and-binary-name.md`
- `design/adr/0021-desktop-cli-positional-database-open.md`
