import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/features/tickets/domain/ticket.dart';
import 'package:tazkerah/features/tickets/domain/tickets_repository.dart';
import 'package:tazkerah/features/tickets/domain/wallet_state.dart';
import 'package:tazkerah/features/tickets/presentation/controllers/order_confirmation_controller.dart';
import 'package:tazkerah/features/tickets/presentation/controllers/wallet_controller.dart';
import 'package:tazkerah/features/tickets/presentation/order_confirmation_screen.dart';
import 'package:tazkerah/features/tickets/presentation/ticket_detail_screen.dart';
import 'package:tazkerah/features/tickets/presentation/tickets_screen.dart';
import 'package:tazkerah/features/tickets/presentation/widgets/wallet_ticket_card.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

/// A [TicketsRepository] a test can steer.
class FakeTicketsRepository implements TicketsRepository {
  FakeTicketsRepository({this.tickets = const [], this.failure});

  List<Ticket> tickets;
  Failure? failure;

  /// Order references that have produced a ticket.
  Map<String, Ticket> ordersReady = {};

  int orderLookups = 0;

  @override
  Future<List<Ticket>> fetchTickets() async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return tickets;
  }

  @override
  Future<Ticket> fetchTicket(String ticketId) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return tickets.firstWhere(
      (t) => t.id == ticketId,
      orElse: () => throw const NotFoundFailure(),
    );
  }

  @override
  Future<Ticket> fetchTicketForOrder(String orderReference) async {
    orderLookups++;
    final failure = this.failure;
    if (failure != null) throw failure;

    final ticket = ordersReady[orderReference];
    if (ticket == null) throw const NotFoundFailure();
    return ticket;
  }
}

Ticket testTicket({
  String id = 'tkt_1',
  String eventTitle = 'Soundstorm Live Arena 2025',
  TicketStatus status = TicketStatus.valid,
  Duration startsIn = const Duration(days: 10),
}) {
  return Ticket(
    id: id,
    orderReference: 'BR-003',
    eventId: 'evt_a',
    eventTitle: eventTitle,
    venueName: 'Banban District · Riyadh',
    startsAt: DateTime.now().toUtc().add(startsIn),
    timeZoneOffset: const Duration(hours: 3),
    seatLabel: 'VIP A-12',
    zoneLabel: 'ZONE 1',
    status: status,
    totalMinor: 39900,
    currency: 'SAR',
    purchasedAt: DateTime.now().toUtc(),
    entranceLabel: 'Gate 4',
  );
}

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

(ProviderContainer, FakeTicketsRepository) build({
  FakeTicketsRepository? repository,
}) {
  final repo = repository ?? FakeTicketsRepository();
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      ticketsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return (container, repo);
}

Widget wrap(ProviderContainer container, Widget home, {Locale? locale}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<void> settleWallet(ProviderContainer c) async {
  c.read(walletControllerProvider);
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
    if (c.read(walletControllerProvider) is! WalletLoading) return;
  }
}

