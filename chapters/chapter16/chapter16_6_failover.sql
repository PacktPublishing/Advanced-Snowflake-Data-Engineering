-- Chapter 16: Rehearsing a failover across regions. Independent after chapter16_0_setup.sql.
-- Run in a Business Critical TRIAL account, never a shared company account: step 1
-- creates an account in the organization.
-- Execute the numbered blocks in order, in the account each block names, and STOP ON ERROR.
-- Prerequisites: core setup in the source; ORGADMIN for steps 1, 2, and 8.
-- Validation: live tested 2026-11-07, AWS_US_WEST_2 source to AWS_US_EAST_1, Snowflake 10.40.103;
-- lab database substituted as OPS_DB_CH16_TEST_20261107. See README.
-- Reader-specific substitutions use <REPLACE: description>.

-- 1. SOURCE, ORGADMIN: create the destination account in another region.
--    SHOW REGIONS lists identifiers; SHOW ACCOUNTS shows the source's region.
USE ROLE ORGADMIN;
CREATE ACCOUNT OPS_DR
  ADMIN_NAME = '<REPLACE: admin_user>'
  ADMIN_PASSWORD = '<REPLACE: strong_password>'
  MUST_CHANGE_PASSWORD = TRUE
  EMAIL = '<REPLACE: your_email>'
  EDITION = BUSINESS_CRITICAL
  REGION = '<REPLACE: region_from_show_regions>';
SHOW ACCOUNTS LIKE 'OPS_DR';
-- Expected: OPS_DR with its account URL. Sign in there and change the password.

-- 2. SOURCE, ORGADMIN: enable replication on both accounts.
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
  '<REPLACE: organization>.<REPLACE: source_account>',
  'ENABLE_ACCOUNT_DATABASE_REPLICATION', 'true');
SELECT SYSTEM$GLOBAL_ACCOUNT_SET_PARAMETER(
  '<REPLACE: organization>.OPS_DR',
  'ENABLE_ACCOUNT_DATABASE_REPLICATION', 'true');

-- 3. SOURCE, ACCOUNTADMIN: create the failover group for the lab database only.
--    ROLES or WAREHOUSES fail the first refresh with error 003131 (dangling references)
--    when the account has an account-level network policy, unless NETWORK POLICIES and
--    ACCOUNT PARAMETERS are replicated too. See the chapter.
USE ROLE ACCOUNTADMIN;
CREATE FAILOVER GROUP DR_FG
  OBJECT_TYPES = DATABASES
  ALLOWED_DATABASES = OPS_DB
  ALLOWED_ACCOUNTS = <REPLACE: organization>.OPS_DR
  REPLICATION_SCHEDULE = '15 MINUTE';
SHOW FAILOVER GROUPS LIKE 'DR_FG';
-- Expected: DR_FG listed as primary, object types DATABASES.

-- 4. DESTINATION (OPS_DR), ACCOUNTADMIN: create the secondary. The scheduled primary
--    starts the first refresh automatically; an explicit REFRESH now fails with
--    "already being refreshed". A new account has no general-purpose warehouse.
USE ROLE ACCOUNTADMIN;
CREATE FAILOVER GROUP DR_FG AS REPLICA OF
  <REPLACE: organization>.<REPLACE: source_account>.DR_FG;
CREATE WAREHOUSE IF NOT EXISTS DR_WH
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 INITIALLY_SUSPENDED = TRUE;
SHOW FAILOVER GROUPS LIKE 'DR_FG';
-- Expected: DR_FG secondary in OPS_DR, primary in the source.

-- 5. DESTINATION: compare the replica with the source. The INFORMATION_SCHEMA table
--    function needs a warehouse and a database to resolve against.
USE WAREHOUSE DR_WH;
SELECT phase_name, start_time, end_time
FROM TABLE(OPS_DB.INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('DR_FG'))
ORDER BY start_time DESC
LIMIT 1;
SELECT COUNT(*) AS row_count, SUM(amount) AS total_amount
FROM OPS_DB.MONITORING.SETTLEMENT_LEDGER;
-- Expected: COMPLETED; 3 rows, 60.00. A FAILED row carries the code in ERROR.

-- 6. DESTINATION: fail over. On a live platform, fence writers and confirm the final
--    refresh first; promotion fails while a refresh runs.
ALTER FAILOVER GROUP DR_FG PRIMARY;
SHOW FAILOVER GROUPS LIKE 'DR_FG';
-- Expected: the destination is now primary.

-- 7. SOURCE, ACCOUNTADMIN: fail back. Retry PRIMARY if the refresh is still running.
USE ROLE ACCOUNTADMIN;
ALTER FAILOVER GROUP DR_FG REFRESH;
ALTER FAILOVER GROUP DR_FG PRIMARY;
SHOW FAILOVER GROUPS LIKE 'DR_FG';
-- Expected: the source is primary again.

-- 8. CLEANUP. First, in the DESTINATION:
--    DROP FAILOVER GROUP DR_FG;
--    Then in the SOURCE:
USE ROLE ACCOUNTADMIN;
DROP FAILOVER GROUP DR_FG;
USE ROLE ORGADMIN;
DROP ACCOUNT OPS_DR GRACE_PERIOD_IN_DAYS = 3;
SHOW ACCOUNTS HISTORY LIKE 'OPS_DR';
-- Expected: dropped_on set, scheduled_deletion_time three days later. The destination's
-- copy of OPS_DB stayed behind as an ordinary database until the account is deleted.
