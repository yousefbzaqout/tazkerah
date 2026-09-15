import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/clock.dart';
import '../../domain/checkout_order.dart';
import '../../domain/checkout_state.dart';
import 'seat_selection_controller.dart';

/// Drives checkout: promote the hold into a payment window, run the countdown,
/// and hand off to the gateway.
///
/// Follows the same deadline rule as [SeatSelectionController], for the same
/// reason: the server extends the hold and returns a fresh `expires_at`, and
/// this only ever *renders* what is left. It never adds the three minutes
/// itself — only the server can actually keep the seats, and a client-granted
/// extension would count down to a deadline that had already passed.
class CheckoutController extends Notifier<CheckoutState> {
  CheckoutController(this._holdReference);

  /// The hold being paid for, handed over by the family.
  final String _holdReference;

  static const Duration tickInterval = Duration(seconds: 1);

  Timer? _ticker;
  int _requestToken = 0;
  bool _disposed = false;

  @override
  CheckoutState build() {
    ref.onDispose(() {
      _disposed = true;
      _ticker?.cancel();
    });
    Future.microtask(load);
    return const CheckoutLoading();
  }

  AppClock get _clock => ref.read(clockProvider);

  bool _isStale(int token) => _disposed || token != _requestToken;

  /// Promotes the hold and starts the payment window.
  Future<void> load() async {
    final token = ++_requestToken;
    state = const CheckoutLoading();

    try {
      final order = await ref
          .read(bookingRepositoryProvider)
          .startCheckout(_holdReference);
      if (_isStale(token)) return;

      // The window may already be over by the time the response lands — a slow
      // network is exactly when that happens, and showing a live timer over
      // dead seats would be a lie.
      if (order.isExpired(_clock.now)) {
        state = CheckoutExpired(order: order);
        return;
      }

      state = CheckoutReview(
        order: order,
        remaining: order.remaining(_clock.now),
      );
      _startTicker();
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      state = CheckoutError(failure);
    } catch (e, stack) {
      if (_isStale(token)) return;
      _report('Checkout preparation failed unexpectedly', e, stack);
      state = CheckoutError(UnknownFailure(debugMessage: e.toString()));
    }
  }

  /// Hands the order to the payment gateway.
  ///
  /// Returns the redirect URL for the caller to open, or null if the handoff
  /// failed. This controller does not open URLs — launching a browser is a
  /// platform action, and keeping it at the call site leaves this testable
  /// without a plugin.
  Future<String?> pay() async {
    final current = state;
    if (current is! CheckoutReview || current.isPaying) return null;

    // Refuse to start a payment against a window that has closed. Without this
    // a tap landing on the same frame as expiry would send the user to a
    // gateway for seats they no longer hold.
    if (current.order.isExpired(_clock.now)) {
      _expire(current.order);
      return null;
    }

    final token = ++_requestToken;
    state = current.copyWith(isPaying: true);

    try {
      final url = await ref
          .read(bookingRepositoryProvider)
          .startPayment(current.order.reference);
      if (_isStale(token)) return null;

      // `isPaying` stays true: the user is leaving for the gateway, and
      // re-enabling the button underneath them invites a second charge.
      return url;
    } on ConflictFailure {
      if (_isStale(token)) return null;
      // The hold went while the request was in flight.
      _expire(current.order);
      return null;
    } on Failure catch (failure) {
      if (_isStale(token)) return null;
      // A transport failure leaves the order intact and the window running, so
      // the user can simply try again.
      state = current.copyWith(isPaying: false);
      _report('Payment handoff failed', failure, StackTrace.current);
      return null;
    } catch (e, stack) {
      if (_isStale(token)) return null;
      _report('Payment handoff failed unexpectedly', e, stack);
      state = current.copyWith(isPaying: false);
      return null;
    }
  }

  /// Cancels the hold and releases the seats.
  Future<void> cancelHold() async {
    final current = state;
    final order = switch (current) {
      CheckoutReview(:final order) => order,
      _ => null,
    };
    if (order == null) return;

    _ticker?.cancel();
    try {
      await ref.read(bookingRepositoryProvider).releaseHold(order.reference);
    } catch (e, stack) {
      // Swallowed: the window expires on its own in minutes, so a failed
      // release costs the user nothing.
      _report('Hold release failed', e, stack);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  /// Recomputes the remaining window from the server's deadline.
  void _tick() {
    final current = state;
    if (current is! CheckoutReview || _disposed) {
      _ticker?.cancel();
      return;
    }

    final now = _clock.now;
    if (current.order.isExpired(now)) {
      _expire(current.order);
      return;
    }

    state = current.copyWith(remaining: current.order.remaining(now));
  }

  void _expire(CheckoutOrder order) {
    _ticker?.cancel();
    state = CheckoutExpired(
      order: order,
      // The policy the seats were released under, quotable by a user disputing
      // the loss.
      policyCode: 'FR-011 / ${order.reference}',
    );
  }

  void _report(String message, Object error, StackTrace stack) {
    developer.log(message, name: 'booking', error: error, stackTrace: stack);
  }
}

/// Auto-disposed, and deliberately so.
///
/// A family keyed on the hold reference would otherwise cache one controller
/// per reference for the life of the app, and a closed payment window is a
/// terminal state — the controller never leaves [CheckoutExpired] on its own,
/// because [build] (and so [load]) runs only once per key. Any later checkout
/// arriving at the same key would read that dead state and show the expired
/// frame over a hold that is actually live. Server references are not
/// guaranteed unique across a session, and the dev repository reuses `BR-003`
/// for every seat, so this is reachable by hand and not merely theoretical.
///
/// Disposing when the screen leaves keeps the key's lifetime tied to the flow
/// it belongs to: the next checkout builds a fresh controller and calls
/// [load].
final checkoutControllerProvider =
    NotifierProvider.family<CheckoutController, CheckoutState, String>(
      CheckoutController.new,
      isAutoDispose: true,
    );
