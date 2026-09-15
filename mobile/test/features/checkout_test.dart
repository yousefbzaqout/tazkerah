import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/platform/url_opener.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/features/booking/domain/checkout_state.dart';
import 'package:tazkerah/features/booking/presentation/checkout_screen.dart';
import 'package:tazkerah/features/booking/presentation/controllers/checkout_controller.dart';
import 'package:tazkerah/features/booking/presentation/controllers/seat_selection_controller.dart';
import 'package:tazkerah/features/booking/presentation/widgets/hold_expired_view.dart';
import 'package:tazkerah/features/booking/presentation/widgets/payment_window_bar.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/fake_booking_repository.dart';

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The opener every test uses, so a launch can be observed or made to fail.
late RecordingUrlOpener opener;

(ProviderContainer, FakeBookingRepository) buildContainer({
  FakeBookingRepository? repository,
}) {
  final repo = repository ?? FakeBookingRepository();
  opener = RecordingUrlOpener();
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      bookingRepositoryProvider.overrideWithValue(repo),
      urlOpenerProvider.overrideWithValue(opener),
    ],
  );
  addTearDown(container.dispose);
  return (container, repo);
}

Widget wrap(ProviderContainer container, {Locale? locale}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CheckoutScreen(holdReference: 'BR-003', eventId: 'evt_a'),
    ),
  );
}

/// Mounts the controller and lets its initial load complete, returning the
/// subscription that keeps it alive.
///
/// Subscribes rather than reading once. The provider is auto-disposed, so a
/// bare `read` with no listener is torn down the moment it returns and the
/// next read rebuilds it from scratch — the loaded state would never be
/// observed. A listener is also what the real screen holds, so the controller
/// sees the same lifetime here as in the app; closing the returned
/// subscription is that screen being left.
Future<ProviderSubscription<CheckoutState>> settle(
  ProviderContainer container,
) async {
  final subscription = container.listen(
    checkoutControllerProvider('BR-003'),
    (_, _) {},
  );
  addTearDown(subscription.close);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return subscription;
}

CheckoutState read(ProviderContainer c) =>
    c.read(checkoutControllerProvider('BR-003'));

CheckoutController notifier(ProviderContainer c) =>
    c.read(checkoutControllerProvider('BR-003').notifier);

