import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/platform/url_opener.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/core/widgets/app_empty_view.dart';
import 'package:tazkerah/core/widgets/app_error_view.dart';
import 'package:tazkerah/features/events/domain/event_detail.dart';
import 'package:tazkerah/features/events/domain/event_detail_state.dart';
import 'package:tazkerah/features/events/presentation/controllers/discovery_controller.dart';
import 'package:tazkerah/features/events/presentation/controllers/event_detail_controller.dart';
import 'package:tazkerah/features/events/presentation/event_detail_screen.dart';
import 'package:tazkerah/features/events/presentation/widgets/event_detail_skeleton.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/fake_events_repository.dart';

/// A viewport tall enough for the hero, the content and the pinned bar.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

late RecordingUrlOpener opener;

(ProviderContainer, FakeEventsRepository) buildContainer({
  FakeEventsRepository? repository,
}) {
  final repo = repository ?? FakeEventsRepository();
  opener = RecordingUrlOpener();
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      eventsRepositoryProvider.overrideWithValue(repo),
      urlOpenerProvider.overrideWithValue(opener),
    ],
  );
  addTearDown(container.dispose);
  return (container, repo);
}

Widget wrap(ProviderContainer container, String eventId, {Locale? locale}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EventDetailScreen(eventId: eventId),
    ),
  );
}

