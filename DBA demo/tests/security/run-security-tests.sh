#!/bin/bash
# Run all security pgtap tests
# Usage: ./run-security-tests.sh <database_name>

DB=${1:-wide_world_importers}

echo "=== Running Security Test Suite ==="
echo "Database: $DB"
echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

pg_prove -d "$DB" tests/security/t/*.sql --verbose

echo ""
echo "=== Security Test Suite Complete ==="
