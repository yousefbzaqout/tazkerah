import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../../../core/widgets/brand_emblem.dart';

/// The sticky top bar: the Tazkerah lockup on the leading side, a profile
/// button on the trailing one.
///
/// Built as a [SliverPersistentHeader] delegate rather than an [AppBar] so it
/// can pin over a scrolling feed while keeping the design's exact height and
/// its translucent, hairline-bottomed treatment — an AppBar would impose its
/// own title and leading conventions on both.
class DiscoveryHeaderDelegate extends SliverPersistentHeaderDelegate {
  const DiscoveryHeaderDelegate({required this.topPadding, this.onProfileTap});

  /// The status-bar inset. Passed in rather than read from a [MediaQuery]
  /// here, because a persistent header delegate is rebuilt outside the
  /// sliver's own context.
  final double topPadding;

  final VoidCallback? onProfileTap;

  /// Bar height below the status bar, from the design's 48pt top padding and
  /// 15pt bottom on a 28pt lockup.
  static const double _barHeight = 60;

  @override
  double get minExtent => _barHeight + topPadding;

  @override
  double get maxExtent => _barHeight + topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final semantic = context.semantic;

    return Container(
      // Sized to the declared extent rather than left to the row's intrinsic
      // height. A persistent header must paint exactly the box it claims:
      // a shorter child makes paintExtent fall below layoutExtent, which is a
      // hard assertion failure in the sliver protocol, not a cosmetic gap.
      height: maxExtent,
      padding: EdgeInsets.only(
        top: topPadding,
        left: AppSpacing.xl - 4,
        right: AppSpacing.xl - 4,
      ),
      decoration: BoxDecoration(
        // Slightly translucent, as drawn: content scrolling beneath it stays
        // faintly visible rather than vanishing under an opaque slab.
        color: AppColors.background.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: semantic.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          const _BrandLockup(),
          const Spacer(),
          _ProfileButton(onTap: onProfileTap),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(DiscoveryHeaderDelegate oldDelegate) =>
      oldDelegate.topPadding != topPadding ||
      oldDelegate.onProfileTap != onProfileTap;
}

/// The compact mark-plus-wordmark pairing.
///
/// Both wordmarks are fixed strings in every locale — they are the logo, not
/// copy — which is why they come from [AppLocalizations] as untranslated
/// constants rather than being hard-coded here.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The real ticket mark, not a Material stand-in. Besides matching the
        // design, it keeps the brand distinct from the Tickets tab, which
        // legitimately owns the Material ticket glyph.
        const BrandEmblem(size: 28),
        const SizedBox(width: AppSpacing.sm + 2),
        // Baseline-aligned, as drawn: the Arabic sits on the same line as the
        // Latin rather than centred against it.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              l10n.appTitleLatin,
              style: context.textStyles.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              l10n.authBrandNameArabic,
              style: TextStyle(
                fontFamily: AppTypography.arabicFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.semantic.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The circular profile glyph on the trailing side.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.navProfile,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerLow,
            shape: BoxShape.circle,
            border: Border.all(color: context.semantic.border),
          ),
          child: Icon(
            Icons.person_outline,
            size: 16,
            color: context.semantic.textSecondary,
          ),
        ),
      ),
    );
  }
}
