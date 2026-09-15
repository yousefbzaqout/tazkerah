import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';

/// The "Tazkerah تذكرة" wordmark.
///
/// The two scripts are a single lockup, not a translated string: the Arabic
/// sits beside the Latin in every locale, in emerald at a smaller size. That
/// is why the Arabic comes from its own ARB key rather than from translating
/// the app title.
///
/// Wrapped in a [Directionality] pinned to LTR so the Latin stays first even
/// in the Arabic locale — a brand lockup does not mirror.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            l10n.appTitleLatin,
            style: context.textStyles.displaySmall?.copyWith(
              fontSize: 36,
              letterSpacing: -0.9,
              height: 1,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            l10n.authBrandNameArabic,
            style: AppTypography.textTheme.titleLarge?.copyWith(
              // Always the Arabic face: this text is Arabic regardless of the
              // active locale.
              fontFamily: AppTypography.arabicFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1,
              color: context.colors.primary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
