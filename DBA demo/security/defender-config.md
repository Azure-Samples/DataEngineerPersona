# Microsoft Defender for Open-Source Relational Databases

## What It Provides

- Anomalous database access detection
- Brute force attack alerts
- Suspicious database activity monitoring
- MITRE ATT&CK tactic mapping
- Multi-cloud support (Azure + AWS RDS)

## Setup

```bash
# Enable Defender
az security pricing create \
  --name OpenSourceRelationalDatabases \
  --tier Standard

# Verify status
az security pricing show \
  --name OpenSourceRelationalDatabases
# Expected: pricingTier = Standard
```

## Alerts to Monitor

| Alert | Severity | Description |
|---|---|---|
| Brute force attack | High | Multiple failed login attempts |
| Anomalous access | Medium | Access from unusual IP/location |
| Suspicious activity | Medium | Unusual query patterns |
| Data exfiltration | High | Large data export detected |

## Integration with Security Tests

Test `sec-010-defender-enabled.sql` verifies Defender is active.
Manual verification via Azure CLI is also documented in the test.
