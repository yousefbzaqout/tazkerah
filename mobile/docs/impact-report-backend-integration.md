# Impact Report — Backend Integration (Phase 7)

**Date:** 2026-09-15
**Status:** Analysis only. No code changed.
**Scope:** Replacing six stub repositories with real ones against the Laravel backend.

This report is written against the code as it exists, not against the
specification. Where the two disagree, the disagreement is the finding.

---

## 0. Executive summary

The Flutter app is **not at the start of the project — it is at the end of the
UI phase and blocked on the backend**. Every screen in the attendee spec is
built, 225 tests pass, the analyzer is clean. What does not exist is a single
line of real network code: all six repositories are stubs, and a production
build does not fall back to them — it **throws**.

The planning question is therefore not "how do we build the app". It is
**"which API contracts get agreed, in what order, so the stubs can be
replaced"** — plus two unresolved design questions (ticket cryptography,
wallet passes) that no amount of Flutter work can settle alone.

**The critical path runs through the backend, not through Flutter.**

---

## 1. Current state — verified, not assumed

Measured on 2026-09-15 from the working tree:

| Signal | Value |
| --- | --- |
| App code | 23,047 lines of Dart across 130 files |
| Test code | 5,326 lines, **225 tests, all passing** |
| `flutter analyze` | **No issues found** |
| Real HTTP calls in features | **Zero** |
| Repositories | **6 of 6 are `Dev*` stubs** |
| Version control | **Not a git repository** |

### 1.1 What is built and working

| Feature | Screens | State |
| --- | --- | --- |
| Auth | splash, sign-in flow, OTP, profile | UI complete, stub backend |
| Events | discovery + search, detail, skeletons, offline cache | UI complete, stub backend |
| Booking | seat map, hold countdown, checkout, payment window | UI complete, stub backend |
| Tickets | wallet, ticket detail, order confirmation | UI complete, stub backend |
| Gate pass | rotating QR, clock-skew fallback, capture intercept | UI complete, stub backend |
| AI Concierge | streaming chat, citations, interrupted-stream retry | UI complete, stub backend |

Infrastructure that is real and tested: `ApiClient` (Dio + three
interceptors), `AppClock` with server-offset correction, `SecureStorage`
abstraction with an in-memory fake, `GoRouter` with deep links, sealed
`Failure` hierarchy with `ErrorMapper`, full ar/en localization with RTL
coverage, design-system theme layer.

### 1.2 What does not exist at all

- **`lib/features/notifications/`** — data, domain, presentation: all three
  directories exist and are **empty**. Local notifications are a spec
  deliverable. `flutter_local_notifications` and `timezone` were deliberately
  removed from `pubspec.yaml` in a dependency audit (the note is still there).
- **`lib/features/wallet/`** — same: three empty directories. Apple/Google
  Wallet `.pkpass` export is a spec deliverable with **no code and no
  dependency**. (Note: the *digital ticket wallet* screen is built — it lives
  in `features/tickets/`. This empty directory is the OS-wallet integration.)
- **Screen capture prevention** — `ScreenCaptureDetector` is an interface with
  no platform implementation. No `flutter_windowmanager`, no `FLAG_SECURE`.
- **Certificate pinning** — `AppConfig.enforceCertificatePinning` returns the
  right boolean; nothing reads it.
- **Real repositories** — six of them.

---

## 2. The blocking finding: production throws

This is the single most important fact in the report.

Each of the six repository providers is written as:

```dart
if (config.environment == AppEnvironment.production) {
  throw UnimplementedError(
    'No production EventsRepository is bound. The backend contract '
    '(GET /events) is still open — see EventsRepository.',
  );
}
return DevEventsRepository();
```

**This is correct engineering and should not be "fixed" by removing the
throw.** It is what stops a release shipping against fake data — a release
built with `--dart-define=ENVIRONMENT=production` crashes at first use rather
than silently showing four hard-coded events and issuing QR payloads that are
random strings.

The implication for planning: **there is no partial production build.** Until
a repository is replaced, its feature is unshippable. The stubs are not
degraded-mode fallbacks; they are development scaffolding with a hard gate.

---

## 3. Impact analysis by dimension

### 3.1 Flutter architecture — impact: **LOW**

The architecture was built for this substitution. `features/*/domain/*_repository.dart`
defines the interface; `data/dev_*.dart` implements it; one provider binds
them. Replacing a stub touches **two files**: a new `data/api_*_repository.dart`
and the `if (production) throw` block.

Nothing in `presentation/` changes. Nothing in `domain/` changes. This is the
payoff from the layering already in `ARCHITECTURE.md`.

**Risk: LOW.** The seam exists and is already exercised by tests, which
override the same providers with fakes.

### 3.2 API contracts — impact: **CRITICAL, and this is the real blocker**

Not one endpoint is agreed. The domain interfaces encode what the app *needs*,
which is the starting position for the negotiation, not the outcome of it:

