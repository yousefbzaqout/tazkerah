import 'package:flutter/material.dart';

/// Type tokens.
///
/// The design runs two families, and the split carries meaning:
///
/// - **Sans** for language — titles, body copy, button labels.
/// - **Mono** for machine values — codes, timers, seat ids, prices, status
///   eyebrows. Mono is what makes `TZK-88429-DXB`, `00:00` and `48291703`
///   legible as data rather than prose, and its fixed advance stops a
///   counting timer from shifting its neighbours on every tick.
///
/// All three faces ship with the app: Space Grotesk, JetBrains Mono and
/// Tajawal. [sansFamily], [monoFamily] and [arabicFamily] are the single
/// place a family changes.
///
/// Never build a [TextStyle] inside a widget. Take one from
/// `Theme.of(context).textTheme`, or from [AppTypography.mono] for machine
/// values, and adjust with `.copyWith` only for colour.
abstract final class AppTypography {
  /// Latin display and UI face, from the design.
  static const String sansFamily = 'SpaceGrotesk';

  /// Arabic face.
  ///
  /// Listed as the fallback for every sans style because Space Grotesk has no
  /// Arabic coverage — without this, Arabic text renders as tofu boxes rather
  /// than falling back gracefully. Flutter consults the fallback list
  /// per-glyph, so a mixed line like "Tazkerah تذكرة" resolves each script to
  /// the right face automatically.
  static const String arabicFamily = 'Tajawal';

  /// Applied to every sans style below.
  static const List<String> sansFallback = <String>[arabicFamily];

  /// Monospace face, from the design.
  ///
  /// Bundled rather than resolved from the platform: these styles carry OTP
  /// digits, timers and seat ids, and letting each OS pick its own mono would
  /// give those values different metrics on iOS and Android.
  static const String monoFamily = 'JetBrainsMono';

  /// Arabic still falls back to Tajawal — JetBrains Mono has no Arabic
  /// coverage either, and a mono label can contain Arabic in that locale.
  static const List<String> monoFallback = <String>[arabicFamily];

  /// Arabic needs more vertical room than Latin at the same point size:
  /// descenders and diacritics collide on tight leading. Applied to the body
  /// styles below, which is where long Arabic copy lands.
  static const double _bodyHeight = 1.55;

  // --------------------------------------------------------------- sans

  /// The Material text theme, in the design's proportions.
  static const TextTheme textTheme = TextTheme(
    // "Tazkerah" on the splash, "Hold expired" on the timeout screen.
    displaySmall: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.5,
    ),

    // Event titles on the detail screen.
    headlineMedium: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.3,
    ),

    // "Select Experience", "Purchase Confirmed".
    headlineSmall: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.2,
    ),

    // Event names on list cards.
    titleLarge: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),

    // Sheet and dialog titles: "Sector locked by organizer".
    titleMedium: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),

    // Row labels in the detail and receipt blocks.
    titleSmall: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),

    // Primary reading copy — the overview paragraph.
    bodyLarge: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: _bodyHeight,
    ),

    // Default body: venue lines, supporting sentences.
    bodyMedium: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: _bodyHeight,
    ),

    // Helper and footnote text.
    bodySmall: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),

    // Button labels.
    labelLarge: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),

    labelMedium: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),

    labelSmall: TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
  );

  // --------------------------------------------------------------- mono

  /// Base monospace style. Prefer the named variants below.
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Uppercase section eyebrows: `EXCLUSIVE GATE ENTRIES`, `PRICE BREAKDOWN`.
  static const TextStyle monoEyebrow = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 1.2,
  );

  /// Status chips and small machine labels: `CACHED`, `HTTP 423 · LOCKED`.
  static const TextStyle monoLabel = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.6,
  );

  /// Reference ids and seat codes: `TZK-88429-DXB`, `VIP · A-12`.
  static const TextStyle monoValue = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.3,
  );

  /// Prices. Tabular figures so a column of amounts aligns on the decimal.
  static const TextStyle monoPrice = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The hold countdown and the QR rotation timer. Tabular figures matter
  /// here: without them every tick nudges the layout.
  static const TextStyle monoTimer = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: 2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A single digit in the OTP entry boxes.
  static const TextStyle monoOtpDigit = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The manual-entry fallback code shown when the QR is suppressed. Large,
  /// widely tracked, meant to be read aloud to a gate steward.
  static const TextStyle monoOtp = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 6,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
