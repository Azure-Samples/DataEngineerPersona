#!/bin/bash
# pgbench benchmark for PostgreSQL
# Usage: ./run-benchmark.sh [database] [duration_seconds]

DB=${1:-wide_world_importers}
DURATION=${2:-60}

echo "=== pgbench Benchmark ==="
echo "Database: $DB"
echo "Duration: ${DURATION}s"
echo ""

echo "--- Standard TPC-B (built-in) ---"
pgbench -i -s 10 "$DB" 2>&1
pgbench -c 10 -j 2 -T "$DURATION" "$DB" 2>&1

echo ""
echo "--- High Concurrency (50 clients) ---"
pgbench -c 50 -j 4 -T "$DURATION" "$DB" 2>&1

echo ""
echo "--- With PgBouncer (if available on port 6432) ---"
pgbench -c 50 -j 4 -T "$DURATION" -h localhost -p 6432 "$DB" 2>&1 || echo "PgBouncer not available on port 6432"

echo ""
echo "=== Benchmark Complete ==="
