import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/features/events/domain/event_detail.dart';
import 'package:tazkerah/features/events/domain/event_summary.dart';
import 'package:tazkerah/features/events/domain/events_repository.dart';

/// An [EventsRepository] a test can steer.
///
/// Answers with whatever [pages] is set to, or throws [failure] when one is
/// set. Records every call so a test can assert on what was requested — which
/// is how debounce and cursor behaviour are checked without timing guesses.
class FakeEventsRepository implements EventsRepository {
  FakeEventsRepository({
    this.pages = const [],
    this.details = const {},
    this.failure,
    this.delay,
  });

  /// Responses, consumed in order. The last one repeats once exhausted, so a
  /// test that does not care about later calls need only supply one.
  List<EventPage> pages;

  /// When set, every call throws this instead of answering.
  Failure? failure;

  /// Optional latency, for tests that need to observe an in-flight state.
  Duration? delay;

  /// Every (query, cursor) pair this repository was asked for.
  final List<({String? query, String? cursor})> calls = [];

  /// Detail responses, keyed by event id. An id that is absent produces a
  /// [NotFoundFailure], which is what the real backend does for a dead link.
  Map<String, EventDetail> details = {};

  /// Ids this repository was asked for detail on.
  final List<String> detailCalls = [];

  int _index = 0;

  @override
  Future<EventPage> fetchEvents({String? query, String? cursor}) async {
    calls.add((query: query, cursor: cursor));

    final delay = this.delay;
    if (delay != null) await Future<void>.delayed(delay);

    final failure = this.failure;
    if (failure != null) throw failure;

    if (pages.isEmpty) return const EventPage(events: []);
    final page = pages[_index.clamp(0, pages.length - 1)];
    _index++;
    return page;
  }

  @override
  Future<EventDetail> fetchEvent(String id) async {
    detailCalls.add(id);

    final delay = this.delay;
    if (delay != null) await Future<void>.delayed(delay);

    final failure = this.failure;
    if (failure != null) throw failure;

    final detail = details[id];
    if (detail == null) throw const NotFoundFailure();
    return detail;
  }
}

/// A throwaway event detail, with only the fields a test names.
EventDetail testDetail({
  EventSummary? summary,
  String subtitle = 'Test Venue • Test Series',
  String overview = 'A test overview paragraph.',
  String venueAddress = 'Test Address',
  DateTime? doorsOpenAt,
  String timeZoneAbbreviation = 'AST',
  Duration timeZoneOffset = const Duration(hours: 3),
  TicketAvailability availability = TicketAvailability.available,
  String? tierLabel,
  String? securityNote = 'Encrypted Dynamic QR Ticket',
}) {
  return EventDetail(
    summary: summary ?? testEvent(),
    subtitle: subtitle,
    overview: overview,
    venueAddress: venueAddress,
    doorsOpenAt: doorsOpenAt,
    timeZoneAbbreviation: timeZoneAbbreviation,
    timeZoneOffset: timeZoneOffset,
    availability: availability,
    tierLabel: tierLabel,
    securityNote: securityNote,
  );
}

/// A throwaway event, with only the fields a test names.
EventSummary testEvent({
  String id = 'evt_1',
  String title = 'Test Event',
  String venue = 'Test Venue',
  String city = 'Riyadh',
  DateTime? startsAt,
  DateTime? endsAt,
  num priceFrom = 100,
  String currency = 'SAR',
  bool soldOut = false,
}) {
  return EventSummary(
    id: id,
    title: title,
    venue: venue,
    city: city,
    startsAt: startsAt ?? DateTime.utc(2026, 12, 14, 19),
    endsAt: endsAt,
    priceFrom: priceFrom,
    currency: currency,
    soldOut: soldOut,
  );
}
