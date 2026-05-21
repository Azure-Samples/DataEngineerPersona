#!/usr/bin/env bash
# Execute the migration
# Usage: ./scripts/run-migration.sh [--config <path>] [--dry-run]
# Bash equivalent of scripts/run-migration.ps1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults
PGLOADER_CONFIG="samples/wide-world-importers/migration-scripts/pgloader.conf"
DRY_RUN=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config) PGLOADER_CONFIG="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --execute) DRY_RUN=false; shift ;;
        -h|--help)
            echo "Usage: $0 [--config <path>] [--dry-run|--execute]"
            echo "  --dry-run   Validate only (default)"
            echo "  --execute   Run actual data migration"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Phase 2: Migration Execution ==="
echo "pgLoader config: $PGLOADER_CONFIG"
echo ""

# Step 1: pgLoader dry run
if ! command -v pgloader &>/dev/null; then
    echo "pgLoader not found. Install: https://pgloader.io"
    exit 1
fi

echo "[1/3] Running pgLoader dry-run (validation only)..."
pgloader --dry-run "$PGLOADER_CONFIG" 2>&1
echo "  Dry-run complete. Review output for type mapping issues."

if [ "$DRY_RUN" = false ]; then
    echo ""
    read -rp "Proceed with actual data migration? (y/N) " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "[2/3] Running pgLoader data transfer..."
        pgloader "$PGLOADER_CONFIG" 2>&1
        echo "  Data transfer complete."
    else
        echo "  Migration aborted by user."
        exit 0
    fi
fi

# Step 2: sqlfluff lint
if command -v sqlfluff &>/dev/null; then
    echo "[3/3] Linting PL/pgSQL with sqlfluff..."
    sqlfluff lint samples/wide-world-importers/migration-scripts/tsql-to-plpgsql/ --dialect postgres 2>&1
else
    echo "[3/3] sqlfluff not found - skipping (install: pip install sqlfluff)"
fi

echo ""
echo "Migration execution complete. Run ./scripts/validate-migration.sh for Phase 3."
