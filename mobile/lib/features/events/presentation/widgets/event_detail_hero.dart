import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../../../core/widgets/brand_emblem.dart';
import 'event_cover_image.dart';

/// The full-bleed hero: cover art running under the status bar, with the back
/// control, brand lockup and share control floating on top.
///
/// The controls sit on photography this app does not control, so each carries
/// its own scrim-backed pill and the image carries a gradient beneath them.
/// Without that, a bright cover leaves white glyphs on white sky.
class EventDetailHero extends StatelessWidget {
  const EventDetailHero({
    super.key,
    required this.imageUrl,
    required this.title,
    this.onBack,
    this.onShare,
  });

  final String? imageUrl;

  /// Seeds the placeholder tint when there is no artwork.
  final String title;

  final VoidCallback? onBack;
  final VoidCallback? onShare;

  /// Hero height as a fraction of the frame, from the design's roughly
  /// 340-in-1000 proportion. A fraction rather than a fixed height so the art
  /// keeps its presence on a short phone and does not swallow a tall one.
  static const double heightFactor = 0.42;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Stack(
      fit: StackFit.expand,
      children: [
        EventCoverImage(imageUrl: imageUrl, title: title),
        // Darkens the top for the controls and the bottom so the art dissolves
        // into the page rather than ending on a hard line.
        const _HeroScrim(),
        Positioned(
          top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          child: Row(
            children: [
              _HeroCircleButton(
                icon: Icons.arrow_back_ios_new,
                label: l10n.detailBack,
                onTap: onBack,
              ),
              const Spacer(),
              const _HeroBrandChip(),
              const Spacer(),
              _HeroCircleButton(
                icon: Icons.ios_share,
                label: l10n.detailShare,
                onTap: onShare,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Top-and-bottom darkening over the hero art.
class _HeroScrim extends StatelessWidget {
  const _HeroScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0.55),
            AppColors.background.withValues(alpha: 0.15),
            AppColors.background.withValues(alpha: 0.75),
            AppColors.background,
          ],
          stops: const [0, 0.3, 0.85, 1],
        ),
      ),
    );
  }
}

/// The small Tazkerah lockup centred over the hero.
class _HeroBrandChip extends StatelessWidget {
  const _HeroBrandChip();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.semantic.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const BrandEmblem(size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.appTitleLatin,
            style: context.textStyles.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            l10n.authBrandNameArabic,
            style: TextStyle(
              fontFamily: AppTypography.arabicFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.semantic.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two circular controls over the hero.
class _HeroCircleButton extends StatelessWidget {
  const _HeroCircleButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.background.withValues(alpha: 0.7),
        shape: CircleBorder(side: BorderSide(color: context.semantic.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            // 44pt, the platform minimum for a comfortable tap target — the
            // design's glyph is smaller, but the touch area must not be.
            width: 44,
            height: 44,
            child: Icon(icon, size: 16, color: context.colors.onSurface),
          ),
        ),
      ),
    );
  }
}
