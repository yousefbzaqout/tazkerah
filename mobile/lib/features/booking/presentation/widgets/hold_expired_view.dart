import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../domain/checkout_order.dart';

/// The expired-hold frame: the window reached zero and the seats went back.
///
/// It shows *what was lost*, struck through, rather than only reporting the
/// failure. A user who has just lost a seat wants to know which seat, at what
/// price, under which rule — partly to understand, and partly because a
/// dispute needs something to quote.
class HoldExpiredView extends StatelessWidget {
  const HoldExpiredView({
    super.key,
    required this.order,
    this.policyCode,
    this.onSelectAgain,
    this.onReturnToEvent,
  });

  final CheckoutOrder order;

  /// The rule the release happened under: `FR-011 / BR-003`.
  final String? policyCode;

  final VoidCallback? onSelectAgain;
  final VoidCallback? onReturnToEvent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final error = context.colors.error;
    final policyCode = this.policyCode;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                _ExpiredClock(color: error),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.checkoutHoldTimer,
                  style: AppTypography.monoLabel.copyWith(
                    color: semantic.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '00:00',
                  textDirection: TextDirection.ltr,
                  style: AppTypography.monoTimer.copyWith(
                    fontSize: 26,
                    color: error,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Two-tone headline, as drawn: the fact in white, the
                // consequence in the alert colour.
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${l10n.checkoutExpiredTitle}\n',
                        style: context.textStyles.headlineSmall,
                      ),
                      TextSpan(
                        text: l10n.checkoutExpiredTitleAccent,
                        style: context.textStyles.headlineSmall?.copyWith(
                          color: error,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.checkoutExpiredMessage,
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: semantic.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _ReleasedReservation(order: order),
                if (policyCode != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: semantic.textDisabled,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.checkoutPolicyNote(policyCode),
                          textAlign: TextAlign.center,
                          style: AppTypography.mono.copyWith(
                            fontSize: 11,
                            color: semantic.textDisabled,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
        _ExpiredActions(
          onSelectAgain: onSelectAgain,
          onReturnToEvent: onReturnToEvent,
        ),
      ],
    );
  }
}

/// The haloed clock glyph with its cancel badge.
class _ExpiredClock extends StatelessWidget {
  const _ExpiredClock({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.schedule, size: 34, color: color),
          ),
          PositionedDirectional(
            end: 4,
            bottom: 8,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.surface,
                border: Border.all(color: color),
              ),
              child: Icon(Icons.close, size: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The struck-through summary of what was released.
class _ReleasedReservation extends StatelessWidget {
  const _ReleasedReservation({required this.order});

  final CheckoutOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final error = context.colors.error;

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
                  l10n.checkoutReleasedReservation,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 10,
                    color: semantic.textTertiary,
                  ),
                ),
              ),
              Text(
                l10n.checkoutExpiredTag,
                style: AppTypography.monoLabel.copyWith(
                  fontSize: 10,
                  color: error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            order.eventTitle,
            style: context.textStyles.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.checkoutHeldSeat(order.seatLabel),
                  // A seat reference is a machine value: LTR in every locale.
                  textDirection: TextDirection.ltr,
                  style: AppTypography.mono.copyWith(
                    fontSize: 12,
                    color: semantic.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${(order.totalMinor / 100).toStringAsFixed(0)} '
                '${order.currency}',
                textDirection: TextDirection.ltr,
                style: AppTypography.monoValue.copyWith(
                  fontSize: 12,
                  color: semantic.textDisabled,
                  // Struck through: the amount was never charged, and showing
                  // it plainly would read as a bill.
                  decoration: TextDecoration.lineThrough,
                  decorationColor: semantic.textDisabled,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The two recovery actions.
class _ExpiredActions extends StatelessWidget {
  const _ExpiredActions({this.onSelectAgain, this.onReturnToEvent});

  final VoidCallback? onSelectAgain;
  final VoidCallback? onReturnToEvent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.semantic.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: onSelectAgain,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.checkoutSelectSeatsAgain),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onReturnToEvent,
              child: Text(l10n.checkoutReturnToEvent),
            ),
          ],
        ),
      ),
    );
  }
}
