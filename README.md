# Tazkerah (تذكرة) — Backend

Laravel **API** for the Tazkerah event-ticketing platform. This repository is the **backend source of truth** for multi-tenant isolation (PostgreSQL RLS), Sanctum auth, and (upcoming) seat holds, checkout, issuance, and scanner APIs.

**Clients (other teams — not this repo’s UI):**

| Client | Owner | Contracts |
| --- | --- | --- |
| Next.js 16 web commerce + Organizer dashboard | Frontend web | [`docs/12-REACT-WEB-HANDOFF.md`](docs/12-REACT-WEB-HANDOFF.md) |
| Flutter Ticket Vault + Gate Scanner | Mobile | [`docs/13-FLUTTER-MOBILE-HANDOFF.md`](docs/13-FLUTTER-MOBILE-HANDOFF.md) |
| Shared API shapes | All | [`docs/14-INTEGRATION-CONTRACTS.md`](docs/14-INTEGRATION-CONTRACTS.md) |

Agent / contributor guardrails: [`AGENTS.md`](AGENTS.md).

---

## Current baseline (what is ready)

| Task | Status | What you get |
| --- | --- | --- |
| **F-001** | Merged to `development` · **TASK_VERIFIED** · **R4_ASSURED** | Multi-tenant schema + **FORCE RLS** + Eloquent `BelongsToTenant` |
| **F-004** | Merged to `development` · **TASK_VERIFIED** · **R4_ASSURED** | Sanctum login / logout / me + per-request tenant GUC middleware |

**Not ready yet (do not invent):** events listing APIs (`T-API-*`), seat hold (`T-009`), checkout (`T-010`), ticket issuance (`T-000`), Horizon (`F-005`), Redis AOF hardening (`F-002`).

Working branch for integration: **`development`**.

---

## Stack (Phase-1 — do not change silently)

| Layer | Version / choice |
| --- | --- |
| Runtime | **PHP 8.4+** (Sail image may be 8.5) · **Laravel 13** · **PHP-FPM** |
| **No** | Laravel Octane / Swoole |
| Database | **PostgreSQL 18** + **pgvector** · **direct** connection (`pgsql:5432`) |
| **No (Phase-1)** | PgBouncer (deferred Phase-2) |
| Cache / locks (later) | **Standalone Redis 8.x** + AOF (F-002 / T-009) — no Sentinel/Cluster |
| Auth | **Laravel Sanctum** Bearer tokens |
| Crypto (later) | ECDSA **P-256** server signing · HMAC-SHA256 TOTP **20s** |

---

## Who should use this README

| Role | Use this for |
| --- | --- |
| **Backend engineers** | Local Sail, migrations, RLS role, tests, feature branches |
| **Frontend (Next.js)** | Auth headers, login/logout/me contracts, tenant header rules |
| **Mobile (Flutter)** | Same auth contracts; Vault / Gate clients |
| **QA** | How to seed OTP, run PHPUnit, interpret 401/403/422/429 |

---

## 1. Prerequisites

- Docker Desktop (or Docker Engine) + Compose
- Git
- Optional on host: PHP 8.4+, Composer (Sail can run everything inside containers)

Clone:

```bash
git clone git@github.com:yousefbzaqout/tazkerah.git
cd tazkerah
git checkout development
git pull origin development
```

---

## 2. Local setup (Laravel Sail)

```bash
cp .env.example .env

# Install PHP deps (first time, if vendor/ missing — use a one-off composer container or host composer)
docker run --rm -u "$(id -u):$(id -g)" -v "$(pwd):/var/www/html" -w /var/www/html composer:2 composer install

# Start stack: app + PostgreSQL (pgvector) + Redis
./vendor/bin/sail up -d

# App key + migrate
./vendor/bin/sail artisan key:generate
./vendor/bin/sail artisan migrate
```

Default app URL: **http://localhost** (or `APP_PORT` from `.env`).

### Important `.env` values

```env
DB_CONNECTION=pgsql
DB_HOST=pgsql          # inside Sail network
DB_PORT=5432
DB_DATABASE=...
DB_USERNAME=sail
DB_PASSWORD=password

# Phase-1: direct Postgres only — do not point at PgBouncer
```

From the **host** (PHPUnit / `psql` on the machine), use `DB_HOST=127.0.0.1` and forwarded port `FORWARD_DB_PORT` (default **5432**).

---

## 3. Multi-tenancy (how the backend isolates data)

### Model (ADR-002 + F-001)

