# Writing and Running SQL

The SQL editor is where you explore, reshape, and prepare data for export.

## Run the current statement

Use **Tools > Run Query** to run the statement around the cursor. This is the fastest way to iterate while editing a larger script.

## Run the whole buffer

Use **Tools > Run Buffer** when the editor contains a full script that should run together.

## Stop a query

Use **Tools > Stop Query** if a query takes longer than expected. Cancellation is best effort, but the app should stay responsive while it asks the database to stop.

## Format SQL

Use **Tools > Format SQL** to clean up spacing and indentation. Formatting is most useful before saving snippets or sharing a query with someone else.

## Work in tabs

Use **Tools > New Query Tab** for separate tasks. For example:

- One tab for quick table inspection
- One tab for a longer cleanup query
- One tab for the final export query

## Safer exploration

When you do not know the data yet, start small:

```sql
SELECT *
FROM table_name
LIMIT 100;
```

Add filters before removing the limit.

## Risky statements

When SQL can modify data, Decent Bench may ask for confirmation or offer a branch-based safety path when the current DecentDB binding supports it.

For technical users: Decent Bench sends SQL to DecentDB rather than using a separate app-specific SQL dialect. If a statement is valid for the pinned DecentDB engine, the editor should not block it just because there is no dedicated UI for that feature.
