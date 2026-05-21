-- sec-004: Least-privilege roles
-- Verify no application role has SUPERUSER, CREATEDB, or CREATEROLE
BEGIN;
SELECT plan(1);

SELECT is(
  (SELECT count(*) FROM pg_roles
   WHERE rolname NOT IN ('postgres', 'azure_pg_admin', 'azure_superuser', 'rds_superuser')
   AND (rolsuper = true OR rolcreatedb = true OR rolcreaterole = true))::integer,
  0,
  'No application role should have SUPERUSER, CREATEDB, or CREATEROLE privileges'
);

SELECT * FROM finish();
ROLLBACK;
