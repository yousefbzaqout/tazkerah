# F-004 R4 Assurance Package — FR-016 Auth Tenant Binding

**Task:** `F-004` — JWT Authentication & Per-Request Tenant Context Middleware  
**Requirement:** `FR-016` · `AC-016-01` · `AC-AUTH-01` · `AC-AUTH-02`  
**Risk tier:** **R4** (`docs/03-VALIDATION.md` §7)  
**Date:** 2026-09-16  
**Branch:** `feature/F-004-auth-tenant-middleware`

---

## Pillars

| Pillar | Evidence |
| --- | --- |
| **Automated Verification** | PHPUnit Isolation + Adversarial + Middleware smoke; CI `.github/workflows/php-f004-auth.yml` (Pint + fail-on-skip) |
| **Deep Adversarial Audit** | `AuthTenantContextAdversarialTest` — elevation, stale ability, OTP single-use, throttle 429, GUC bleed, role escalation, membership clear |
| **Stronger reviewer independence** | [Security Review](f777d3b3-5a0d-4236-aad3-92c458ef9d21) → `R4_ASSURED`; independent [Adversarial Audit](53396f86-0e88-4eee-a8df-31debcea5dc6) → initially `R4_FAIL` (dispositioned below) |

---

## Automated verification

```text
./vendor/bin/phpunit --filter 'AuthTenantContext(Test|AdversarialTest)|SetTenantContextMiddlewareTest'
OK (23+ tests) — see latest CI run

FR-016 directive: Automated CI suite across tenant_id contexts — MET
```

Static analysis (PHPStan/CodeQL) not claimed — residual `R4-RES-02` (same as F-001).

---

## Deep adversarial matrix

| Probe | Expected | Test |
| --- | --- | --- |
| No Bearer | 401 Problem Details | `test_missing_bearer_*` |
| Bad login payload | 422 | `test_login_validation_*` |
| Wrong OTP | 401 | `test_invalid_otp_*` |
| OTP replay | 401 | `test_r4_otp_is_single_use` |
| Unknown user + OTP | 401 same type | `test_r4_unknown_user_*` |
| Attendee + organizer_web / flutter_gate | 403 client-forbidden | SEC-001 tests + adversarial |
| Login burst | 429 | `test_r4_login_throttle_returns_429` |
| Header ≠ membership | 403 | `test_x_tenant_id_mismatch_*` |
| Header without membership | 403 | `test_r4_header_without_membership_*` |
| Forged `tenant:` ability ≠ membership | 403 | `test_r4_forged_tenant_ability_*` |
| Membership cleared after token mint | empty GUC / events | `test_r4_cleared_membership_ignores_stale_tenant_ability` |
| Alternating tenants | no bleed | `test_r4_guc_cleared_*` / concurrent |
| Logout current token | 401 reuse; other tokens OK | logout tests |
| Empty membership | fail-closed events | `test_ac_016_01_*` |

---

## Independent review disposition

| Finding ID | Source | Severity | Reopen AC? | Disposition |
| --- | --- | --- | --- | --- |
| SEC-001 Client roles | Prior Security Review | High | No | **Closed** — `users.roles` ∩ client |
| SEC-002 Login throttle | Prior Security Review | Medium | No | **Closed** — `throttle:10,1` + 429 test |
| F004-R4-01 Stale ability after membership clear | Independent audit | High | Claimed yes | **Closed** — bind only from `users.tenant_id`; ability cannot resurrect cleared membership; adversarial test added |
| F004-R4-02 OTP get/forget race | Independent audit | Medium | No | **Closed** — lock + unlocked fallback; wrong OTP does not `pull` |
| F004-R4-03 Static analysis / doc lag | Independent audit | Medium | No | **Accepted residual** `R4-RES-02`; FR-016 directive is cross-tenant CI (met); assurance doc updated |
| `REVOKE_TASK_VERIFIED`? | Independent proposed yes | — | — | **No** after F004-R4-01/02 closed |

### Independence statement

Reviewers did not author the auth middleware under review. Implementer closed automated gaps and dispositioned findings without expanding into `T-RL-01` Problem Details body or OTP SMS delivery.

---

## Residuals (not AC reopeners)

| ID | Note |
| --- | --- |
| `R4-RES-01` | Production non-bypass DB role (`tazkerah_app`) |
| `R4-RES-OTP` | OTP issuance/delivery out of F-004 |
| `R4-RES-02` | Whole-repo static analysis CI not claimed |
| `R4-RES-RL` | Login 429 body shape → `T-RL-01` |

---

## Verdict

| Gate | Result |
| --- | --- |
| AC-016-01 / AC-AUTH-01 / AC-AUTH-02 | **PASS** |
| R4 Automated Verification | **PASS** |
| R4 Deep Adversarial Audit | **PASS** |
| R4 Reviewer independence | **PASS** |
| F-004 task | **TASK_VERIFIED** stands |
| **R4 assurance for F-004** | **R4_ASSURED** |
| **REVOKE_TASK_VERIFIED** | **no** |
