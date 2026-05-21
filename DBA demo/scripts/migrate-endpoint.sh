#!/usr/bin/env bash
# =============================================================================
# Generic SQL Server → PostgreSQL Migration (Bring Your Own Endpoint)
#
# Use this script when migrating ANY customer SQL Server to ANY PostgreSQL.
# Uses pgloader for the bulk transfer.
#
# For the WideWorldImporters local demo (Docker), use migrate-data.sh instead.
#
# Connection strings come from .env. Required:
#   SQLSERVER_HOST, SQLSERVER_PORT, SQLSERVER_DB, SQLSERVER_USER, SQLSERVER_PASSWORD
#   PG_HOST,        PG_PORT,        PG_DB,        PG_USER,        PG_PASSWORD
#
# Usage:
#   bash scripts/migrate-endpoint.sh                  # full migration
#   bash scripts/migrate-endpoint.sh --dry-run        # validate only
#   bash scripts/migrate-endpoint.sh --schema-only    # tables/views only
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ------------------------------------------------------------------
# Load .env
# ------------------------------------------------------------------
if [ -f "$REPO_ROOT/.env" ]; then
    set -a; source "$REPO_ROOT/.env"; set +a
elif [ -f "$REPO_ROOT/.env.example" ]; then
    echo "  No .env found — using defaults from .env.example"
    set -a; source "$REPO_ROOT/.env.example"; set +a
else
    echo "ERROR: No .env or .env.example found. Copy .env.example to .env and edit." >&2
    exit 1
fi

# ------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------
DRY_RUN=false
SCHEMA_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)     DRY_RUN=true; shift ;;
        --schema-only) SCHEMA_ONLY=true; shift ;;
        -h|--help)
            sed -n '1,20p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ------------------------------------------------------------------
# Resolve connection variables
# ------------------------------------------------------------------
: "${SQLSERVER_HOST:?SQLSERVER_HOST is required (set in .env)}"
: "${SQLSERVER_PORT:=1433}"
: "${SQLSERVER_DB:?SQLSERVER_DB is required (set in .env)}"
: "${SQLSERVER_USER:=sa}"
: "${SQLSERVER_PASSWORD:?SQLSERVER_PASSWORD is required (set in .env)}"

: "${PG_HOST:?PG_HOST is required (set in .env)}"
: "${PG_PORT:=5432}"
: "${PG_DB:?PG_DB is required (set in .env)}"
: "${PG_USER:?PG_USER is required (set in .env)}"
: "${PG_PASSWORD:?PG_PASSWORD is required (set in .env)}"

# Map the common .env names (set by .env.example for the demo) to BYO names
# This lets demo defaults like SA_PASSWORD work when SQLSERVER_PASSWORD is unset.
SQLSERVER_PASSWORD="${SQLSERVER_PASSWORD:-${SA_PASSWORD:-}}"

echo ""
echo "============================================="
echo "  SQL Server → PostgreSQL (BYO endpoint)"
echo "============================================="
echo ""
echo "  Source: $SQLSERVER_USER@$SQLSERVER_HOST:$SQLSERVER_PORT/$SQLSERVER_DB"
echo "  Target: $PG_USER@$PG_HOST:$PG_PORT/$PG_DB"
echo ""

# ------------------------------------------------------------------
# Preflight: pgloader installed?
# ------------------------------------------------------------------
if ! command -v pgloader >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: pgloader not found.

Install:
  Ubuntu/Debian:  sudo apt-get install -y pgloader
  macOS (brew):   brew install pgloader
  Docker:         alias pgloader='docker run --rm -i dimitri/pgloader pgloader'
  Docs:           https://pgloader.io
EOF
    exit 127
fi

# ------------------------------------------------------------------
# Generate pgloader config from template
# ------------------------------------------------------------------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PGLOADER_CONF="$TMP_DIR/migration.load"

INCLUDE_DATA="INCLUDING ONLY TABLE NAMES MATCHING ~/./"
if [ "$SCHEMA_ONLY" = true ]; then
    INCLUDE_DATA="WITH no data, create tables, create indexes, reset sequences"
fi

# URL-encode the SQL Server password (pgloader connection URI safe)
SQLSERVER_PASSWORD_ENC="$(printf '%s' "$SQLSERVER_PASSWORD" | sed -e 's/@/%40/g' -e 's/:/%3A/g' -e 's/\//%2F/g' -e 's/?/%3F/g' -e 's/#/%23/g' -e 's/!/%21/g')"
PG_PASSWORD_ENC="$(printf '%s' "$PG_PASSWORD" | sed -e 's/@/%40/g' -e 's/:/%3A/g' -e 's/\//%2F/g' -e 's/?/%3F/g' -e 's/#/%23/g' -e 's/!/%21/g')"

cat > "$PGLOADER_CONF" <<EOF
LOAD DATABASE
     FROM mssql://$SQLSERVER_USER:$SQLSERVER_PASSWORD_ENC@$SQLSERVER_HOST:$SQLSERVER_PORT/$SQLSERVER_DB
     INTO postgresql://$PG_USER:$PG_PASSWORD_ENC@$PG_HOST:$PG_PORT/$PG_DB

 WITH include drop, create tables, create indexes, reset sequences,
      foreign keys, downcase identifiers, uniquify index names

 SET work_mem to '128MB',
     maintenance_work_mem to '512 MB',
     search_path to 'public'

 CAST type bit when (= 1 precision) to boolean drop typemod,
      type uniqueidentifier to uuid drop typemod,
      type nvarchar to text drop typemod,
      type nchar to text drop typemod,
      type datetime2 to timestamptz drop typemod,
      type datetimeoffset to timestamptz drop typemod,
      type money to numeric drop typemod,
      type smallmoney to numeric drop typemod,
      type tinyint to smallint drop typemod,
      type hierarchyid to text drop typemod,
      type geography to text drop typemod,
      type geometry to text drop typemod
;
EOF

# ------------------------------------------------------------------
# Run
# ------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    echo "[1/2] pgloader dry-run (validation only)..."
    pgloader --dry-run "$PGLOADER_CONF"
    echo ""
    echo "Dry-run complete. Re-run without --dry-run to perform the migration."
    exit 0
fi

echo "[1/2] Running pgloader..."
pgloader "$PGLOADER_CONF"

echo ""
echo "[2/2] Verifying target..."
PGPASSWORD="$PG_PASSWORD" psql \
    -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" \
    -c "SELECT table_schema, COUNT(*) AS tables FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema') GROUP BY table_schema ORDER BY table_schema;"

echo ""
echo "============================================="
echo "  BYO Migration complete!"
echo "============================================="
echo ""
echo "  Next steps:"
echo "    1. Run pgtap tests:         pg_prove -d \"postgresql://$PG_USER@$PG_HOST/$PG_DB\" tests/pgtap/t/"
echo "    2. Run row-count compare:   psql ... -f tests/row-count-comparison/compare.sql"
echo "    3. Use the agent in Copilot Chat: /db-migrate"
echo ""
