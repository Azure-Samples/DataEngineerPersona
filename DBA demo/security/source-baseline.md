# SQL Server Security Baseline

Capture this baseline BEFORE migration using MSSQL extension.

## Queries to Run (via mssql_run_query)

### Authentication
```sql
SELECT name, type_desc, is_disabled, create_date, modify_date
FROM sys.sql_logins
ORDER BY name;
```

### Permissions
```sql
SELECT
  pr.name AS principal_name,
  pr.type_desc AS principal_type,
  pe.permission_name,
  pe.state_desc
FROM sys.server_permissions pe
JOIN sys.server_principals pr ON pe.grantee_principal_id = pr.principal_id
ORDER BY pr.name;
```

### Encryption Status
```sql
SELECT name, is_encrypted, is_master_key_encrypted_by_server
FROM sys.databases;
```

### Audit Configuration
```sql
SELECT name, status_desc, audit_file_path
FROM sys.server_audits;
```

## Baseline Metrics

| Metric | Value | Notes |
|---|---|---|
| SQL logins (non-AD) | *TBD* | Count of password-based logins |
| Plaintext conn strings | *TBD* | Check Web.config, app.config |
| TDE enabled | *TBD* | Transparent Data Encryption |
| Audit enabled | *TBD* | SQL Server Audit |
| Firewall rules | *TBD* | Open ports/IPs |
