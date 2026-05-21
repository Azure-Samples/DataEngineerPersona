-- sec-007: Parameterized queries only
-- Verify PL/pgSQL functions do not use string concatenation in EXECUTE
-- This is a static analysis check - review function source code
BEGIN;
SELECT plan(1);

SELECT is(
  (SELECT count(*) FROM pg_proc p
   JOIN pg_namespace n ON p.pronamespace = n.oid
   WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
   AND p.prosrc LIKE '%EXECUTE%||%')::integer,
  0,
  'No PL/pgSQL functions should use string concatenation (||) inside EXECUTE statements'
);

SELECT * FROM finish();
ROLLBACK;
