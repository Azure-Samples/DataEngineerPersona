-- perf-008: Concurrent load test
-- This test is run via HammerDB TPC-C, not directly.
-- See benchmarks/hammerdb/ for TPC-C configurations.
-- This file documents the expected test parameters:
--   Virtual Users: 50
--   Ramp-up: 30 seconds
--   Duration: 5 minutes
--   Metrics: TPS, avg response time, 95th percentile latency
SELECT 'Run via HammerDB TPC-C - see benchmarks/hammerdb/' AS note;
