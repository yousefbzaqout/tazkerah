# Tazkerah

Attendee mobile application for the Tazkerah event ticketing platform.
Flutter, targeting iOS and Android.

## Requirements

- Flutter 3.44+ (Dart 3.12+)
- Xcode 16+ for iOS
- JDK 17 and the Android SDK for Android

## Getting started

```bash
flutter pub get
flutter gen-l10n     # regenerate localizations after editing lib/l10n/*.arb
flutter run
```

The app expects a backend at the URL in `AppConfig`. The default points at
`http://10.0.2.2:8000/api/v1`, which is the host machine as seen from the
Android emulator. Override it per environment:

```bash
flutter run \
  --dart-define=ENVIRONMENT=staging \
  --dart-define=API_BASE_URL=https://staging.api.tazkerah.app/api/v1
```

On an iOS simulator, reach a local backend on `http://localhost:8000/api/v1`.

## Checks

```bash
flutter analyze
flutter test
```

## Localization

Strings live in `lib/l10n/app_en.arb` (the template, with descriptions) and
`lib/l10n/app_ar.arb`. Add a key to the template first, then translate it, then
run `flutter gen-l10n`. Generated output under `lib/l10n/generated/` is not
edited by hand.

Arabic is a first-class locale, so build layouts with directional widgets
(`EdgeInsetsDirectional`, `AlignmentDirectional`) rather than left/right
equivalents, and check screens in both directions.

## Structure

See [ARCHITECTURE.md](ARCHITECTURE.md) for the layout, the dependency rules,
and the reasoning behind the foundational decisions — including three open
questions on ticket cryptography that block Phase 5.

## Notes for the next phase

- Universal links and App Links need `apple-app-site-association` and
  `assetlinks.json` served from the production domain before deep links open
  the app without a chooser.
