import 'dart:async';

import '../../../core/errors/failure.dart';
import '../domain/event_detail.dart';
import '../domain/event_summary.dart';
import '../domain/events_repository.dart';

/// A stand-in [EventsRepository] for running discovery before the backend
/// exists.
///
/// **Not a production implementation.** [AppConfig] gates it to non-production
/// builds. It serves the four events drawn in the design so the screen can be
/// checked on a device in both locales, and — like [DevAuthRepository] — it is
/// deliberately capable of failing, because the offline and error states are
/// most of what there is to look at here.
///
/// Drive the states by hand with the search box:
///
/// - `offline` → the request fails, and the controller falls back to cache
/// - `error`   → the request fails with nothing cached
/// - `empty`   → a successful response with no rows
class DevEventsRepository implements EventsRepository {
  DevEventsRepository({this.latency = const Duration(milliseconds: 700)});

  /// Simulated round-trip, so the skeleton state is visible on a device
  /// rather than flashing past.
  ///
  /// Set it to [Duration.zero] in tests that do not care about the loading
  /// state: a pending timer outliving the widget tree fails the test binding,
  /// and a stub should not be the reason a router test is flaky.
  final Duration latency;

  /// Tracks the in-flight delay so [dispose] can cancel it.
  Timer? _pending;

  /// Cancels any simulated request still in flight.
  ///
  /// Real implementations will close their HTTP client here. The stub has
  /// nothing to close but a timer — and leaving that running is what makes a
  /// disposed test binding complain about pending work.
  void dispose() {
    _pending?.cancel();
    _pending = null;
  }

