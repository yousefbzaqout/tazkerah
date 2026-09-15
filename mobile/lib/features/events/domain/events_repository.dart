import 'event_detail.dart';
import 'event_summary.dart';

/// What the discovery feed needs from the backend.
///
/// Declared in domain so the controller and its tests do not depend on how it
/// is fulfilled. The endpoint below is the contract this app expects; the
/// backend has not agreed it yet:
///
///   GET /events?query={q}&cursor={c}  -> {data: [...], next_cursor, cached_at}
///   GET /events/{id}                  -> {id, title, overview, ...}
///
/// Until a real implementation is bound, [eventsRepositoryProvider] binds a
/// development stub outside production and throws inside it — the same rule
/// [AuthRepository] follows, for the same reason: canned success that ships
/// by accident is worse than a build that refuses to start.
abstract interface class EventsRepository {
  /// Fetches one page of the discovery feed.
  ///
  /// [query] filters by free text when non-empty. [cursor] continues a
  /// previous page; null starts from the beginning.
  ///
  /// Throws a [Failure] on transport or protocol errors. Returning an empty
  /// page is not an error — it is an empty feed, and the UI distinguishes the
  /// two.
  Future<EventPage> fetchEvents({String? query, String? cursor});

  /// Fetches one event in full.
  ///
  /// A separate call rather than a richer list payload: the detail screen is
  /// reached by deep link as often as by tapping a card, so it must be able to
  /// load an event the feed never returned.
  ///
  /// Throws [NotFoundFailure] when [id] does not exist — an expired campaign
  /// link is a normal thing to be handed, and the screen renders it as a
  /// missing event rather than a crash.
  Future<EventDetail> fetchEvent(String id);
}

/// One page of the feed, plus what the UI needs to know about its freshness.
class EventPage {
  const EventPage({required this.events, this.nextCursor, this.cachedAt});

  final List<EventSummary> events;

  /// Cursor for the following page, or null when this is the last one.
  ///
  /// A cursor rather than a page number: the feed is ordered by start date and
  /// events are inserted continuously, so offset paging would duplicate and
  /// skip rows as the underlying list shifts between requests.
  final String? nextCursor;

  /// When this data was captured, if it came from the local cache.
  ///
  /// Null means it is live. Non-null is what puts the app into the design's
  /// offline state: the amber banner, the `CACHED` tags, and the "Last
  /// synchronized 14m ago" footer all read from this one field, so a cached
  /// page cannot render as live.
  final DateTime? cachedAt;

  bool get isFromCache => cachedAt != null;
}
