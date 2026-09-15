import '../../../core/errors/failure.dart';
import 'checkout_order.dart';

/// What the checkout screen is showing.
///
/// The two designed frames are the terminal points of one short flow: a live
/// payment window, and the window having closed. A sealed hierarchy keeps them
/// apart, so the screen cannot read an order in a state where the seats have
/// already been released.
sealed class CheckoutState {
  const CheckoutState();
}

/// Promoting the hold into a payment window.
class CheckoutLoading extends CheckoutState {
  const CheckoutLoading();
}

/// The order is on screen and the payment window is running.
class CheckoutReview extends CheckoutState {
  const CheckoutReview({
    required this.order,
    required this.remaining,
    this.isPaying = false,
  });

  final CheckoutOrder order;

  /// Time left in the window, recomputed each tick from [order].
  final Duration remaining;

  /// A payment has been started and the gateway handoff is in flight. The
  /// screen blocks re-submission — a double charge is not a recoverable error.
  final bool isPaying;

  CheckoutReview copyWith({
    CheckoutOrder? order,
    Duration? remaining,
    bool? isPaying,
  }) {
    return CheckoutReview(
      order: order ?? this.order,
      remaining: remaining ?? this.remaining,
      isPaying: isPaying ?? this.isPaying,
    );
  }
}

/// The window closed and the server released the seats.
///
/// Carries what was lost so the screen can show the struck-through reservation
/// the design specifies — a bare "expired" with no detail leaves the user
/// unsure what happened to their money and their seat.
class CheckoutExpired extends CheckoutState {
  const CheckoutExpired({required this.order, this.policyCode});

  final CheckoutOrder order;

  /// The rule that released the seats: `FR-011 / BR-003`. Shown as a
  /// reference, because a user disputing a lost seat needs something to quote.
  final String? policyCode;
}

/// The order could not be prepared at all.
class CheckoutError extends CheckoutState {
  const CheckoutError(this.failure);

  final Failure failure;

  /// Whether the hold was already gone before checkout began.
  ///
  /// A 409 here means the seats were released between leaving the seat map and
  /// arriving at checkout — the same outcome as an expired window, so the
  /// screen shows the released state rather than a retry nobody can satisfy.
  bool get isHoldGone =>
      failure is ConflictFailure || failure is NotFoundFailure;
}
