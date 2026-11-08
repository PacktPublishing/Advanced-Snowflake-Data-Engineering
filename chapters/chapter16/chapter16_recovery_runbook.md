# Chapter 16 recovery runbook reference

The failover exercise moved to `chapter16_6_failover.sql` on 2026-11-06, so this
runbook now holds only the locked-backup reference. The locked-backup configuration
requires Business Critical and APPLY BACKUP RETENTION LOCK. Documentation reviewed
in September 2026; no retention lock applied.

For a planned promotion on a live platform, record source account, destination
account, incident owner, RPO, RTO, and the consumer-routing decision. Test user
authentication, grants, warehouse access, application queries, and source position
before redirecting clients, and record recovery time at successful application
validation, not at DDL completion. Client Redirect, configured before the failover,
moves clients with a connection object:
https://docs.snowflake.com/en/user-guide/client-redirect

## Locked-backup portion

This is an irreversible retention commitment once applied to a backup set.
Approve retention length and storage budget before executing. It is not part of
chapter16_5_restore.sql or core teardown.

```sql
USE ROLE ACCOUNTADMIN;
CREATE BACKUP POLICY OPS_DB.MONITORING.LOCKED_30D
  WITH RETENTION LOCK
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
  EXPIRE_AFTER_DAYS = 30;
CREATE BACKUP SET OPS_DB.MONITORING.LEDGER_LOCKED_BACKUPS
  FOR TABLE OPS_DB.MONITORING.SETTLEMENT_LEDGER
  WITH BACKUP POLICY OPS_DB.MONITORING.LOCKED_30D;
```

Verify completed backup identifiers with SHOW BACKUPS. A scheduled set alone is
not proof of a usable recovery point. Use the restore syntax in the chapter's
restore worksheet, with the locked set and chosen backup identifier. Rehearse
restore authorization without using ACCOUNTADMIN for ordinary incident response.

## Cleanup after optional recovery work

For a locked set, first stop scheduled backup creation using the documented
`ALTER BACKUP SET ... SUSPEND BACKUP CREATION POLICY` action. Keep expiration
running. Retain the set until all covered backups expire, then remove the set
and policy according to their drop requirements. The lock cannot be revoked.
Core teardown must wait until locked sets and failover membership are removed.
