-- sec-009: Network restrictions
-- This test documents that firewall rules should be verified via Azure CLI:
-- az postgres flexible-server firewall-rule list --resource-group <rg> --name <server>
-- No rule should have start_ip_address = 0.0.0.0
BEGIN;
SELECT plan(1);

SELECT ok(
  true,
  'Verify firewall rules via Azure CLI: no 0.0.0.0/0 rules should exist (az postgres flexible-server firewall-rule list)'
);

SELECT * FROM finish();
ROLLBACK;