1. Every tenant-scoped row has `tenant_id`.
2. PostgreSQL **FORCE RLS** on: `events`, `sectors`, `seats`, `tickets`, `scan_logs`, `event_policy_chunks`.
3. Session GUC: `app.current_tenant_id`.
4. Non-bypass DB role: **`tazkerah_app`** (tests / middleware use `SET ROLE`).
5. Eloquent defense-in-depth: `BelongsToTenant` global scope.

### HTTP binding (F-004)

Middleware `SetTenantContext` runs on `/api/*`:

1. Authenticates via Sanctum when required.
2. Sets GUC from **`users.tenant_id` only** (membership).
3. Honors `X-Tenant-ID` **only if it matches** membership (else **403**).
4. Clears GUC + `RESET ROLE` after the request (no sticky tenant across PHP-FPM workers).

**Production rule:** the app DB user must be able to `SET ROLE tazkerah_app` (or connect as an equivalent non-superuser). Connecting as table owner / superuser **bypasses FORCE RLS**.

---

## 4. Authentication — how the team uses auth

Contracts: [`docs/14-INTEGRATION-CONTRACTS.md`](docs/14-INTEGRATION-CONTRACTS.md) §1.1.

### Base path

```text
/api/v1
```

### Headers (all tenant-scoped product calls)

| Header | Required | Notes |
| --- | --- | --- |
| `Authorization: Bearer <token>` | Yes (except login) | Sanctum PAT |
| `X-Tenant-ID: <uuid>` | Yes when acting in a tenant | Must match the user’s membership |
| `Content-Type: application/json` | Yes for JSON bodies | |
| `X-Client` | Recommended | `next_web` \| `flutter_vault` \| `flutter_gate` \| `organizer_web` |

### Login — `POST /api/v1/auth/login`

**Request**

```json
{
  "identifier": "sami@example.com",
  "otp": "482910",
  "client": "next_web"
}
```

| Field | Rules |
| --- | --- |
| `identifier` | User email |
| `otp` | 6 characters |
| `client` | One of: `next_web`, `flutter_vault`, `flutter_gate`, `organizer_web` |

**Success `200`** — `token`, `token_type: Bearer`, `expires_at`, `user`, `tenants[]`.

**Errors**

| Status | When |
| --- | --- |
| **401** | Invalid OTP / unknown user (same problem type — no user enumeration) |
| **403** | `client` requests a role the user does not have in `users.roles` |
| **422** | Validation (RFC 7807 Problem Details) |
| **429** | Throttle (`10` requests / minute on login) |

**Roles (important):** privileges come from **`users.roles` in the database**, intersected with roles implied by `client`. Example: attendee cannot login with `client: "organizer_web"`.

#### Phase-1 OTP (backend team / QA)

OTP **send/SMS/email is not implemented** in F-004 (UI owns that later). For local/dev/tests, seed a challenge in cache:

```php
app(\App\Auth\LoginOtpVerifier::class)->store('sami@example.com', '482910');
```

Or from Sail tinker:

```bash
./vendor/bin/sail artisan tinker
>>> app(\App\Auth\LoginOtpVerifier::class)->store('sami@example.com', '482910');
```

Then call login with that OTP. OTP is **single-use**.

#### Seed a user (example)

```bash
./vendor/bin/sail artisan tinker
```

```php
$tenantId = (string) Illuminate\Support\Str::uuid();
DB::table('tenants')->insert(['id' => $tenantId, 'name' => 'Neon Arena', 'created_at' => now()]);

$user = App\Models\User::factory()->create([
    'email' => 'sami@example.com',
    'name' => 'Sami',
    'tenant_id' => $tenantId,
    'roles' => ['attendee'], // or ['organizer'], ['gate_staff']
]);
```

### Me — `GET /api/v1/auth/me`

Requires Bearer. Returns `user_id`, `email`, `name`, `tenants[]` with roles.

### Logout — `POST /api/v1/auth/logout`

Requires Bearer. Returns **204**. That token is revoked; other tokens for the same user remain valid.

### Probe (dev / tests only) — `GET /api/v1/tenant/context`

Authenticated. Returns membership `tenant_id`, live GUC `db_tenant_id`, and scoped `event_ids`. **Not a product API** — for AC / R4 isolation checks.

---

## 5. How Frontend / Mobile should call the API

### Typical Attendee (Next.js `next_web` / Flutter Vault)

1. Seed or receive OTP → `POST /api/v1/auth/login` with `client: "next_web"` or `"flutter_vault"`.
2. Store `token` securely.
3. On every tenant call, send:

```http
Authorization: Bearer 1|...
X-Tenant-ID: 9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d
X-Client: next_web
```

4. On logout: `POST /api/v1/auth/logout` with the same Bearer.

### Organizer / Gate

