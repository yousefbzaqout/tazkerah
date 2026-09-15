import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/features/events/data/events_cache.dart';
import 'package:tazkerah/features/events/domain/discovery_state.dart';
import 'package:tazkerah/features/events/domain/events_repository.dart';
import 'package:tazkerah/features/events/presentation/controllers/discovery_controller.dart';

import '../support/fake_events_repository.dart';

/// A container with the discovery feature wired to a fake repository and
/// in-memory storage.
(ProviderContainer, FakeEventsRepository, SecureStorage) buildContainer({
  FakeEventsRepository? repository,
  SecureStorage? storage,
}) {
  final repo = repository ?? FakeEventsRepository();
  final store = storage ?? InMemorySecureStorage();
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(store),
      eventsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return (container, repo, store);
}

/// Reads the controller and lets its scheduled first load run to completion.
Future<DiscoveryState> settle(ProviderContainer container) async {
  container.read(discoveryControllerProvider);
  // The first load is scheduled in `build` via a microtask; two turns of the
  // event loop covers the scheduling and the awaited fetch.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return container.read(discoveryControllerProvider);
}

void main() {
  group('DiscoveryController — loading', () {
    test('starts in the loading state before anything resolves', () {
      final (container, _, _) = buildContainer();

      expect(
        container.read(discoveryControllerProvider).status,
        DiscoveryStatus.loading,
      );
    });

    test('lands on ready with the returned rows', () async {
      final (container, _, _) = buildContainer(
        repository: FakeEventsRepository(
          pages: [
            EventPage(
              events: [
                testEvent(id: 'a'),
                testEvent(id: 'b'),
              ],
            ),
          ],
        ),
      );

      final state = await settle(container);

      expect(state.status, DiscoveryStatus.ready);
      expect(state.events.map((e) => e.id), ['a', 'b']);
      expect(state.isStale, isFalse);
    });

    test('an empty response is empty, not an error', () async {
      final (container, _, _) = buildContainer(
        repository: FakeEventsRepository(pages: [const EventPage(events: [])]),
      );

      final state = await settle(container);

      expect(state.status, DiscoveryStatus.empty);
      expect(state.failure, isNull);
    });

    test('fails to error when nothing is cached', () async {
      final (container, _, _) = buildContainer(
        repository: FakeEventsRepository(failure: const NetworkFailure()),
      );

      final state = await settle(container);

      expect(state.status, DiscoveryStatus.error);
      expect(state.failure, isA<NetworkFailure>());
      expect(state.events, isEmpty);
    });
  });

  group('DiscoveryController — offline fallback', () {
    test('serves cached rows when the network fails', () async {
      final storage = InMemorySecureStorage();
      final cachedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 14),
      );
      await EventsCache(storage).save([
        testEvent(id: 'cached_1'),
        testEvent(id: 'cached_2'),
      ], at: cachedAt);

      final (container, _, _) = buildContainer(
        repository: FakeEventsRepository(failure: const NetworkFailure()),
        storage: storage,
      );

      final state = await settle(container);

      expect(state.status, DiscoveryStatus.offline);
      expect(state.isStale, isTrue);
      expect(state.events.map((e) => e.id), ['cached_1', 'cached_2']);
      expect(state.cachedAt, isNotNull);
      // The failure is not surfaced: there are usable rows on screen, so an
      // error view over them would be wrong.
      expect(state.failure, isNull);
    });

    test('a successful load writes the cache', () async {
      final storage = InMemorySecureStorage();
      final (container, _, _) = buildContainer(
        repository: FakeEventsRepository(
          pages: [
            EventPage(events: [testEvent(id: 'fresh')]),
          ],
        ),
        storage: storage,
      );

      await settle(container);

      final cached = await EventsCache(storage).read();
      expect(cached, isNotNull);
      expect(cached!.events.single.id, 'fresh');
      expect(cached.isFromCache, isTrue);
    });

    test('a search failure does not fall back to the cached feed', () async {
      final storage = InMemorySecureStorage();
      await EventsCache(
        storage,
      ).save([testEvent(id: 'cached_1')], at: DateTime.now().toUtc());

      final repo = FakeEventsRepository(
        pages: [
          EventPage(events: [testEvent(id: 'live')]),
        ],
      );
      final (container, _, _) = buildContainer(
        repository: repo,
        storage: storage,
      );
      await settle(container);

      // Now search, with the network down.
      repo.failure = const NetworkFailure();
      final controller = container.read(discoveryControllerProvider.notifier);
      controller.search('opera');
      await Future<void>.delayed(
        DiscoveryController.searchDebounce + const Duration(milliseconds: 50),
      );

      final state = container.read(discoveryControllerProvider);
      // Showing the unfiltered cached feed here would answer a question the
      // user did not ask.
      expect(state.status, DiscoveryStatus.error);
      expect(state.events, isEmpty);
    });
  });

  group('DiscoveryController — refresh', () {
    test('keeps rows on screen and goes stale when a refresh fails', () async {
      final repo = FakeEventsRepository(
        pages: [
          EventPage(events: [testEvent(id: 'a')]),
        ],
      );
      final (container, _, _) = buildContainer(repository: repo);
      await settle(container);

      repo.failure = const NetworkFailure();
      await container.read(discoveryControllerProvider.notifier).refresh();

      final state = container.read(discoveryControllerProvider);
      expect(state.status, DiscoveryStatus.offline);
      expect(state.events.single.id, 'a', reason: 'rows must survive');
      expect(state.cachedAt, isNotNull);
      expect(state.isRefreshing, isFalse);
    });
  });

  group('DiscoveryController — search', () {
    test('debounces: one request for a burst of keystrokes', () async {
      final repo = FakeEventsRepository(
        pages: [
          EventPage(events: [testEvent()]),
        ],
      );
      final (container, _, _) = buildContainer(repository: repo);
      await settle(container);
      final initialCalls = repo.calls.length;

      final controller = container.read(discoveryControllerProvider.notifier);
      for (final q in ['s', 'so', 'sou', 'soun', 'sound']) {
        controller.search(q);
      }
      await Future<void>.delayed(
        DiscoveryController.searchDebounce + const Duration(milliseconds: 50),
      );

      expect(repo.calls.length - initialCalls, 1);
      expect(repo.calls.last.query, 'sound');
    });

    test('clearing searches immediately, without the debounce', () async {
      final repo = FakeEventsRepository(
        pages: [
          EventPage(events: [testEvent()]),
        ],
      );
      final (container, _, _) = buildContainer(repository: repo);
      await settle(container);

      final controller = container.read(discoveryControllerProvider.notifier);
      controller.search('opera');
      await Future<void>.delayed(
        DiscoveryController.searchDebounce + const Duration(milliseconds: 50),
      );
      final afterSearch = repo.calls.length;

      controller.clearSearch();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls.length, afterSearch + 1);
      expect(repo.calls.last.query, isNull, reason: 'unfiltered feed');
    });
  });

  group('DiscoveryController — pagination', () {
    test('appends the next page and keeps the existing rows', () async {
      final repo = FakeEventsRepository(
        pages: [
          EventPage(
            events: [testEvent(id: 'a')],
            nextCursor: '1',
          ),
          EventPage(events: [testEvent(id: 'b')]),
        ],
      );
      final (container, _, _) = buildContainer(repository: repo);
      await settle(container);

      expect(container.read(discoveryControllerProvider).hasMore, isTrue);

      await container.read(discoveryControllerProvider.notifier).loadMore();

      final state = container.read(discoveryControllerProvider);
      expect(state.events.map((e) => e.id), ['a', 'b']);
      expect(state.hasMore, isFalse);
      expect(repo.calls.last.cursor, '1');
    });

    test('does not page while showing cached rows', () async {
      final storage = InMemorySecureStorage();
      await EventsCache(
        storage,
      ).save([testEvent(id: 'cached')], at: DateTime.now().toUtc());

      final repo = FakeEventsRepository(failure: const NetworkFailure());
      final (container, _, _) = buildContainer(
        repository: repo,
        storage: storage,
      );
      await settle(container);
      final callsBeforePaging = repo.calls.length;

      await container.read(discoveryControllerProvider.notifier).loadMore();

      expect(repo.calls.length, callsBeforePaging);
    });
  });

  group('EventsCache', () {
    test('discards a page older than its maximum age', () async {
      final storage = InMemorySecureStorage();
      final cache = EventsCache(storage);
      await cache.save(
        [testEvent()],
        at: DateTime.now().toUtc().subtract(
          EventsCache.maxAge + const Duration(minutes: 1),
        ),
      );

      expect(await cache.read(), isNull);
    });

    test('survives a corrupt payload rather than throwing', () async {
      final storage = InMemorySecureStorage();
      await storage.write('events.feed.v1', 'not json at all');

      expect(await EventsCache(storage).read(), isNull);
    });

    test('round-trips every field a card renders', () async {
      final storage = InMemorySecureStorage();
      final cache = EventsCache(storage);
      final event = testEvent(
        id: 'evt_x',
        title: 'Soundstorm',
        venue: 'Banban',
        city: 'Riyadh',
        startsAt: DateTime.utc(2026, 12, 14, 19),
        endsAt: DateTime.utc(2026, 12, 16, 2),
        priceFrom: 399,
        soldOut: true,
      );

      await cache.save([event], at: DateTime.now().toUtc());
      final restored = (await cache.read())!.events.single;

      expect(restored.id, 'evt_x');
      expect(restored.title, 'Soundstorm');
      expect(restored.venue, 'Banban');
      expect(restored.city, 'Riyadh');
      expect(restored.startsAt, event.startsAt);
      expect(restored.endsAt, event.endsAt);
      expect(restored.priceFrom, 399);
      expect(restored.soldOut, isTrue);
    });
  });
}
