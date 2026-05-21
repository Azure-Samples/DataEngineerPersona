# WideWorldImporters Sample Database

Microsoft's official SQL Server sample database used as the demo target for this migration accelerator.

## Download

- **Full backup (.bak):** [aka.ms/WideWorldImporters](https://aka.ms/WideWorldImporters)
- **Source repo:** [microsoft/sql-server-samples](https://github.com/microsoft/sql-server-samples/tree/master/samples/databases/wide-world-importers)

## Database Profile

| Property | Value |
|---|---|
| Schemas | Application, Purchasing, Sales, Warehouse |
| Tables | 15+ (with temporal/system-versioned) |
| Stored Procedures | 30+ |
| Views | 10+ |
| Triggers | Multiple (temporal table maintenance) |
| Special Types | HIERARCHYID, GEOGRAPHY, JSON columns |
| Database Size | ~120 MB (full sample) |

## Why WideWorldImporters?

Ideal for migration demos because it contains:
- **Complex stored procedures** with business logic
- **Temporal tables** (system-versioned) that require special migration handling
- **HIERARCHYID** columns that have no direct PostgreSQL equivalent
- **GEOGRAPHY** columns requiring PostGIS
- **JSON columns** (custom fields stored as NVARCHAR(MAX) with JSON)
- **Multiple schemas** testing cross-schema migration

## Setup

The recommended way is the one-click setup script which runs Docker containers and restores the backup automatically. From the dev container (or any bash shell with Docker available):

```bash
bash scripts/setup-local-env.sh
bash scripts/migrate-data.sh
```

If you need to restore manually inside the SQL Server Docker container:

```sql
RESTORE DATABASE WideWorldImporters
FROM DISK = '/backup/WideWorldImporters-Full.bak'
WITH MOVE 'WWI_Primary' TO '/var/opt/mssql/data/WideWorldImporters.mdf',
     MOVE 'WWI_UserData' TO '/var/opt/mssql/data/WideWorldImporters_UserData.ndf',
     MOVE 'WWI_Log' TO '/var/opt/mssql/data/WideWorldImporters.ldf',
     MOVE 'WWI_InMemory_Data_1' TO '/var/opt/mssql/data/WideWorldImporters_InMemory.ndf';
```

> The paths above are for the SQL Server Docker container (`wwi-sqlserver`). The backup is bind-mounted at `/backup/` from the `./data/` directory on your host.
