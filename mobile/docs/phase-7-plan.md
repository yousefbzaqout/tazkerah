# Phase 7 Plan — Backend Integration

**Date:** 2026-09-15
**Supersedes:** the sequencing section of `impact-report-backend-integration.md`
(that report's analysis still holds; this plan replaces its Step 0–5 now that
the backend repository has been read).

---

## 0. What changed since the impact report

The impact report was written without access to the backend. The repository is
now cloned and read, and **two of its assumptions were wrong in the optimistic
direction**:

| Impact report assumed | Actually true |
| --- | --- |
| "No API contracts agreed" | Correct — and worse: the one endpoint that exists **contradicts** the app |
| Backend is a peer at an unknown stage | Backend is at **M0 foundation** — stock Laravel + Sanctum, nothing domain-specific |

Both findings push the same way: **Flutter is not the bottleneck, and should
not be the next thing worked on.**

---

## 1. Verified state of both sides

### 1.1 Backend — `github.com/yousefbzaqout/tazkerah`

Branch `cursor/m0-foundation-b1ce` (open as PR #1), one commit past `main`.

**Exists:**
- Laravel 13 / PHP 8.3, Sanctum 4.3
- `POST /api/tokens` — email + password + device_name → plain-text token
- `GET /api/health`, `GET /api/user` (`auth:sanctum`)
- Docker compose: Postgres 18, Redis
- Four M0 feature tests; PHPUnit on in-memory SQLite

**Does not exist — despite being named in the specification:**

| Spec requirement | Reality |
| --- | --- |
| `roles` / RBAC (4 roles) | **No migration, no package.** `users` is stock: name, email, password |
| `events`, `categories` | No migration, no model |
| `seats`, `ticket_types` | No migration, no model |
| `orders`, `tickets` | No migration, no model |
| `scan_logs` | No migration, no model |
| `event_embeddings` + pgvector | **`pgvector` absent from composer.json** |
| Redis Horizon | **Absent from composer.json.** `QUEUE_CONNECTION=database` |
| Redis atomic locks | Redis container runs; no lock code. `CACHE_STORE=database` |
| Prism / OpenAI | **Absent from composer.json** |
| PgBouncer | **F-003 explicitly blocked** — not in `compose.yaml` |

The backend has **one** of the ~12 systems the spec assigns it. It is at the
foundation stage, not mid-build.

### 1.2 Mobile — `mobile/` on branch `mobile`

23,047 lines, 130 Dart files, **225 tests green**, analyzer clean. Six `Dev*`
stubs; production throws rather than binding them. Unchanged from the impact
report except for the monorepo move.

---

## 2. The contract conflicts — resolve before writing integration code

### 2.1 Auth: OTP vs password — **BLOCKING, and it is a product decision**

This is not a naming mismatch. The two sides model **different authentication
systems**.

**Flutter expects** (`lib/features/auth/domain/auth_repository.dart`):

```
POST /auth/request-code  {identifier}        -> 204
POST /auth/verify-code   {identifier, code}  -> {refresh_token, ...}
GET  /me                                     -> {profile}
POST /auth/sign-out                          -> 204
```

**Backend provides** (`routes/api.php`):

```
POST /api/tokens  {email, password, device_name} -> {token}
```

Four incompatibilities, each independently blocking:

1. **No password exists in the app.** There is no password field on any screen,
   no password in `UserProfile`, no reset flow. Adopting the backend's contract
   means **designing and building password UI that the design does not contain**.
2. **No OTP exists in the backend.** No codes table, no delivery channel (SMS or
   email), no rate limiting, no expiry.
3. **`identifier` vs `email`.** The app's `UserProfile` carries `identifier`
   plus *optional* `email` and *optional* `phone` — it was built so a user can
   sign in by phone. The backend's `users.email` is `unique()` and
   `NOT NULL`.
4. **No refresh token.** The app persists a refresh token and holds the access
   token in memory only (a recorded security decision). Sanctum issues one
   long-lived token with no refresh concept.

**This must be decided by a person, not worked around.** Two coherent options:

- **(A) Backend adopts OTP.** Costs: codes table, SMS/email provider, rate
  limiting, refresh-token issuance. Flutter changes: **none** — every screen is
  already built and tested.
- **(B) App adopts password.** Costs: new sign-in UI, password reset flow, ARB
  strings in two locales, new tests. Discards working, tested OTP screens.
  Backend changes: refresh tokens, phone support if kept.

**Recommendation: (A).** Not because the app is finished, but because OTP is
what the *design* specifies and what the attendee flow is built around. Option
(B) throws away shipped work to match a route that exists only as M0
scaffolding — it was never a considered auth design.

### 2.2 Ticket cryptography — still unresolved, still blocking

Unchanged from the impact report and now urgent, because the backend has not
yet built the wrong thing:

> The spec's **"TOTP signed with JWT" is not a coherent construct.** TOTP
> verification requires the verifier to hold the shared secret — an offline
> gate scanner holding it **could forge every ticket at its event.**

Standing recommendation: **signed grant** (server key) + **short-lived
presentation proof** (device key, ES256 — the only curve with hardware backing
on both platforms).

**The window to decide this is now.** The backend has written no ticket code,
so the decision costs a conversation today and a rewrite in a month.

### 2.3 Offline QR — spec contradicts the app's design

The spec requires offline QR generation. The app is built so the **server
issues every rotation** and the device holds no key material. A device with no
connectivity therefore **cannot present a pass at all**.

§2.2 decides this: a device-key proof restores offline capability; server-issued
codes mean the offline claim must come out of the spec. **Do not implement
either side until §2.2 is answered.**

---

## 3. Plan

### Step 1 — Decisions (blocking, no code)

Three answers needed, in this order. Each is cheap now and expensive later.

| # | Question | Who | Blocks |
| --- | --- | --- | --- |
| 1 | OTP or password? (§2.1) | Product + backend + mobile | All auth work, both sides |
| 2 | Ticket crypto scheme? (§2.2) | Backend + mobile + web scanner | Gate pass, TOTP engine, scanner |
| 3 | Offline QR: keep or drop? (§2.3) | Product | Follows from #2 |

**Nothing in Step 2 or 3 should start before #1 and #2 are answered.**

### Step 2 — Contracts before implementations

Write `docs/api-contracts.md` from the six domain interfaces. The interfaces
are already precise about what the app needs; this turns them into a document
the backend builds against.

Three properties the app already depends on that must survive the negotiation —
each a recorded decision, not a preference:

1. **Totals are quoted by the server, never summed on the client.** VAT and
   fees are policy that changes without an app release.
2. **`expires_at` is absolute and server-issued.** Countdowns are recomputed
   from it, never decremented locally.
3. **Event times carry a UTC offset *and* a timezone abbreviation** (`AST`).
   The abbreviation is a regional fact the client cannot derive from `+03:00`.

### Step 3 — Backend builds the domain

The backend needs roughly **six migration sets and their endpoints** before the
app has anything to integrate against: roles/RBAC, events/categories,
seats/ticket_types, orders/tickets, scan_logs, event_embeddings.

Mobile integration is **gated on this**, feature by feature. There is no
useful Flutter network code to write against endpoints that do not exist.

### Step 4 — Integrate, in dependency order

Once an endpoint exists, replacing its stub is genuinely small: **one new
`data/api_*_repository.dart` and one provider edit**. Nothing in
`presentation/` or `domain/` changes — that is the payoff from the existing
layering.

Order: **Auth → Events → Booking → Tickets → Gate pass → Concierge.**
One commit per repository, each independently reviewable and revertible.

Each integration also needs a test class the project does not yet have: DTO
deserialization against recorded fixtures, and error mapping for real status
codes. Existing tests keep passing untouched — they never tested the stubs.

### Step 5 — Mobile work that needs no backend

**This is what to do while Step 3 runs.** It is the only Flutter work not
blocked by contracts:

| Task | Why it is unblocked | Size |
| --- | --- | --- |
| `applicationId` off `com.example` | **One-way door** — permanent once published on Play | Small |
| iOS bundle id | Pairs with the above | Small |
| Notifications (`features/notifications/` is empty) | Local scheduling needs no API. Re-add `flutter_local_notifications` + `timezone` **together** | Medium |
| `FLAG_SECURE` + iOS capture detection | Implements the existing `ScreenCaptureDetector` interface | Medium |
| Certificate pinning | `AppConfig.enforceCertificatePinning` exists and nothing reads it | Small |

On notifications, two constraints from the existing dependency audit:
`flutter_local_notifications` forces **core library desugaring into every
Android build**, and `timezone` is **not optional** alongside it — reminders
fire in the event's timezone, not the device's. Android 13+ also needs runtime
`POST_NOTIFICATIONS`, and scheduled notifications must be **rescheduled on
launch** because the OS drops them on reboot and reinstall.

On capture prevention, restated because the app's honesty depends on it: **iOS
reports a screenshot only after it happens; Android can block it.** The product
response is rotation and invalidation, not prevention. Do not let this be
"fixed" by promising prevention on both platforms.

### Step 6 — Push and PR hygiene

Branch `mobile` is **2 commits ahead, local only, not pushed**. Before pushing:

1. Tell the backend engineer the layout changed — after pulling, their paths
   move from `app/` to `backend/app/` and `composer install` runs from there.
2. **Let PR #1 merge first.** Pushing the restructure to `main` beforehand
   conflicts with every file in that PR.
3. Then push `mobile`.

---

## 4. Risk register

| # | Risk | Level | Note |
| --- | --- | --- | --- |
| 1 | Auth contract conflict | **CRITICAL** | Blocks both sides. Decide first |
| 2 | Ticket cryptography unresolved | **CRITICAL** | Spec describes a forgeable scheme |
| 3 | Backend domain not started | **CRITICAL** | 6 table sets missing; gates all integration |
| 4 | Offline QR contradicts design | **HIGH** | Follows from #2 |
| 5 | Production build throws | **HIGH** | Correct behaviour; resolves as stubs are replaced |
| 6 | `applicationId` is `com.example` | **MEDIUM** | **One-way door.** Fix in Step 5 |
| 7 | Spec assumes packages not installed | **MEDIUM** | Horizon, pgvector, Prism all absent |
| 8 | Notifications / wallet not started | **MEDIUM** | Wallet is a descope candidate |
| 9 | Cert pinning, capture prevention unwired | **MEDIUM** | Step 5 |

---

## 5. The one-line summary

**Mobile is ahead of the backend and blocked by it.** The correct next action is
not Flutter code — it is getting three decisions answered (§3 Step 1) and the
API contracts written, while mobile does the five unblocked platform tasks in
Step 5.
