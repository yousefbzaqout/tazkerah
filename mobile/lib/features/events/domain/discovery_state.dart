import '../../../core/errors/failure.dart';
import 'event_summary.dart';

/// What the discovery screen is currently showing.
///
/// The design draws three states — skeleton loading, populated feed, and
/// offline-cached — and they are not independent booleans. A screen cannot be
/// both loading-from-empty and showing cached rows, and "offline" is only
/// meaningful when there is cached data behind it. Modelling that as one
/// object with a small [DiscoveryStatus] enum keeps those combinations
/// unrepresentable, the way [SignInFlowState] does for auth.
class DiscoveryState {
  const DiscoveryState({
    this.status = DiscoveryStatus.loading,
    this.events = const [],
    this.failure,
    this.cachedAt,
    this.query = '',
    this.nextCursor,
    this.isLoadingMore = false,
    this.isRefreshing = false,
  });

  final DiscoveryStatus status;

  /// The rows to render. Non-empty in [DiscoveryStatus.ready] and
  /// [DiscoveryStatus.offline]; empty otherwise.
  final List<EventSummary> events;

  /// Why the feed could not load. Only set in [DiscoveryStatus.error], where
  /// there is nothing cached to fall back to.
  final Failure? failure;

  /// When the shown data was captured, for the offline footer. Set with
  /// [DiscoveryStatus.offline].
  final DateTime? cachedAt;

  /// The active search text. Held here rather than in the text field so a tab
  /// switch and back restores the filter along with the results.
  final String query;

  /// Cursor for the next page; null when the feed is fully loaded.
  final String? nextCursor;

  /// A page request is in flight below the current rows. Distinct from
  /// [status] so appending never blanks the list the user is reading.
  final bool isLoadingMore;

  /// A pull-to-refresh is in flight. Also distinct from [status]: the existing
  /// rows stay on screen under the spinner rather than collapsing to skeletons.
  final bool isRefreshing;

  /// Whether another page can be requested.
  bool get hasMore => nextCursor != null;

  /// Whether the feed is showing data that is known to be stale.
  bool get isStale => status == DiscoveryStatus.offline;

  DiscoveryState copyWith({
    DiscoveryStatus? status,
    List<EventSummary>? events,
    Failure? failure,
    DateTime? cachedAt,
    String? query,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool clearFailure = false,
    bool clearCachedAt = false,
    bool clearCursor = false,
  }) {
    return DiscoveryState(
      status: status ?? this.status,
      events: events ?? this.events,
      failure: clearFailure ? null : (failure ?? this.failure),
      cachedAt: clearCachedAt ? null : (cachedAt ?? this.cachedAt),
      query: query ?? this.query,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

/// The mutually exclusive conditions the feed can be in.
enum DiscoveryStatus {
  /// First load, nothing to show yet — the design's skeleton frame.
  loading,

  /// Live data on screen.
  ready,

  /// Cached data on screen, with no connection to refresh it. The rows are
  /// real and usable; the chrome says so.
  offline,

  /// Nothing to show and nothing cached to fall back to.
  error,

  /// The request succeeded and returned no rows — a normal outcome, and
  /// deliberately not [error]. An empty search result is not a failure.
  empty,
}
