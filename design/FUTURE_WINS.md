# Decent Bench Future Wins

**Status:** Consolidated product roadmap
**Purpose:** Product and engineering priority index for Decent Bench. Dedicated
specs and ADRs remain the implementation source of truth when they exist.

Decent Bench should win by being the polished DecentDB workbench: import data,
inspect schema, run SQL, export results, and generate application-facing
artifacts without forcing users to hand-wire database access.

## Status Map

Status values:

- `TODO`: prioritized roadmap work that is not actively being implemented right now.
- `IN PROGRESS`: active implementation or design work is underway right now.
- `BACKLOG`: valuable, but not part of the near-term implementation path.

Future version values are planning buckets, not release commitments.

| Priority | Future Version | Status | Feature | Current Source Of Truth | Why This Rank |
|---:|---|---|---|---|---|
| 1 | vNext | TODO | Schema-first strongly typed SDK generation | Needs Decent Bench ADR/spec; built on DecentDB stable schema/query-contract metadata | Turns Decent Bench from an import/query workbench into the official app-integration workflow for DecentDB |
| 2 | vNext | TODO | Saved queries and workspace projects | `design/PRD.md` post-1.0 scope | Natural home for named query contracts, regeneration settings, and repeatable workbench sessions |
| 3 | vNext | TODO | JSON, Parquet, and Excel export | `design/PRD.md`, `design/SPEC.md` Next scope | Completes the import-query-export loop for common downstream workflows |
| 4 | vNext+1 | TODO | Richer import transforms and connector expansion | `design/IMPORT_SUPPORT_PLAN.md` | Extends the workbench's core data-wrangling value without changing DecentDB engine scope |
| 5 | vNext+1 | BACKLOG | Query-plan and performance diagnostics | Needs ADR/spec | Helps users understand DecentDB behavior without making the engine roadmap carry UI concerns |

## Current Foundations

These should be treated as shipped or materially advanced foundations rather
than future roadmap claims:

- DecentDB-first desktop workspace
- drag-and-drop open/import entry point
- Excel, SQLite, and MariaDB/MySQL-style SQL dump import paths
- schema browser backed by DecentDB rich schema metadata
- multi-tab SQL editor against the pinned DecentDB SQL surface
- paged/virtualized results grid
- CSV export
- TOML configuration and desktop preferences
- ADR-governed design process

## 1. Schema-First Strongly Typed SDK Generation

**Status:** `TODO`
**Future Version:** vNext
**Source of truth:** Needs Decent Bench ADR/spec before implementation. The
DecentDB engine owns the shipped stable schema/query-contract metadata surface
needed by this workflow.

### Why This Matters

Decent Bench already sits at the place where users inspect a DecentDB file,
understand its schema, write SQL, and export artifacts. That makes it the right
product home for schema-first SDK generation. The generator should be a
workbench/tooling capability, not clutter in the DecentDB engine core.

The value is not just "generate classes from tables." The value is a repeatable
workflow:

- inspect an existing DecentDB database
- define or select named query contracts
- preview generated artifacts
- generate language-native models, bind helpers, and typed result contracts
- detect schema drift and breaking changes
- regenerate safely in local development and CI

### Decent Bench-Owned Scope

- generator workflow in the GUI and a headless `dbench` command for CI/agents
- canonical generator IR that adapts DecentDB metadata into codegen-friendly form
- generated models/types from tables and views
- generated parameter-binding helpers
- typed query result contracts for explicit named queries
- schema drift and breaking-change reports
- deterministic file layout and golden-testable output
- documentation and sample projects for generated SDKs
- initial language targets:
  - C#/.NET
  - TypeScript/Node
  - Python

### DecentDB-Owned Foundation

DecentDB provides only the low-level contract this feature needs:

- versioned schema metadata export
- schema fingerprinting suitable for drift checks
- complete DecentDB type metadata, including native spatial values
- query describe/contract primitives for explicit named queries
- Rust API, C ABI, and binding exposure for required metadata
- deterministic JSON output suitable for golden tests and CI

### Non-Goals

- runtime ORM with change tracking
- arbitrary dynamic SQL extraction from application repositories
- full LINQ-style query DSL generation
- remote-service SDK generation
- putting codegen templates or language package layouts in the DecentDB engine

### First Useful Slice

1. Accept a Decent Bench ADR that confirms ownership boundaries with DecentDB.
2. Define the generator IR and on-disk contract file format.
3. Consume DecentDB schema metadata from a sample database.
4. Generate C# models and simple bind/result helpers from tables and one named
   query file.
5. Add golden tests for deterministic output.
6. Add a minimal sample app that compiles against the generated C# output.

### Later Slices

- TypeScript/Node generator
- Python generator
- drift and breaking-change report UI
- saved workspace project integration
- optional repository wrappers
- Go, Java, and Rust generators

## Near-Term Sequence

1. Create the Decent Bench ADR/spec for schema-first SDK generation ownership,
   IR, output layout, and C# MVP scope.
2. Coordinate with DecentDB on the stable schema/query-contract metadata
   surface.
3. Build the headless generator path first so CI and coding agents can use it.
4. Layer GUI preview/regeneration workflows on top of the same generator core.