/// The checkout screen behind a minimal router, for the tests where a
/// successful payment navigates onward.
Widget wrapRouted(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/checkout/BR-003',
    routes: [
      GoRoute(
        path: '/checkout/:hold',
        builder: (context, state) => CheckoutScreen(
          holdReference: state.pathParameters['hold']!,
          eventId: 'evt_a',
        ),
      ),
      GoRoute(
        path: '/orders/:reference',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('confirmation'))),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: AppTheme.dark(),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('CheckoutController', () {
    test('promotes the hold and opens a payment window', () async {
      final (container, repo) = buildContainer();
      await settle(container);

      final state = read(container);
      expect(state, isA<CheckoutReview>());
      expect((state as CheckoutReview).order.reference, 'BR-003');
      expect(repo.checkoutReferences, ['BR-003']);
      // The window is running, not yet expired.
      expect(state.remaining.inSeconds, greaterThan(0));

      await notifier(container).cancelHold();
    });

    test('remaining time comes from the order deadline', () async {
      final repo = FakeBookingRepository(
        order: testOrder(remaining: const Duration(seconds: 45)),
      );
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      final state = read(container) as CheckoutReview;
      // A client that assumed the full +3m would show 03:00 here.
      expect(state.remaining.inSeconds, lessThanOrEqualTo(45));
      expect(state.remaining.inSeconds, greaterThan(35));

      await notifier(container).cancelHold();
    });

    test('an already-expired order never shows a live window', () async {
      final repo = FakeBookingRepository(
        // The window closed while the response was in flight.
        order: testOrder(remaining: const Duration(seconds: -5)),
      );
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      expect(read(container), isA<CheckoutExpired>());
    });

    test('a gone hold is reported as gone, not as a retryable error', () async {
      final repo = FakeBookingRepository(
        checkoutFailure: const ConflictFailure(code: 'HOLD_EXPIRED'),
      );
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      final state = read(container);
      expect(state, isA<CheckoutError>());
      expect((state as CheckoutError).isHoldGone, isTrue);
    });

    test('a network failure stays retryable', () async {
      final repo = FakeBookingRepository(
        checkoutFailure: const NetworkFailure(),
      );
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      final state = read(container) as CheckoutError;
      expect(state.isHoldGone, isFalse);
    });

    test('pay returns the gateway url and blocks re-submission', () async {
      final (container, repo) = buildContainer();
      await settle(container);

      final url = await notifier(container).pay();
      expect(url, 'https://pay.test/BR-003');
      expect(repo.paymentReferences, ['BR-003']);

      // Still marked as paying: the user is leaving for the gateway, and a
      // second tap would be a second charge.
      expect((read(container) as CheckoutReview).isPaying, isTrue);
      expect(await notifier(container).pay(), isNull);
      expect(repo.paymentReferences, hasLength(1));
    });

    test('paying into a closed window expires instead of charging', () async {
      final repo = FakeBookingRepository(
        order: testOrder(remaining: const Duration(milliseconds: 40)),
      );
      final (container, _) = buildContainer(repository: repo);
      await settle(container);
      expect(read(container), isA<CheckoutReview>());

      await Future<void>.delayed(const Duration(milliseconds: 80));
      final url = await notifier(container).pay();

      expect(url, isNull);
      expect(read(container), isA<CheckoutExpired>());
      expect(repo.paymentReferences, isEmpty, reason: 'no charge attempted');
    });

    test('a payment conflict releases into the expired frame', () async {
      final repo = FakeBookingRepository(
        paymentFailure: const ConflictFailure(code: 'HOLD_EXPIRED'),
      );
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      expect(await notifier(container).pay(), isNull);
      expect(read(container), isA<CheckoutExpired>());
    });

    test('a transport failure leaves the window open for a retry', () async {
      final repo = FakeBookingRepository(
        paymentFailure: const NetworkFailure(),
      );
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      expect(await notifier(container).pay(), isNull);
      final state = read(container);
      expect(state, isA<CheckoutReview>());
      expect((state as CheckoutReview).isPaying, isFalse, reason: 'retryable');

      await notifier(container).cancelHold();
    });

    test('cancelling releases the hold', () async {
      final (container, repo) = buildContainer();
      await settle(container);

      await notifier(container).cancelHold();
      expect(repo.releasedReferences, ['BR-003']);
    });

    test('disposal cancels the countdown', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
          bookingRepositoryProvider.overrideWithValue(FakeBookingRepository()),
        ],
      );
      await settle(container);
      expect(read(container), isA<CheckoutReview>());

      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    });

    test('an expired window does not poison the next booking at the same '
        'reference', () async {
      // The reported bug: once a window closed, every later booking opened
      // straight into the expired frame. `CheckoutExpired` is terminal — the
      // controller never leaves it, because build (and so load) runs once per
      // key — so a cached controller re-read at the same reference served that
      // dead state to a hold that was actually live. Hold references are not
      // guaranteed unique across a session, which is what makes the collision
      // reachable.
      final repo = FakeBookingRepository(
        order: testOrder(remaining: const Duration(seconds: -5)),
      );
      final (container, _) = buildContainer(repository: repo);

      final first = await settle(container);
      expect(read(container), isA<CheckoutExpired>(), reason: 'first window');

      // The user leaves the closed checkout screen. Disposal is scheduled
      // rather than immediate, so let it run before the next visit.
      first.close();
      await Future<void>.delayed(Duration.zero);

      // A second booking lands on the same reference, and this time the server
      // says the window is open.
      repo.order = testOrder(remaining: const Duration(minutes: 3));
      await settle(container);

      expect(
        read(container),
        isA<CheckoutReview>(),
        reason: 'the new hold is live and must not inherit the expired frame',
      );

      await notifier(container).cancelHold();
    });
  });

  group('CheckoutScreen — review', () {
    testWidgets('renders the window bar, reservation and breakdown', (
      tester,
    ) async {
      useTallViewport(tester);
      final (container, _) = buildContainer();

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      expect(find.text('Order Checkout'), findsOneWidget);
      expect(find.byType(PaymentWindowBar), findsOneWidget);
      expect(find.text('PAYMENT WINDOW ACTIVE'), findsOneWidget);
      expect(find.text('Hold extended +3m for checkout'), findsOneWidget);
      expect(find.text('CONFIRMED RESERVATION'), findsOneWidget);
      expect(find.text('AlUla Desert Nocturne'), findsOneWidget);
      expect(find.text('VIP · Sector A · Row 12'), findsOneWidget);
      expect(find.text('PRICE BREAKDOWN'), findsOneWidget);
      expect(find.text('VAT Reg #310892019'), findsOneWidget);
      expect(find.text('850.00 SAR'), findsOneWidget);
      expect(find.text('131.25 SAR'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.text('1,006.25'), findsOneWidget);
      expect(find.text('Pay now · 1,006.25 SAR'), findsOneWidget);
      expect(find.text('Cancel hold'), findsOneWidget);

      await notifier(container).cancelHold();
      await tester.pumpAndSettle();
    });

    testWidgets('cancelling asks before releasing the seats', (tester) async {
      useTallViewport(tester);
      final (container, repo) = buildContainer();

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel hold'));
      await tester.pumpAndSettle();

      expect(find.text('Release your seats?'), findsOneWidget);
      // Backing out must not release anything.
      await tester.tap(find.text('Keep my seats'));
      await tester.pumpAndSettle();
      expect(repo.releasedReferences, isEmpty);

      await notifier(container).cancelHold();
      await tester.pumpAndSettle();
    });
  });

  group('CheckoutScreen — payment handoff', () {
    testWidgets('opens the gateway URL', (tester) async {
      useTallViewport(tester);
      final (container, _) = buildContainer();

      // A router, because a successful handoff navigates to confirmation.
      await tester.pumpWidget(wrapRouted(container));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Pay now'));
      await tester.pumpAndSettle();

      expect(opener.opened.single.toString(), 'https://pay.test/BR-003');
    });

    testWidgets('a launch that fails does not advance to confirmation', (
      tester,
    ) async {
      useTallViewport(tester);
      final (container, _) = buildContainer();
      // No browser, or a URL nothing can handle.
      opener.succeeds = false;

      await tester.pumpWidget(wrap(container));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.textContaining('Pay now'));
      // Fixed pumps, not `pumpAndSettle`: the payment window's countdown
      // ticks every second, so the tree never reaches a settled state.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Still on checkout: advancing would show a confirmation screen for a
      // payment that was never started.
      expect(find.text('PAYMENT WINDOW ACTIVE'), findsOneWidget);
      expect(
        find.text('Payment could not be started. Please try again.'),
        findsOneWidget,
      );

      await notifier(container).cancelHold();
      await tester.pump();
    });
  });

  group('CheckoutScreen — expired', () {
    testWidgets('renders the released reservation and recovery actions', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeBookingRepository(
        order: testOrder(remaining: const Duration(seconds: -1)),
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      expect(find.byType(HoldExpiredView), findsOneWidget);
      expect(find.text('SESSION TIMEOUT'), findsOneWidget);
      expect(find.text('HOLD TIMER'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('RELEASED RESERVATION'), findsOneWidget);
      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.text('Held Seat: VIP · Sector A · Row 12'), findsOneWidget);
      expect(find.text('SELECT SEATS AGAIN'), findsOneWidget);
      expect(find.text('Return to Event Overview'), findsOneWidget);
      // No pay action may survive into the expired frame.
      expect(find.textContaining('Pay now'), findsNothing);
    });

    testWidgets('renders right-to-left in Arabic', (tester) async {
      useTallViewport(tester);
      final repo = FakeBookingRepository(
        order: testOrder(remaining: const Duration(seconds: -1)),
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('انتهت الجلسة'), findsOneWidget);
      expect(find.text('اختر المقاعد مرة أخرى'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('انتهت الجلسة'))),
        TextDirection.rtl,
      );
    });
  });
}