/// Lets the controller's scheduled first load run to completion.
Future<void> settle(ProviderContainer container, String id) async {
  container.read(eventDetailControllerProvider(id));
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('EventDetailController', () {
    test('loads the requested event', () async {
      final repo = FakeEventsRepository(
        details: {'evt_a': testDetail(overview: 'Canyon acoustics.')},
      );
      final (container, _) = buildContainer(repository: repo);

      await settle(container, 'evt_a');

      final state = container.read(eventDetailControllerProvider('evt_a'));
      expect(state, isA<EventDetailReady>());
      expect((state as EventDetailReady).detail.overview, 'Canyon acoustics.');
      expect(repo.detailCalls, ['evt_a']);
    });

    test('an unknown id becomes a missing-event error, not a crash', () async {
      final (container, _) = buildContainer();

      await settle(container, 'evt_gone');

      final state = container.read(eventDetailControllerProvider('evt_gone'));
      expect(state, isA<EventDetailError>());
      expect((state as EventDetailError).isMissing, isTrue);
    });

    test('a transient failure is retryable rather than missing', () async {
      final repo = FakeEventsRepository(failure: const NetworkFailure());
      final (container, _) = buildContainer(repository: repo);

      await settle(container, 'evt_a');

      final state = container.read(eventDetailControllerProvider('evt_a'));
      expect(state, isA<EventDetailError>());
      expect((state as EventDetailError).isMissing, isFalse);

      // Retry recovers.
      repo.failure = null;
      repo.details = {'evt_a': testDetail()};
      await container
          .read(eventDetailControllerProvider('evt_a').notifier)
          .load();

      expect(
        container.read(eventDetailControllerProvider('evt_a')),
        isA<EventDetailReady>(),
      );
    });

    test('a failed refresh keeps the event already on screen', () async {
      final repo = FakeEventsRepository(
        details: {'evt_a': testDetail(overview: 'Original copy.')},
      );
      final (container, _) = buildContainer(repository: repo);
      await settle(container, 'evt_a');

      repo.failure = const NetworkFailure();
      await container
          .read(eventDetailControllerProvider('evt_a').notifier)
          .refresh();

      final state = container.read(eventDetailControllerProvider('evt_a'));
      expect(state, isA<EventDetailReady>(), reason: 'content must survive');
      expect((state as EventDetailReady).detail.overview, 'Original copy.');
      expect(state.isRefreshing, isFalse);
    });

    test('two ids hold independent state', () async {
      final repo = FakeEventsRepository(
        details: {
          'evt_a': testDetail(overview: 'A copy.'),
          'evt_b': testDetail(overview: 'B copy.'),
        },
      );
      final (container, _) = buildContainer(repository: repo);

      await settle(container, 'evt_a');
      await settle(container, 'evt_b');

      final a = container.read(eventDetailControllerProvider('evt_a'));
      final b = container.read(eventDetailControllerProvider('evt_b'));
      expect((a as EventDetailReady).detail.overview, 'A copy.');
      expect((b as EventDetailReady).detail.overview, 'B copy.');
    });
  });

  group('EventDetailScreen', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      final repo = FakeEventsRepository(
        details: {'evt_a': testDetail()},
        delay: const Duration(milliseconds: 200),
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container, 'evt_a'));
      await tester.pump();

      expect(find.byType(EventDetailSkeleton), findsOneWidget);

      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    });

    testWidgets('renders the design\'s content blocks', (tester) async {
      useTallViewport(tester);
      final repo = FakeEventsRepository(
        details: {
          'evt_a': testDetail(
            summary: testEvent(
              title: 'Maraya Starlight Acoustic Nights',
              venue: 'Desert Pavilion',
              city: 'AlUla',
              priceFrom: 650,
              startsAt: DateTime.utc(2025, 11, 28, 17, 30),
            ),
            subtitle: 'AlUla Desert Pavilion • Exclusive Concert Series',
            venueAddress: 'Ashar Valley',
            overview: 'Immerse yourself in an intimate open-air performance.',
            doorsOpenAt: DateTime.utc(2025, 11, 28, 16, 0),
            availability: TicketAvailability.sellingFast,
            tierLabel: 'Tier 1 Selling Fast',
          ),
        },
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container, 'evt_a'));
      await tester.pumpAndSettle();

      expect(find.text('OFFICIAL GATE ENTRY'), findsOneWidget);
      expect(find.text('Tier 1 Selling Fast'), findsOneWidget);
      expect(find.text('Maraya Starlight Acoustic Nights'), findsOneWidget);
      expect(
        find.text('AlUla Desert Pavilion • Exclusive Concert Series'),
        findsOneWidget,
      );
      expect(find.text('DATE & TIME'), findsOneWidget);
      expect(find.text('LOCATION'), findsOneWidget);
      expect(find.text('Ashar Valley'), findsOneWidget);
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('Encrypted Dynamic QR Ticket'), findsOneWidget);
      expect(find.text('STARTING FROM'), findsOneWidget);
      expect(find.text('650'), findsOneWidget);
      expect(find.text('Select seats'), findsOneWidget);
    });

    testWidgets('renders the venue time with its gates time', (tester) async {
      useTallViewport(tester);
      final repo = FakeEventsRepository(
        details: {
          // 17:30Z in a +03:00 venue is 20:30 local, with gates at 19:00.
          'evt_a': testDetail(
            summary: testEvent(startsAt: DateTime.utc(2025, 11, 28, 17, 30)),
            doorsOpenAt: DateTime.utc(2025, 11, 28, 16, 0),
          ),
        },
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container, 'evt_a'));
      await tester.pumpAndSettle();

      expect(find.text('20:30 AST (Gates 19:00)'), findsOneWidget);
    });

    testWidgets('a sold-out event cannot start a booking', (tester) async {
      useTallViewport(tester);
      final repo = FakeEventsRepository(
        details: {
          'evt_a': testDetail(availability: TicketAvailability.soldOut),
        },
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container, 'evt_a'));
      await tester.pumpAndSettle();

      expect(find.text('Sold out'), findsOneWidget);
      expect(find.text('Select seats'), findsNothing);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull, reason: 'must not be tappable');
    });

    testWidgets('a selling-fast event can still start a booking', (
      tester,
    ) async {
      useTallViewport(tester);
      // Regression: "selling fast" is a marketing signal about remaining
      // inventory, not a restriction. Treating it as one disabled the button
      // on exactly the events users are most trying to buy.
      final repo = FakeEventsRepository(
        details: {
          'evt_a': testDetail(
            availability: TicketAvailability.sellingFast,
            tierLabel: 'Tier 1 Selling Fast',
          ),
        },
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container, 'evt_a'));
      await tester.pumpAndSettle();

      expect(find.text('Select seats'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull, reason: 'must be tappable');
    });

    testWidgets('sharing opens the public event link', (tester) async {
      useTallViewport(tester);
      final repo = FakeEventsRepository(
        details: {'evt_a': testDetail(summary: testEvent(id: 'evt_a'))},
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container, 'evt_a'));
      await tester.pumpAndSettle();

      // The hero's controls carry a Semantics label rather than a tooltip.
      await tester.tap(find.bySemanticsLabel('Share event'));
      await tester.pumpAndSettle();

      // The web URL, not an in-app route: a link must work for someone who
      // does not have the app.
      expect(
        opener.opened.single.toString(),
        'https://tazkerah.app/events/evt_a',
      );
    });

    testWidgets('a missing event offers a way back, not a retry', (
      tester,
    ) async {
      final (container, _) = buildContainer();

      await tester.pumpWidget(wrap(container, 'evt_gone'));
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text('Event not available'), findsOneWidget);
      expect(find.text('Browse events'), findsOneWidget);
      expect(find.byType(AppErrorView), findsNothing);
    });

    testWidgets('a network failure offers a retry', (tester) async {
      final repo = FakeEventsRepository(failure: const NetworkFailure());
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(wrap(container, 'evt_a'));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders right-to-left in Arabic', (tester) async {
      useTallViewport(tester);
      final repo = FakeEventsRepository(
        details: {
          'evt_a': testDetail(
            summary: testEvent(title: 'ليالي مرايا الصوتية'),
            overview: 'أمسية موسيقية في وادي عشار.',
          ),
        },
      );
      final (container, _) = buildContainer(repository: repo);

      await tester.pumpWidget(
        wrap(container, 'evt_a', locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ليالي مرايا الصوتية'), findsOneWidget);
      expect(find.text('نبذة'), findsOneWidget);
      expect(find.text('اختيار المقاعد'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('نبذة'))),
        TextDirection.rtl,
      );
    });
  });
}
