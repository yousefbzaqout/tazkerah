import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/event_summary.dart';
import '../event_formatting.dart';
import 'event_cover_image.dart';

/// One event in the discovery feed.
///
/// The composition from the design: edge-to-edge cover art under a dark
/// gradient, a date chip floated over its top-left corner, then a content row
/// pairing the title and venue against a right-aligned starting price.
///
/// The gradient is not decoration. The date chip and the card's upper edge sit
/// on top of photography this app does not control, so without it a bright
/// image would leave white-on-white text. It is what makes the chip legible on
/// any cover.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showCachedTag = false,
  });

  final EventSummary event;
  final VoidCallback? onTap;

  /// Renders the `CACHED` tag from the offline frame. Driven by the feed's
  /// status rather than by the card, so a card cannot claim to be cached on a
  /// live screen.
  final bool showCachedTag;

  /// Cover height, from the design's 240px on a 420px-wide frame. Expressed as
  /// a ratio instead of a fixed height so the art keeps its proportions on a
  /// narrow phone and a tablet alike.
  ///
  /// Public because [EventCardSkeleton] must reserve exactly this much space.
  /// Two constants would drift, and the feed would jump as skeletons were
  /// replaced by cards of a different height.
  static const double coverAspectRatio = 420 / 240;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final l10n = context.l10n;

    final dateChip = EventFormatting.dateChip(context, event);
    final price = EventFormatting.price(context, event);

    return Semantics(
      button: onTap != null,
      // One label for the whole card. Without this a screen reader walks the
      // chip, title, venue and price as four unrelated fragments.
      label: l10n.discoveryEventCardLabel(
        event.title,
        EventFormatting.fullDate(context, event),
        price,
      ),
      excludeSemantics: true,
      child: Material(
        color: context.colors.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: semantic.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: coverAspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      EventCoverImage(
                        imageUrl: event.imageUrl,
                        title: event.title,
                        desaturate: showCachedTag,
                      ),
                      const _CoverScrim(),
                      PositionedDirectional(
                        top: AppSpacing.md + 2,
                        start: AppSpacing.md + 2,
                        child: _DateChip(label: dateChip),
                      ),
                      if (showCachedTag)
                        PositionedDirectional(
                          top: AppSpacing.md + 2,
                          end: AppSpacing.md + 2,
                          child: AppStatusPill(
                            label: l10n.discoveryCachedTag,
                            tone: AppStatusTone.degraded,
                          ),
                        )
                      else if (event.soldOut)
                        PositionedDirectional(
                          top: AppSpacing.md + 2,
                          end: AppSpacing.md + 2,
                          child: AppStatusPill(
                            label: l10n.discoverySoldOut,
                            tone: AppStatusTone.failed,
                            showDot: false,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: _CardContent(event: event, price: price),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Title and venue on the left, price on the right.
class _CardContent extends StatelessWidget {
  const _CardContent({required this.event, required this.price});

  final EventSummary event;
  final String price;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: context.textStyles.titleLarge,
                // Two lines, as drawn. A longer title truncates rather than
                // pushing the card taller and breaking the feed's rhythm.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm - 2),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: semantic.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      EventFormatting.location(context, event),
                      style: context.textStyles.bodySmall?.copyWith(
                        color: semantic.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.discoveryPriceFrom,
              style: AppTypography.monoLabel.copyWith(
                fontSize: 10,
                color: semantic.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              price,
              style: AppTypography.monoPrice.copyWith(
                fontSize: 18,
                color: event.soldOut ? semantic.textDisabled : semantic.success,
                decoration: event.soldOut ? TextDecoration.lineThrough : null,
              ),
              // The price is a machine value; bidi reordering would put the
              // currency on the wrong side of the amount in Arabic.
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ],
    );
  }
}

/// The dark gradient over the cover art.
///
/// Bottom-weighted, matching the design: transparent at the top so the
/// photograph reads, opaque at the bottom where it meets the card body, which
/// is what makes the seam between image and content invisible.
class _CoverScrim extends StatelessWidget {
  const _CoverScrim();

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surfaceContainerLow;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0.05),
            surface.withValues(alpha: 0.45),
            surface,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
    );
  }
}

/// The blurred date capsule floated over the cover.
class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        border: Border.all(
          color: context.colors.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.monoLabel.copyWith(
          fontSize: 12,
          color: context.colors.onSurface,
        ),
      ),
    );
  }
}
