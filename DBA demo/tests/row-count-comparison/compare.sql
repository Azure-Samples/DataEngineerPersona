-- Row count comparison queries
-- Run these on BOTH SQL Server (via MSSQL ext) and PostgreSQL (via PG ext)
-- Compare results - all counts must match

-- PostgreSQL version:
SELECT
  schemaname || '.' || relname AS table_name,
  n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY schemaname, relname;

-- SQL Server equivalent (run via mssql_run_query):
-- SELECT
--   SCHEMA_NAME(t.schema_id) + '.' + t.name AS table_name,
--   SUM(p.rows) AS row_count
-- FROM sys.tables t
-- JOIN sys.partitions p ON t.object_id = p.object_id
-- WHERE p.index_id IN (0, 1)
-- GROUP BY SCHEMA_NAME(t.schema_id), t.name
-- ORDER BY table_name;
