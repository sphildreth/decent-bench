# Opening and Creating Workspaces

A workspace is one open DecentDB database file plus the app state around it: query tabs, schema selection, recent files, and layout choices.

## Open a database

Use **File > Open** to choose an existing `.ddb` file. Decent Bench opens one database at a time, which keeps the app focused and makes file operations predictable.

Recent files are available from **File > Open Recent**.

## Create a database

Use **File > New** to create a new `.ddb` file. A new database starts empty. You can import data, run SQL to create tables, or paste SQL from another tool.

## Save and Save As

DecentDB writes database changes directly to the database file. **File > Save** is still available as a clear confirmation point for the current workspace.

Use **File > Save As** when you want a copy of the current database. Decent Bench copies the database file and any active sidecar files that belong with it.

## Close a workspace

Use **File > Close** to close the current database while leaving the app open. This clears schema and result state so the next open starts cleanly.

## Legacy DecentDB files

If a file was created by an older DecentDB format and needs migration, Decent Bench offers a copy-based migration flow. The original file is left untouched, and the migrated copy is opened after the migration completes.

## Practical file safety

- Keep important `.ddb` files in a normal folder, not a temporary download folder.
- Do not delete sidecar files while the database is open.
- Use **Save As** before risky experiments if you want an easy fallback copy.
