import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../extensions/build_context_x.dart';

/// A price with its currency, as the design sets it: a large mono amount in
/// emerald followed by a small muted currency code.
///
/// Takes [amount] as a preformatted string rather than a number. Formatting a
/// currency correctly is locale work — separators and digit shapes differ
/// between `en` and `ar` — and belongs in the layer that has the locale, not
/// in a widget that would have to guess.
class PriceDisplay extends StatelessWidget {
  const PriceDisplay({
    super.key,
    required this.amount,
    required this.currency,
    this.caption,
    this.emphasis = PriceEmphasis.standard,
    this.strikethrough = false,
  });

  /// Already formatted for the active locale: `1,006.25`.
  final String amount;

  /// Currency code: `SAR`.
  final String currency;

  /// Small label above, such as `FROM` or `STARTING FROM`.
  final String? caption;

  final PriceEmphasis emphasis;

  /// Struck through for a released or refunded amount.
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final caption = this.caption;

    final amountStyle = switch (emphasis) {
      PriceEmphasis.standard => AppTypography.monoPrice,
      PriceEmphasis.large => AppTypography.monoPrice.copyWith(fontSize: 26),
      PriceEmphasis.muted => AppTypography.monoPrice.copyWith(fontSize: 15),
    };

    final amountColor = switch (emphasis) {
      PriceEmphasis.muted => semantic.textTertiary,
      _ => semantic.success,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (caption != null)
          Text(
            caption,
            style: AppTypography.monoLabel.copyWith(
              color: semantic.textTertiary,
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              amount,
              style: amountStyle.copyWith(
                color: amountColor,
                decoration: strikethrough ? TextDecoration.lineThrough : null,
                decorationColor: amountColor,
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              currency,
              style: AppTypography.monoLabel.copyWith(
                color: semantic.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum PriceEmphasis {
  /// Card and detail prices.
  standard,

  /// The order total.
  large,

  /// Line items in a breakdown.
  muted,
}
