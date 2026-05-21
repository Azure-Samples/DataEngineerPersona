-- List PL/pgSQL functions installed by migration
SELECT n.nspname AS schema, p.proname AS function
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('application','sales','warehouse','website')
ORDER BY 1,2;
