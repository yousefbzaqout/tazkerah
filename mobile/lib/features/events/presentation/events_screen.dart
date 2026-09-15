import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_status_pill.dart';
import '../domain/discovery_state.dart';
import 'controllers/discovery_controller.dart';
import 'widgets/discovery_header.dart';
import 'widgets/discovery_search_field.dart';
import 'widgets/event_card.dart';
import 'widgets/event_card_skeleton.dart';
import 'widgets/offline_footer.dart';

/// Event discovery — the app's landing screen.
///
/// Renders the three frames from the design as one screen driven by
/// [DiscoveryState]: the skeleton feed while loading, the populated feed when
/// live, and the cached feed with its amber chrome when offline. They are one
/// screen rather than three because the transitions between them must preserve
/// scroll position and the search box's contents.
///
/// The whole thing is one [CustomScrollView] so the header pins over the feed
/// and the footer travels with the content. Nothing here fetches; the
/// controller owns that, and this reads its state.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Requests the next page as the end of the feed comes into view.
  ///
  /// The trigger is one viewport height from the bottom rather than at it, so
  /// the next page is usually already there by the time the user reaches the
  /// end and the feed reads as continuous.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent - position.viewportDimension) {
      ref.read(discoveryControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryControllerProvider);
    final controller = ref.read(discoveryControllerProvider.notifier);
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          controller: _scrollController,
          // Always scrollable so pull-to-refresh works even when the feed is
          // empty or showing an error — which is exactly when a user reaches
          // for it.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: DiscoveryHeaderDelegate(
                topPadding: topPadding,
                onProfileTap: () => context.goNamed(AppRoutes.profileName),
              ),
            ),
            if (state.isStale)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl - 4,
                    AppSpacing.md,
                    AppSpacing.xl - 4,
                    0,
                  ),
                  child: AppBanner(
                    title: context.l10n.discoveryOfflineBanner,
                    tone: AppStatusTone.degraded,
                    icon: Icons.cloud_off_outlined,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl - 4,
                  AppSpacing.xl,
                  AppSpacing.xl - 4,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DiscoveryHeadline(state: state),
                    const SizedBox(height: AppSpacing.lg),
                    DiscoverySearchField(
                      value: state.query,
                      onChanged: controller.search,
                      onClear: controller.clearSearch,
                    ),
                  ],
                ),
              ),
            ),
            ..._buildBody(context, state, controller),
            // Breathing room under the last card, matching the design's
            // bottom spacing above the home indicator.
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The part of the screen that changes with [DiscoveryStatus].
  List<Widget> _buildBody(
    BuildContext context,
    DiscoveryState state,
    DiscoveryController controller,
  ) {
    const horizontal = EdgeInsets.symmetric(horizontal: AppSpacing.lg);

    switch (state.status) {
      case DiscoveryStatus.loading:
        return [
          SliverPadding(
            padding: horizontal,
            sliver: SliverList.separated(
              // Three, as drawn — enough to fill the viewport without
              // animating a long list nobody will see.
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
              itemBuilder: (context, index) => EventCardSkeleton(
                // Staggered widths so the column does not read as a
                // rendering fault.
                titleWidthFactor: [0.55, 0.62, 0.48][index % 3],
              ),
            ),
          ),
        ];

      case DiscoveryStatus.error:
        final failure = state.failure;
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: failure == null
                ? const SizedBox.shrink()
                : AppErrorView(failure: failure, onRetry: controller.load),
          ),
        ];

      case DiscoveryStatus.empty:
        final l10n = context.l10n;
        final searching = state.query.trim().isNotEmpty;
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyView(
              title: l10n.discoveryEmptyTitle,
              message: searching
                  ? l10n.discoveryEmptyMessage
                  : l10n.discoveryEmptyFeedMessage,
              icon: Icons.search_off_outlined,
              action: searching
                  ? TextButton(
                      onPressed: controller.clearSearch,
                      child: Text(l10n.discoverySearchClear),
                    )
                  : null,
            ),
          ),
        ];

      case DiscoveryStatus.ready:
      case DiscoveryStatus.offline:
        return [
          SliverPadding(
            padding: horizontal,
            sliver: SliverList.separated(
              itemCount: state.events.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
              itemBuilder: (context, index) {
                final event = state.events[index];
                return EventCard(
                  // Keyed by id so a refresh that reorders the feed moves the
                  // existing card rather than rebuilding a different event's
                  // content into it — which would swap cover images between
                  // rows mid-scroll.
                  key: ValueKey(event.id),
                  event: event,
                  showCachedTag: state.isStale,
                  onTap: () => context.go(AppRoutes.eventDetailPath(event.id)),
                );
              },
            ),
          ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          if (state.isStale && state.cachedAt != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  0,
                ),
                child: OfflineFooter(
                  cachedAt: state.cachedAt!,
                  isReconnecting: state.isRefreshing,
                  onReconnect: controller.refresh,
                ),
              ),
            ),
        ];
    }
  }
}

/// The eyebrow, status pill and title above the feed.
///
/// All three change with status: the eyebrow names the source of the data, and
/// the pill reports whether it is live, syncing, or a count of cached rows.
class _DiscoveryHeadline extends StatelessWidget {
  const _DiscoveryHeadline({required this.state});

  final DiscoveryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final (String eyebrow, Widget? pill) = switch (state.status) {
      DiscoveryStatus.loading => (
        l10n.eventsEyebrow,
        AppStatusPill(
          label: l10n.discoverySynchronizing,
          tone: AppStatusTone.live,
        ),
      ),
      DiscoveryStatus.offline => (
        l10n.discoveryCacheEyebrow,
        AppStatusPill(
          label: l10n.discoveryPassesReady(state.events.length),
          tone: AppStatusTone.degraded,
        ),
      ),
      DiscoveryStatus.ready => (
        l10n.eventsEyebrow,
        AppStatusPill(label: l10n.eventsLivePasses, tone: AppStatusTone.live),
      ),
      // Nothing to report on an empty or failed feed, and a pill claiming
      // "LIVE PASSES" above an error would be actively misleading.
      DiscoveryStatus.empty ||
      DiscoveryStatus.error => (l10n.eventsEyebrow, null),
    };

    return AppSectionHeader(
      title: l10n.discoveryTitle,
      eyebrow: eyebrow,
      trailing: pill,
    );
  }
}
