import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/features/booking/domain/seat.dart';
import 'package:tazkerah/features/booking/domain/seat_hold.dart';
import 'package:tazkerah/features/booking/domain/seat_selection_state.dart';
import 'package:tazkerah/features/booking/presentation/controllers/seat_selection_controller.dart';
import 'package:tazkerah/features/booking/presentation/seat_selection_screen.dart';
import 'package:tazkerah/features/booking/presentation/widgets/seat_conflict_toast.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/fake_booking_repository.dart';

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

(ProviderContainer, FakeBookingRepository) buildContainer({
  FakeBookingRepository? repository,
}) {
  final repo = repository ?? FakeBookingRepository(sectors: [testSector()]);
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      bookingRepositoryProvider.overrideWithValue(repo),
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
      home: const SeatSelectionScreen(eventId: 'evt_a', eventTitle: 'Test'),
    ),
  );
}

/// Mounts the controller and lets the seat map load.
///
/// Subscribes rather than reading once, for the reason given on the same
/// helper in `checkout_test.dart`: the provider is auto-disposed, so a read
/// with no listener is disposed as soon as it returns and the loaded map is
/// thrown away before any assertion can see it.
Future<void> settle(ProviderContainer container) async {
  final subscription = container.listen(
    seatSelectionControllerProvider('evt_a'),
    (_, _) {},
  );
  addTearDown(subscription.close);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

SeatSelectionState read(ProviderContainer c) =>
    c.read(seatSelectionControllerProvider('evt_a'));

SeatSelectionController notifier(ProviderContainer c) =>
    c.read(seatSelectionControllerProvider('evt_a').notifier);

void main() {
  group('SeatSelectionController — loading and selecting', () {
    test('loads the seat map', () async {
      final (container, _) = buildContainer();
      await settle(container);

      final state = read(container);
      expect(state.phase, SeatSelectionPhase.selecting);
      expect(state.sectors, hasLength(1));
    });

    test('a map failure is an error state', () async {
      final (container, _) = buildContainer(
        repository: FakeBookingRepository(mapFailure: const NetworkFailure()),
      );
      await settle(container);

      expect(read(container).phase, SeatSelectionPhase.error);
      expect(read(container).failure, isA<NetworkFailure>());
    });

    test('selects an available seat but not a sold one', () async {
      final (container, _) = buildContainer();
      await settle(container);

      notifier(container).selectSeat('sector_vip_a_8');
      expect(read(container).selectedSeatId, 'sector_vip_a_8');

      // The third seat is sold; tapping it must not change the selection.
      notifier(container).selectSeat('sector_vip_a_10');
      expect(read(container).selectedSeatId, 'sector_vip_a_8');
    });
  });

  group('SeatSelectionController — 409 conflict', () {
    test('marks the seat, clears the selection and raises the toast', () async {
      final repo = FakeBookingRepository(sectors: [testSector()]);
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      notifier(container).selectSeat('sector_vip_a_8');
      repo.holdFailure = const ConflictFailure(code: 'SEAT_UNAVAILABLE');
      await notifier(container).holdSelectedSeat();

      final state = read(container);
      expect(state.conflict, isNotNull);
      expect(state.conflict!.seatLabel, 'A-08');
      expect(state.conflict!.displayLabel, 'VIP · A-08');
      expect(state.selectedSeatId, isNull, reason: 'selection is cleared');
      expect(
        state.allSeats.firstWhere((s) => s.id == 'sector_vip_a_8').status,
        SeatStatus.conflict,
        reason: 'the lost seat is marked on the map',
      );
      // The map stays usable — this is an answer, not an error page.
      expect(state.phase, SeatSelectionPhase.selecting);
      expect(state.failure, isNull);
    });

    test('choosing another seat clears the toast', () async {
      final repo = FakeBookingRepository(sectors: [testSector()]);
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      notifier(container).selectSeat('sector_vip_a_8');
      repo.holdFailure = const ConflictFailure();
      await notifier(container).holdSelectedSeat();
      expect(read(container).conflict, isNotNull);

      notifier(container).selectSeat('sector_vip_a_9');
      expect(read(container).conflict, isNull);
    });
  });

  group('SeatSelectionController — 423 locked sector', () {
    test(
      'tapping a locked sector raises the sheet without a request',
      () async {
        final repo = FakeBookingRepository(
          sectors: [
            testSector(
              id: 'sector_b',
              name: 'SECTOR B (Mezzanine)',
              isLocked: true,
              lockReason: 'BR-007',
            ),
          ],
        );
        final (container, _) = buildContainer(repository: repo);
        await settle(container);

        notifier(container).selectSeat('sector_b_a_8');

        final state = read(container);
        expect(state.lockedSector, isNotNull);
        expect(state.lockedSector!.lockReason, 'BR-007');
        expect(state.selectedSeatId, isNull);
        expect(repo.heldSeatIds, isEmpty, reason: 'no hold is attempted');
      },
    );

    test('a 423 from the server also raises the sheet', () async {
      final repo = FakeBookingRepository(sectors: [testSector()]);
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      notifier(container).selectSeat('sector_vip_a_8');
      repo.holdFailure = const LockedFailure(reason: 'BR-007');
      await notifier(container).holdSelectedSeat();

      expect(read(container).lockedSector, isNotNull);
      expect(read(container).selectedSeatId, isNull);
    });
  });

  group('SeatSelectionController — hold and countdown', () {
    test('a granted hold moves to held and marks the seat', () async {
      final (container, _) = buildContainer();
      await settle(container);

      notifier(container).selectSeat('sector_vip_a_8');
      await notifier(container).holdSelectedSeat();

      final state = read(container);
      expect(state.phase, SeatSelectionPhase.held);
      expect(state.hold!.reference, 'BR-003');
      expect(
        state.allSeats.firstWhere((s) => s.id == 'sector_vip_a_8').status,
        SeatStatus.held,
      );
      // The map stops accepting taps while the order is reserved.
      expect(state.isMapInteractive, isFalse);
    });

    test(
      'remaining time comes from the server deadline, not a local count',
      () async {
        // A hold with only 90 seconds left: a client that assumed the full
        // 10-minute TTL would show 10:00 here.
        final repo = FakeBookingRepository(
          sectors: [testSector()],
          hold: SeatHold(
            reference: 'BR-009',
            seatIds: const ['sector_vip_a_8'],
            expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 90)),
            totalMinor: 39900,
            currency: 'SAR',
          ),
        );
        final (container, _) = buildContainer(repository: repo);
        await settle(container);

        notifier(container).selectSeat('sector_vip_a_8');
        await notifier(container).holdSelectedSeat();

        final remaining = read(container).remaining;
        expect(remaining.inSeconds, lessThanOrEqualTo(90));
        expect(remaining.inSeconds, greaterThan(80));
      },
    );

    test('an already-expired deadline reads as zero, never negative', () {
      final hold = SeatHold(
        reference: 'BR-010',
        seatIds: const ['a'],
        expiresAt: DateTime.utc(2020),
        totalMinor: 100,
        currency: 'SAR',
      );

      expect(hold.remaining(DateTime.utc(2026)), Duration.zero);
      expect(hold.isExpired(DateTime.utc(2026)), isTrue);
    });

    test('releasing a hold returns the seat to available', () async {
      final repo = FakeBookingRepository(sectors: [testSector()]);
      final (container, _) = buildContainer(repository: repo);
      await settle(container);

      notifier(container).selectSeat('sector_vip_a_8');
      await notifier(container).holdSelectedSeat();
      await notifier(container).releaseHold();

      final state = read(container);
      expect(state.phase, SeatSelectionPhase.selecting);
      expect(state.hold, isNull);
      expect(
        state.allSeats.firstWhere((s) => s.id == 'sector_vip_a_8').status,
        SeatStatus.available,
      );
      expect(repo.releasedReferences, ['BR-003']);
    });
  });

  group('SeatSelectionController — disposal', () {
    test('disposing the provider cancels the countdown', () async {
      // A periodic timer that outlives its provider keeps a disposed notifier
      // alive and fires state writes into nothing. The test binding catches it
      // here; on a device it would be a slow leak per abandoned seat map.
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
          bookingRepositoryProvider.overrideWithValue(
            FakeBookingRepository(sectors: [testSector()]),
          ),
        ],
      );
      await settle(container);
      notifier(container).selectSeat('sector_vip_a_8');
      await notifier(container).holdSelectedSeat();
      expect(read(container).phase, SeatSelectionPhase.held);

      container.dispose();

      // Past a tick: nothing may throw, and no state write may be attempted.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    });
  });

  group('SeatSelectionScreen', () {
    testWidgets('renders the map and the empty selection bar', (tester) async {
      useTallViewport(tester);
      final (container, _) = buildContainer();

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      expect(find.text('CURRENT SELECTION'), findsOneWidget);
      expect(find.text('No seat selected'), findsOneWidget);
      expect(find.text('Select an available seat'), findsOneWidget);
      expect(find.text('Live Sync'), findsOneWidget);
    });

    testWidgets('shows the conflict toast after a 409', (tester) async {
      useTallViewport(tester);
      final repo = FakeBookingRepository(sectors: [testSector()]);
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      notifier(container).selectSeat('sector_vip_a_8');
      repo.holdFailure = const ConflictFailure();
      await notifier(container).holdSelectedSeat();
      await tester.pumpAndSettle();

      expect(find.byType(SeatConflictToast), findsOneWidget);
      expect(find.text('CONFLICT · HTTP 409'), findsOneWidget);
      expect(find.text('Seat just taken — pick another'), findsOneWidget);
      expect(find.text('TAKEN'), findsOneWidget);
      // The selection bar is back to its empty prompt.
      expect(find.text('No seat selected'), findsOneWidget);
    });

    testWidgets('shows the held bar and timer after a hold', (tester) async {
      useTallViewport(tester);
      final (container, _) = buildContainer();

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      notifier(container).selectSeat('sector_vip_a_8');
      await notifier(container).holdSelectedSeat();
      await tester.pump();

      expect(find.text('HELD (BR-003)'), findsOneWidget);
      expect(find.text('SEATS HELD'), findsOneWidget);
      expect(find.text('ASSIGNED SELECTION'), findsOneWidget);
      expect(find.text('Continue to checkout'), findsOneWidget);
      expect(
        find.text('Seat selection locked while timer is running'),
        findsOneWidget,
      );

      // Release before teardown: the countdown is a periodic timer, and the
      // test binding fails a test that leaves one pending.
      await notifier(container).releaseHold();
      await tester.pumpAndSettle();
    });

    testWidgets('renders right-to-left in Arabic', (tester) async {
      useTallViewport(tester);
      final (container, _) = buildContainer();

      await tester.pumpWidget(wrap(container, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('الاختيار الحالي'), findsOneWidget);
      expect(find.text('اختر مقعدًا متاحًا'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('الاختيار الحالي'))),
        TextDirection.rtl,
      );
    });
  });
}
