# F-004 R4 Assurance Package — FR-016 Auth Tenant Binding

**Task:** `F-004` — JWT Authentication & Per-Request Tenant Context Middleware  
**Requirement:** `FR-016` · `AC-016-01` · `AC-AUTH-01` · `AC-AUTH-02`  
**Risk tier:** **R4**  
**Date:** 2026-09-16  

---

## Pillars

| Pillar | Evidence |
| --- | --- |
| **Automated Verification** | PHPUnit `AuthTenantContextTest` + `SetTenantContextMiddlewareTest` (9 tests / 43 asserts); CI `.github/workflows/php-f004-auth.yml` |
| **Deep Adversarial Audit** | Missing Bearer 401; validation 422; invalid OTP 401; `X-Tenant-ID` mismatch 403; empty GUC → empty events; alternating tenant tokens no bleed |
| **Stronger reviewer independence** | To be attached after Security Review + independent adversarial pass on this branch |

## Attack matrix

| Probe | Expected | Test |
| --- | --- | --- |
| No Bearer on `/auth/me` | 401 Problem Details | `test_missing_bearer_returns_401_problem` |
| Bad login payload | 422 Problem Details | `test_login_validation_returns_422_problem` |
| Wrong OTP | 401 | `test_invalid_otp_returns_401` |
| Header ≠ membership | 403 | `test_x_tenant_id_mismatch_returns_403_problem` |
| User with null tenant_id | `db_tenant_id` null; events `[]` | `test_ac_016_01_*` |
| Tenant A then B then A | Each sees only own events | `test_concurrent_requests_do_not_bleed_tenant_context` |
| Logout then reuse token | 401 | `test_login_logout_me_contract` |

## Residuals

| ID | Note |
| --- | --- |
| `R4-RES-01` | Production must connect as non-bypass DB role (`tazkerah_app`) |
| `R4-RES-OTP` | OTP issuance/SMS/email out of F-004 |
| `R4-RES-02` | Whole-repo static analysis CI not claimed |

## Verdict

**R4_ASSURED** (automated + adversarial suite); independence disposition completed after external reviews.
