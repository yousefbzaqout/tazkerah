import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/build_context_x.dart';

/// The banner at the top of checkout: the window is open, and this is how long
/// is left.
///
/// Turns amber as the window narrows. The threshold is a product decision
/// rather than a visual one — it is the point at which a user should stop
/// reading and start paying — so it lives here as a named constant rather than
/// as a magic number inside a colour expression.
class PaymentWindowBar extends StatelessWidget {
  const PaymentWindowBar({super.key, required this.remaining});

  final Duration remaining;

  /// Below this the bar reads as urgent.
  static const Duration urgentThreshold = Duration(seconds: 60);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final isUrgent = remaining <= urgentThreshold;
    final accent = isUrgent ? semantic.warning : semantic.success;

    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 2,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.checkoutWindowActive,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 11,
                    color: accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.checkoutWindowExtended(
                    AppConstants.paymentWindowExtension.inMinutes,
                  ),
                  style: context.textStyles.bodySmall?.copyWith(
                    fontSize: 11,
                    color: semantic.textTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm - 2,
            ),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$minutes:$seconds',
              // A timer is a machine value: LTR in every locale, and tabular
              // so the digits do not shift the bar each second.
              textDirection: TextDirection.ltr,
              style: AppTypography.monoValue.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
