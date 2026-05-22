# Troubleshooting

This page covers common problems and the first things to check.

## A database will not open

Check that:

- The file exists and is readable.
- The file is a DecentDB database, usually ending in `.ddb`.
- Another process is not holding the file in a way that blocks access.
- The file does not need legacy migration.

If Decent Bench offers migration, use the copy-based migration path so the original file stays unchanged.

## Import fails

Check the source file first:

- For Excel, confirm the sheet has rows and usable column headers.
- For SQLite, confirm the file opens in its source application.
- For SQL dumps, confirm the dump uses common `CREATE TABLE` and `INSERT` statements.

Then review any warnings shown in the import wizard. The warning usually points to the table, column, or statement that needs attention.

## Query returns no rows

An empty result can be correct. Check:

- Filters in the `WHERE` clause
- Join conditions
- Date ranges
- Uppercase and lowercase differences in text
- Whether the table actually contains rows

## Query is slow

Try:

- Add a `LIMIT` while exploring.
- Filter earlier in the query.
- Check whether the filtered column has an index.
- Stop the query and simplify it.

## Export does not contain what you expected

Look at the visible result grid before exporting. Export uses the current table or result source, so make sure the active tab and selected export command match what you intend.

## Find logs

Use **Tools > View Log** to inspect application activity when a problem needs more detail. Logs are most useful when reporting a repeatable issue.

## When asking for help

Include:

- What you were trying to do
- The file type involved
- The exact error message
- Whether the same file opened or imported successfully before
- The smallest steps that reproduce the issue
