# Exploring Schema

The schema explorer helps you understand what is inside the open database before you write SQL.

## What you can inspect

Depending on the database, the schema explorer can show:

- Tables and views
- Columns and column types
- Indexes
- Triggers
- Constraints
- Generated column details
- Relationships used by the ERD view

Select an object to see more detail in **Properties / Details**.

## Tables and columns

Start with tables and columns when you are learning a new database. Check names, data types, and likely key columns before writing joins or filters.

## Views

Views appear alongside tables. Treat them like saved queries that can be selected from, unless the database reports a limitation.

## Indexes and constraints

Indexes and constraints help explain how a database is organized:

- Indexes often point to columns used for lookup or sorting.
- Primary keys identify rows.
- Foreign keys describe relationships between tables.

## ERD view

Use **Tools > Entity Relationship Diagram** to open a read-only relationship view. This is for understanding and navigation, not schema design.

You can export the diagram as an image when you need to include it in notes or share it with someone else.

## When schema details are missing

Some details depend on what the current DecentDB binding exposes. When a detail is unavailable, Decent Bench should keep the rest of schema browsing usable and show a clear message instead of failing the whole view.
