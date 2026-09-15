import 'package:flutter/material.dart';

/// Colour tokens, read from the Tazkerah design.
///
/// The design is **dark only** — there is no light variant in any frame, so
/// none is invented here. [AppTheme] commits to the dark palette rather than
/// generating a light scheme nobody has approved.
///
/// Widgets must not hold `Color(0x...)` literals. Read colours from
/// `Theme.of(context).colorScheme` where a Material role fits, and from
/// [AppSemanticColors] (via `context.semantic`) for the ticketing states
/// Material has no role for.
abstract final class AppColors {
  // ---------------------------------------------------------------- surfaces

  /// Page background. The near-black the whole app sits on.
  static const Color background = Color(0xFF090A0F);

  /// Raised surface: cards, inputs, the app bar.
  static const Color surface = Color(0xFF0F1118);

  /// A step above [surface]: nested panels, the price-breakdown block, and
  /// bottom sheets that must read as closer to the viewer.
  static const Color surfaceElevated = Color(0xFF1A1D27);

  /// Hairlines and input outlines.
  static const Color border = Color(0xFF232738);

  /// A brighter border for the focused or selected element.
  static const Color borderStrong = Color(0xFF39414F);

  /// The emblem's gradient ends. A 135° sweep across the brand mark's tile.
  static const Color emblemGradientStart = Color(0xFF12141C);
  static const Color emblemGradientEnd = Color(0xFF1A1D27);

  // ------------------------------------------------------------------- brand

  /// Emerald. Primary actions, prices, and anything confirmed or live.
  static const Color primary = Color(0xFF10B981);

  /// Pressed and hovered states of [primary].
  static const Color primaryDim = Color(0xFF0D9268);

  /// Tinted fill behind primary content — the "confirmed" badge, the success
  /// check halo. Low alpha so it sits on [surface] without glowing.
  static const Color primarySoft = Color(0x1A10B981);

  /// Text and icons on top of a [primary] fill. Near-black, not white: the
  /// emerald is bright enough that white text fails contrast on it.
  static const Color onPrimary = Color(0xFF04120C);

  // ------------------------------------------------------------------ status

  /// Amber. Degraded but not failed: offline, sector locked, clock drift,
  /// screenshot intercepted.
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0x1FF59E0B);

  /// Red. The action could not complete: seat conflict, hold expired,
  /// invalid code.
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0x1FEF4444);

  /// Success reuses [primary] deliberately — in this product a confirmed
  /// purchase and a live pass are the same emerald, and splitting them would
  /// put two greens on one screen.
  static const Color success = primary;
  static const Color successSoft = primarySoft;

  // -------------------------------------------------------------------- text

  /// Headings and primary content.
  static const Color textPrimary = Color(0xFFF2F5F7);

  /// Supporting copy: venue lines, descriptions, helper text.
  static const Color textSecondary = Color(0xFF94A3B8);

  /// Field labels, metadata, and the uppercase mono eyebrows.
  static const Color textTertiary = Color(0xFF64748B);

  /// Placeholders and disabled labels.
  static const Color textDisabled = Color(0xFF475569);

  /// The dimmest step, used for the footer's separator dot.
  static const Color textFaint = Color(0xFF334155);

  /// Amber text on a warning surface. Lighter than [warning] itself, which is
  /// reserved for dots, icons and borders.
  static const Color warningText = Color(0xFFFBBF24);

  // ------------------------------------------------------------------ ticket

  /// The QR card itself is white so a scanner can read it in a dark hall —
  /// the one deliberately light surface in the app.
  static const Color qrCanvas = Color(0xFFFFFFFF);

  /// QR modules and the text printed on [qrCanvas].
  static const Color qrInk = Color(0xFF0A0C10);
}
