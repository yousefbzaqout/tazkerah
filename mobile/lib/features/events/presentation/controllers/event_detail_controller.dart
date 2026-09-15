import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/event_detail_state.dart';
import 'discovery_controller.dart';

/// Loads one event for the detail screen.
///
/// Keyed by event id through [family], so two detail screens open in different
/// tabs hold independent state and neither can overwrite the other's event.
///
/// Follows the same rule as [DiscoveryController]: a failed refresh never
/// blanks a screen that already has content. It does not navigate — the screen
/// decides what "Select seats" does.
class EventDetailController extends Notifier<EventDetailState> {
  EventDetailController(this._eventId);

  /// The event this controller was created for, handed to it by the family.
  final String _eventId;

  /// Guards against a response for a superseded request being applied, and
  /// against writing to a notifier the provider has already disposed.
  int _requestToken = 0;
  bool _disposed = false;

  @override
  EventDetailState build() {
    ref.onDispose(() => _disposed = true);
    // Scheduled rather than awaited: `build` must return synchronously, and
    // the screen renders its loading state while this runs.
    Future.microtask(load);
    return const EventDetailLoading();
  }

  bool _isStale(int token) => _disposed || token != _requestToken;

  /// First load, or a retry after an error.
  Future<void> load() async {
    final token = ++_requestToken;
    state = const EventDetailLoading();
    await _fetch(token);
  }

  /// Reloads while keeping the current content on screen.
  Future<void> refresh() async {
    final current = state;
    if (current is! EventDetailReady || current.isRefreshing) {
      // Nothing to refresh over — fall back to a normal load so pulling on an
      // error state still retries.
      if (current is! EventDetailReady) return load();
      return;
    }

    final token = ++_requestToken;
    state = current.copyWith(isRefreshing: true);
    await _fetch(token, previous: current);
  }

  /// The one place the repository is called, so every entry point gets the
  /// same error handling.
  ///
  /// [previous] is the content to fall back to when a *refresh* fails: the
  /// event on screen is still the last good copy, and replacing it with an
  /// error page would be a worse answer than showing slightly stale detail.
  Future<void> _fetch(int token, {EventDetailReady? previous}) async {
    try {
      final detail = await ref
          .read(eventsRepositoryProvider)
          .fetchEvent(_eventId);
      if (_isStale(token)) return;
      state = EventDetailReady(detail);
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      state =
          previous?.copyWith(isRefreshing: false) ?? EventDetailError(failure);
    } catch (e, stack) {
      if (_isStale(token)) return;
      // Catch-all so an unforeseen error surfaces as a retryable state rather
      // than escaping as an uncaught zone error. Resolving the repository can
      // itself throw — an unbound provider does in production builds.
      _report(e, stack);
      state =
          previous?.copyWith(isRefreshing: false) ??
          EventDetailError(UnknownFailure(debugMessage: e.toString()));
    }
  }

  /// Logs an unexpected failure. Phase 8 points this at the crash reporter.
  void _report(Object error, StackTrace stack) {
    developer.log(
      'Event detail load failed unexpectedly',
      name: 'events',
      error: error,
      stackTrace: stack,
    );
  }
}

/// One controller per event id.
final eventDetailControllerProvider =
    NotifierProvider.family<EventDetailController, EventDetailState, String>(
      EventDetailController.new,
    );
