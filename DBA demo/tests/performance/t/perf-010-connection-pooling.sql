-- perf-010: Connection pooling throughput
-- This test measures PgBouncer effectiveness.
-- Run via pgbench with PgBouncer in front:
--   pgbench -c 50 -j 4 -T 60 -h localhost -p 6432 wide_world_importers
-- Compare TPS with direct connection:
--   pgbench -c 50 -j 4 -T 60 -h localhost -p 5432 wide_world_importers
SELECT 'Run via pgbench with and without PgBouncer - see benchmarks/pgbench/' AS note;
