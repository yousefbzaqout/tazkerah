# Flutter — Per-Feature Plans

**Date:** 2026-09-15
**Companion to:** `phase-7-plan.md` (sequencing and blockers) and
`impact-report-backend-integration.md` (system-wide analysis).

One section per Flutter feature in the specification. Each records what is
**built**, what is **missing against the spec**, and what the remaining work
is — separated into **backend-blocked** and **startable now**, because that
distinction decides what you can actually do this week.

Every "missing" item below was verified against the code, not inferred.

---

## Legend

| Mark | Meaning |
| --- | --- |
| ✅ | Built and tested |
| ⚠️ | Built, but a spec detail is missing |
| ⛔ | Not built |
| 🔒 | Blocked on a backend contract or decision |
| 🟢 | Startable now, no backend needed |

---

## 1. Auth & Sign-in

**Status: ✅ built — 🔒 blocked by a contract conflict**

Built: splash, sign-in flow, OTP entry, profile, sign-out with local wipe even
when revocation fails. `DevAuthRepository` accepts exactly one code so failure
paths are reachable by hand.

**The blocker is not missing code — it is that the two sides disagree.**

| App expects | Backend provides |
| --- | --- |
| `POST /auth/request-code` → 204 | — |
| `POST /auth/verify-code` → `{refresh_token}` | — |
| `GET /me` | `GET /api/user` |
| `POST /auth/sign-out` → 204 | — |
| — | `POST /api/tokens` `{email, password, device_name}` |

Four incompatibilities, each blocking on its own:

1. **No password anywhere in the app.** No field, no screen, no reset flow.
2. **No OTP anywhere in the backend.** No codes table, no delivery channel, no
   rate limiting, no expiry.
3. **`identifier` vs `email`.** `UserProfile` carries `identifier` plus
   *optional* `email` and *optional* `phone` — built so a user can sign in by
   phone. Backend `users.email` is `unique()` and `NOT NULL`.
4. **No refresh token.** The app persists a refresh token and keeps the access
   token in memory only (a recorded security decision). Sanctum issues one
   long-lived token.

### Work — if the backend adopts OTP (recommended)

- 🔒 `data/api_auth_repository.dart` implementing the four endpoints
- 🔒 DTOs + deserialization tests against recorded fixtures
- 🔒 Wire `accessTokenProvider` (currently returns `null` — a documented
  placeholder) to the real session
- 🔒 Token-refresh-on-401 in `AuthInterceptor`, including the **concurrent-401
  race**: several requests failing at once must trigger **one** refresh, not N
- 🟢 Nothing — every screen is already built and tested

### Work — if the app adopts password instead

Materially larger, and it discards working screens: new sign-in UI, password
reset flow, ARB strings in both locales, new widget tests, plus all of the
above. **This is the cost of option (B) in `phase-7-plan.md` §2.1.**

---

## 2. Event Discovery

**Status: ⚠️ built, two spec features missing**

Built: paginated feed, search, skeleton/populated/offline-cached states as one
enum, 24h first-page cache, pull-to-refresh. The rule the controller enforces —
*a failure never blanks a screen that already has something to show* — is
tested.

**Missing against the spec** (verified — these fields do not exist):

| Spec says | Reality |
| --- | --- |
| "التصفية حسب التصنيف" (filter by category) | **No `category` field on `EventSummary` at all.** Not a UI gap — the entity has no category |
| "عرض مكان الفعالية على الخريطة" (show on map) | **No `latitude`/`longitude` anywhere.** `EventSummary` has `venue` and `city` as strings only |

### Work

- 🔒 `data/api_events_repository.dart` — feed + detail, keeping the cache
- 🔒 **Add `category` to the contract**, then the entity, then a filter UI.
  Decide with the backend whether categories are a fixed enum or a resource
- 🔒 **Add coordinates to the contract** before any map work
- 🟢 Map package choice and cost review — `google_maps_flutter` needs an API
  key with billing enabled, and both platforms need key configuration. Worth
  settling **before** the contract conversation so you ask for the right shape
- 🟢 Nothing else — search and filtering UI patterns already exist to extend

**Note:** search was added deliberately and is not in the design (see
`ARCHITECTURE.md`). It is built from existing tokens so it can be removed as
one widget. A category filter should follow the same discipline.

---

## 3. Event Detail

**Status: ⚠️ built, one spec feature missing**

Built: hero, info cards, availability-gated purchase bar, venue-timezone
rendering with abbreviation (`AST`), skeleton, security note, anti-passback
flag.

**Missing against the spec:**

| Spec says | Reality |
| --- | --- |
| "استعراض أجندة الفعالية والمتحدثين" (agenda and speakers) | **Neither exists.** No `speakers`, no `agenda` field, no widget — verified by grep across `lib/` |

This also matters beyond this screen: the AI Concierge's whole purpose is
answering questions about **schedule and speakers**, and the RAG index is built
from that same data. If the agenda has no contract, the concierge has nothing
truthful to retrieve.

### Work

- 🔒 **Agenda + speakers contract** — the shape (sessions with times, speaker
  bios, stage/track) needs agreeing. This is the largest missing entity in
  discovery
