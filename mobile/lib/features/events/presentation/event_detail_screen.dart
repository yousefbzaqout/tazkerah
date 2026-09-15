import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_status_pill.dart';
import '../../../core/navigation/seat_selection_args.dart';
import '../domain/event_detail.dart';
import '../domain/event_detail_state.dart';
import 'controllers/event_detail_controller.dart';
import 'event_formatting.dart';
import 'widgets/event_detail_hero.dart';
import 'widgets/event_detail_skeleton.dart';
import 'widgets/event_info_cards.dart';
import 'widgets/event_purchase_bar.dart';

/// Event details: hero, headline, date and location, overview, and the
/// booking entry point.
///
/// Reached both by tapping a card and by deep link (`/events/{id}`), so it
/// loads by id rather than taking an event object — a link opened from outside
/// the app has no card behind it.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventDetailControllerProvider(eventId));
    final controller = ref.read(
      eventDetailControllerProvider(eventId).notifier,
    );

    return Scaffold(
      body: switch (state) {
        EventDetailLoading() => const EventDetailSkeleton(),
        EventDetailError(:final failure, :final isMissing) => SafeArea(
          child: isMissing
              ? AppEmptyView(
                  title: context.l10n.detailMissingTitle,
                  message: context.l10n.detailMissingMessage,
                  icon: Icons.event_busy_outlined,
                  action: FilledButton(
                    onPressed: () => context.goNamed(AppRoutes.eventsName),
                    child: Text(context.l10n.detailBrowseEvents),
                  ),
                )
              // A transient fault is worth retrying; a deleted event is not,
              // which is why the two are not the same screen.
              : AppErrorView(failure: failure, onRetry: controller.load),
        ),
        EventDetailReady(:final detail) => _DetailBody(
          detail: detail,
          onRefresh: controller.refresh,
        ),
      },
    );
  }
}

/// The loaded screen: scrolling content under a pinned purchase bar.
class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.onRefresh});

  final EventDetail detail;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final locale = Localizations.localeOf(context).toString();
    final heroHeight =
        MediaQuery.sizeOf(context).height * EventDetailHero.heightFactor;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            // Offset so the spinner clears the hero's floating controls
            // rather than landing under them.
            edgeOffset: MediaQuery.paddingOf(context).top + AppSpacing.xxl,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: heroHeight,
                    child: EventDetailHero(
                      imageUrl: detail.heroImageUrl ?? detail.summary.imageUrl,
                      title: detail.title,
                      onBack: () => _onBack(context),
                      onShare: () => _onShare(context, ref),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _StatusRow(detail: detail),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        detail.title,
                        style: context.textStyles.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        detail.subtitle,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: semantic.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _InfoRow(detail: detail, locale: locale),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.detailOverviewLabel,
                        style: AppTypography.monoEyebrow.copyWith(
                          color: semantic.textTertiary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        detail.overview,
                        style: context.textStyles.bodyLarge?.copyWith(
                          color: semantic.textSecondary,
                        ),
                      ),
                      if (detail.securityNote != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        TicketSecurityRow(
                          note: detail.securityNote!,
                          antiPassbackEnabled: detail.antiPassbackEnabled,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: EventPurchaseBar(
            detail: detail,
            price: NumberFormat.decimalPattern(
              locale,
            ).format(detail.summary.priceFrom),
            currency: detail.summary.currency,
            onSelectSeats: () => _onSelectSeats(context),
          ),
        ),
      ],
    );
  }

  /// Returns to the feed. Falls back to the events tab when there is nothing
  /// to pop — which is the case for a deep link opened from outside the app,
  /// where popping would leave the user on a blank stack.
  void _onBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.eventsName);
    }
  }

  /// Opens the event's public link.
  ///
  /// Shares the web URL rather than an in-app route so the link works for
  /// someone without the app: universal links open it in Tazkerah when
  /// installed, and on the website when not.
  Future<void> _onShare(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    final opened = await ref
        .read(urlOpenerProvider)
        .share(text: detail.title, url: AppRoutes.eventShareUrl(detail.id));
    if (!context.mounted || opened) return;

    messenger.showSnackBar(SnackBar(content: Text(l10n.detailShareSoon)));
  }

  /// Opens seat selection, handing over the title and venue this screen
  /// already holds so the next one need not refetch them.
  void _onSelectSeats(BuildContext context) {
    context.push(
      AppRoutes.eventSeatsPath(detail.id),
      extra: SeatSelectionArgs(
        title: detail.title,
        venue: detail.venueAddress.isEmpty ? null : detail.venueAddress,
      ),
    );
  }
}

/// The pill and availability line above the title.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.detail});

  final EventDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final tierLabel = detail.tierLabel;

    return Row(
      children: [
        AppStatusPill(
          label: l10n.detailOfficialGateEntry,
          tone: AppStatusTone.live,
          showDot: false,
        ),
        if (tierLabel != null) ...[
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: switch (detail.availability) {
                      TicketAvailability.soldOut => context.colors.error,
                      TicketAvailability.sellingFast => semantic.warning,
                      _ => semantic.success,
                    },
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm - 2),
                Flexible(
                  child: Text(
                    tierLabel,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: semantic.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The paired date and location cards.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.detail, required this.locale});

  final EventDetail detail;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final start = detail.localStartsAt;
    final doors = detail.localDoorsOpenAt;
    final timeFormat = DateFormat.Hm(locale);

    final timeLine = doors == null
        ? l10n.detailTimeNoGates(
            timeFormat.format(start),
            detail.timeZoneAbbreviation,
          )
        : l10n.detailGatesAt(
            timeFormat.format(start),
            detail.timeZoneAbbreviation,
            timeFormat.format(doors),
          );

    return IntrinsicHeight(
      // Equal-height cards, as drawn: without this a two-line address makes
      // the location card taller than the date card and the row looks broken.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: EventInfoCard(
              icon: Icons.calendar_today_outlined,
              label: l10n.detailDateTimeLabel,
              primary: DateFormat.yMMMEd(locale).format(start),
              secondary: timeLine,
              secondaryTone: InfoCardTone.live,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: EventInfoCard(
              icon: Icons.location_on_outlined,
              label: l10n.detailLocationLabel,
              primary: detail.venueAddress,
              secondary: EventFormatting.location(context, detail.summary),
            ),
          ),
        ],
      ),
    );
  }
}
