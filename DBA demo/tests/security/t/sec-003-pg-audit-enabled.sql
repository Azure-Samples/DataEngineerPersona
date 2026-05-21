-- sec-003: pgAudit enabled
-- Verify pgaudit is in shared_preload_libraries
BEGIN;
SELECT plan(1);

SELECT ok(
  current_setting('shared_preload_libraries') LIKE '%pgaudit%',
  'pgAudit should be loaded in shared_preload_libraries'
);

SELECT * FROM finish();
ROLLBACK;