| Repository | Needs from backend |
| --- | --- |
| `AuthRepository` | request OTP, verify OTP, refresh session, revoke session |
| `EventsRepository` | paginated feed + search, event detail with venue timezone |
| `BookingRepository` | seat map, hold seats (409/423 semantics), promote hold to order, quote totals |
| `TicketsRepository` | list tickets, poll order → issued ticket |
| `GatePassRepository` | issue rotating presentation code + rotation interval |
| `ConciergeRepository` | streaming answer with citations (SSE) |

Three contract details the app already depends on and that must survive the
negotiation — each was a deliberate decision recorded in `ARCHITECTURE.md`:

1. **Totals are quoted by the server, never summed on the client.** VAT and
   fees are policy. `CheckoutOrder` carries line items *and* a total.
2. **`expires_at` is absolute, server-issued.** The countdown is recomputed
   from it every tick, never decremented locally.
3. **Event times carry a UTC offset *and* a timezone abbreviation** (`AST`).
   The abbreviation is a regional fact the client cannot derive from `+03:00`.

**Risk: CRITICAL.** Every other risk in this report is downstream of this one.

### 3.3 Ticket cryptography — impact: **CRITICAL, unresolved by design**

`ARCHITECTURE.md` already records this and it has not moved. The specification
says *"TOTP signed with JWT"*. **That is not a coherent construct.** TOTP
verification requires the verifier to hold the shared secret — so an offline
gate scanner holding it **could forge every ticket at its event**.

The recorded recommendation: a **signed grant** (server key) plus a
**short-lived presentation proof** (device key, ES256 — the only curve with
hardware backing on both iOS and Android).

The app is currently written to be agnostic: `GatePassRepository` issues every
rotation, the device generates nothing and holds no key material. That is the
right posture while the question is open, but it means **the gate pass cannot
work offline today** — which contradicts the spec's offline-first claim for
the attendee app.

This blocks: Flutter gate pass, backend TOTP engine, and the web offline
scanner simultaneously. **It is a three-team decision, not a Flutter one.**

**Risk: CRITICAL. Recommend resolving this before any other integration work.**

### 3.4 Offline behaviour — impact: **MEDIUM, with a spec contradiction**

Built and working: events feed cache (first page, 24h cap), secure storage for
session material, offline banners that never blank a populated screen.

**The contradiction:** the spec requires the QR to be generated offline. The
app's current design has the *server* issue every rotation, so **a device with
no connectivity cannot present a pass at all.** Resolving §3.3 in favour of a
device-key proof fixes this; resolving it in favour of server-issued codes
means the offline claim must be dropped from the spec.

This is exactly the kind of mismatch an Impact Report is for: both the code and
the spec are internally consistent, and they contradict each other.

### 3.5 Notifications — impact: **MEDIUM, greenfield**

Empty feature. Re-adding `flutter_local_notifications` brings back the costs
the audit documented: **core library desugaring forced into every Android
build**, plus Linux/Windows implementations that are not shipped.

`timezone` is **not optional** alongside it — reminders fire at 24h and 2h
before an event, and an event's time is a property of its venue, not the
device. This is the same timezone decision already made in §3.2.

Also required: iOS `UNUserNotificationCenter` permission prompt, Android 13+
`POST_NOTIFICATIONS` runtime permission, and a reschedule-on-launch path
(the OS drops scheduled notifications on reboot and app reinstall).

**Risk: MEDIUM.** Self-contained, no dependency on other features, but it is a
real feature's worth of work, not a wiring task.

### 3.6 Wallet passes — impact: **MEDIUM, and probably should be descoped**

`ARCHITECTURE.md` already recommends this and the recommendation stands:
**Apple and Google Wallet passes are static.** Neither can carry a rotating
code without provisioning a shared secret to the wallet provider — which
re-opens the §3.3 forgery problem, this time with a third party holding the
secret.

`.pkpass` generation additionally requires an **Apple Developer pass-type
certificate** — an account-level prerequisite with a lead time that has
nothing to do with writing code.

**Recommendation: information-only passes for v1** (event name, date, venue,
seat, order reference), with entry through the app. **Flag this to the
stakeholder as a scope change, not a silent omission.**

### 3.7 Android / iOS — impact: **MEDIUM, with two irreversible items**

| Item | State | Note |
| --- | --- | --- |
| `applicationId` | `com.example.tazkerah` | **Permanent once published on Play.** Must change before any submission. |
| iOS bundle id | unset | Must be set in Xcode alongside it. |
| Backup disabled | done, both platforms | Correct — device binding depends on it |
| Universal links / App Links | not served | Needs `apple-app-site-association` + `assetlinks.json` on the production domain |
| Notification permissions | not requested | §3.5 |
| `FLAG_SECURE` | not implemented | §3.9 |

