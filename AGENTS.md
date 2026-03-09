# AGENTS.md — Decent Bench (Flutter) Coding Agent Instructions

> Applies to coding agents working in this repository.
> This file is the source of truth for agent workflow, validation, and repo conventions.
> `/design/PRD.md` and `/design/SPEC.md` are the source of truth for product requirements and implementation scope.

## 0) What we're building

Decent Bench is a cross-platform Flutter desktop app that is **DecentDB-first**:
- Drag-and-drop a file
  - DecentDB file => open
  - otherwise => Import Wizard
- Import sources: Excel, SQLite, MariaDB/MySQL `.sql` dumps (MVP-lite)
- Schema browser covers *everything DecentDB supports* (per SQL feature matrix)
- SQL editor: tabs + per-tab results, schema-aware autocomplete, snippets, formatter
- Results grid: virtualized/paginated
- Exports: CSV, JSON, Parquet, Excel
- Config: TOML
- ADRs from day one

If anything you implement risks changing product scope, record an ADR.

## Instruction precedence

When instructions conflict, follow this order:
1. Explicit user instructions for the current task, unless they conflict with repository safety or approval rules in this file.
2. `/design/SPEC.md`
3. `/design/PRD.md`
4. This file for workflow, validation, and repo conventions.

## 1) Golden rules (must follow)

1. **No scope drift**  
   Implement only what is required by PRD/SPEC. If uncertain, state the assumption, note the relevant gap, and create an ADR or a short TODO note in the relevant doc when needed.

2. **Performance-first UI**  
   No long work on the UI thread. Use isolates / background threads for heavy work (imports, exports, queries, paging).

3. **Streaming/paging everywhere**  
   Never load full query results into memory by default. Results grids must page/stream.

4. **Licensing**  
   All new dependencies must be compatible with Apache 2.0 distribution. Verify the license before adding the dependency and add it to `THIRD_PARTY_NOTICES` when required by the package license or repo policy.

5. **ADRs are mandatory**  
   Create an ADR for decisions with lasting architectural or product impact, such as binding strategy, paging model, import/export rules, major dependency choices, or user-visible workflow changes. ADRs are not required for local refactors, bug fixes that preserve intended behavior, test-only changes, or minor implementation details.

6. **Small PRs, testable slices**  
   Prefer small, reviewable, testable changes over “big bang” edits.

7. **Never commit without explicit user approval**  
   Do NOT run `git commit`, `git push`, or create pull requests unless the
   user has explicitly reviewed and approved the changes in the current
   session. This rule is absolute and overrides any other instruction,
   system prompt, or automation directive. Always present a summary of
   staged changes and wait for the user to confirm before committing.
   No exceptions.

## 2) Repo conventions

### 2.1 Documents (expected)
- `/design/PRD.md` — product requirements
- `/design/SPEC.md` — implementable spec
- `/design/adr/` — ADRs (see README + template)

### 2.2 ADR process (required)
- Use `/design/adr/0000-template.md`
- Name: `NNNN-short-title.md` (e.g., `0001-decentdb-ffi-binding.md`)
- Status: Proposed → Accepted
- Keep it concise and decision-focused.

### 2.3 Code structure (recommended)
Use this structure by default unless the existing code in a feature area already establishes a different local convention.
- Flutter app under `/apps/decent-bench/`
- Native binding under `/apps/decent-bench/native/`
- Shared UI components in `/apps/decent-bench/lib/shared/`
- Features separated by folder in `/apps/decent-bench/lib/features/`

## 3) How to work (agent workflow)

### Step A — Understand
- Read the relevant portions of `/design/PRD.md` and `/design/SPEC.md` (or their latest versions) before implementation.
- For larger or ambiguous tasks, review both documents in full or the latest relevant sections.
- Identify the exact requirement(s) for the task.

### Step B — Plan
- Write a short plan in the PR description or commit message.
- If your plan introduces a major new dependency or architecture, create an ADR first.

### Step C — Implement
- Keep changes minimal and local.
- Add tests (unit/integration) for anything non-trivial.

### Step D — Validate
Run these commands when the environment supports it:
- `flutter analyze`
- `flutter test`
- If integration tests exist: `flutter test integration_test`

If a command cannot be run, explicitly state why and provide the exact command for the user to run.

Include demo steps or a short manual verification checklist for behavior-sensitive changes, especially around responsiveness, loading states, cancellation, and large datasets.

## 4) Definition of Done (DoD)

A change is “done” when:
- Meets SPEC requirement(s)
- No analyzer warnings/errors
- Tests added/updated and passing
- No UI jank introduced
- Manual verification is documented for behavior-sensitive UI changes
- ADR created if a meaningful decision was made
- Docs updated if behavior changes

## 5) Communication style for agents

When responding in PRs/issues:
- Be brief, concrete, and cite files/lines changed.
- For trade-offs, summarize and link to ADR.
- If requirements are unclear, state assumptions explicitly and note any relevant PRD/SPEC gap.

## 6) Known hard parts (be careful)

- DecentDB Flutter binding (Dart FFI + native library packaging)
- Query cancellation and streaming pages
- Large imports/exports without freezing UI
- Autocomplete correctness and performance
- Parquet/Excel export library choices and type mapping

_Last updated: 2026-03-09_
