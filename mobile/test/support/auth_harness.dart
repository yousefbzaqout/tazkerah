import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/features/events/data/dev_events_repository.dart';
import 'package:tazkerah/features/events/domain/event_detail.dart';
import 'package:tazkerah/features/events/domain/event_summary.dart';
import 'package:tazkerah/features/events/domain/events_repository.dart';
import 'package:tazkerah/features/tickets/data/dev_tickets_repository.dart';
import 'package:tazkerah/features/tickets/domain/ticket.dart';
import 'package:tazkerah/features/tickets/domain/tickets_repository.dart';
import 'package:tazkerah/features/tickets/presentation/controllers/wallet_controller.dart';
import 'package:tazkerah/features/events/presentation/controllers/discovery_controller.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/core/storage/storage_keys.dart';
import 'package:tazkerah/features/auth/domain/auth_state.dart';
import 'package:tazkerah/features/auth/presentation/controllers/auth_controller.dart';

/// Storage seeded with a session, for tests that need to reach past the auth
/// gate to the screen they actually care about.
SecureStorage signedInStorage() {
  final storage = InMemorySecureStorage();
  storage.write(StorageKeys.refreshToken, 'test-refresh-token');
  return storage;
}

/// A container with the app in a signed-in state.
///
/// Returns the container rather than an override list so callers get one
/// object to both inject and read auth state from.
ProviderContainer signedInContainer() => ProviderContainer(
  overrides: [
    secureStorageProvider.overrideWithValue(signedInStorage()),
    ...instantEventsFeed,
  ],
);

/// A container with the app in a signed-out state.
ProviderContainer signedOutContainer() => ProviderContainer(
  overrides: [
    secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
    ...instantEventsFeed,
  ],
);

/// The discovery feed, answering with no simulated latency.
///
/// Signing in lands on the events tab, so every test that reaches past the
/// auth gate starts a feed request whether it cares about the feed or not.
/// The stub's deliberate 700ms delay would then still be pending when the
/// widget tree is torn down, which the test binding reports as a leaked
/// timer — a failure in a router test that has nothing to do with routing.
final instantEventsFeed = [
  ticketsRepositoryProvider.overrideWith((ref) {
    final repository = DevTicketsRepository(latency: Duration.zero);
    ref.onDispose(repository.dispose);
    return _AnyIdTickets(repository);
  }),
  eventsRepositoryProvider.overrideWith((ref) {
    final repository = DevEventsRepository(latency: Duration.zero);
    ref.onDispose(repository.dispose);
    return _AnyIdEvents(repository);
  }),
];

/// The dev feed, but resolving *any* event id to a detail named after it.
///
/// Routing tests navigate to ids the stub catalogue does not contain
/// (`evt_123`), and a 404 there would test the catalogue rather than the
/// router. Echoing the id back as the title keeps the original assertion
/// meaningful: the title only reads `Event evt_123` if the path parameter
/// actually reached the screen.
class _AnyIdEvents implements EventsRepository {
  _AnyIdEvents(this._inner);

  final DevEventsRepository _inner;

  @override
  Future<EventPage> fetchEvents({String? query, String? cursor}) =>
      _inner.fetchEvents(query: query, cursor: cursor);

  @override
  Future<EventDetail> fetchEvent(String id) async {
    try {
      return await _inner.fetchEvent(id);
    } on Failure {
      return EventDetail(
        summary: EventSummary(
          id: id,
          title: 'Event $id',
          venue: 'Test Venue',
          city: 'Riyadh',
          startsAt: DateTime.utc(2026, 12, 14, 19),
          priceFrom: 100,
          currency: 'SAR',
        ),
        subtitle: 'Test Venue • Riyadh',
        overview: 'Routing test fixture.',
        venueAddress: 'Test Venue',
      );
    }
  }
}

/// Waits for the startup session check to resolve.
///
/// [AuthController.restore] reads storage asynchronously, so a test that
/// pumps immediately still sees [AuthStatus.unknown] and the splash screen.
/// This settles the router onto its real destination.
Future<void> settleAuth(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final auth = container.read(authControllerProvider);
  while (auth.status == AuthStatus.unknown) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

/// The dev wallet, but resolving *any* ticket id to a ticket named after it.
///
/// Routing tests navigate to ids the stub does not hold (`tkt_456`), and a
/// 404 there would test the stub rather than the router. Echoing the id back
/// keeps the original assertion meaningful: the title only reads
/// `Ticket tkt_456` if the path parameter actually reached the screen.
class _AnyIdTickets implements TicketsRepository {
  _AnyIdTickets(this._inner);

  final DevTicketsRepository _inner;

  @override
  Future<List<Ticket>> fetchTickets() => _inner.fetchTickets();

  @override
  Future<Ticket> fetchTicketForOrder(String orderReference) =>
      _inner.fetchTicketForOrder(orderReference);

  @override
  Future<Ticket> fetchTicket(String ticketId) async {
    try {
      return await _inner.fetchTicket(ticketId);
    } on Failure {
      return Ticket(
        id: ticketId,
        orderReference: 'BR-TEST',
        eventId: 'evt_a',
        eventTitle: 'Ticket $ticketId',
        venueName: 'Test Venue',
        startsAt: DateTime.now().toUtc().add(const Duration(days: 10)),
        timeZoneOffset: const Duration(hours: 3),
        seatLabel: 'A-01',
        zoneLabel: 'ZONE 1',
        status: TicketStatus.valid,
        totalMinor: 10000,
        currency: 'SAR',
      );
    }
  }
}
