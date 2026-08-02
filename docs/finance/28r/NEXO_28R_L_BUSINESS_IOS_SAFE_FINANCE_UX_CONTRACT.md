# Nexo 28R.L — Business iOS safe finance UX

## Scope

28R.L adds a permission-aware Business iOS surface for:

1. read-only finance configuration;
2. money movement list and evidence drill-down;
3. receivables, payables, cash and bank summaries;
4. authorised historical-import upload/preview affordances;
5. reconciliation review;
6. coverage and cutover status;
7. unresolved items;
8. explicit locale and currency presentation.

## Safety boundary

- The backend remains the source of truth.
- Business iOS formats individual backend amounts but never aggregates
  authoritative totals.
- The UI accepts only `OPERATIONAL_NOT_POSTED` snapshots.
- `authoritativeAccounting=true`, cross-organisation scope, mixed currency and
  unmasked external financial references are rejected before presentation.
- Upload, preview and reconciliation actions require both an explicit
  permission and a backend capability.
- The default repository fails closed until the 28R.P runtime endpoint is
  wired. It never fabricates sample financial values.
- 28R.L does not create journal entries, post accounting, approve cutover or
  claim compliance for a country.

## Deferred

- Runtime API repository and live endpoints: 28R.P.
- Admin finance-control UX and cutover approval: 28R.M.
- RBAC hardening and malicious-file controls: 28R.O.
- Canonical accounting posting and general ledger: 29R.

