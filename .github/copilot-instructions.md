# Copilot Instructions for Decent Bench

## Project Overview

- Decent Bench is a cross-platform Flutter desktop app for working with local DecentDB files.
- The core workflow is import -> inspect schema -> run SQL -> export results.
- This is a DecentDB-first workbench, not a general-purpose database administration tool.

## Source of Truth

- Read `AGENTS.md` before making substantial changes.
- Treat `design/SPEC.md` as the implementation source of truth.
- Use `design/PRD.md` for product intent and user-facing goals.
- Check `design/adr/` for prior architectural decisions before changing behavior or structure.

## Repository Layout

- Main Flutter app: `apps/decent-bench/`
- Shared UI/utilities: `apps/decent-bench/lib/shared/`
- Feature code: `apps/decent-bench/lib/features/`
- Native packaging/bindings support: `apps/decent-bench/native/`
- Product and architecture docs: `design/`

## Working Rules

- Keep changes scoped to the requested task. Do not expand product scope without updating the relevant design docs and, when appropriate, adding an ADR.
- Preserve the app's DecentDB-first workflow and pinned-engine behavior.
- Keep heavy work off the UI thread. Use isolates, background jobs, or existing async pipelines for imports, exports, and long-running queries.
- Do not load full result sets into memory by default. Results must remain paged, streamed, or virtualized.
- Prefer small, reviewable changes over broad refactors.
- Preserve existing project structure and local conventions in each feature area.
- Never commit without explicit user approval. Do NOT run `git commit`, `git push`, or create pull requests unless the user has explicitly reviewed and approved the changes in the current session. No exceptions.

## Dart and Flutter Expectations

- Follow existing feature boundaries: separate presentation, state/orchestration, domain contracts, and infrastructure when a feature is non-trivial.
- Keep widgets focused and avoid mixing UI rendering with import, query, or export orchestration.
- Match the existing style in the touched area rather than reformatting unrelated code.
- Add or update tests for non-trivial behavior changes.
- Adhere to the local Dart and Flutter Copilot skills documented in `.github/skills/`.

## Dependencies and Licensing

- Only add dependencies that are compatible with Apache 2.0 distribution.
- If a new dependency requires attribution or notice updates, update `THIRD_PARTY_NOTICES.md`.

## Validation

- Run validation from `apps/decent-bench/` when the environment supports it.
- Preferred checks:
  - `flutter analyze`
  - `flutter test`
  - `flutter test integration_test`
- If tests require the DecentDB native library, use `DECENTDB_NATIVE_LIB=/path/to/decentdb/build/libc_api.so` or the platform equivalent.

## Documentation Expectations

- Update docs when behavior, workflows, configuration, or architecture materially change.
- Add an ADR for lasting architectural or user-visible workflow decisions.
- If requirements are unclear, prefer documenting the assumption in code comments, docs, or an ADR instead of silently widening scope.

## Known Hard Parts

- DecentDB Flutter binding (Dart FFI + native library packaging)
- Query cancellation and streaming pages
- Large imports/exports without freezing UI
- Autocomplete correctness and performance
- Parquet/Excel export library choices and type mapping