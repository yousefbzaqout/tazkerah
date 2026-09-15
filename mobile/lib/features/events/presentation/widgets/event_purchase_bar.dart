import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../../../core/widgets/ticket/price_display.dart';
import '../../domain/event_detail.dart';

/// The pinned bar at the foot of the detail screen: the starting price on the
/// leading side, the seat-selection action on the trailing one.
///
/// Pinned rather than scrolled with the content, because it is the screen's
/// one conversion point and a user who has read half the overview should not
/// have to scroll to the bottom to act on it.
///
/// The action's label and enabled state both come from [TicketAvailability],
/// so a sold-out event cannot present a working button — the button says what
/// it is, and does nothing, rather than leading into a dead flow.
class EventPurchaseBar extends StatelessWidget {
  const EventPurchaseBar({
    super.key,
    required this.detail,
    required this.price,
    required this.currency,
    this.onSelectSeats,
  });

  final EventDetail detail;

  /// Already formatted for the locale, per [PriceDisplay]'s contract.
  final String price;
  final String currency;

  final VoidCallback? onSelectSeats;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final l10n = context.l10n;
    final enabled = detail.canSelectSeats && onSelectSeats != null;

    final label = switch (detail.availability) {
      TicketAvailability.soldOut => l10n.detailSoldOut,
      TicketAvailability.notYetOnSale => l10n.detailNotOnSale,
      _ => l10n.detailSelectSeats,
    };

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: semantic.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: semantic.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.detailStartingFrom,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 10,
                    color: semantic.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Reuses the shared price component rather than restyling the
                // amount here, so the detail price and the card price cannot
                // drift apart.
                PriceDisplay(
                  amount: price,
                  currency: currency,
                  emphasis: PriceEmphasis.large,
                  strikethrough:
                      detail.availability == TicketAvailability.soldOut,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.detailFeesIncluded,
                  style: context.textStyles.bodySmall?.copyWith(
                    fontSize: 11,
                    color: semantic.textDisabled,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: FilledButton(
              onPressed: enabled ? onSelectSeats : null,
              // Overrides only what differs from the themed button, so the
              // emerald fill, shape and disabled treatment all still come
              // from `filledButtonTheme` rather than being rebuilt here.
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                ),
                // The bar is tighter than a full-width form button.
                minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: AppSpacing.sm),
                    // Mirrored by hand under RTL. No Material arrow carries
                    // `matchTextDirection`, so `Icon` will not flip it on its
                    // own — and an arrow that keeps pointing right in Arabic
                    // points backwards through the flow it is describing.
                    Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.rtl,
                      child: const Icon(Icons.arrow_forward, size: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
