# Chapter 16 CoCo investigation

Use an authenticated reporting connection with a restricted reporting role.
Check `cortex --version` and `cortex --help` against the CoCo CLI reference before use.
Start with `cortex -c <REPLACE: reporting_connection>`.
No account query, schema mutation, or cloud deployment was run during preparation.

## Scope prompt

Investigate the seven UTC days ending before yesterday.
Use approved Account Usage views and OPS_DB.MONITORING only.
Show the SQL, reporting boundaries, and source latency first.
Rank billed service credits and conventional query attribution separately.
Explain idle credits without allocating them silently to queries.
Use QUERY_METERING_HISTORY for Adaptive query costs if available.
Inspect settlement incident history and identify missing recovery evidence.
Return three candidate changes, each with its query family, query identifiers, evidence, validation, rejection criterion, and rollback.
Do not change grants, warehouses, schedules, replication, or backup policies.
Write the review as a dated status.md entry: owner, decision (chosen, rejected with evidence, consequence), query identifiers, current setting and rollback, open gaps with owner and revisit date.
Stage any change as a statement in the entry and do not run it.

## Verification and change record

Require SQL and results to remain distinct from recommendations. Record account,
role, warehouse, UTC bounds, source view, source latency, query identifiers, and
missing data. Re-run evidence under the same grants. A hypothesis is not a tested
saving. Separate billed credits, direct attribution, overhead allocation, and
Adaptive metering. Never infer a successful recovery from a configured schedule.

Commit the status.md entry on a branch and review it in a pull request; run a staged statement only after the service owner approves.

For an accepted change record: current state, proposed state, hypothesis, result
comparison, runtime and credits, impact on SLO/RPO/RTO, rollback command, owner,
and decision time. Use a separate authorized change session for mutations.