  /// [Future.delayed] with a handle on the timer, so it can be cancelled.
  Future<void> _sleep() {
    if (latency == Duration.zero) return Future<void>.value();
    final completer = Completer<void>();
    _pending = Timer(latency, () {
      _pending = null;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Queries that force a failure, so each state is reachable without
  /// switching off the network.
  static const String offlineQuery = 'offline';
  static const String errorQuery = 'error';
  static const String emptyQuery = 'empty';

  /// Page size, small enough that pagination is exercisable with a stub
  /// catalogue of eight.
  static const int pageSize = 4;

  @override
  Future<EventPage> fetchEvents({String? query, String? cursor}) async {
    await _sleep();

    final normalized = query?.trim().toLowerCase() ?? '';

    if (normalized == offlineQuery || normalized == errorQuery) {
      throw const NetworkFailure(
        debugMessage: 'DevEventsRepository: simulated connectivity failure',
      );
    }
    if (normalized == emptyQuery) {
      return const EventPage(events: []);
    }

    final matches = normalized.isEmpty
        ? _catalogue
        : _catalogue
              .where(
                (e) =>
                    e.title.toLowerCase().contains(normalized) ||
                    e.venue.toLowerCase().contains(normalized) ||
                    e.city.toLowerCase().contains(normalized),
              )
              .toList();

    // The cursor is the index to resume from. A real backend would issue an
    // opaque token; an index is enough to exercise the paging path.
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = (start + pageSize).clamp(0, matches.length);
    final page = matches.sublist(start.clamp(0, matches.length), end);

    return EventPage(
      events: page,
      nextCursor: end < matches.length ? '$end' : null,
    );
  }

  @override
  Future<EventDetail> fetchEvent(String id) async {
    await _sleep();

    final summary = _catalogue.where((e) => e.id == id).firstOrNull;
    if (summary == null) {
      // The same answer the real backend gives for a dead campaign link, so
      // the screen's missing-event path is reachable by hand.
      throw NotFoundFailure(
        debugMessage: 'DevEventsRepository: no event with id "$id"',
      );
    }

    final detail = _details[id];
    return EventDetail(
      summary: summary,
      subtitle: detail?.subtitle ?? '${summary.venue} • ${summary.city}',
      overview: detail?.overview ?? _genericOverview,
      venueAddress: detail?.venueAddress ?? summary.venue,
      // Gates an hour and a half before the doors time in the design.
      doorsOpenAt: summary.startsAt.subtract(const Duration(minutes: 90)),
      // Saudi Arabia is UTC+3 year round; the design prints it as AST.
      timeZoneAbbreviation: 'AST',
      timeZoneOffset: const Duration(hours: 3),
      availability: summary.soldOut
          ? TicketAvailability.soldOut
          : (detail?.availability ?? TicketAvailability.available),
      tierLabel: summary.soldOut ? null : detail?.tierLabel,
      securityNote: 'Encrypted Dynamic QR Ticket',
    );
  }

  /// Editorial copy for the events the design names. Anything not listed here
  /// still renders — it falls back to generic copy rather than failing, which
  /// keeps the second catalogue page usable.
  static final Map<String, _DevDetail> _details = {
    'evt_maraya_starlight': const _DevDetail(
      subtitle: 'AlUla Desert Pavilion • Exclusive Concert Series',
      venueAddress: 'Ashar Valley',
      overview:
          'Immerse yourself in an intimate open-air acoustic performance '
          "under the celestial canopy of AlUla's sandstone canyons. Featuring "
          'world-renowned instrumentalists blending minimalist classical '
          'compositions with resonant regional percussion in an acoustically '
          'tuned natural canyon amphitheater.',
      availability: TicketAvailability.sellingFast,
      tierLabel: 'Tier 1 Selling Fast',
    ),
    'evt_soundstorm_2025': const _DevDetail(
      subtitle: 'Banban District • Flagship Festival',
      venueAddress: 'Banban Festival Grounds',
      overview:
          'Three nights of headline electronic performances across six '
          'stages, with regional and international artists closing out the '
          'year in the desert north of Riyadh.',
      availability: TicketAvailability.sellingFast,
      tierLabel: 'Tier 2 Selling Fast',
    ),
    'evt_royal_philharmonic': const _DevDetail(
      subtitle: 'Grand Opera Hall • Classical Season',
      venueAddress: 'King Abdullah Cultural District',
      overview:
          'A full-orchestra programme built around the seventh nocturne, '
          'performed in a hall tuned for unamplified strings.',
    ),
  };

  static const String _genericOverview =
      'Full programme details for this event are published closer to the '
      'date. Gate entry is by encrypted pass issued to your device.';

  /// The events drawn in the design, plus four more so pagination has a second
  /// page to fetch. Dates are relative to construction rather than hard-coded,
  /// so the feed does not silently become a list of past events.
  static final List<EventSummary> _catalogue = _buildCatalogue();

  static List<EventSummary> _buildCatalogue() {
    final now = DateTime.now().toUtc();
    DateTime inDays(int days, {int hour = 19}) =>
        DateTime.utc(now.year, now.month, now.day + days, hour);

    return [
      EventSummary(
        id: 'evt_soundstorm_2025',
        title: 'Soundstorm Live Arena 2025',
        venue: 'Banban District',
        city: 'Riyadh',
        startsAt: inDays(21),
        endsAt: inDays(23, hour: 2),
        priceFrom: 399,
        currency: 'SAR',
      ),
      EventSummary(
        id: 'evt_maraya_starlight',
        title: 'Maraya Starlight Acoustic Nights',
        venue: 'Desert Pavilion',
        city: 'AlUla',
        startsAt: inDays(46, hour: 20),
        priceFrom: 650,
        currency: 'SAR',
      ),
      EventSummary(
        id: 'evt_royal_philharmonic',
        title: 'Royal Philharmonic Nocturne No. 7',
        venue: 'Grand Opera Hall',
        city: 'Riyadh',
        startsAt: inDays(71, hour: 21),
        priceFrom: 280,
        currency: 'SAR',
      ),
      EventSummary(
        id: 'evt_subbass_analog',
        title: 'Sub-Bass Analog Resonances',
        venue: 'Hangar 04 Industrial Zone',
        city: 'Jeddah',
        startsAt: inDays(88, hour: 22),
        priceFrom: 185,
        currency: 'SAR',
      ),
      EventSummary(
        id: 'evt_coastal_sessions',
        title: 'Coastal Sessions: Red Sea Edition',
        venue: 'Corniche Amphitheatre',
        city: 'Jeddah',
        startsAt: inDays(104),
        endsAt: inDays(105, hour: 1),
        priceFrom: 220,
        currency: 'SAR',
      ),
      EventSummary(
        id: 'evt_calligraphy_biennale',
        title: 'Calligraphy Biennale Opening Night',
        venue: 'Diriyah Art Futures',
        city: 'Diriyah',
        startsAt: inDays(119, hour: 18),
        priceFrom: 95,
        currency: 'SAR',
      ),
      EventSummary(
        id: 'evt_oud_masters',
        title: 'Oud Masters in Residence',
        venue: 'King Fahd Cultural Centre',
        city: 'Riyadh',
        startsAt: inDays(133, hour: 20),
        priceFrom: 150,
        currency: 'SAR',
        soldOut: true,
      ),
      EventSummary(
        id: 'evt_dunes_after_dark',
        title: 'Dunes After Dark',
        venue: 'Thumamah Reserve',
        city: 'Riyadh',
        startsAt: inDays(151, hour: 21),
        priceFrom: 310,
        currency: 'SAR',
      ),
    ];
  }
}

/// Editorial fields for one stub event.
class _DevDetail {
  const _DevDetail({
    required this.subtitle,
    required this.overview,
    required this.venueAddress,
    this.availability = TicketAvailability.available,
    this.tierLabel,
  });

  final String subtitle;
  final String overview;
  final String venueAddress;
  final TicketAvailability availability;
  final String? tierLabel;
}