- 🔒 Entity + widgets once the shape exists
- 🟢 Nothing — the rest of the screen is complete

---

## 4. Seat Selection & Booking

**Status: ✅ built, contract-sensitive**

Built: interactive seat map, hold countdown, 409 conflict toast over a working
map, 423 locked-sector sheet, selection locked during a hold, hold-expired
view.

Three recorded decisions the backend contract **must** preserve:

1. **`expires_at` is absolute and server-issued.** The countdown is recomputed
   every tick, never decremented — a subtracted counter drifts while
   backgrounded and shows time on a hold the server already released.
2. **409 and 423 are answers, not errors.** Losing a seat race marks that seat
   and keeps the map working; a locked sector opens a sheet with alternatives.
   `LockedFailure` exists so 423 has a type to switch on.
3. **The payment window is granted, not computed.** Checkout asks the server to
   promote a hold; the server returns a fresh `expires_at` the client only
   renders. Adding three minutes locally would count down to a deadline the
   server never granted.

**Backend dependency:** this feature is the client half of the spec's Redis
Atomic Locks engine. That engine **does not exist yet** — `CACHE_STORE=database`,
no lock code, no Horizon. The app's 10-minute hold assumes a server that
releases seats on TTL expiry.

### Work

- 🔒 `data/api_booking_repository.dart`
- 🔒 Confirm 409/423 semantics explicitly in the contract — if the backend
  returns 500 or 422 for a lost race, the designed states become unreachable
- 🟢 Nothing — all three designed frames are built and tested

---

## 5. Checkout & Payment

**Status: ✅ built**

Built: order summary from server-quoted line items, payment window bar,
hosted-gateway handoff via `url_launcher`, re-check of the deadline before
paying, `isPaying` latched after handoff.

Two recorded decisions:

- **Totals are quoted, never summed on the client.** VAT, booking fees and
  municipal charges are policy that changes without an app release. Line items
  are a *list*, not named fields, so a market without a booking fee sends one
  fewer row.
- **Paying is refused once the window closes**, and a second tap cannot produce
  a second charge.

### Work

- 🔒 `data/api_booking_repository.dart` checkout half
- 🔒 **Return-from-gateway handling.** The app launches a hosted page; how the
  user comes back needs deciding — deep link, or polling only. The confirmation
  screen already polls, so this may need no new code, but it must be a decision
  rather than an assumption
- 🟢 Nothing

---

## 6. Ticket Wallet

**Status: ✅ built**

Built: upcoming/past sections, cut-out ticket card, ticket detail,
order-confirmation polling.

Two recorded decisions:

- **Confirmation waits for an issued ticket rather than declaring success.**
  Exhausting the window reports *pending*, never *failed* — telling someone
  their payment failed when their card was charged is the worst outcome here.
- **A used ticket is "past" even for a future event.** Sorting on status before
  date; a scanned ticket shown as upcoming implies a second entry that will not
  be granted.

### Work

- 🔒 `data/api_tickets_repository.dart`
- 🔒 **Offline wallet persistence.** `EventsCache` caches the *feed*; tickets
  are currently in-memory for the session. The spec requires tickets available
  offline, so a ticket cache is real work — and it must respect the existing
  decision that **nothing about a presentation code is ever persisted**
- 🟢 The ticket cache can be **designed and built now** against the existing
  `TicketsRepository` interface, since it is a local concern

---

## 7. Gate Pass / Dynamic QR

**Status: ✅ built — 🔒 blocked by the cryptography decision**

Built: rotating QR display, rotation interval taken from the grant, clock-skew
suppression with an eight-digit fallback, capture-intercept handling,
re-sync-decides-from-offset logic.

Recorded decisions:

- **The app displays codes; it does not generate them.** No key material and no
  generation logic on the device.
- **A captured code is dropped, not hidden** — removed from state entirely and
  reported so the issuer invalidates that rotation.
- **Clock skew suppresses the QR** past 180s rather than showing one that will
  be rejected at the gate with no explanation.

### The two spec conflicts

**(a) The spec's crypto is not sound.** "TOTP signed with JWT" is not coherent:
TOTP verification requires the verifier to hold the shared secret, so an
**offline gate scanner holding it could forge every ticket at its event.**
Standing recommendation: signed grant (server key) + short-lived presentation
proof (device key, **ES256** — the only curve with hardware backing on both
platforms).

**(b) Offline QR is currently impossible.** The spec requires offline
generation; the app is built so the server issues every rotation. A device with
no connectivity cannot present a pass at all. **(a) decides this** — a device
key restores offline capability, server-issued codes mean the offline claim
comes out of the spec.

### Work

- 🔒 **Everything network-facing waits on (a).** Do not implement around it
- 🟢 **Screen brightness boost** — spec item, **not built** (verified: no
  brightness code). Needs a package; purely local
- 🟢 **`FLAG_SECURE` on Android + iOS capture detection** — implements the
  existing `ScreenCaptureDetector` interface, which has no platform code yet

