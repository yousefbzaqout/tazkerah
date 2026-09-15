import 'package:flutter/material.dart';
// `intl` exports its own `TextDirection`, which shadows the one from
// `dart:ui` that `Text` expects. Hidden so the widget code keeps meaning the
// framework's.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../domain/checkout_order.dart';

/// The reservation panel: what was booked, where, when, and which seat.
class OrderReservationCard extends StatelessWidget {
  const OrderReservationCard({super.key, required this.order});

  final CheckoutOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final locale = Localizations.localeOf(context).toString();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: semantic.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.checkoutConfirmedReservation,
            style: AppTypography.monoLabel.copyWith(
              fontSize: 10,
              color: semantic.success,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(order.eventTitle, style: context.textStyles.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            order.venueLine,
            style: context.textStyles.bodySmall?.copyWith(
              color: semantic.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MiniCard(
                    label: l10n.detailDateTimeLabel,
                    value: DateFormat.MMMEd(
                      locale,
                    ).add_Hm().format(order.localStartsAt),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MiniCard(
                    label: l10n.checkoutSeatReserved,
                    value: order.seatLabel,
                    valueColor: semantic.success,
                    // The seat reference is a machine value; bidi reordering
                    // would scramble `VIP · Sector A · Row 12` in Arabic.
                    valueDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the paired label/value cards.
class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueDirection,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextDirection? valueDirection;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: semantic.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.monoLabel.copyWith(
              fontSize: 9,
              color: semantic.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            textDirection: valueDirection,
            style: context.textStyles.titleSmall?.copyWith(color: valueColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The itemised charges and the total.
///
/// Every figure comes from the server. This widget formats and arranges; it
/// does not add anything up — see [CheckoutOrder] for why the total is quoted
/// rather than computed.
class OrderPriceBreakdown extends StatelessWidget {
  const OrderPriceBreakdown({super.key, required this.order});

  final CheckoutOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final locale = Localizations.localeOf(context).toString();
    final money = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    );
    final vat = order.vatRegistration;
    final totalNote = order.totalNote;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: semantic.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.checkoutPriceBreakdown,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 11,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              if (vat != null)
                Text(
                  l10n.checkoutVatRegistration(vat),
                  style: AppTypography.mono.copyWith(
                    fontSize: 9,
                    color: semantic.textDisabled,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in order.lineItems)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: semantic.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${money.format(item.amountMinor / 100)} ${order.currency}',
                    textDirection: TextDirection.ltr,
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 12,
                      color: semantic.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: semantic.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.checkoutTotalAmount,
                      style: context.textStyles.titleSmall,
                    ),
                    if (totalNote != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        totalNote,
                        style: context.textStyles.bodySmall?.copyWith(
                          fontSize: 10,
                          color: semantic.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money.format(order.totalMinor / 100),
                    textDirection: TextDirection.ltr,
                    style: AppTypography.monoPrice.copyWith(
                      fontSize: 22,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    order.currency,
                    style: AppTypography.monoLabel.copyWith(
                      color: semantic.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