- User must have `roles` containing `organizer` or `gate_staff`.
- Login with `client: "organizer_web"` or `"flutter_gate"`.
- Same Bearer + matching `X-Tenant-ID` rules.

### Error handling (clients)

Prefer Problem Details JSON (`type`, `title`, `status`, `detail`). Map:

- **401** → re-auth  
- **403** → wrong tenant / forbidden client  
- **422** → field errors  
- **429** → backoff (`Retry-After` when present)

Full matrices and future endpoints: **`docs/14-INTEGRATION-CONTRACTS.md`**.

---

## 6. Testing (backend)

PostgreSQL required (SQLite will skip RLS suites).

```bash
# Inside Sail network:
./vendor/bin/sail test --filter 'TenantRls|AuthTenantContext|SetTenantContext'

# From host against forwarded Postgres:
DB_HOST=127.0.0.1 DB_PORT=5432 DB_DATABASE=testing DB_USERNAME=sail DB_PASSWORD=password \
  DB_CONNECTION=pgsql ./vendor/bin/phpunit --filter 'TenantRls|AuthTenantContext|SetTenantContext'
```

CI workflows on `development` / feature branches:

- `.github/workflows/php-f001-rls.yml` — F-001 RLS R4  
- `.github/workflows/php-f004-auth.yml` — F-004 auth R4  

Style: `./vendor/bin/pint`.

Audit evidence:

- [`docs/audits/F-001-RESULT.md`](docs/audits/F-001-RESULT.md) · [`docs/audits/F-001-R4-ASSURANCE.md`](docs/audits/F-001-R4-ASSURANCE.md)  
- [`docs/audits/F-004-RESULT.md`](docs/audits/F-004-RESULT.md) · [`docs/audits/F-004-R4-ASSURANCE.md`](docs/audits/F-004-R4-ASSURANCE.md)

---

## 7. Git workflow (team)

| Rule | Detail |
| --- | --- |
| Base branch | Always branch from **`development`** |
| Names | `feature/<desc>`, `fix/<desc>`, `docs/<desc>`, `chore/<desc>` — include task ID when possible (`feature/F-002-...`) |
| Commits | Conventional Commits: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `chore`, `ci`, `build` |
| Example | `feat(F-002): enable Redis AOF in compose` |
| PRs | Open against **`development`**; wait for CI; merge when green |
| Do not | Force-push `development` / `main`, `--no-verify`, invent Octane / PassKit / Sentinel |

Approved backend task IDs: see [`docs/07-TASKS.md`](docs/07-TASKS.md) and [`AGENTS.md`](AGENTS.md).

**Implementation order (backend):**  
`F-001` → `F-004` → **`F-002`** → `F-005` → `T-000` → `T-API-*` → …

---

## 8. Documentation map

| Doc | Purpose |
| --- | --- |
| [`docs/02-REQUIREMENTS.md`](docs/02-REQUIREMENTS.md) | FR / NFR / AC |
| [`docs/03-VALIDATION.md`](docs/03-VALIDATION.md) | Risk R1–R4 assurance |
| [`docs/05-ARCHITECTURE.md`](docs/05-ARCHITECTURE.md) | System design + DDL/RLS |
| [`docs/07-TASKS.md`](docs/07-TASKS.md) | Approved tasks only |
| [`docs/14-INTEGRATION-CONTRACTS.md`](docs/14-INTEGRATION-CONTRACTS.md) | **Binding** API JSON for FE/Mobile |
| [`docs/decisions/`](docs/decisions/) | ADRs 001–006 |
| [`AGENTS.md`](AGENTS.md) | Agent / contributor hard rules |

---

## 9. Lifecycle SoT (do not invent alternate enums)

- **Seat:** `AVAILABLE` → `HELD` → `CHECKOUT` → `SOLD`
- **Ticket row:** created **only** at payment `SOLD`, then `SOLD_USED` \| `REVOKED`
- **Checkout session:** `PENDING` \| `PAID` \| `FAILED` \| `EXPIRED` (separate from seat/ticket)
- **Sector lock:** PostgreSQL `sectors.is_locked` SoT + Redis `sector:{id}:locked` cache (later tasks)

---

## 10. Quick curl cookbook

```bash
# 1) After seeding OTP + user in tinker:
curl -s -X POST http://localhost/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -H 'X-Client: next_web' \
  -d '{"identifier":"sami@example.com","otp":"482910","client":"next_web"}'

# 2) Me
curl -s http://localhost/api/v1/auth/me \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-ID: $TENANT_UUID"

# 3) Logout
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost/api/v1/auth/logout \
  -H "Authorization: Bearer $TOKEN"
```

---

## License

Application code follows the repository license. Laravel framework components remain under the [MIT license](https://opensource.org/licenses/MIT).
