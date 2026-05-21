-- Verify migration: total rows in PostgreSQL across migrated schemas
SELECT
    table_schema || '.' || table_name AS table_name,
    (xpath('/row/c/text()', xml_count))[1]::text::int AS rows
FROM (
    SELECT
        table_name,
        table_schema,
        query_to_xml(format('SELECT count(*) AS c FROM %I.%I', table_schema, table_name), false, true, '') AS xml_count
    FROM information_schema.tables
    WHERE table_schema IN ('application','purchasing','sales','warehouse')
      AND table_type = 'BASE TABLE'
) t
ORDER BY table_schema, table_name;
