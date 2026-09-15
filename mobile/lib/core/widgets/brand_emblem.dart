import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_shadows.dart';
import '../../app/theme/app_spacing.dart';

/// The Tazkerah mark: a ticket outline with a centre dot, on a gradient tile.
///
/// The glyph is painted from the design's exported path data rather than
/// rendered through an SVG library — the artwork is two paths, so a painter
/// reproduces it exactly without adding a dependency the audit would have to
/// justify. `assets/icons/ticket_emblem.svg` remains the source of truth if
/// the mark is ever redrawn.
class BrandEmblem extends StatelessWidget {
  const BrandEmblem({super.key, this.size = 56});

  /// Outer tile size. The glyph inside is half this, matching the design's
  /// 28-in-56 proportion.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.emblemGradientStart, AppColors.emblemGradientEnd],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.emblem,
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size / 2),
          painter: const _TicketGlyphPainter(),
        ),
      ),
    );
  }
}

/// Paints the ticket mark on a 28x28 grid, scaled to the available size.
class _TicketGlyphPainter extends CustomPainter {
  const _TicketGlyphPainter();

  /// The design's viewBox. Paths below are in these units and scaled at paint
  /// time, so the glyph stays crisp at any size.
  static const double _viewBox = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    canvas.save();
    canvas.scale(scale);

    // Ticket body: rounded rectangle with a semicircular bite out of each
    // side, exactly as exported.
    final body = Path()
      ..moveTo(4.66667, 9.33333)
      ..cubicTo(4.66667, 8.04467, 5.71133, 7, 7, 7)
      ..lineTo(21, 7)
      ..cubicTo(22.2887, 7, 23.3333, 8.04467, 23.3333, 9.33333)
      ..lineTo(23.3333, 11.0833)
      ..cubicTo(21.7225, 11.0833, 20.4167, 12.3892, 20.4167, 14)
      ..cubicTo(20.4167, 15.6108, 21.7225, 16.9167, 23.3333, 16.9167)
      ..lineTo(23.3333, 18.6667)
      ..cubicTo(23.3333, 19.9554, 22.2887, 21, 21, 21)
      ..lineTo(7, 21)
      ..cubicTo(5.71133, 21, 4.66667, 19.9554, 4.66667, 18.6667)
      ..lineTo(4.66667, 16.9167)
      ..cubicTo(6.27749, 16.9167, 7.58333, 15.6108, 7.58333, 14)
      ..cubicTo(7.58333, 12.3892, 6.27749, 11.0833, 4.66667, 11.0833)
      ..close();

    canvas.drawPath(
      body,
      Paint()..color = AppColors.primary.withValues(alpha: 0.9),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45833,
    );

    // Centre dot, punched in the background colour.
    canvas.drawCircle(
      const Offset(14, 14),
      2.04167,
      Paint()..color = AppColors.background,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketGlyphPainter oldDelegate) => false;
}
