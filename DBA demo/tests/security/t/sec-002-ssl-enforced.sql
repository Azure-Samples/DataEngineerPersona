-- sec-002: SSL enforced
-- Verify SSL is enabled on the server
BEGIN;
SELECT plan(1);

SELECT is(
  current_setting('ssl'),
  'on',
  'SSL should be enabled on the PostgreSQL server'
);

SELECT * FROM finish();
ROLLBACK;
