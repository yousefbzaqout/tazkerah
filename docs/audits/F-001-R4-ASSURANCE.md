# F-001 R4 Assurance Package — FR-016 Tenant Isolation

**Task:** `F-001` — Multi-Tenant Schema & PostgreSQL Row-Level Security Kernel  
**Requirement:** `FR-016` · `AC-016-01` · `AC-016-02`  
**Risk tier:** **R4** (`docs/03-VALIDATION.md` §7; `docs/06-TRACEABILITY.yaml`)  
**ADR:** `ADR-002`  
**Date:** 2026-09-16  
**Scope:** Backend RLS kernel only (HTTP `SET LOCAL` middleware remains **`F-004`**)

---

## R4 package components (SoT)

| Pillar | What was executed |
| --- | --- |
| **Automated Verification** | PHPUnit `TenantRlsIsolationTest` + `TenantRlsAdversarialTest` on PostgreSQL/pgvector; GitHub Actions `.github/workflows/php-f001-rls.yml` (Pint + `--filter TenantRls` + fail-on-skip) |
| **Deep Adversarial Audit** | Cross-tenant SELECT/UPDATE/DELETE/INSERT on all six FORCE-RLS tables; empty GUC; invalid GUC; Eloquent `withoutGlobalScope` still blocked by RLS; documented owner/superuser residual |
| **Stronger reviewer independence** | [Security Review](215b49aa-2915-414a-8cd9-9c8f73523a02) → `R4_ASSURED`; independent [Adversarial Audit](f470701c-6a77-4636-b6cf-e5b24042d25f) → initially `R4_FAIL` (dispositioned below) |

---

## Automated verification evidence

### Local

```text
./vendor/bin/phpunit --filter TenantRls
OK (7 tests, … assertions)  — Isolation + Adversarial

./vendor/bin/pint --test (F-001 RLS surface)
passed
```

### CI controls (hardened)

- Service: `pgvector/pgvector:pg18`
- Pint `--test` on F-001 PHP surface
- PHPUnit filter: `TenantRls(Isolation|Adversarial)Test`
- Fail if output contains `skipped`
- Fail if suite does not report OK

### FR-016 high-assurance directive (`docs/03-VALIDATION.md`)

> Automated CI suite running queries across multiple `tenant_id` contexts to verify zero cross-tenant data leakage.

**Met** by Isolation + Adversarial CI job. Broader R4 tier wording (“strict static security analysis”) is **not** claimed here: no Larastan/Psalm/CodeQL workflow exists in the baseline yet (residual `R4-RES-02`).

---

## Deep adversarial matrix

| Attack / probe | Expected under `tazkerah_app` | Test |
| --- | --- | --- |
| Empty `app.current_tenant_id` | 0 rows on all 6 RLS tables + Eloquent | `test_r4_empty_guc_fail_closed_on_all_rls_tables` |
| Cross-tenant SELECT | Only home-tenant IDs | `test_r4_cross_tenant_matrix_*` |
| Cross-tenant UPDATE/DELETE | 0 rows affected on all 6 tables | same |
| Cross-tenant INSERT | `WITH CHECK` → `QueryException` on **all 6** tables | same |
| Bypass Eloquent Global Scope | Still cannot see foreign tenant | `test_r4_eloquent_without_global_scope_still_rls_under_app_role` |
| Invalid GUC UUID | Fail-closed (error / unusable) | `test_r4_invalid_guc_uuid_fail_closed` |
| Table owner / superuser session | Sees all rows (FORCE RLS does not apply to owner) | `test_r4_superuser_sees_all_but_app_role_is_isolated` — **residual ops control** |

**FORCE-RLS tables (Architecture §5 DDL):** `events`, `sectors`, `seats`, `tickets`, `scan_logs`, `event_policy_chunks`.  
**Not RLS (by SoT):** `tenants` catalog; nullable `users.tenant_id` column without policy.

---

## Runtime hardening (this package)

Migration grants `tazkerah_app` membership to `CURRENT_USER` when allowed so login roles (e.g. `sail`) can `SET ROLE tazkerah_app` and exercise FORCE RLS in tests/CI/dev — aligning ADR-002.

Production still must:

1. Connect as a non-bypass role (`tazkerah_app` or equivalent), **not** table owner/superuser.
2. Wire per-request `SET LOCAL app.current_tenant_id` via **`F-004`**.

---

## Independent review disposition

| Finding ID | Source | Severity | Reopen AC-016? | Disposition |
| --- | --- | --- | --- | --- |
| SEC-01 Owner/superuser bypass | Security Review | Medium (ops) | **No** | **Accepted residual** `R4-RES-01`: documented + asserted; closed by runtime role binding + `F-004` sequencing |
| SEC-02 HTTP / `X-Tenant-ID` | Security Review | — | **No** | **UNREQUESTED** → `F-004` |
| F001-R4-01 `users` without RLS | Independent audit | Claimed High | **No** | **Rejected vs SoT**: Architecture §5 enables RLS only on the six tables; `AC-016-02` names events/seats/scan logs. `users.tenant_id` is a nullable FK column, not an RLS surface. Audit brief clarified. |
| F001-R4-02 Incomplete INSERT matrix | Independent audit | Medium | **No** | **Closed**: adversarial INSERT now covers all six FORCE-RLS tables |
| F001-R4-03 No static analysis CI | Independent audit | Medium | **No** | **Accepted residual** `R4-RES-02`: FR-016 directive (cross-tenant CI) is met; full-repo PHPStan/CodeQL not in baseline — track separately, do not invent stack here |
| `REVOKE_TASK_VERIFIED`? | Independent audit proposed yes | — | — | **No** — Security Review + SoT agree ACs stand |

### Independence statement

Reviewers did not author the RLS migration or isolation tests under review. Implementer closed automated gaps (INSERT matrix, CI harden, GRANT, assurance doc) without implementing `F-004` middleware.

---

## Verdict

| Gate | Result |
| --- | --- |
| AC-016-01 / AC-016-02 | **PASS** |
| R4 Automated Verification (FR-016 directive) | **PASS** |
| R4 Deep Adversarial Audit | **PASS** (with `R4-RES-01` ops residual) |
| R4 Reviewer independence | **PASS** (two independent reviews + written disposition) |
| F-001 task ACs | **TASK_VERIFIED** stands |
| Broader R4 “static security analysis” tier wording | **Residual** `R4-RES-02` (not claimed) |
| **R4 assurance for FR-016 kernel** | **R4_ASSURED** |

**Not claimed:** production-ready multi-tenant HTTP API (requires `F-004` + non-bypass DB credentials); whole-repo static analysis CI.