**Risk: MEDIUM**, but `applicationId` is a **one-way door**. Change it early.

### 3.8 Testing — impact: **LOW-MEDIUM**

225 tests pass today because every test overrides providers with fakes —
`test/support/` already holds `fake_auth_repository.dart`,
`fake_booking_repository.dart`, `fake_events_repository.dart`.

Real repositories need a **new class** of test the project does not yet have:
DTO deserialization against recorded fixtures, error mapping for real status
codes, and interceptor behaviour on token refresh. Existing tests keep passing
untouched — they were never testing the stubs.

**Risk: LOW-MEDIUM.** Additive work, no regression surface.

### 3.9 Security — impact: **HIGH**

| Item | State |
| --- | --- |
| Certificate pinning | Flag exists, **nothing reads it** |
| Screen capture prevention | Interface only, **no platform code** |
| Token refresh race | Interceptor exists; concurrent-401 behaviour **untested against a real server** |
| Backup disabled | Done |
| Access token memory-only | Done |

Screen capture is worth restating because the app's honesty depends on it:
**iOS reports a screenshot only after it happens; Android can block it with
`FLAG_SECURE`.** The product response is rotation + invalidation, not
prevention — a design relying on prevention would be truthful on one platform
and false on the other. Do not let anyone "fix" this by promising prevention.

### 3.10 Performance — impact: **LOW**

The rotating QR re-renders every 20s; `qr_flutter` is pure Dart with no
platform channel. Seat maps are the heaviest widget and are already built
against the stub's data shape. No new hot paths are introduced by swapping a
stub for a real HTTP call — **but** every stub currently returns in a fixed
simulated latency (300–700ms) and never times out. Real network conditions
will surface loading and error states that have only ever been triggered
synthetically.

**Risk: LOW**, but expect the first real-network run to find UI state bugs the
stubs could not produce.

### 3.11 Version control — impact: **HIGH, and it is the cheapest fix here**

`/Users/h/Developer/tazkerah` is **not a git repository.** 23,000 lines of
working, tested, analyzer-clean code with **no history and no recovery point.**

Every other practice in this plan depends on it: reviewing an implementation
against this report needs a diff; rolling back a failed integration needs a
commit; the "compare actual changes to expected impact" step is not
mechanizable without one.

**Risk: HIGH. This is a 30-second fix and should be the first action taken.**

---

## 4. Risk register, ordered

| # | Risk | Level | Blocks |
| --- | --- | --- | --- |
| 1 | No version control | **HIGH** | Everything. Fix first. |
| 2 | Ticket cryptography unresolved | **CRITICAL** | Gate pass, backend, web scanner |
| 3 | Zero API contracts agreed | **CRITICAL** | All six repositories |
| 4 | Production build throws | **HIGH** | Any release |
| 5 | Offline QR contradicts architecture | **HIGH** | Spec truthfulness |
| 6 | `applicationId` still `com.example` | **MEDIUM** | Store submission (one-way door) |
| 7 | Notifications not started | **MEDIUM** | Spec deliverable |
| 8 | Wallet passes not started | **MEDIUM** | Spec deliverable — descope candidate |
| 9 | Cert pinning unwired | **MEDIUM** | Production security posture |
| 10 | Capture prevention unwired | **MEDIUM** | Anti-sharing claim |

---

## 5. Recommended sequence

**Step 0 — today, before anything else**
`git init`, `.gitignore` is already present and correct, commit the working
tree. One command, and it is the precondition for every review step that
follows.

**Step 1 — decision, not code**
Settle ticket cryptography (§3.3) with the backend engineer. Nothing about the
gate pass — on any of the three platforms — can be finished until this is
answered. Take the recorded ES256 recommendation into that conversation.

**Step 2 — contracts before implementations**
Write `docs/api-contracts.md` from the six domain interfaces. This is the
artefact the backend engineer builds against, and the thing to argue about
*before* either side writes code.

**Step 3 — integrate in dependency order**
Auth → Events → Booking → Tickets → Gate pass → Concierge. Each is one new
`data/api_*_repository.dart` plus one provider edit. Commit per repository so
each is independently reviewable and revertible.

**Step 4 — the two greenfield features**
Notifications (§3.5). Wallet passes only after the v1 scope decision (§3.6).

**Step 5 — production hardening**
`applicationId`, cert pinning, `FLAG_SECURE`, universal links.

---

## 6. What I recommend raising with the team

Three items need a decision from someone other than the Flutter developer:

1. **Ticket cryptography** — the spec describes a construct that does not
   work. Backend + Flutter + web scanner must agree on the replacement.
2. **Offline QR** — currently impossible under the app's design. Either the
   crypto decision enables it, or the claim comes out of the spec.
3. **Wallet passes** — recommend information-only for v1. This is a visible
   scope reduction and needs explicit sign-off rather than quiet omission.

---

*No code was modified in producing this report.*
