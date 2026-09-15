import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/dev_events_repository.dart';
import '../../data/events_cache.dart';
import '../../domain/discovery_state.dart';
import '../../domain/events_repository.dart';

/// Drives the discovery feed.
///
/// Owns four operations — first load, refresh, search, and paging — and the
/// rule that connects them: **a failure never blanks a screen that has
/// something to show.** A refresh that fails over cached rows keeps the rows
/// and turns the chrome amber; only a first load with nothing behind it is
/// allowed to reach [DiscoveryStatus.error].
///
/// Like [SignInController], it never navigates. The screen decides what a tap
/// does with the id this controller supplies.
class DiscoveryController extends Notifier<DiscoveryState> {
  /// How long typing must pause before a search is sent.
  ///
  /// Search fires per keystroke otherwise, which on a phone keyboard means
  /// eight requests to type "soundstorm" and a results list that flickers
  /// through seven wrong answers on the way to the right one.
  static const Duration searchDebounce = Duration(milliseconds: 350);

  Timer? _debounce;

  /// Identifies the newest in-flight request. A response whose token no longer
  /// matches is discarded: without this, a slow request for "sound" can land
  /// after a fast one for "soundstorm" and overwrite the correct results with
  /// stale ones.
  int _requestToken = 0;

  /// Set once the provider is disposed, so a response that lands afterwards is
  /// dropped instead of assigning to a discarded notifier.
  bool _disposed = false;

  @override
  DiscoveryState build() {
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    // Kick off the first load. Scheduled rather than awaited: `build` must
    // return the initial state synchronously, and the screen renders the
    // skeleton while this runs.
    Future.microtask(load);
    return const DiscoveryState();
  }

  EventsRepository get _repository => ref.read(eventsRepositoryProvider);
  EventsCache get _cache => ref.read(eventsCacheProvider);

  /// Whether a response that has just arrived should be discarded — either
  /// because a newer request superseded it, or because the provider was
  /// disposed while it was in flight. Assigning to `state` after disposal
  /// throws, and a stub or a slow network makes that a routine race rather
  /// than a theoretical one.
  bool _isStale(int token) => _disposed || token != _requestToken;

  /// First load, or a retry after [DiscoveryStatus.error].
  ///
  /// Shows the skeleton, then either live rows, cached rows, or an error.
  Future<void> load() async {
    final token = ++_requestToken;
    state = state.copyWith(
      status: DiscoveryStatus.loading,
      clearFailure: true,
      clearCachedAt: true,
    );

    try {
      final page = await _repository.fetchEvents(query: _queryOrNull);
      if (_isStale(token)) return;

      // Only an unfiltered first page is worth caching — it is what the app
      // opens on. Caching a search result would mean showing someone's last
      // query back to them as if it were the feed.
      if (_queryOrNull == null && page.events.isNotEmpty) {
        await _cache.save(page.events, at: DateTime.now().toUtc());
      }

      state = _pageToState(page);
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      await _fallBackToCache(failure, token: token);
    } catch (e, stack) {
      if (_isStale(token)) return;
      // Catch-all so an unforeseen error surfaces as a retryable state rather
      // than escaping as an uncaught zone error. Resolving the repository can
      // itself throw — an unbound provider does in production builds.
      _report('Discovery load failed unexpectedly', e, stack);
      await _fallBackToCache(
        UnknownFailure(debugMessage: e.toString()),
        token: token,
      );
    }
  }

  /// Pull-to-refresh. Keeps the current rows on screen while it runs.
  ///
  /// A failed refresh is reported by flipping to the offline state — the rows
  /// the user is looking at are now known-stale — rather than by throwing the
  /// list away for an error page.
  Future<void> refresh() async {
    if (state.isRefreshing) return;
    final token = ++_requestToken;
    state = state.copyWith(isRefreshing: true, clearFailure: true);

    try {
      final page = await _repository.fetchEvents(query: _queryOrNull);
      if (_isStale(token)) return;

      if (_queryOrNull == null && page.events.isNotEmpty) {
        await _cache.save(page.events, at: DateTime.now().toUtc());
      }

      state = _pageToState(page).copyWith(isRefreshing: false);
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      state = _degradeAfterFailedRefresh(failure);
    } catch (e, stack) {
      if (_isStale(token)) return;
      _report('Discovery refresh failed unexpectedly', e, stack);
      state = _degradeAfterFailedRefresh(
        UnknownFailure(debugMessage: e.toString()),
      );
    }
  }

