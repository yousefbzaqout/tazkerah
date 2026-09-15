# Tazkerah — Mobile Architecture

Attendee application for iOS and Android. This document records the decisions
behind the foundation so later phases extend it rather than reinterpret it.

## Layout

```
lib/
├── app/                     Composition root
│   ├── app.dart             MaterialApp.router
│   ├── config/              Build-time configuration (--dart-define)
│   ├── router/              GoRouter, shell, route names
│   └── theme/               Colours, spacing, ThemeData
│
├── core/                    Shared across features. Depends on no feature.
│   ├── constants/           Product constants
│   ├── errors/              Failure hierarchy, Dio mapping, localized copy
│   ├── extensions/          BuildContext shorthands
│   ├── network/             ApiClient, interceptors
│   ├── providers/           Riverpod wiring for core
│   ├── storage/             SecureStorage abstraction, key registry
│   ├── utils/               Bootstrap, clock
│   └── widgets/             Shared loading / error / empty views
│
├── features/                One directory per feature, self-contained
│   └── <feature>/
│       ├── data/            DTOs, remote and local sources, repository impls
│       ├── domain/          Entities, repository interfaces, use cases
│       └── presentation/    Screens, widgets, Riverpod controllers
│
├── l10n/                    ARB sources + generated localizations
└── main.dart                Entry point, error zone, ProviderScope
```

## Dependency rules

- `features/*` may depend on `core/` and `app/`, never on another feature. When
  two features need the same thing, it moves to `core/`.
- `presentation` never imports Dio, `flutter_secure_storage`, or a DTO. It talks
  to repositories through providers.
- `domain` holds plain Dart — no Flutter imports — so it can be tested without a
  widget binding and reasoned about without the framework.
- `data` is the only layer that knows a wire format exists.

## Decisions

**Riverpod over BLoC.** The earlier analysis recommended BLoC; the brief
specifies Riverpod, and it serves the same requirements. Compile-time-safe
dependency resolution, provider overrides that make platform channels testable
(see `test/app/app_test.dart`), and `ref.watch` composition for the derived
state coming in later phases — a QR code derived from a ticket, a corrected
clock, and a rotation tick.

**Failures, not exceptions, above the data layer.** `ErrorMapper` converts every
`DioException` at the boundary. Presentation switches over a sealed `Failure`
hierarchy, which the compiler checks for exhaustiveness — a new failure type
cannot be silently unhandled.

**`AppClock` instead of `DateTime.now()`.** Rotating ticket codes are generated
against server-corrected time. A device clock is user-controlled, so trusting it
would let someone shift the rotation window from Settings. `ClockSyncInterceptor`
learns the offset from ordinary traffic; `Stopwatch` drives elapsed time so a
mid-session clock change cannot skip the rotation. The offset is a hint — the
gate scanner holds the authoritative clock.

**`SecureStorage` as an interface.** One abstraction with one justification:
`flutter_secure_storage` needs a platform channel that `flutter_test` does not
provide. `InMemorySecureStorage` is the reason tests run at all. No other
abstraction here exists without a comparable need.

**`StatefulShellRoute` for tabs.** Each tab keeps its own navigation stack and
scroll position, so switching away from a half-scrolled list and back returns
the user where they were.

**Backup disabled on both platforms.** `allowBackup=false` plus exclusive
`data_extraction_rules.xml` on Android; `first_unlock_this_device` and
`synchronizable: false` on iOS. Ticket security depends on the device key being
bound to one device — a cloud backup that restored it elsewhere would undo that.

**Discovery state as one enum, not several booleans.** The design supplies
three discovery frames — skeleton, populated, offline-cached — and they are
mutually exclusive. `DiscoveryStatus` makes that explicit, so "loading while
showing cached rows" and "offline with an empty cache" cannot be represented.
The rule the controller enforces: *a failure never blanks a screen that already
has something to show*. A failed refresh over live rows keeps the rows and
turns the chrome amber; only a first load with nothing cached reaches the error
state.

**The feed cache is the offline state.** `EventsCache` persists the first page
only. Without it the "Offline — showing cached events" banner would sit above
an empty list. It stores through `SecureStorage` because that is the storage
abstraction the app has — event listings are public, not secret — and a second
storage dependency would need its own justification, fake and platform channel
for a payload this small. It is capped at 24 hours: a day-old feed is useful, a
month-old one advertises events that have already happened.

