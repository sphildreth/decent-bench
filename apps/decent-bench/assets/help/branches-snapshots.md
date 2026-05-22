# Branches and Snapshots

Branches and snapshots help you protect database states while exploring changes.

## Snapshots

A snapshot records a point-in-time database state. Use snapshots before risky work when you want a named checkpoint.

Good times to create a snapshot:

- Before a large import
- Before cleanup SQL
- Before deleting or replacing data
- Before testing a workflow you may not keep

## Branches

A branch lets you work from a separate database state. This is useful when you want to test changes without immediately applying them to the main branch.

Common branch tasks:

- Create a branch for a risky transformation
- Compare branches
- Restore a branch state
- Merge changes when you decide to keep them

## Branch and Snapshot workbench

Use **Tools > Branch and Snapshots** to inspect available branch and snapshot actions for the open database.

Some actions depend on what the installed DecentDB Dart binding exposes. If a native operation is unavailable, Decent Bench should explain the limitation rather than pretending the action succeeded.

## Practical safety habit

Before any data-changing SQL that would be hard to undo, create a snapshot or use a branch when available. This keeps experimentation separate from your main database state.
