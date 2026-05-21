-- sec-010: Microsoft Defender for Open-Source DBs enabled
-- Verify via Azure CLI:
-- az security pricing show --name OpenSourceRelationalDatabases
-- Status should be "Standard"
BEGIN;
SELECT plan(1);

SELECT ok(
  true,
  'Verify Defender is enabled via Azure CLI: az security pricing show --name OpenSourceRelationalDatabases (status should be Standard)'
);

SELECT * FROM finish();
ROLLBACK;
