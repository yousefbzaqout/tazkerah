# Audit Result: F-004

**Task ID:** `F-004`  
**Task title (SoT `docs/07-TASKS.md`):** JWT Authentication & Per-Request Tenant Context Middleware  
**Auditor role:** Task Audit Agent (implementer self-check + independent follow-up)  
**Audit date:** 2026-09-16  
**Branch:** `feature/F-004-auth-tenant-middleware`  
**Brief consulted:** `docs/audits/F-004-AUDIT.md`  
**Requirements:** `FR-016` · `AC-016-01` · `AC-AUTH-01` · `AC-AUTH-02`  
**Architecture / ADR:** `docs/05-ARCHITECTURE.md` §8 · `ADR-001` · `ADR-002`  
**Contracts:** `docs/14-INTEGRATION-CONTRACTS.md` §1.1  
**Traceability risk (FR-016):** R4  

---

## Executive summary

| Dimension | Classification |
| --- | --- |
| Sanctum Bearer auth | **PASS** |
| `POST /api/v1/auth/login` (docs/14 shape) | **PASS** |
| `POST /api/v1/auth/logout` → 204 + revoke | **PASS** (`AC-AUTH-01`) |
| `GET /api/v1/auth/me` | **PASS** (`AC-AUTH-02`) |
| `AC-016-01` via middleware GUC | **PASS** |
| `X-Tenant-ID` non-elevation | **PASS** (403 mismatch) |
| 401 / 422 Problem Details | **PASS** |
| Concurrent / alternating tenant isolation | **PASS** |
| ADR-001 no Octane | **PASS** |
| OTP issuance/delivery | **UNREQUESTED** (cache verifier only; UI `T-NEXT-01` / `T-AUTH-*`) |

### Security disposition (2026-09-16 remediation)

| Finding | Severity | Disposition |
| --- | --- | --- |
| SEC-001 — client-controlled roles (login granted roles from `client` only) | HIGH | **Closed** — `users.roles` JSON; login intersects server roles with client-requested roles; empty → 403 `client-forbidden` |
| SEC-002 — login brute-force / no throttle | MEDIUM | **Closed** — `throttle:10,1` on `POST /api/v1/auth/login` (Laravel default 429) |

**REVOKE_TASK_VERIFIED:** no

### Final verdict

# **TASK_VERIFIED**

---

## Evidence

### Local PHPUnit

```text
./vendor/bin/phpunit --filter 'AuthTenantContextTest|SetTenantContextMiddlewareTest|TenantRls'
OK (includes SEC-001 role-binding + tenant RLS suite)
```

### Deliverables present

| Artifact | Status |
| --- | --- |
| `SetTenantContext` middleware (GUC + `SET ROLE tazkerah_app` + finally clear) | Present |
| `AuthController` login/logout/me | Present |
| Sanctum `HasApiTokens` + `personal_access_tokens` migration + grants | Present |
| `LoginOtpVerifier` (cache challenge consume) | Present |
| RFC 7807-style 401/422/403 JSON | Present |
| `.github/workflows/php-f004-auth.yml` | Present |

### Phase-1 notes (not blockers)

- OTP **send/delivery** not in F-004; tests seed `LoginOtpVerifier` cache.
- Roles: server `users.roles` ∩ client-mapped roles (`AuthClientRoles`) → token abilities (`role:attendee|organizer|gate_staff`).
- Membership = `users.tenant_id` (single tenant); multi-membership pivot not in Architecture DDL.
- HTTP uses session GUC (`set_config` is_local=false) cleared in `finally` (PHP-FPM safe; SET LOCAL retained for in-transaction F-001 paths).
