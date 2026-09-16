# Audit Brief: F-001

## Task
* **Task ID**: F-001
* **Title**: Multi-Tenant Schema & PostgreSQL Row-Level Security Kernel
* **Type**: Backend / Database / Security

## Risk Level
* **Risk**: R4 (FR-016 — `docs/06-TRACEABILITY.yaml`)

## Requirement Mapping
* **Requirements**: `FR-016`
* **Acceptance Criteria**: `AC-016-01`, `AC-016-02`
* **Business / SoT**: Fail-closed empty result / 0 rows affected under missing or foreign tenant context (Phase-1). HTTP `SET LOCAL app.current_tenant_id` wiring is **`F-004`**.

## Architecture & ADR References
* **Architecture**: `docs/05-ARCHITECTURE.md` §5 Data Model, §6 Database Strategy
* **ADRs**: `ADR-002-Tenant-Isolation.md` (PostgreSQL RLS + session GUC)
* **Related**: Eloquent `BelongsToTenant` Global Scope (FR-016 defense-in-depth)

## Focus Areas
* **Security Areas**: FORCE RLS on tenant tables; app must not connect as a superuser / RLS-bypass role in production; tests use `tazkerah_app`.
* **Data Areas**: FORCE RLS on `events`, `sectors`, `seats`, `tickets` (default `SOLD`), `scan_logs`, `event_policy_chunks` (Architecture §5 DDL). `tenants` catalog + nullable `users.tenant_id` are schema columns without RLS policies (by SoT — not AC-016 surfaces).
* **Failure Modes**: Missing tenant GUC → empty set; cross-tenant write → 0 rows or `WITH CHECK` rejection.
* **Edge Cases**: Cross-tenant INSERT/UPDATE/DELETE; Eloquent scope when context empty.

## Expected Evidence
* `./vendor/bin/phpunit --filter TenantRls` exit 0 (Isolation + Adversarial; PostgreSQL / pgvector).
* `./vendor/bin/pint` clean on touched PHP.
* CI workflow `.github/workflows/php-f001-rls.yml` green on PR (Pint + fail-on-skip).
* Migration enables FORCE RLS + policies; `down()` drops policies/role safely; `GRANT tazkerah_app TO` login where allowed.
* R4 package: `docs/audits/F-001-R4-ASSURANCE.md` (Automated Verification + Deep Adversarial + independent review disposition).
