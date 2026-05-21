-- sec-001: No plaintext credentials
-- Verify all password hashes in pg_authid use SCRAM-SHA-256
BEGIN;
SELECT plan(1);

SELECT is(
  (SELECT count(*) FROM pg_authid
   WHERE rolpassword IS NOT NULL
   AND rolpassword NOT LIKE 'SCRAM-SHA-256$%')::integer,
  0,
  'All passwords should use SCRAM-SHA-256 hashing'
);

SELECT * FROM finish();
ROLLBACK;