void main() {
  group('WalletController', () {
    test('splits upcoming from past', () async {
      final repo = FakeTicketsRepository(
        tickets: [
          testTicket(id: 'soon', startsIn: const Duration(days: 2)),
          testTicket(id: 'later', startsIn: const Duration(days: 30)),
          testTicket(id: 'gone', startsIn: const Duration(days: -5)),
        ],
      );
      final (container, _) = build(repository: repo);
      await settleWallet(container);

      final state = container.read(walletControllerProvider) as WalletReady;
      // Soonest first: the ticket needed next is the one being looked for.
      expect(state.upcoming.map((t) => t.id), ['soon', 'later']);
      expect(state.past.map((t) => t.id), ['gone']);
    });

    test('a used ticket is past even for a future event', () async {
      final repo = FakeTicketsRepository(
        tickets: [
          testTicket(
            id: 'scanned',
            status: TicketStatus.used,
            startsIn: const Duration(days: 5),
          ),
        ],
      );
      final (container, _) = build(repository: repo);
      await settleWallet(container);

      final state = container.read(walletControllerProvider) as WalletReady;
      // It has been scanned; showing it as upcoming would imply a second
      // entry that will not be granted.
      expect(state.upcoming, isEmpty);
      expect(state.past.single.id, 'scanned');
    });

    test('a failure is an error state', () async {
      final repo = FakeTicketsRepository(failure: const NetworkFailure());
      final (container, _) = build(repository: repo);
      await settleWallet(container);

      expect(container.read(walletControllerProvider), isA<WalletError>());
    });
  });

  group('OrderConfirmationController', () {
    test('waits while the payment settles, then confirms', () async {
      final repo = FakeTicketsRepository();
      final (container, _) = build(repository: repo);

      final sub = container.listen(
        orderConfirmationControllerProvider('BR-003'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Nothing issued yet: the app has no authority over the charge, so it
      // waits rather than declaring success.
      expect(sub.read(), isA<OrderSettling>());

      repo.ordersReady['BR-003'] = testTicket(id: 'tkt_new');
      await Future<void>.delayed(
        OrderConfirmationController.pollInterval +
            const Duration(milliseconds: 100),
      );

      final state = sub.read();
      expect(state, isA<OrderConfirmed>());
      expect((state as OrderConfirmed).ticket.id, 'tkt_new');
    });

    test('gives up as pending rather than as failed', () async {
      final repo = FakeTicketsRepository();
      final (container, _) = build(repository: repo);

      final sub = container.listen(
        orderConfirmationControllerProvider('BR-999'),
        (_, _) {},
      );
      addTearDown(sub.close);

      // Outlast the polling window without the ticket ever arriving.
      await Future<void>.delayed(
        OrderConfirmationController.pollInterval *
                OrderConfirmationController.maxAttempts +
            const Duration(seconds: 1),
      );

      expect(sub.read(), isA<OrderConfirmationFailed>());
      expect(repo.orderLookups, OrderConfirmationController.maxAttempts);
    });
  });

  group('TicketsScreen', () {
    testWidgets('renders both sections', (tester) async {
      useTallViewport(tester);
      final repo = FakeTicketsRepository(
        tickets: [
          testTicket(id: 'a', eventTitle: 'Upcoming Show'),
          testTicket(
            id: 'b',
            eventTitle: 'Past Show',
            status: TicketStatus.used,
            startsIn: const Duration(days: -3),
          ),
        ],
      );
      final (container, _) = build(repository: repo);

      await tester.pumpWidget(wrap(container, const TicketsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('PAST'), findsOneWidget);
      expect(find.text('Upcoming Show'), findsOneWidget);
      expect(find.text('Past Show'), findsOneWidget);
      expect(find.byType(WalletTicketCard), findsNWidgets(2));
    });

    testWidgets('an empty wallet offers the event feed', (tester) async {
      final (container, _) = build();

      await tester.pumpWidget(wrap(container, const TicketsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No tickets yet'), findsOneWidget);
      expect(find.text('Browse events'), findsOneWidget);
    });
  });

  group('TicketDetailScreen', () {
    testWidgets('a valid ticket offers the gate pass', (tester) async {
      useTallViewport(tester);
      final repo = FakeTicketsRepository(tickets: [testTicket()]);
      final (container, _) = build(repository: repo);

      await tester.pumpWidget(
        wrap(container, const TicketDetailScreen(ticketId: 'tkt_1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ORDER BR-003'), findsOneWidget);
      expect(find.text('VALID'), findsOneWidget);
      expect(find.text('VIP A-12'), findsOneWidget);
      expect(find.text('Present at gate'), findsOneWidget);
    });

    testWidgets('a used ticket cannot be presented', (tester) async {
      useTallViewport(tester);
      final repo = FakeTicketsRepository(
        tickets: [testTicket(status: TicketStatus.used)],
      );
      final (container, _) = build(repository: repo);

      await tester.pumpWidget(
        wrap(container, const TicketDetailScreen(ticketId: 'tkt_1')),
      );
      await tester.pumpAndSettle();

      // Says why rather than offering a dead button.
      expect(find.text('Present at gate'), findsNothing);
      expect(
        find.text('This ticket can no longer be presented.'),
        findsOneWidget,
      );
    });

    testWidgets('a missing ticket offers a way back', (tester) async {
      final (container, _) = build();

      await tester.pumpWidget(
        wrap(container, const TicketDetailScreen(ticketId: 'nope')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ticket not found'), findsOneWidget);
    });
  });

  group('OrderConfirmationScreen', () {
    testWidgets('shows the issued ticket in Arabic too', (tester) async {
      useTallViewport(tester);
      final repo = FakeTicketsRepository();
      repo.ordersReady['BR-003'] = testTicket(eventTitle: 'حفل موسيقي');
      final (container, _) = build(repository: repo);

      await tester.pumpWidget(
        wrap(
          container,
          const OrderConfirmationScreen(orderReference: 'BR-003'),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تم تأكيد الشراء'), findsOneWidget);
      expect(find.text('حفل موسيقي'), findsOneWidget);
      expect(find.text('عرض تذكرتي'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('عرض تذكرتي'))),
        TextDirection.rtl,
      );
    });
  });
}
