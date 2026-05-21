#!/bin/bash
# Run all performance tests and output JSON results
# Usage: ./run-performance-tests.sh <database_name> [iteration_name]

DB=${1:-wide_world_importers}
ITERATION=${2:-run-$(date +%Y%m%d-%H%M%S)}
OUTDIR="tests/performance/results"

mkdir -p "$OUTDIR"

echo "=== Running Performance Test Suite ==="
echo "Database: $DB"
echo "Iteration: $ITERATION"
echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

RESULT_FILE="$OUTDIR/$ITERATION.json"

echo '{' > "$RESULT_FILE"
echo '  "iteration": "'"$ITERATION"'",' >> "$RESULT_FILE"
echo '  "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",' >> "$RESULT_FILE"
echo '  "database": "'"$DB"'",' >> "$RESULT_FILE"
echo '  "tests": [' >> "$RESULT_FILE"

for f in tests/performance/t/perf-*.sql; do
  TEST_ID=$(basename "$f" .sql)
  echo "  Running $TEST_ID..."

  # Run the query and capture EXPLAIN ANALYZE output
  START=$(date +%s%3N)
  psql -d "$DB" -f "$f" -q > /dev/null 2>&1
  END=$(date +%s%3N)
  ELAPSED=$((END - START))

  echo "    {\"test_id\": \"$TEST_ID\", \"execution_time_ms\": $ELAPSED}," >> "$RESULT_FILE"
done

echo '  ]' >> "$RESULT_FILE"
echo '}' >> "$RESULT_FILE"

echo ""
echo "Results saved to: $RESULT_FILE"
echo "=== Performance Test Suite Complete ==="
