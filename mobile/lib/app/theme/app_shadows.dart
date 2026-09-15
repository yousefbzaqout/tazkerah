import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Elevation tokens.
///
/// On a near-black background a neutral drop shadow is close to invisible, so
/// the design separates layers two ways instead: a lighter surface colour, and
/// a coloured glow on the element that matters. Both appear here.
abstract final class AppShadows {
  /// No elevation. Most cards sit flat and rely on their surface colour and
  /// border for separation.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Cards lifted off the page — the event cards, the receipt block.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Bottom sheets and dialogs. Deep enough to read against the scrim.
  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, -8)),
  ];

  /// The emerald halo under a primary button.
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(color: Color(0x4010B981), blurRadius: 24, offset: Offset(0, 6)),
  ];

  /// The ring around the live QR card, and the success check halo.
  static const List<BoxShadow> primaryHalo = [
    BoxShadow(color: Color(0x3310B981), blurRadius: 32, spreadRadius: 2),
  ];

  /// The amber glow on an intercepted or suppressed pass.
  static const List<BoxShadow> warningHalo = [
    BoxShadow(color: Color(0x33F59E0B), blurRadius: 32, spreadRadius: 2),
  ];

  /// The red glow on the expired-hold clock.
  static const List<BoxShadow> dangerHalo = [
    BoxShadow(color: Color(0x33EF4444), blurRadius: 32, spreadRadius: 2),
  ];

  /// Scrim behind a modal.
  static const Color scrim = Color(0xB3000000);

  /// Guards [qrCanvas] against the dark page so the white card does not bloom
  /// at the high brightness the ticket screen forces.
  static const List<BoxShadow> qrCard = [
    BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Border colour for a control in its resting state.
  static const Color hairline = AppColors.border;

  /// The brand emblem's tile: a deep drop shadow plus a faint emerald bloom.
  static const List<BoxShadow> emblem = [
    BoxShadow(
      color: Color(0x99000000),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
    BoxShadow(color: Color(0x3310B981), blurRadius: 20, spreadRadius: -8),
  ];

  /// The ambient emerald wash behind the auth screen's brand mark. Gradient
  /// stops, not a shadow, but it belongs with the other elevation effects.
  static const List<Color> ambientBloomColors = [
    Color(0x0D10B981),
    Color(0x0010B981),
  ];
}
