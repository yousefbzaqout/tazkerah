import 'checkout_order.dart';
import 'seat.dart';
import 'seat_hold.dart';

/// What seat selection needs from the backend.
///
/// Declared in domain so the controller and its tests do not depend on how it
/// is fulfilled. The endpoints below are the contract this app expects; the
/// backend has not agreed them:
///
///   GET    /events/{id}/seats        -> {sectors: [...]}
///   POST   /events/{id}/holds        -> {reference, expires_at, total, ...}
///   DELETE /holds/{reference}        -> 204
///   POST   /holds/{reference}/checkout -> {order, expires_at, ...}
///   POST   /orders/{reference}/pay   -> {redirect_url}
///
/// The two failure modes this screen is built around are *answers*, not
/// faults, and both must come back as typed failures:
///
///   409 ConflictFailure  — the seat was taken between render and submit
///   423 LockedFailure    — the sector is withheld by the organizer
abstract interface class BookingRepository {
  /// Fetches the hall layout with current availability.
  Future<List<Sector>> fetchSeatMap(String eventId);

  /// Attempts to reserve [seatId].
  ///
  /// Returns the granted hold, whose `expires_at` is the authoritative
  /// deadline. Throws [ConflictFailure] if another guest got there first, and
  /// [LockedFailure] if the sector is withheld.
  ///
  /// The race is real and unavoidable: availability is rendered from a
  /// snapshot, and a seat can be taken in the milliseconds between a tap and
  /// this call. The screen is designed around losing it, not around
  /// preventing it.
  Future<SeatHold> holdSeat({required String eventId, required String seatId});

  /// Releases a hold early, when the user backs out.
  ///
  /// Failures are swallowed by the caller: the hold expires on its own within
  /// minutes, so a failed release is a delay rather than an error worth
  /// interrupting someone with.
  Future<void> releaseHold(String reference);

  /// Promotes a hold into a payment window and returns the priced order.
  ///
  /// The server extends the hold — the design's "+3m for checkout" — and
  /// returns a new `expires_at`. The client never adds three minutes itself:
  /// only the server can actually keep the seats, and a client that displayed
  /// an extension the server had not granted would count down to a deadline
  /// that had already passed.
  ///
  /// Throws [ConflictFailure] or [NotFoundFailure] if the hold is already gone.
  Future<CheckoutOrder> startCheckout(String holdReference);

  /// Hands the order to the payment gateway.
  ///
  /// Returns the URL to redirect to. Cards are never collected in-app — the
  /// design's "No card storage required" is a security property, not a
  /// convenience: an app that never sees a PAN cannot leak one, and stays out
  /// of PCI scope.
  Future<String> startPayment(String orderReference);
}
