import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../extensions/build_context_x.dart';

/// A seat's availability, as the map renders it.
enum SeatState {
  available,

  /// Held by this user, in the current order.
  held,

  /// Taken by someone else.
  sold,

  /// The seat that just lost a race — the 409 case.
  conflict,

  /// Present in the layout but not sellable in this tier.
  unavailable,
}

/// One seat in the seat map.
///
/// Deliberately a plain [StatelessWidget] over a `CustomPainter`: at the
/// design's scale (tens of seats per sector) widgets are simpler and
/// accessible. A hall with thousands of seats will need a painter with
/// viewport culling instead — that is a Phase 4 decision, flagged in the
/// architecture review, and this widget is not the thing to scale.
class SeatChip extends StatelessWidget {
  const SeatChip({
    super.key,
    required this.label,
    this.state = SeatState.available,
    this.onTap,
    this.size = 28,
  });

  /// Seat number as printed: `08`, `12`.
  final String label;

  final SeatState state;

  /// Null for any seat that cannot be chosen.
  final VoidCallback? onTap;

  final double size;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    final (Color background, Color foreground, Color? border) = switch (state) {
      SeatState.available => (
        semantic.surfaceElevated,
        semantic.textSecondary,
        semantic.borderStrong,
      ),
      SeatState.held => (semantic.seatHeld, context.colors.onPrimary, null),
      SeatState.sold => (semantic.surfaceElevated, semantic.seatSold, null),
      SeatState.conflict => (
        semantic.dangerContainer,
        semantic.seatConflict,
        semantic.seatConflict,
      ),
      SeatState.unavailable => (Colors.transparent, semantic.seatSold, null),
    };

    final isInteractive = onTap != null && state == SeatState.available;

    return Semantics(
      button: isInteractive,
      enabled: isInteractive,
      label: label,
      child: InkWell(
        onTap: isInteractive ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: border == null ? null : Border.all(color: border),
          ),
          child: Text(
            label,
            // Seat numbers are machine values: always LTR, even in Arabic.
            textDirection: TextDirection.ltr,
            style: AppTypography.mono.copyWith(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
