import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../domain/seat.dart';
import '../../domain/seat_hold.dart';

/// The selection bar: what is chosen, what it costs, and the action.
///
/// Shown while the user is still choosing. Its disabled state is the design's
/// "Select an available seat" prompt — the button explains what to do rather
/// than sitting inert with a label that implies it should work.
class SeatSelectionBar extends StatelessWidget {
  const SeatSelectionBar({
    super.key,
    required this.seat,
    required this.priceLabel,
    required this.currency,
    this.isSubmitting = false,
    this.onHold,
  });

  /// The chosen seat, or null when nothing is selected.
  final Seat? seat;

  /// Already formatted for the locale, or null when there is nothing to price.
  final String? priceLabel;
  final String currency;

  final bool isSubmitting;
  final VoidCallback? onHold;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final seat = this.seat;
    final enabled = seat != null && !isSubmitting && onHold != null;

    return _BarShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.seatCurrentSelection,
                      style: AppTypography.monoLabel.copyWith(
                        fontSize: 10,
                        color: semantic.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      seat == null ? l10n.seatNoSelection : seat.label,
                      style: seat == null
                          ? context.textStyles.bodyMedium?.copyWith(
                              color: semantic.textDisabled,
                            )
                          : AppTypography.monoValue.copyWith(
                              fontSize: 18,
                              color: context.colors.onSurface,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.seatSubtotal,
                    style: AppTypography.monoLabel.copyWith(
                      fontSize: 10,
                      color: semantic.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    // An em dash, not "0": nothing is selected, which is not
                    // the same as something that costs nothing.
                    priceLabel == null
                        ? '— $currency'
                        : '$priceLabel $currency',
                    textDirection: TextDirection.ltr,
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 14,
                      color: priceLabel == null
                          ? semantic.textDisabled
                          : semantic.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: enabled ? onHold : null,
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    seat == null ? l10n.seatSelectPrompt : l10n.seatHoldSeat,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The held bar: the assigned seat, the total, and checkout.
class SeatHeldBar extends StatelessWidget {
  const SeatHeldBar({
    super.key,
    required this.hold,
    required this.seat,
    required this.sectorName,
    required this.totalLabel,
    this.subtitle,
    this.onCheckout,
  });

  final SeatHold hold;
  final Seat? seat;

  /// The sector as printed beside the seat: `VIP`.
  final String sectorName;

  /// Already formatted for the locale.
  final String totalLabel;

  /// Editorial line under the seat: "Soundstorm Exclusive Front Row".
  final String? subtitle;

  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final seat = this.seat;
    final subtitle = this.subtitle;

    return _BarShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: semantic.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.seatAssignedSelection,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 10,
                    color: semantic.textTertiary,
                  ),
                ),
              ),
              Text(
                l10n.seatTotalPrice,
                style: context.textStyles.bodySmall?.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wraps rather than overflowing: the seat id and its row
                    // caption together exceed a narrow bar, and the caption
                    // dropping to a second line is far better than the id
                    // being clipped.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: AppSpacing.sm,
                      children: [
                        Text(
                          '$sectorName · ${seat?.label ?? ''}',
                          textDirection: TextDirection.ltr,
                          style: AppTypography.monoValue.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (seat != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              l10n.seatRowSeatCaption(seat.row, seat.number),
                              style: context.textStyles.bodySmall?.copyWith(
                                color: semantic.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: semantic.success,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$totalLabel ${hold.currency}',
                    textDirection: TextDirection.ltr,
                    style: AppTypography.monoPrice.copyWith(
                      fontSize: 20,
                      color: semantic.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.seatFeesNote,
                    style: context.textStyles.bodySmall?.copyWith(
                      fontSize: 10,
                      color: semantic.textDisabled,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onCheckout,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.seatContinueCheckout),
                const SizedBox(width: AppSpacing.sm),
                Transform.flip(
                  flipX: Directionality.of(context) == TextDirection.rtl,
                  child: const Icon(Icons.arrow_forward, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared chrome for both bars, so they cannot drift apart.
class _BarShell extends StatelessWidget {
  const _BarShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: semantic.border)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