**Search is not in the design.** No discovery frame draws a search affordance.
It was added because a paginated feed that can only be scrolled is not a
working discovery screen. It is deliberately built from existing tokens and
introduces no new colour, so removing it is one widget and changes nothing
else if the designer decides discovery should stay scroll-only.

**`EventDetail` contains a summary rather than extending it.** The list and
detail endpoints return different payloads, and forcing the feed to carry an
overview paragraph for every row would make the list response the size of the
detail one. The detail entity holds the summary it shares with the card, so the
title, venue, date and price cannot drift between the two screens.

**Event times render in the venue's timezone, not the device's.** An event's
start time is a property of where it happens. A traveller reading "20:30" must
see the time they will walk through the gate, so `EventDetail` carries an
offset and an abbreviation (`AST`) from the backend — the abbreviation is a
regional fact rather than an arithmetic one, and the same +03:00 is AST in
Riyadh and MSK in Moscow.

**Availability gates the booking action.** `TicketAvailability` drives both the
button's label and whether it is live, so a sold-out event cannot present a
working "Select seats" that leads into a dead flow. `sellingFast` is explicitly
*not* a restriction — it is a marketing signal about remaining inventory, and
treating it as one disabled the button on precisely the events users most want
to buy.

**The hold countdown is recomputed, never decremented.** `SeatHold` carries the
server's absolute `expires_at`, and each tick asks `AppClock` how long is left
rather than subtracting a second from a local counter. A subtracted counter
drifts while the app is backgrounded and keeps showing time on a hold the
server has already released — telling someone they still have a seat they have
lost is the worst failure this screen can produce. `AppConstants.reservationHoldDuration` stays
display-only, as its own comment already said.

**409 and 423 are answers, not errors.** Losing a seat race marks that seat on
the map and raises a toast over a still-working map; a locked sector opens a
sheet offering alternatives. Neither replaces the screen with an error view,
because in both cases the user can still act — and `LockedFailure` was added to
the `Failure` hierarchy so 423 has a type to switch on rather than falling
through to `UnknownFailure`.

**Seat selection locks during a hold.** Once seats are reserved the map stops
accepting taps, as the design's "Seat selection locked while timer is running"
note states. Letting the user reshuffle seats under a live reservation would
desynchronise the client from what the server is holding.

**The payment window is granted, not computed.** Checkout asks the server to
promote a hold; the server extends it (`AppConstants.paymentWindowExtension`
mirrors the "+3m" for display) and returns a fresh `expires_at` that the client
only ever renders. Adding three minutes locally would show a window the server
never granted and count down to a deadline that had already passed.

**Totals are quoted, never summed on the client.** `CheckoutOrder` carries both
the line items and the total. VAT rates, booking fees and municipal charges are
policy that changes without an app release, and a client that added up its own
figure would eventually disagree with the invoice the customer is charged. The
line items are a list rather than named fields for the same reason: a market
without a booking fee sends one fewer row, not a zero.

**Paying is refused once the window closes.** `pay()` re-checks the deadline
before calling the gateway and expires instead, and `isPaying` stays true after
a successful handoff. Both guard the same thing: a charge against seats the
user no longer holds, or a second charge from a second tap.

**The app displays codes; it does not generate them.** `GatePassRepository`
issues every rotation, and `PresentationCode` holds an opaque payload with a
display hash. No key material and no generation logic lives on the device,
which keeps the unresolved ticket-cryptography contract (see Open decisions)
entirely on the backend's side rather than half-implemented here.

**The rotation interval travels with the grant.** `GatePass.rotationInterval`
comes from the server; `AppConstants.qrRotationInterval` is only a display
default. The screen therefore cannot advertise a cycle the gate disagrees with,
and a backend change needs no app release.

**A captured code is dropped, not hidden.** On a capture the payload is removed
from state entirely — there is no flag whose inversion would reveal it — and
the capture is reported so the issuer invalidates that rotation. Withholding it
locally would not be enough: a forwarded screenshot would still scan. Revealing
a fresh code is deliberately manual, because an automatic re-reveal would put
the payload back on screen while a recording may still be running.

**Screen capture is detected, never prevented.** iOS reports a screenshot only
*after* it happens, while Android can block it outright with `FLAG_SECURE`. The
product response is rotation rather than blocking, because a design relying on
prevention would be honest on one platform and false on the other.

