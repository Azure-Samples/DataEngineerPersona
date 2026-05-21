#!/usr/bin/env bash
# Local environment setup: SQL Server to PostgreSQL Migration
# Usage: ./scripts/setup-local-env.sh
# Bash equivalent of scripts/setup-local-env.ps1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env if it exists, otherwise fall back to .env.example
if [ -f "$REPO_ROOT/.env" ]; then
    set -a; source "$REPO_ROOT/.env"; set +a
elif [ -f "$REPO_ROOT/.env.example" ]; then
    echo "  No .env found — using defaults from .env.example"
    set -a; source "$REPO_ROOT/.env.example"; set +a
fi

SA_PASSWORD="${SA_PASSWORD:-Str0ngP@ssw0rd!}"
PG_PASSWORD="${PG_PASSWORD:-Str0ngP@ssw0rd!}"

echo ""
echo "============================================="
echo "  SQL Server to PostgreSQL - Local Setup"
echo "============================================="
echo ""

# Step 1: Check prerequisites
echo "[1/6] Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    echo "  ERROR: Docker not found. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo "  ERROR: Docker is not running. Start Docker and try again."
    exit 1
fi
echo "  Docker is running."

# Step 2: Create data directory for backup cache
echo "[2/6] Preparing data directory..."
DATA_DIR="$REPO_ROOT/data"
mkdir -p "$DATA_DIR"
echo "  ./data/ directory ready."

# Step 3: Start containers
echo "[3/6] Starting Docker containers..."

export SA_PASSWORD PG_PASSWORD

cd "$REPO_ROOT"
docker compose up -d

echo "  Containers started."

# Step 4: Wait for SQL Server to be healthy
echo "[4/6] Waiting for SQL Server to be ready..."
MAX_ATTEMPTS=30
for i in $(seq 1 $MAX_ATTEMPTS); do
    if docker exec wwi-sqlserver /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" -C -Q "SELECT 1" -b &>/dev/null; then
        echo "  SQL Server is ready."
        break
    fi
    if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
        echo "  ERROR: SQL Server did not start within $((MAX_ATTEMPTS * 10)) seconds."
        echo "  Check: docker logs wwi-sqlserver"
        exit 1
    fi
    echo "  Attempt $i/$MAX_ATTEMPTS - waiting 10s..."
    sleep 10
done

# Step 5: Download and restore WideWorldImporters
echo "[5/6] Setting up WideWorldImporters database..."

BAK_PATH="$DATA_DIR/WideWorldImporters-Full.bak"
BAK_URL="https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak"

if [ ! -f "$BAK_PATH" ]; then
    echo "  Downloading WideWorldImporters-Full.bak (~120MB)..."
    curl -L -o "$BAK_PATH" "$BAK_URL"
    echo "  Download complete."
else
    echo "  Backup already cached at ./data/WideWorldImporters-Full.bak"
fi

# Check if database already exists
DB_EXISTS=$(docker exec wwi-sqlserver /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C \
    -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = 'WideWorldImporters'" \
    -h -1 -b 2>/dev/null | tr -d '[:space:]')

if [ "$DB_EXISTS" = "1" ]; then
    echo "  WideWorldImporters already restored. Skipping."
else
    echo "  Restoring WideWorldImporters database..."
    docker exec wwi-sqlserver /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
        RESTORE DATABASE WideWorldImporters
        FROM DISK = '/backup/WideWorldImporters-Full.bak'
        WITH MOVE 'WWI_Primary' TO '/var/opt/mssql/data/WideWorldImporters.mdf',
             MOVE 'WWI_UserData' TO '/var/opt/mssql/data/WideWorldImporters_UserData.ndf',
             MOVE 'WWI_Log' TO '/var/opt/mssql/data/WideWorldImporters.ldf',
             MOVE 'WWI_InMemory_Data_1' TO '/var/opt/mssql/data/WideWorldImporters_InMemory.ndf',
             REPLACE;
    " -b

    if [ $? -ne 0 ]; then
        echo "  ERROR: Database restore failed."
        echo "  Check: docker logs wwi-sqlserver"
        exit 1
    fi
    echo "  Restore complete."
fi

# Step 6: Wait for PostgreSQL and verify
echo "[6/6] Verifying PostgreSQL..."
MAX_ATTEMPTS=15
for i in $(seq 1 $MAX_ATTEMPTS); do
    if docker exec wwi-postgres pg_isready -U wwi_user -d wide_world_importers &>/dev/null; then
        echo "  PostgreSQL is ready."
        break
    fi
    if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
        echo "  ERROR: PostgreSQL did not start."
        exit 1
    fi
    sleep 5
done

# Verify schemas were created
PG_SCHEMAS=$(docker exec wwi-postgres psql -U wwi_user -d wide_world_importers -t -c \
    "SELECT string_agg(schema_name, ', ' ORDER BY schema_name) FROM information_schema.schemata WHERE schema_name IN ('warehouse','sales','purchasing','application','integration','sequences','website');" 2>&1)
echo "  PostgreSQL schemas: $(echo "$PG_SCHEMAS" | xargs)"

# Summary
echo ""
echo "============================================="
echo "  Local Environment Ready!"
echo "============================================="
echo ""
echo "  SQL Server:  localhost,1433  |  sa / $SA_PASSWORD  |  DB: WideWorldImporters"
echo "  PostgreSQL:  localhost:5432  |  wwi_user / $PG_PASSWORD  |  DB: wide_world_importers"
echo ""
echo "  Next steps:"
echo "    1. Connect to SQL Server via MSSQL extension"
echo "    2. Connect to PostgreSQL via PG extension"
echo "    3. Run: /db-migrate samples/wide-world-importers"
echo ""
echo "  Useful commands:"
echo "    docker compose ps          # Check container status"
echo "    docker compose logs -f     # Tail container logs"
echo "    docker compose down        # Stop containers"
echo "    docker compose down -v     # Stop + delete volumes (full reset)"
echo ""
