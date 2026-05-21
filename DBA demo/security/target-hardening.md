# PostgreSQL Target Hardening Guide

Apply these configurations to the Azure Database for PostgreSQL Flexible Server target.

## Authentication

### Entra ID Passwordless (Recommended)
```
# Connection string (no password!)
Host=eshop-pg.postgres.database.azure.com;
Database=wide_world_importers;
Username=app-managed-identity;
SSL Mode=Require;
```

### Azure CLI Setup
```bash
# Enable Entra ID admin
az postgres flexible-server ad-admin create \
  --resource-group myRG \
  --server-name myPGServer \
  --display-name "DBA Team" \
  --object-id <entra-group-id>
```

## pgAudit Extension

```sql
-- Enable via Azure Portal: Server Parameters -> shared_preload_libraries -> add pgaudit
-- Then:
CREATE EXTENSION pgaudit;
ALTER SYSTEM SET pgaudit.log = 'all';
SELECT pg_reload_conf();
```

## Network Security

```bash
# Remove any 0.0.0.0/0 rules
az postgres flexible-server firewall-rule list \
  --resource-group myRG \
  --name myPGServer

# Use Private Link instead
az postgres flexible-server private-link create \
  --resource-group myRG \
  --server-name myPGServer \
  --private-link-name myPL \
  --vnet myVNet \
  --subnet mySubnet
```

## PUBLIC Schema Lockdown

```sql
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE wide_world_importers FROM PUBLIC;
```

## Role-Based Access

```sql
-- Application role (read-write on specific schemas)
CREATE ROLE app_user LOGIN;
GRANT USAGE ON SCHEMA warehouse, sales, purchasing TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA warehouse TO app_user;

-- Read-only analytics role
CREATE ROLE analytics_reader LOGIN;
GRANT USAGE ON SCHEMA warehouse, sales, purchasing TO analytics_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA warehouse, sales, purchasing TO analytics_reader;
```

## Microsoft Defender

```bash
# Enable Defender for Open-Source Relational DBs
az security pricing create \
  --name OpenSourceRelationalDatabases \
  --tier Standard
```
