# Performance Test Results

This directory stores timestamped JSON results from each migration iteration.

## How Results Are Tracked

Each run of `run-performance-tests.sh` produces a JSON file:
- `run-001-20260325.json` - Baseline after initial pgLoader migration
- `run-002-20260326.json` - After ora2pg-suggested indexes
- `run-003-20260327.json` - After cursor-to-CTE rewrites
- `run-004-20260328.json` - After PgBouncer connection pooling

## Trending

The `trending.md` file is auto-generated after each run showing:
- Execution time per test across iterations (line chart)
- Improvement percentage per SP migration (bar chart)
- Overall migration readiness score
