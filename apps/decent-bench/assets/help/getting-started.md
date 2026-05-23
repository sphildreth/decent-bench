# Getting Started

Decent Bench is a local desktop workbench for DecentDB files. The usual flow is:

1. Open or create a DecentDB database.
2. Import data if you are starting from a supported source file.
3. Inspect the schema.
4. Write and run SQL.
5. Export the shaped result.

## Start from an existing DecentDB file

Use **File > Open** and choose a `.ddb` file. Decent Bench opens the database, loads the schema explorer, and adds the file to recent workspaces.

You can also drag a `.ddb` file onto the app window.

## Start from a new DecentDB file

Use **File > New** and choose where the new `.ddb` file should be created. After the file opens, you can import data or run SQL that creates tables.

## Start from another file type

Drag a supported file onto the window or use the **Import** menu.

Supported import sources include:

- Delimited text: `.csv`, `.tsv`, `.txt`, `.dat`, `.log`, and `.psv`
- Fixed-width text: `.fwf` and fixed-width-looking `.txt` or `.dat` files
- Structured documents and logs: `.json`, `.ndjson`, `.jsonl`, `.xml`, `.log`,
  and `.har`
- HTML and Markdown tables: `.html`, `.htm`, and `.md`
- Spreadsheets: `.xlsx`, `.ods`, SpreadsheetML `.xml`, with `.xls` available
  through the legacy warning path
- SQLite databases: `.db`, `.sqlite`, and `.sqlite3`
- SQL dumps: `.sql`, including common MySQL/MariaDB dumps and PostgreSQL plain
  dumps
- Archive wrappers: `.zip`, `.gz`, `.tgz`, `.tar.gz`, `.bz2`, `.tbz2`,
  `.tar.bz2`, `.xz`, `.txz`, and `.tar.xz` when they contain a supported inner
  file
- Clipboard table paste from the Import menu

If the file type is not recognized, Decent Bench shows a clear message instead of guessing.

## The main areas

- **Schema Explorer** shows tables, views, columns, indexes, triggers, and relationships.
- **SQL Editor** is where you write and run queries.
- **Results Window** shows paged results so large queries stay responsive.
- **Properties / Details** shows more information about the selected object or result.
- **Status Bar** shows the current database and recent activity.

## Good first query

After opening a database, select a table in the schema explorer and try:

```sql
SELECT *
FROM your_table
LIMIT 100;
```

Use a small `LIMIT` while exploring unfamiliar data. It keeps the first result fast and easy to read.
