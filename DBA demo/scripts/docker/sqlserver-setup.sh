#!/bin/bash
# SQL Server setup: download and restore WideWorldImporters backup
# Run inside the sqlserver container or from host via:
#   docker exec wwi-sqlserver bash /backup/sqlserver-setup.sh

set -e

SA_PASSWORD="${SA_PASSWORD:-Str0ngP@ssw0rd!}"
BAK_URL="https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak"
BAK_PATH="/backup/WideWorldImporters-Full.bak"

echo "=== WideWorldImporters Setup ==="

# Wait for SQL Server to be ready
echo "[1/3] Waiting for SQL Server..."
for i in $(seq 1 30); do
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -Q "SELECT 1" -b > /dev/null 2>&1; then
        echo "  SQL Server is ready."
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "  ERROR: SQL Server did not start within 300 seconds."
        exit 1
    fi
    echo "  Attempt $i/30 - waiting 10s..."
    sleep 10
done

# Download backup if not already cached
echo "[2/3] Checking for WideWorldImporters backup..."
if [ -f "$BAK_PATH" ]; then
    echo "  Backup already exists at $BAK_PATH (cached). Skipping download."
else
    echo "  Downloading WideWorldImporters-Full.bak (~120MB)..."
    curl -L -o "$BAK_PATH" "$BAK_URL"
    echo "  Download complete."
fi

# Check if database already exists
DB_EXISTS=$(/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = 'WideWorldImporters'" -h -1 -b 2>/dev/null | tr -d '[:space:]')

if [ "$DB_EXISTS" = "1" ]; then
    echo "[3/3] WideWorldImporters database already exists. Skipping restore."
else
    echo "[3/3] Restoring WideWorldImporters database..."
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
        RESTORE DATABASE WideWorldImporters
        FROM DISK = '$BAK_PATH'
        WITH MOVE 'WWI_Primary' TO '/var/opt/mssql/data/WideWorldImporters.mdf',
             MOVE 'WWI_UserData' TO '/var/opt/mssql/data/WideWorldImporters_UserData.ndf',
             MOVE 'WWI_Log' TO '/var/opt/mssql/data/WideWorldImporters.ldf',
             MOVE 'WWI_InMemory_Data_1' TO '/var/opt/mssql/data/WideWorldImporters_InMemory.ndf',
             REPLACE;
    " -b
    echo "  Restore complete."
fi

# Verify
echo ""
echo "=== Verification ==="
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
    USE WideWorldImporters;
    SELECT 'Tables: ' + CAST(COUNT(*) AS VARCHAR) FROM sys.tables;
    SELECT 'Schemas: ' + STRING_AGG(name, ', ') FROM sys.schemas WHERE name IN ('Application','Purchasing','Sales','Warehouse','Website','Integration','Sequences');
" -b

echo ""
echo "=== WideWorldImporters is ready ==="
