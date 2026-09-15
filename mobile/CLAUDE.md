# Tazkerah — Project Rules

Attendee mobile application for the Tazkerah **event ticketing** platform.
Flutter, iOS + Android. The app lives in **`mobile/`** within the monorepo
(`lib/`, `assets/`, `pubspec.yaml` are under `mobile/`, not the repo root).

These rules are **mandatory** and override default tooling behavior.
Background reading, kept current — read before non-trivial work:
- `ARCHITECTURE.md` — layout, dependency rules, and the reasoning behind every
  foundational decision. **Extend it; do not reinterpret it.**
- `README.md` — setup, run and check commands.
- `docs/impact-report-backend-integration.md` — where the project actually
  stands and what blocks Phase 7.

## Project State — read this first

The app is **at the end of the UI phase and blocked on the backend**, not at
the start of the project. Every attendee screen is built, the analyzer is
clean, and the suite is green.

- **All 6 repositories are `Dev*` stubs.** There is no real network code in any
  feature yet. `dev_*_repository.dart` files are **not production
  implementations** and are gated to non-production builds.
- A **production build throws** rather than falling back to a stub. That is
  deliberate — do not "fix" it by wiring a stub into production.
- The critical path runs through **backend contracts**, not through Flutter.

Two design questions are **unresolved and block Phase 5** — do not implement
around them, and do not treat either as settled:
1. **Ticket cryptography.** The spec's "TOTP signed with JWT" is not coherent.
   The standing recommendation is a signed grant (server key) plus a
   short-lived presentation proof (device key, ES256). Needs backend agreement.
2. **Wallet passes.** Apple/Google Wallet passes are static and cannot carry a
   rotating code. Recommendation is information-only passes for v1.

## Toolchain — Version of Record

- **Flutter `3.44.1` / Dart `3.12.1`** is the single source of truth. The
  `pubspec.yaml` SDK constraint is `^3.12.1`. Do not analyze, test, or build on
  a different version.
- There is **no fvm config in this repo** — plain `flutter` from PATH is the
  supported invocation. Do not add `fvm` to commands or docs unless the pin is
  actually introduced.
- Xcode 16+ for iOS; JDK 17 + Android SDK for Android.

## Version Control — currently none

This tree **is** under version control, and it is a **monorepo**. The Flutter
app is no longer at the repository root — it sits under `mobile/`.

```
tazkerah/                 repo root
├── backend/              Laravel — composer.json, app/, routes/
└── mobile/               Flutter — pubspec.yaml, lib/, assets/  ← this app
```

