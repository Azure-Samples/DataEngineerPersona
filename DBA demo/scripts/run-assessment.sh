#!/usr/bin/env bash
# Run source database assessment
# Usage: ./scripts/run-assessment.sh --connection-string "Server=localhost;Database=WideWorldImporters;..."
# Bash equivalent of scripts/run-assessment.ps1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults
CONNECTION_STRING=""
OUTPUT_DIR="docs"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --connection-string) CONNECTION_STRING="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 --connection-string <conn> [--output-dir <dir>]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -z "$CONNECTION_STRING" ]; then
    echo "ERROR: --connection-string is required"
    echo "Usage: $0 --connection-string \"Server=localhost;Database=WideWorldImporters;Trusted_Connection=True;\""
    exit 1
fi

echo "=== Phase 1: Source Database Assessment ==="
echo "Connection: ${CONNECTION_STRING:0:50}..."
echo "Output: $OUTPUT_DIR/"
echo ""

# Step 1: ora2pg assessment (if available)
if command -v ora2pg &>/dev/null; then
    echo "[1/4] Running ora2pg assessment..."
    ora2pg -t SHOW_REPORT -c samples/wide-world-importers/ora2pg.conf 2>&1 | tee "$OUTPUT_DIR/ora2pg-report.txt"
else
    echo "[1/4] ora2pg not found - skipping (install: https://ora2pg.darold.net)"
fi

# Step 2: DAB entity discovery (if available)
if command -v dab &>/dev/null; then
    echo "[2/4] Running DAB entity discovery..."
    export SQLSERVER_CONN="$CONNECTION_STRING"
    dab init --database-type mssql --connection-string "@env('SQLSERVER_CONN')" \
        --host-mode development --config dab/dab-config-discovery.json 2>&1
    echo "  DAB entity discovery complete. Review dab/dab-config-discovery.json"
else
    echo "[2/4] DAB CLI not found - skipping (install: dotnet tool install microsoft.dataapibuilder -g)"
fi

# Step 3: sec-check baseline (if available)
if command -v agentsec &>/dev/null; then
    echo "[3/4] Running sec-check security baseline..."
    agentsec scan samples/ --output security/sec-check-results/source-scan.json 2>&1
else
    echo "[3/4] sec-check not found - skipping (install from sec-check repo)"
fi

echo "[4/4] Assessment complete."
echo ""
echo "Next steps:"
echo "  1. Connect to source DB via MSSQL extension in VS Code"
echo "  2. Run /db-migrate in Copilot Chat for full agent-driven assessment"
echo "  3. Or run ./scripts/run-migration.sh for Phase 2"
