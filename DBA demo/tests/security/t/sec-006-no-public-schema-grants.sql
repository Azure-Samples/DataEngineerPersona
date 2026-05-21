-- sec-006: PUBLIC schema locked
-- Verify PUBLIC role cannot CREATE in public schema
BEGIN;
SELECT plan(1);

SELECT ok(
  NOT has_schema_privilege('public', 'public', 'CREATE'),
  'PUBLIC role should not have CREATE privilege on public schema'
);

SELECT * FROM finish();
ROLLBACK;