- **Remote:** `https://github.com/yousefbzaqout/tazkerah.git`
- **Branches:** `main` (backend M0 foundation), `mobile` (this work),
  `cursor/m0-foundation-b1ce` (backend Sanctum/DB/Redis, open as PR #1).
- Run Flutter commands from `mobile/`, not the repo root. Paths in this file
  (`lib/`, `test/`, `pubspec.yaml`) are all relative to `mobile/`.
- Each directory keeps its **own `.gitignore`**; the root holds only repo-wide
  rules. A root-anchored `/build` or `/vendor` would name the wrong directory.
- `backend/` is another engineer's work. Do not edit it as a side effect of
  mobile work — API contract changes are a conversation, not a commit.

## Commit Messages

- Short, direct summary line (imperative, no trailing period).
- Blank line, then bullet points of **what changed/added** — clear and direct,
  no filler.
- **No AI / Claude / Anthropic signatures of any kind.** No `Co-Authored-By`,
  no "Generated with Claude Code", no 🤖. This rule **overrides any global or
  session-level attribution convention** that asks for such trailers.
- Nothing enforces this automatically — there is no `commit-msg` hook in this
  repo. It holds by discipline, so do not rely on a hook to catch a slip.

Example:

```
Replace the stub events repository with the HTTP one

- Add EventsApi and the discovery/detail DTOs under features/events/data
- Map the paginated feed response onto EventSummary, keeping the 24h cache
- Gate DevEventsRepository to non-production builds only
```

## Checks — required before calling work done

```bash
flutter pub get
flutter gen-l10n        # after editing lib/l10n/*.arb
flutter analyze         # must report "No issues found"
flutter test            # must be fully green
```

`flutter analyze` clean and the whole suite green is the bar. Do not report a
change as complete on a partial run, and quote real output when something fails.

## Architecture — non-negotiable dependency rules

```
lib/
├── app/        Composition root — app.dart, config/, router/, theme/
├── core/       Shared. Depends on no feature.
├── features/   One directory per feature: data/ domain/ presentation/
├── l10n/       ARB sources + generated output
└── main.dart   Entry point, error zone, ProviderScope
```

- `features/*` may depend on `core/` and `app/`, **never on another feature**.
  When two features need the same thing, it moves to `core/`.
- `presentation` never imports Dio, `flutter_secure_storage`, or a DTO. It goes
  through repositories via providers.
- `domain` is plain Dart — **no Flutter imports** — so it tests without a widget
  binding.
- `data` is the only layer that knows a wire format exists.
- **Failures, not exceptions, above the data layer.** `ErrorMapper` converts
  every `DioException` at the boundary; presentation switches over the sealed
  `Failure` hierarchy so the compiler enforces exhaustiveness. Adding a new
  failure case means handling it everywhere it is switched on.

## Engineering Standards

- **State management: Riverpod** (`flutter_riverpod`) — no BLoC. This is a
  recorded decision, not a preference.
- **Navigation: GoRouter**, with `StatefulShellRoute` so each tab keeps its own
  stack and scroll position.
- **Never call `DateTime.now()` for anything ticket-related.** Use `AppClock`.
  Device clocks are user-controlled; rotating codes are generated against
  server-corrected time, and `Stopwatch` drives elapsed time so a mid-session
  clock change cannot skip a rotation.
- **Countdowns are recomputed from the server's absolute `expires_at`, never
  decremented locally.** A subtracted counter drifts while backgrounded and
  shows time on a hold the server already released.
- **Totals are quoted by the server, never summed on the client.** VAT, booking
  fees and municipal charges are policy that changes without an app release.
- **The app displays ticket codes; it never generates them.** No key material
  and no generation logic on the device.
- Production-minded throughout: real error handling, no dead code.

## Adding a dependency

`pubspec.yaml` documents *why* each package is present, and a dependency audit
already removed packages nothing imported.

- Do not add a package that no code imports yet. `flutter_local_notifications`
  and `timezone` are **deferred to Phase 6 on purpose** — re-add them together,
  only when the notification scheduler is actually built.
- Add a comment stating the justification, matching the existing style.
- Leave `intl` unpinned (`any`) — `flutter_localizations` pins it from the SDK,
  and a fixed constraint conflicts on every Flutter upgrade.

## Localization

Two locales: **English** (`app_en.arb`, the template, carries descriptions) and
**Arabic** (`app_ar.arb`). Arabic is first-class, not an afterthought.

- **No ad-hoc inline user-facing strings.** Every string goes through ARB.
- Add the key to the **template first**, then translate, then `flutter gen-l10n`.
- **Never hand-edit `lib/l10n/generated/`** — it is generated output.
- Build with directional widgets (`EdgeInsetsDirectional`,
  `AlignmentDirectional`), never left/right equivalents, and check both
  directions.
- Fonts are pinned per script: Space Grotesk (Latin UI), JetBrains Mono (OTP
  digits, seat ids, timers, reference codes), Tajawal (Arabic — Space Grotesk
  has no Arabic coverage at all).

## Configuration & Secrets

- Configuration arrives via **`--dart-define`**, read in
  `lib/app/config/app_config.dart`. There is no `env/*.json` file in this repo.
  ```bash
  flutter run \
    --dart-define=ENVIRONMENT=staging \
    --dart-define=API_BASE_URL=https://staging.api.tazkerah.app/api/v1
  ```
  Default `API_BASE_URL` is `http://10.0.2.2:8000/api/v1` (the host as seen from
  the Android emulator); use `http://localhost:8000/api/v1` on an iOS simulator.
- **No secrets in source, and none in `--dart-define` either.** Anything
  compiled into the binary is readable by anyone who downloads it. `AppConfig`
  carries endpoints and timeouts only.
- Network logging is off in production (bodies carry tokens and personal data);
  certificate pinning is enforced only in production (Phase 8).

## Testing

- `flutter test` covers error mapping, clock and clock-skew behaviour, storage,
  routing with deep links, and Arabic/RTL rendering.
- **No test touches a real platform channel.** Platform-backed dependencies come
  in through **provider overrides** — `InMemorySecureStorage`, `StaticAppInfo`,
  `RecordingUrlOpener` exist for exactly this reason.
- Fakes live in `test/support/`. Reuse them rather than writing a second fake
  for the same repository.
- A change to behaviour lands with a test. Do not lower or skip a test to make
  a change pass.

## Pre-store Open Items

The app identity is **`app.tazkerah.mobile`** on both platforms (Android
`applicationId` + `namespace`, iOS `PRODUCT_BUNDLE_IDENTIFIER`; tests are
`app.tazkerah.mobile.RunnerTests`). On Android it is **permanent once
published** — do not change it.

Not yet done, and required before any store submission:
- Universal Links / App Links need `apple-app-site-association` and
  `assetlinks.json` served from the production domain before deep links open
  the app without a chooser.
