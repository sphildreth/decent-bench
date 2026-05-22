# Importing Data

Imports bring data from another file into a DecentDB database. The importer guides you through the source file, destination table names, column names, and type choices.

## Supported sources

- **Excel**: `.xls` and `.xlsx`
- **SQLite**: `.db`, `.sqlite`, and `.sqlite3`
- **SQL dumps**: `.sql` files with common table and insert statements

You can start an import from the **Import** menu, toolbar import buttons, or drag and drop.

## Excel import

Use Excel import when a workbook is the source of truth. The wizard helps you choose the sheet and review column names before loading data.

Tips:

- Put headers in the first row when possible.
- Remove summary rows or notes before importing if they are not data.
- If a column mixes text and numbers, choose the type that preserves the values you care about.

## SQLite import

Use SQLite import when you already have a local database file. The wizard reads source tables and creates matching DecentDB tables.

This is useful when another app exports SQLite or when you want to move lightweight data into DecentDB.

## SQL dump import

Use SQL dump import for common MariaDB or MySQL-style `.sql` files. Decent Bench supports the practical table-and-insert patterns used by many dumps, but a dump that uses advanced server features may need cleanup first.

## Column names and types

Before the final import, review:

- Table names
- Column names
- Type overrides
- Any warnings shown by the wizard

Choose clear names up front. It makes later SQL easier to write and easier to understand.

## Imports should not freeze the app

Large imports run as background work. You should still be able to see progress and cancel when cancellation is available.

## Not yet available

Live database connection import is intentionally deferred. Use file-based exports such as SQLite, Excel, CSV, or SQL dump as the practical bridge until connection management is implemented.
