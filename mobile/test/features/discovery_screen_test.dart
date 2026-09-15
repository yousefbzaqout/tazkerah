import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/core/widgets/app_empty_view.dart';
import 'package:tazkerah/core/widgets/app_error_view.dart';
import 'package:tazkerah/features/events/data/events_cache.dart';
import 'package:tazkerah/features/events/domain/events_repository.dart';
import 'package:tazkerah/features/events/presentation/controllers/discovery_controller.dart';
import 'package:tazkerah/features/events/presentation/events_screen.dart';
import 'package:tazkerah/features/events/presentation/widgets/event_card.dart';
import 'package:tazkerah/features/events/presentation/widgets/event_card_skeleton.dart';
import 'package:tazkerah/features/events/presentation/widgets/offline_footer.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/fake_events_repository.dart';

/// A viewport tall enough to hold two full event cards.
///
/// The default test surface is 800x600, which at the design's card height
/// shows barely one. A lazy list correctly declines to build what is off
/// screen, so without this a test asserting on the second card is testing the
/// viewport, not the screen.
const Size _tallPhone = Size(420, 1600);

/// Applies [_tallPhone] to the binding for the duration of one test.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = _tallPhone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

(Widget, ProviderContainer) buildScreen({
  FakeEventsRepository? repository,
  SecureStorage? storage,
  Locale locale = const Locale('en'),
}) {
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(
        storage ?? InMemorySecureStorage(),
      ),
      eventsRepositoryProvider.overrideWithValue(
        repository ?? FakeEventsRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);

  return (
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EventsScreen(),
      ),
    ),
    container,
  );
}

void main() {
  group('Discovery screen — loading', () {
    testWidgets('shows skeleton cards while the first page is in flight', (
      tester,
    ) async {
      final (screen, _) = buildScreen(
        repository: FakeEventsRepository(
          pages: [
            EventPage(events: [testEvent()]),
          ],
          delay: const Duration(milliseconds: 200),
        ),
      );

      await tester.pumpWidget(screen);
      await tester.pump();

      expect(find.byType(EventCardSkeleton), findsWidgets);
      expect(find.text('SYNCHRONIZING...'), findsOneWidget);
      expect(find.byType(EventCard), findsNothing);

      // Let the in-flight request finish so the ticker is disposed cleanly.
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    });
  });

  group('Discovery screen — populated', () {
    testWidgets('renders a card per event with title, venue and price', (
      tester,
    ) async {
      useTallViewport(tester);
      final (screen, _) = buildScreen(
        repository: FakeEventsRepository(
          pages: [
            EventPage(
              events: [
                testEvent(
                  id: 'a',
                  title: 'Soundstorm Live Arena 2025',
                  venue: 'Banban District',
                  city: 'Riyadh',
                  priceFrom: 399,
                ),
                testEvent(id: 'b', title: 'Maraya Starlight'),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.byType(EventCard), findsNWidgets(2));
      expect(find.text('Soundstorm Live Arena 2025'), findsOneWidget);
      expect(find.text('Banban District • Riyadh'), findsOneWidget);
      expect(find.text('399 SAR'), findsOneWidget);
      expect(find.text('LIVE PASSES'), findsOneWidget);
    });

    testWidgets('renders the date chip as a range for a multi-day event', (
      tester,
    ) async {
      final (screen, _) = buildScreen(
        repository: FakeEventsRepository(
          pages: [
            EventPage(
              events: [
                testEvent(
                  startsAt: DateTime.utc(2026, 12, 14, 19),
                  endsAt: DateTime.utc(2026, 12, 16, 2),
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.text('DEC 14–16'), findsOneWidget);
    });

    testWidgets('renders a single date for a one-day event', (tester) async {
      final (screen, _) = buildScreen(
        repository: FakeEventsRepository(
          pages: [
            EventPage(
              events: [testEvent(startsAt: DateTime.utc(2027, 1, 8, 20))],
            ),
          ],
        ),
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.text('JAN 08'), findsOneWidget);
    });
  });

  group('Discovery screen — offline', () {
    testWidgets('shows the banner, cached tags and the sync footer', (
      tester,
    ) async {
      useTallViewport(tester);
      final storage = InMemorySecureStorage();
      await EventsCache(storage).save([
        testEvent(id: 'cached_1'),
        testEvent(id: 'cached_2'),
      ], at: DateTime.now().toUtc().subtract(const Duration(minutes: 14)));

      final (screen, _) = buildScreen(
        repository: FakeEventsRepository(failure: const NetworkFailure()),
        storage: storage,
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.text('Offline — showing cached events'), findsOneWidget);
      expect(find.text('LOCAL CRYPTOGRAPHIC CACHE'), findsOneWidget);
      expect(find.text('2 PASSES READY'), findsOneWidget);
      expect(find.text('CACHED'), findsNWidgets(2));
      expect(find.byType(OfflineFooter), findsOneWidget);
      expect(find.text('Last synchronized 14m ago'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
    });
  });

  group('Discovery screen — empty and error', () {
    testWidgets('shows the empty view when the feed returns nothing', (
      tester,
    ) async {
      final (screen, _) = buildScreen(
        repository: FakeEventsRepository(pages: [const EventPage(events: [])]),
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text('No events found'), findsOneWidget);
      // No status pill may claim the feed is live here.
      expect(find.text('LIVE PASSES'), findsNothing);
    });

    testWidgets('shows a retryable error when nothing is cached', (
      tester,
    ) async {
      final repo = FakeEventsRepository(failure: const NetworkFailure());
      final (screen, _) = buildScreen(repository: repo);

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);

      // Retry recovers onto a working feed.
      repo.failure = null;
      repo.pages = [
        EventPage(events: [testEvent(title: 'Back Online')]),
      ];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Back Online'), findsOneWidget);
    });
  });

  group('Discovery screen — search', () {
    testWidgets('typing filters the feed through the repository', (
      tester,
    ) async {
      final repo = FakeEventsRepository(
        pages: [
          EventPage(events: [testEvent(title: 'Everything')]),
          EventPage(
            events: [testEvent(id: 'f', title: 'Filtered Result')],
          ),
        ],
      );
      final (screen, _) = buildScreen(repository: repo);

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'opera');
      await tester.pumpAndSettle(
        DiscoveryController.searchDebounce + const Duration(milliseconds: 50),
      );

      expect(repo.calls.last.query, 'opera');
      expect(find.text('Filtered Result'), findsOneWidget);
    });
  });

  group('Discovery screen — Arabic', () {
    testWidgets('renders right-to-left with translated chrome', (tester) async {
      final (screen, _) = buildScreen(
        repository: FakeEventsRepository(
          pages: [
            EventPage(events: [testEvent(title: 'حفل موسيقي')]),
          ],
        ),
        locale: const Locale('ar'),
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      expect(find.text('اختر تجربتك'), findsOneWidget);
      expect(find.text('حفل موسيقي'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(EventCard).first)),
        TextDirection.rtl,
      );
    });
  });
}
