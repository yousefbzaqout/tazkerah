import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../extensions/build_context_x.dart';

/// The cut-out ticket shape: a rounded card with a semicircular notch bitten
/// out of each side and a perforated line between them.
///
/// Drawn as a [ShapeBorder] rather than composed from stacked widgets, so the
/// notch is part of the card's outline. That matters because the shape then
/// clips its own background, casts a correct shadow, and works at any size.
///
/// [notchOffsetFromBottom] places the perforation. The design puts it roughly
/// two thirds down, separating the event details above from the stub below.
class TicketShapeBorder extends OutlinedBorder {
  const TicketShapeBorder({
    super.side = BorderSide.none,
    this.radius = AppRadius.lg,
    this.notchRadius = AppRadius.ticketNotch,
    this.notchOffsetFromBottom = 96,
  });

  final double radius;
  final double notchRadius;
  final double notchOffsetFromBottom;

  double _notchCentreY(Rect rect) {
    // Clamped so an unusually short card cannot push the notch outside its
    // own bounds, which would produce a torn-looking outline.
    return rect.bottom -
        notchOffsetFromBottom.clamp(notchRadius * 2, rect.height - notchRadius);
  }

  Path _buildPath(Rect rect) {
    final notchY = _notchCentreY(rect);
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    final leftNotch = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(rect.left, notchY), radius: notchRadius),
      );
    final rightNotch = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.right, notchY),
          radius: notchRadius,
        ),
      );

    return Path.combine(
      PathOperation.difference,
      Path.combine(PathOperation.difference, body, leftNotch),
      rightNotch,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect.deflate(side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_buildPath(rect.deflate(side.strokeInset)), side.toPaint());
  }

  @override
  TicketShapeBorder copyWith({
    BorderSide? side,
    double? radius,
    double? notchRadius,
    double? notchOffsetFromBottom,
  }) {
    return TicketShapeBorder(
      side: side ?? this.side,
      radius: radius ?? this.radius,
      notchRadius: notchRadius ?? this.notchRadius,
      notchOffsetFromBottom:
          notchOffsetFromBottom ?? this.notchOffsetFromBottom,
    );
  }

  @override
  ShapeBorder scale(double t) => TicketShapeBorder(
    side: side.scale(t),
    radius: radius * t,
    notchRadius: notchRadius * t,
    notchOffsetFromBottom: notchOffsetFromBottom * t,
  );
}

/// A ticket-shaped card with a dashed perforation across the notch line.
///
/// Layout is the caller's: pass [body] for the part above the perforation and
/// [stub] for the part below. This widget owns the shape, not the content.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.body,
    this.stub,
    this.stubHeight = 96,
    this.accentColor,
  });

  /// Content above the perforation.
  final Widget body;

  /// Content below it. Omit for a plain notched card.
  final Widget? stub;

  /// Height reserved for [stub]; also where the notch sits.
  final double stubHeight;

  /// Tints the border and perforation — emerald for a live pass, amber when
  /// intercepted. Defaults to the neutral border.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final accent = accentColor ?? semantic.border;
    final stub = this.stub;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.colors.surfaceContainerLow,
        shape: TicketShapeBorder(
          side: BorderSide(color: accent),
          notchOffsetFromBottom: stub == null ? stubHeight : stubHeight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: body),
          if (stub != null) ...[
            _Perforation(color: accent),
            SizedBox(
              height: stubHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: stub,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The dashed line running between the two notches.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Inset past the notch cut-outs so the dashes do not run into them.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashedLinePainter(color: color.withValues(alpha: 0.6)),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += _dash + _gap) {
      final end = (x + _dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
