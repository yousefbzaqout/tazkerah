import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/ticket.dart';
import 'wallet_controller.dart';

/// What the order confirmation screen is showing.
sealed class OrderConfirmationState {
  const OrderConfirmationState();
}

/// The payment is still settling and the ticket has not been issued yet.
///
/// A distinct state rather than an error: a gateway that has taken the money
/// but not yet notified the backend is a normal few seconds, and telling the
/// user their purchase failed during it would be wrong and alarming.
class OrderSettling extends OrderConfirmationState {
  const OrderSettling({this.attempts = 0});

  final int attempts;
}

class OrderConfirmed extends OrderConfirmationState {
  const OrderConfirmed(this.ticket);
  final Ticket ticket;
}

/// The ticket could not be found after exhausting the settling window.
class OrderConfirmationFailed extends OrderConfirmationState {
  const OrderConfirmationFailed(this.failure);
  final Failure failure;
}

/// Waits for the ticket a completed payment produces.
///
/// Polls rather than assuming: the app returns from a hosted gateway with no
/// authority over whether the charge settled, so the only honest confirmation
/// is a ticket the backend has actually issued.
class OrderConfirmationController extends Notifier<OrderConfirmationState> {
  OrderConfirmationController(this._orderReference);

  final String _orderReference;

  /// How long to keep asking before giving up.
  ///
  /// Settlement is usually immediate; this covers a slow webhook. Beyond it
  /// the screen stops claiming to know, and points the user at their wallet —
  /// where the ticket will appear once it lands.
  static const Duration pollInterval = Duration(seconds: 2);
  static const int maxAttempts = 5;

  Timer? _poll;
  bool _disposed = false;

  @override
  OrderConfirmationState build() {
    ref.onDispose(() {
      _disposed = true;
      _poll?.cancel();
    });
    Future.microtask(load);
    return const OrderSettling();
  }

  Future<void> load() async {
    await _attempt(0);
  }

  Future<void> _attempt(int attempt) async {
    if (_disposed) return;

    try {
      final ticket = await ref
          .read(ticketsRepositoryProvider)
          .fetchTicketForOrder(_orderReference);
      if (_disposed) return;
      state = OrderConfirmed(ticket);
      // The wallet now has one more ticket in it.
      ref.invalidate(walletControllerProvider);
    } on NotFoundFailure catch (failure) {
      if (_disposed) return;

      if (attempt + 1 >= maxAttempts) {
        state = OrderConfirmationFailed(failure);
        return;
      }
      state = OrderSettling(attempts: attempt + 1);
      _poll?.cancel();
      _poll = Timer(pollInterval, () => _attempt(attempt + 1));
    } on Failure catch (failure) {
      if (_disposed) return;
      state = OrderConfirmationFailed(failure);
    } catch (e, stack) {
      if (_disposed) return;
      developer.log(
        'Order confirmation failed unexpectedly',
        name: 'tickets',
        error: e,
        stackTrace: stack,
      );
      state = OrderConfirmationFailed(
        UnknownFailure(debugMessage: e.toString()),
      );
    }
  }
}

final orderConfirmationControllerProvider =
    NotifierProvider.family<
      OrderConfirmationController,
      OrderConfirmationState,
      String
    >(OrderConfirmationController.new, isAutoDispose: true);
