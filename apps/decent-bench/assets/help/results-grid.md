# Reading Query Results

The results grid shows query output without assuming the whole result set should be loaded at once.

## Paged results

Decent Bench uses paged result loading so large queries remain manageable. You can inspect early rows quickly, then continue paging if you need more.

## Why paging matters

Large result sets can contain thousands or millions of rows. Loading every row into memory would make the app slow and could make your computer work harder than necessary.

Paging keeps common workflows fast:

- Preview a table
- Check whether a filter is correct
- Inspect a few suspicious rows
- Export the final query when ready

## Read columns carefully

Imported files sometimes contain surprising column names or mixed values. If the results do not look right, check:

- Column order
- Empty values
- Text that should be numeric
- Date-like values that may still be text
- Duplicate column names from joins

## Use SQL to shape results

The grid is for viewing. Use SQL to sort, filter, rename, join, and compute values before exporting.

Examples:

```sql
SELECT
  artist_name AS artist,
  album_count
FROM artist_summary
ORDER BY album_count DESC
LIMIT 100;
```

## When results are empty

An empty grid usually means the query ran successfully but returned no rows. Check filters, joins, and date ranges first.
