# Audit Brief: F-004

## Task
* **Task ID**: F-004
* **Title**: JWT Authentication & Per-Request Tenant Context Middleware (PHP-FPM)
* **Type**: Backend / Auth / Security

## Risk Level
* **Risk**: R4 (FR-016 — `docs/06-TRACEABILITY.yaml` / `docs/03-VALIDATION.md`)

## Requirement Mapping
* **Requirements**: `FR-016`
* **Acceptance Criteria**: `AC-016-01`, `AC-AUTH-01`, `AC-AUTH-02`; invalid Bearer → **401**; validation → RFC 7807 **422**
* **Contracts**: `docs/14-INTEGRATION-CONTRACTS.md` §1.1 (`login` / `logout` / `me`, Bearer + `X-Tenant-ID`)
* **Business / SoT**: Per-request `SET LOCAL`-equivalent GUC + `tazkerah_app` role for FORCE RLS. OTP **issuance/delivery** is out of F-004 (UI: `T-NEXT-01` / `T-AUTH-*`); Phase-1 verifier consumes cache challenges.

## Architecture & ADR References
* **Architecture**: `docs/05-ARCHITECTURE.md` §8 Authentication & Authorization
* **ADRs**: `ADR-001` (PHP-FPM, no Octane), `ADR-002` (RLS + session GUC)

## Focus Areas
* **Security Areas**: Missing GUC → fail-closed empty RLS; `X-Tenant-ID` must not elevate beyond membership; clear GUC/role after request (no FPM bleed).
* **Data Areas**: Sanctum `personal_access_tokens`; `users.tenant_id` membership; GUC `app.current_tenant_id`.
* **Failure Modes**: 401 unauthenticated; 403 tenant mismatch; 422 validation Problem Details.
* **Edge Cases**: Alternating tenant requests on same connection; logout revokes token.

## Expected Evidence
* `./vendor/bin/phpunit --filter AuthTenantContextTest` exit 0 (PostgreSQL / pgvector).
* `./vendor/bin/pint` clean on F-004 PHP surface.
* CI workflow `.github/workflows/php-f004-auth.yml` green.
* Routes: `POST /api/v1/auth/login`, `POST /api/v1/auth/logout`, `GET /api/v1/auth/me`.
