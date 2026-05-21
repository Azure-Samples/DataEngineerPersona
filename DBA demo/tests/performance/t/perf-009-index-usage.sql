-- perf-009: Index usage ratio
-- Check that indexes are being used (not seq scans)
SELECT
  schemaname,
  relname AS table_name,
  idx_scan AS index_scans,
  seq_scan AS sequential_scans,
  CASE
    WHEN (idx_scan + seq_scan) = 0 THEN 0
    ELSE ROUND(100.0 * idx_scan / (idx_scan + seq_scan), 1)
  END AS index_usage_pct
FROM pg_stat_user_tables
WHERE (idx_scan + seq_scan) > 0
ORDER BY index_usage_pct ASC;
