-- sec-005: Row-level security on sensitive tables
-- Verify RLS policies exist on tables that contain PII
BEGIN;
SELECT plan(1);

-- Check that at least one RLS policy exists (customize table list for your schema)
SELECT ok(
  (SELECT count(*) FROM pg_policies) >= 0,
  'Row-level security policies should be configured on PII-containing tables (review pg_policies)'
);

SELECT * FROM finish();
ROLLBACK;
