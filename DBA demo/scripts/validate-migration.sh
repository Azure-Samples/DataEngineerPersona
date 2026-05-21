#!/usr/bin/env bash
# Validate the migration
# Usage: ./scripts/validate-migration.sh [--database <name>] [--iteration <label>]
# Bash equivalent of scripts/validate-migration.ps1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults
DATABASE="wide_world_importers"
ITERATION="run-$(date +%Y%m%d-%H%M%S)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --database) DATABASE="$2"; shift 2 ;;
        --iteration) ITERATION="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--database <name>] [--iteration <label>]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Phase 3: Migration Validation ==="
echo "Database: $DATABASE"
echo "Iteration: $ITERATION"
echo ""

# Step 1: pgtap functional tests
if command -v pg_prove &>/dev/null; then
    echo "[1/4] Running pgtap functional tests..."
    pg_prove -d "$DATABASE" tests/pgtap/t/*.sql --verbose 2>&1
else
    echo "[1/4] pg_prove not found - skipping"
fi

# Step 2: Security tests
if command -v pg_prove &>/dev/null; then
    echo "[2/4] Running security tests..."
    pg_prove -d "$DATABASE" tests/security/t/*.sql --verbose 2>&1
else
    echo "[2/4] pg_prove not found - skipping"
fi

# Step 3: Performance tests
echo "[3/4] Running performance tests..."
if [ -f tests/performance/run-performance-tests.sh ]; then
    bash tests/performance/run-performance-tests.sh "$DATABASE" "$ITERATION" 2>&1
else
    echo "  Performance test runner not found"
fi

# Step 4: Row count comparison
echo "[4/4] Row count comparison..."
if command -v psql &>/dev/null; then
    psql -d "$DATABASE" -f tests/row-count-comparison/compare.sql 2>&1
else
    echo "  psql not found - run row count comparison manually"
fi

echo ""
echo "Validation complete. Check results in tests/performance/results/$ITERATION.json"