**Restate when anyone asks for "screenshot prevention":** iOS reports a
screenshot only *after* it happens; Android can block it outright. The product
response is rotation and invalidation, **not** prevention — a design relying on
prevention would be honest on one platform and false on the other. Do not
promise it on both.

---

## 8. AI Concierge

**Status: ✅ built**

Built: streaming chat UI, citations, interrupted-stream retry that keeps
partial text, disabled-with-explanation offline state.

Recorded decisions:

- **The app runs no model and holds no index.** Retrieval is server-side.
- **No offline mode by design** — an answer assembled from whatever happened to
  be cached would be worse than none for gate times and refund policy.
- **A partial answer is kept, never discarded**, marked `interrupted`.
- **Answers cite sources**, and only citations naming something the app can
  open are tappable.

### Work

- 🔒 **Real SSE client.** This is the largest genuinely-new Flutter work in the
  integration. `ChatChunk` and the streaming controller exist and are tested,
  but no SSE parsing does — Dio needs `ResponseType.stream` plus a line parser
  handling `data:` frames, multi-line payloads, and mid-stream errors
- 🔒 Backend RAG does not exist: **pgvector, Prism and OpenAI are all absent
  from `composer.json`**, and there is no `event_embeddings` table
- 🔒 Depends on §3 — with no agenda/speakers contract, there is nothing to index
- 🟢 Nothing

---

## 9. Local Notifications

**Status: ⛔ not built — 🟢 fully startable now**

`lib/features/notifications/` exists with **three empty directories**. This is
the largest unbuilt spec feature that needs **no backend at all**.

Scheduling is local: 24h and 2h before an event, from ticket data the app
already has.

### Work — all 🟢

- Re-add `flutter_local_notifications` **and `timezone` together**. `timezone`
  is **not optional**: reminders fire in the **event's** timezone, not the
  device's — the same decision already made for event display
- Accept the cost the dependency audit documented: **core library desugaring
  forced into every Android build**, plus Linux/Windows implementations not
  shipped
- Permissions: iOS `UNUserNotificationCenter` prompt, Android 13+ runtime
  `POST_NOTIFICATIONS`
- **Reschedule on launch** — the OS drops scheduled notifications on reboot and
  reinstall. Without this the feature silently stops working
- Cancel on refund/cancellation
- Tests with a fake scheduler — no test may touch a real platform channel

---

## 10. Wallet Passes (Apple / Google)

**Status: ⛔ not built — recommend descoping to information-only for v1**

`lib/features/wallet/` is **three empty directories**.

**The technical reason this cannot work as specified:** Apple and Google Wallet
passes are **static**. Neither can carry a rotating code without provisioning a
shared secret to the wallet provider — which re-opens the §7 forgery problem,
this time with a third party holding the secret.

`.pkpass` also requires an **Apple Developer pass-type certificate** — an
account-level prerequisite with lead time unrelated to writing code.

### Work

- 🔒 **Product decision first.** Recommend information-only passes for v1
  (event, date, venue, seat, order reference), entry through the app
- 🔒 Backend generates and signs `.pkpass`; the app only opens it
- 🟢 Start the Apple certificate request now if v1 keeps passes — the lead time
  is the long pole, not the code

**Flag this as a visible scope reduction needing sign-off, not a quiet
omission.**

---

## 11. Cross-cutting — 🟢 all startable now

| Task | Why it matters |
| --- | --- |
| **`applicationId` off `com.example.tazkerah`** | **One-way door** — permanent once published on Play. Do this first |
| **iOS bundle identifier** | Pairs with the above |
| **Certificate pinning** | `AppConfig.enforceCertificatePinning` exists and **nothing reads it** |
| **Universal Links / App Links** | Needs `apple-app-site-association` + `assetlinks.json` on the production domain |

---

## 12. Suggested order

**This week — nothing here waits on anyone:**

1. `applicationId` + iOS bundle id (**one-way door**)
2. Notifications (§9) — the biggest unblocked feature
3. `FLAG_SECURE` + capture detection (§7)
4. Screen brightness (§7)
5. Certificate pinning (§11)

**In parallel — decisions to chase, not code:**

1. **Auth: OTP or password** (§1) — blocks the most work
2. **Ticket cryptography** (§7) — cheapest to decide now, before the backend
   builds the wrong thing
3. **Agenda + speakers contract** (§3) — blocks both detail and the concierge
4. Category + coordinates in the events contract (§2)
5. Wallet pass scope (§10)

**After contracts exist — integrate in dependency order:**

Auth → Events → Booking → Tickets → Gate pass → Concierge.
One commit per repository; each is one new `data/api_*_repository.dart` plus
one provider edit, with nothing in `presentation/` or `domain/` changing.

---

## 13. Honest summary

Of the ten features, **seven are built and blocked on the backend**, two are
**unbuilt but need no backend** (notifications, brightness/capture), and one
should probably be **descoped** (wallet passes).

Three spec features are missing from otherwise-complete screens and need
contract work before any UI: **category filter**, **map coordinates**, and
**agenda/speakers** — the last of which the AI Concierge also depends on.

**The most productive Flutter week available right now is §12's "this week"
list.** Everything else needs a decision from someone else first.
