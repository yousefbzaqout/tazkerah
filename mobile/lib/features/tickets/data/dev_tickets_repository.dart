import 'dart:async';

import '../../../core/errors/failure.dart';
import '../domain/ticket.dart';
import '../domain/tickets_repository.dart';

/// A stand-in [TicketsRepository] for running the wallet before the backend
/// exists.
///
/// **Not a production implementation.** [AppConfig] gates it to non-production
/// builds. It holds tickets in memory for the life of the session, so a
/// purchase made in the app appears in the wallet immediately — which is what
/// makes the flow from checkout to gate testable by hand.
class DevTicketsRepository implements TicketsRepository {
  DevTicketsRepository({this.latency = const Duration(milliseconds: 350)});

  final Duration latency;

  Timer? _pending;

  /// Tickets issued this session, keyed by id. Seeded with one so the wallet
  /// is not empty on a cold start.
  final Map<String, Ticket> _tickets = _seed();

  /// Order references that have been paid, so a confirmation screen can find
  /// the ticket a payment produced.
  final Map<String, String> _ticketIdByOrder = {'BR-003': 'tkt_seed_1'};

  void dispose() {
    _pending?.cancel();
    _pending = null;
  }

  Future<void> _sleep() {
    if (latency == Duration.zero) return Future<void>.value();
    final completer = Completer<void>();
    _pending = Timer(latency, () {
      _pending = null;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  @override
  Future<List<Ticket>> fetchTickets() async {
    await _sleep();
    final all = _tickets.values.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return all;
  }

  @override
  Future<Ticket> fetchTicket(String ticketId) async {
    await _sleep();
    final ticket = _tickets[ticketId];
    if (ticket == null) {
      throw NotFoundFailure(
        debugMessage: 'DevTicketsRepository: no ticket "$ticketId"',
      );
    }
    return ticket;
  }

  @override
  Future<Ticket> fetchTicketForOrder(String orderReference) async {
    await _sleep();

    final existing = _ticketIdByOrder[orderReference];
    if (existing != null) return _tickets[existing]!;

    // A completed order the stub has not seen yet: mint a ticket for it, so
    // the checkout-to-wallet path works end to end without a backend.
    final id = 'tkt_${orderReference.toLowerCase()}';
    final now = DateTime.now().toUtc();
    final ticket = Ticket(
      id: id,
      orderReference: orderReference,
      eventId: 'evt_maraya_starlight',
      eventTitle: 'AlUla Desert Nocturne: Ambient Horizons',
      venueName: 'Maraya Concert Pavilion · AlUla',
      startsAt: now.add(const Duration(days: 30)),
      timeZoneOffset: const Duration(hours: 3),
      seatLabel: 'VIP A-12',
      zoneLabel: 'VIP PODIUM',
      status: TicketStatus.valid,
      totalMinor: 100625,
      currency: 'SAR',
      purchasedAt: now,
      entranceLabel: 'Gate 4',
    );

    _tickets[id] = ticket;
    _ticketIdByOrder[orderReference] = id;
    return ticket;
  }

  /// One upcoming ticket and one already used, so both wallet sections have
  /// something in them on a cold start.
  static Map<String, Ticket> _seed() {
    final now = DateTime.now().toUtc();
    return {
      'tkt_seed_1': Ticket(
        id: 'tkt_seed_1',
        orderReference: 'BR-003',
        eventId: 'evt_soundstorm_2025',
        eventTitle: 'Soundstorm Live Arena 2025',
        venueName: 'Banban District · Riyadh',
        startsAt: now.add(const Duration(days: 21)),
        timeZoneOffset: const Duration(hours: 3),
        seatLabel: 'VIP A-12',
        zoneLabel: 'ZONE 1',
        status: TicketStatus.valid,
        totalMinor: 39900,
        currency: 'SAR',
        purchasedAt: now.subtract(const Duration(days: 3)),
        entranceLabel: 'Gate 4',
      ),
      'tkt_seed_2': Ticket(
        id: 'tkt_seed_2',
        orderReference: 'BR-001',
        eventId: 'evt_royal_philharmonic',
        eventTitle: 'Royal Philharmonic Nocturne No. 7',
        venueName: 'Grand Opera Hall · Riyadh',
        startsAt: now.subtract(const Duration(days: 14)),
        timeZoneOffset: const Duration(hours: 3),
        seatLabel: 'B-04',
        zoneLabel: 'STALLS',
        status: TicketStatus.used,
        totalMinor: 28000,
        currency: 'SAR',
        purchasedAt: now.subtract(const Duration(days: 40)),
        entranceLabel: 'Gate 2',
      ),
    };
  }
}