**Clock skew suppresses the QR rather than showing one that will fail.** Past
`AppConstants.clockSkewSuppressionThreshold` (180s, per the design's
"SKEW > 180s") the rotating code is never even requested, because one generated
against an untrusted clock falls outside the scanner's tolerance and would be
rejected at the gate with no explanation. A server-issued eight-digit code is
offered instead — the one credential that does not depend on this device being
right about the time, which is why it cannot be derived on-device.

`AppClock` answers two distinct questions here: `isSyncStale` asks how *old*
the offset is, `isSkewExcessive` how *large*. A device synced a minute ago can
still be badly skewed and one synced days ago may be accurate, so the two
warrant different responses and are kept separate.

**Re-sync decides from the new offset, never from the attempt.** A successful
round-trip that leaves the drift too large keeps the fallback in place, and the
screen says so — otherwise someone at a gate would put away a code they still
need.

**`Ticket` and `GatePass` are separate entities.** The ticket is the durable
record a user owns and which the wallet caches; the pass is its *presentation*
at a gate, carrying rotating codes and security state. Keeping them apart is
what lets the wallet be stored offline while nothing about a presentation code
is ever persisted.

**Confirmation waits for an issued ticket rather than declaring success.** The
app hands off to a hosted gateway and has no authority over whether a charge
settled, so `OrderConfirmationController` polls for the ticket the backend
actually issued. Exhausting that window is reported as *pending*, never as
failed — telling someone their payment failed when their card was charged is
the worst thing this screen could do.

**A used ticket is "past" even for a future event.** The wallet sorts on
status before date: a scanned ticket shown as upcoming would imply a second
entry that will not be granted.

**The concierge runs no model and holds no index.** Retrieval is server-side;
the app sends a question and renders the stream. It has no offline mode by
design — an answer assembled from whatever happened to be cached would be worse
than none for questions about gate times and refund policy, so the screen is
disabled with an explanation rather than degraded.

**A partial answer is kept, never discarded.** If a stream drops halfway, the
text already received stays on screen marked `interrupted`, with a retry.
Throwing it away would lose something the user was mid-way through reading and
make a flaky connection look like silence. A retry replaces the failed exchange
rather than stacking a second copy of the question.

**Answers cite their sources.** Retrieval happens server-side and the sources
come back with the answer; a concierge that states an event's gate time should
be able to say where that came from. Only citations naming something the app
can open are tappable — a dead link is worse than plain text.

**Sign-out wipes locally even when revocation fails.** `ProfileController`
asks the backend to revoke the session first — that is what stops a stolen
refresh token being replayed — then clears the refresh token, the device
private key and the device id regardless of the outcome. A user who taps sign
out on a flaky connection must not be left signed in on the device in front of
them, and the three pieces of material go together: a session ended with a
device key left behind would leave a handset that could still present passes.

**The profile is deliberately sparse.** It shows only what sign-in or a
purchase already required, plus the bound device id — surfaced because device
binding is the anti-sharing property of the whole ticket design, and a user who
cannot see it cannot reason about why a new phone loses their passes.

## Open decisions

These block later phases and are called out in the architecture review:

1. **Ticket cryptography.** The specification describes "TOTP signed with JWT",
   which is not a coherent construct: TOTP verification requires the verifier to
   hold the shared secret, so an offline scanner holding it could forge every
   ticket at its event. The recommendation is a signed grant (server key) plus a
   short-lived presentation proof (device key, ES256 — the only curve with
   hardware backing on both platforms). Needs agreement with the backend before
   Phase 5.

2. **Rotation interval — settled.** Set to the specified 20s, matching the
   design's "Code refreshes every 20s". The original concern stands and is
   worth watching in gate testing: 20s can rotate mid-scan under poor
   conditions, and the anti-sharing property comes from device binding rather
   than a short
   window. Must match the backend's tolerance either way.

3. **Wallet passes.** Apple and Google Wallet passes are static; neither can
   carry a rotating code without provisioning a shared secret to the wallet
   provider. Recommend information-only passes for v1, with entry through the
   app.

## Testing

`flutter test` covers error mapping, clock behaviour including clock-skew cases,
storage, routing with deep links, and Arabic/RTL rendering. Platform-backed
dependencies are supplied through provider overrides; no test touches a real
platform channel.
