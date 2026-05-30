# Exporting Results

Exports let you move shaped data out of Decent Bench after you have inspected or queried it.

## Export query results

Use the **Export** menu to export the active result set. This is the usual path after you write a query that produces the exact rows and columns you want.

Available result export formats depend on the current build. CSV, JSON, and Excel are app-owned export paths. Parquet is planned but intentionally not enabled until the app has a dedicated Parquet implementation.

## Export a table

Use table export when you want data from one table without writing a custom query. If you need filtering, sorting, joins, or renamed columns, write a query first and export the results instead.

## Export schema SQL

Use schema export when you need a readable description of database structure. Schema SQL is useful for review, notes, and sharing the shape of a database without sharing all row data.

## Export an ERD image

Use **Tools > Export ERD Image** when you need a visual relationship diagram. This is useful in documentation, data review, or planning conversations.

## Export a quality report

Use **Tools > Export Quality Report** after running a quality profile. Quality
reports are available as Markdown, HTML, or JSON. Failing row sample values are
redacted by default; enable sample values only when the report destination is
allowed to contain source data.

## Choose the right format

- **CSV** is simple and works almost everywhere.
- **JSON** is useful for structured records and downstream tooling.
- **Excel** is useful when the recipient expects a spreadsheet.
- **Quality reports** are best for review and trust checks after imports.
- **Parquet** is best for analytics pipelines and large typed datasets, but it is not enabled yet.

## Before exporting

Check the result grid first:

- Are the rows correct?
- Are column names readable?
- Are dates and numbers in the expected shape?
- Did you include only the fields you need?

Exporting is easier to trust when the visible result already matches your intent.