  /// Called on every keystroke. Debounced — the request goes out once typing
  /// settles.
  void search(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, load);
  }

  /// Clears the search and returns to the full feed immediately, without
  /// waiting out the debounce — the tap on the clear button is itself the
  /// signal that the user has finished typing.
  void clearSearch() {
    if (state.query.isEmpty) return;
    _debounce?.cancel();
    state = state.copyWith(query: '');
    load();
  }

  /// Appends the next page. Safe to call from a scroll listener: it is a
  /// no-op while one is already in flight, at the end of the feed, or when
  /// the screen is not showing live rows.
  ///
  /// Paging is not offered over cached data — there is no connection to fetch
  /// the next page with, and the cache holds only the first one.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null ||
        state.isLoadingMore ||
        state.status != DiscoveryStatus.ready) {
      return;
    }

    final token = _requestToken;
    state = state.copyWith(isLoadingMore: true);

    try {
      final page = await _repository.fetchEvents(
        query: _queryOrNull,
        cursor: cursor,
      );
      // A search or refresh started while this was in flight; that newer
      // result owns the list now, and appending to it would splice a page of
      // the old query onto the new one.
      if (_isStale(token)) return;

      state = state.copyWith(
        events: [...state.events, ...page.events],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      // A page that fails to append leaves the existing rows untouched. The
      // cursor is kept so scrolling again retries.
      _report('Discovery page append failed', failure, StackTrace.current);
      state = state.copyWith(isLoadingMore: false);
    } catch (e, stack) {
      if (_isStale(token)) return;
      _report('Discovery page append failed unexpectedly', e, stack);
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Serves cached rows when the network could not be reached, or surfaces the
  /// failure when there is nothing cached to fall back to.
  Future<void> _fallBackToCache(Failure failure, {required int token}) async {
    // A search has no cache behind it: the cached page is the unfiltered feed,
    // and showing it as the result of a search would answer a question the
    // user did not ask.
    if (_queryOrNull == null) {
      final cached = await _cache.read();
      if (_isStale(token)) return;

      if (cached != null && cached.events.isNotEmpty) {
        state = state.copyWith(
          status: DiscoveryStatus.offline,
          events: cached.events,
          cachedAt: cached.cachedAt,
          clearFailure: true,
          clearCursor: true,
          isRefreshing: false,
        );
        return;
      }
    }

    state = state.copyWith(
      status: DiscoveryStatus.error,
      events: const [],
      failure: failure,
      clearCachedAt: true,
      clearCursor: true,
      isRefreshing: false,
    );
  }

  /// A refresh failed while rows were on screen. Those rows stay; the screen
  /// now describes them as stale.
  DiscoveryState _degradeAfterFailedRefresh(Failure failure) {
    if (state.events.isEmpty) {
      return state.copyWith(
        status: DiscoveryStatus.error,
        failure: failure,
        isRefreshing: false,
      );
    }

    return state.copyWith(
      status: DiscoveryStatus.offline,
      // The rows were last known good at their existing timestamp, or — if
      // they were live until this moment — as of now.
      cachedAt: state.cachedAt ?? DateTime.now().toUtc(),
      isRefreshing: false,
      clearFailure: true,
    );
  }

  /// Maps a successful page onto the right terminal state.
  DiscoveryState _pageToState(EventPage page) {
    if (page.events.isEmpty) {
      return state.copyWith(
        status: DiscoveryStatus.empty,
        events: const [],
        clearFailure: true,
        clearCachedAt: true,
        clearCursor: true,
      );
    }

    return state.copyWith(
      status: page.isFromCache
          ? DiscoveryStatus.offline
          : DiscoveryStatus.ready,
      events: page.events,
      cachedAt: page.cachedAt,
      clearCachedAt: !page.isFromCache,
      nextCursor: page.nextCursor,
      clearCursor: page.nextCursor == null,
      clearFailure: true,
    );
  }

  /// The active query, or null when unfiltered. The repository takes null for
  /// "no filter", and an empty string would be a filter that matches nothing
  /// on a strict backend.
  String? get _queryOrNull {
    final trimmed = state.query.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Logs an unexpected failure. Phase 8 points this at the crash reporter.
  void _report(String message, Object error, StackTrace stack) {
    developer.log(message, name: 'events', error: error, stackTrace: stack);
  }
}

/// Binds a concrete [EventsRepository].
///
/// No real implementation exists yet — the endpoint in [EventsRepository] has
/// not been agreed with the backend. This binds [DevEventsRepository] outside
/// production so the screen is runnable by hand, and throws in production so a
/// release cannot ship against stub data. Replace the body once the endpoint
/// exists; nothing above the data layer changes.
final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.environment == AppEnvironment.production) {
    throw UnimplementedError(
      'No production EventsRepository is bound. The backend contract '
      '(GET /events) is still open — see EventsRepository.',
    );
  }

  final repository = DevEventsRepository();
  // Cancels the stub's simulated latency when the provider goes away, so a
  // request in flight cannot outlive the scope that started it.
  ref.onDispose(repository.dispose);
  return repository;
});

/// The offline copy of the feed's first page.
final eventsCacheProvider = Provider<EventsCache>((ref) {
  return EventsCache(ref.watch(secureStorageProvider));
});

final discoveryControllerProvider =
    NotifierProvider<DiscoveryController, DiscoveryState>(
      DiscoveryController.new,
    );
