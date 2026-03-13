## Headless CLI Import Mode And Plan File
**Date:** 2026-03-13
**Status:** Accepted

### Decision

Decent Bench should add a separate headless import CLI mode instead of
overloading the existing interactive `--import` flag.

The command split is:

- `dbench /path/to/workspace.ddb`
  - open an existing DecentDB workspace in the desktop UI
- `dbench --import <path>`
  - launch the desktop UI and open the matching import wizard
- `dbench --in <source-path> --out <target.ddb>`
  - run a headless import without showing the UI
- `dbench --in <source-path> --out <target.ddb> --plan <plan.json>`
  - run a headless import with explicit import options

Rules:

- `--in` and `--out` must be provided together
- `--plan` is only valid with `--in` and `--out`
- `--silent` is only valid with the headless mode
- positional `.ddb` open cannot be combined with `--import`, `--in`, or
  `--out`
- the plan file should carry import behavior and overrides, not input or output
  paths
- the plan file uses a versioned JSON contract documented in
  `docs/HEADLESS_IMPORT_PLAN_DETAILS.md`

### Rationale

This keeps interactive and non-interactive workflows distinct:

- `--import` stays easy to explain because it always means "show me the import
  wizard"
- `--in` and `--out` read naturally in scripts and batch jobs
- the headless path can evolve machine-friendly reporting and failure behavior
  without affecting the desktop startup UX

Keeping source and output paths on the command line also makes plan files more
portable across machines and environments.

### Alternatives Considered

- Add a verb-based CLI such as `dbench import ...`
- Reuse `--import` for both UI and headless modes
- Put the input and output paths inside the JSON plan file
- Add a separate import-only executable

### Trade-offs

- `--in` and `--out` are concise, but less self-documenting than longer flag
  names
- the CLI will have three distinct startup modes that must stay documented
  together
- headless mode introduces a versioned JSON contract that must be kept stable
  once shipped
- strict plan validation is intentionally conservative so automation fails fast
  on schema drift or misspelled keys

### References

- [design/SPEC.md](/home/steven/source/decent-bench/design/SPEC.md)
- [design/adr/0013-desktop-cli-import-launch-and-binary-name.md](/home/steven/source/decent-bench/design/adr/0013-desktop-cli-import-launch-and-binary-name.md)
- [design/adr/0021-desktop-cli-positional-database-open.md](/home/steven/source/decent-bench/design/adr/0021-desktop-cli-positional-database-open.md)
- [docs/HEADLESS_IMPORT_PLAN_DETAILS.md](/home/steven/source/decent-bench/docs/HEADLESS_IMPORT_PLAN_DETAILS.md)
