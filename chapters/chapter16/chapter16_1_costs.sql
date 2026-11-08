-- Chapter 16: Analyzing financial operations. Independent after chapter16_0_setup.sql.
-- Execute the named blocks in order and STOP ON ERROR.
-- Prerequisites: setup role, warehouse, database, and fixture tables.
-- Validation: live tested on Snowflake 10.33.101, 2026-09-21. Attribution block
-- simplified 2026-09-29; sample_query_id and MEASUREMENT block added 2026-11-06,
-- rerun pending; see README.
-- Reader-specific substitutions use <REPLACE: description>.
-- Role: OPS_ENGINEER for lab work; explicit administrator blocks only where needed.

USE ROLE OPS_ENGINEER;
USE WAREHOUSE OPS_WH;
ALTER SESSION SET TIMEZONE = 'UTC';
SELECT usage_date, service_type,
       SUM(credits_billed) AS billed_credits
FROM snowflake.account_usage.metering_daily_history
WHERE usage_date >= DATEADD(day, -8, CURRENT_DATE())
  AND usage_date < DATEADD(day, -1, CURRENT_DATE())
GROUP BY usage_date, service_type
ORDER BY usage_date, billed_credits DESC;

-- QUERY_ATTRIBUTION_HISTORY carries QUERY_TAG and QUERY_PARAMETERIZED_HASH itself.
SELECT COALESCE(NULLIF(query_tag, ''), '(untagged)') AS workload,
       query_parameterized_hash,
       COUNT(*) AS attributed_executions,
       SUM(credits_attributed_compute) AS query_credits,
       MAX_BY(query_id, credits_attributed_compute) AS sample_query_id
FROM snowflake.account_usage.query_attribution_history
WHERE start_time >= DATEADD(day, -8, CURRENT_DATE())
  AND start_time < DATEADD(day, -1, CURRENT_DATE())
GROUP BY workload, query_parameterized_hash
ORDER BY query_credits DESC
LIMIT 20;

-- OPTIONAL ADAPTIVE METERING: read only; run only when the view is available.
-- Metering-hour boundary aligns charges with hourly accounting, including jobs
-- that started before the period. Aggregate rows before joining query-level data.
SELECT query_id, SUM(credits_used_compute) AS compute_credits,
       SUM(credits_used_cloud_services) AS cloud_services_credits,
       SUM(credits_used) AS metered_credits
FROM snowflake.account_usage.query_metering_history
WHERE query_metering_hour >= DATEADD(day, -8, CURRENT_DATE())
  AND query_metering_hour < DATEADD(day, -1, CURRENT_DATE())
GROUP BY query_id
ORDER BY metered_credits DESC
LIMIT 20;

-- MEASUREMENT: credits per execution per day for one family, before and after a
-- change that keeps the SQL text (clustering key, warehouse size). A change to the
-- SQL text produces a new hash; find it with the attribution block above.
SELECT TO_DATE(start_time) AS run_day,
       COUNT(*) AS executions,
       SUM(credits_attributed_compute) / COUNT(*) AS credits_per_execution
FROM snowflake.account_usage.query_attribution_history
WHERE query_parameterized_hash = '<REPLACE: query_parameterized_hash>'
  AND start_time >= DATEADD(day, -8, CURRENT_DATE())
GROUP BY run_day
ORDER BY run_day;
