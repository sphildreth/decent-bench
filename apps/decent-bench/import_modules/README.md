# Import Modules

This directory is the source of truth for built-in import module metadata.

## Scope

- Built-in modules only.
- External module loading is out of scope.
- Manifests are declarative metadata only.

This contract follows ADR-0049, ADR-0050, ADR-0051, and ADR-0052.

## Layout

```text
apps/decent-bench/import_modules/
  README.md
  schema/
    import_module_manifest.schema.md
    import_module_manifest.example.toml
  builtin/
    <module_id>/
      module.toml
      README.md
      fixtures/
```

## Manifest Contract

Read [Manifest Schema](schema/import_module_manifest.schema.md) for the
versioned field contract and validation rules.

Read [Example Manifest](schema/import_module_manifest.example.toml) for a
complete module example that uses only supported v1 fields.

## Security And Execution Boundary

- A manifest cannot execute code.
- A manifest cannot define shell commands, scripts, SQL to run, dynamic
  library paths, package installation instructions, or arbitrary executable
  paths.
- Import behavior is implemented only by reviewed adapters referenced by
  adapter id.

## SQLite Clarification

SQLite is one source module. It is not a universal staging or interchange layer
for other formats. The canonical import handoff is typed DecentDB schema and
typed batches.

## Status Promotion Workflow

New formats start as `candidate` or `investigate` modules with documentation,
known extensions, dependency concerns, and limitations. Promotion requires:

1. `planned`: product acceptance in the import roadmap and a module manifest
   with no executable adapter requirement.
2. `partial`: a registered adapter, module README, fixture notes, at least one
   declared limitation, and tests covering the supported subset.
3. `complete`: a registered executable adapter, declared capabilities,
   module-local docs, fixture coverage or deterministic fixture-generation
   instructions, user-facing help coverage, and passing catalog validation.

No module may be promoted to `complete` by changing only the status field.
The adapter, docs, fixture contract, and validation tests must move together.
