/// A server-granted reservation over one or more seats.
///
/// The important field is [expiresAt], and it is *absolute server time*, not a
/// duration. A hold that stored "10 minutes" and counted down locally would
/// drift while the app is backgrounded and keep showing time remaining after
/// the server had already released the seats — telling someone they still have
/// a seat they have lost is the worst failure this screen can produce.
class SeatHold {
  const SeatHold({
    required this.reference,
    required this.seatIds,
    required this.expiresAt,
    required this.totalMinor,
    required this.currency,
  });

  /// Booking reference shown in the header pill: `BR-003`.
  final String reference;

  /// The seats this hold covers.
  final List<String> seatIds;

  /// When the server releases these seats, in UTC. Authoritative.
  final DateTime expiresAt;

  /// Order total in minor units, as quoted with the hold.
  final int totalMinor;
  final String currency;

  /// Time left, measured against a corrected clock.
  ///
  /// Takes [now] rather than reading the clock itself so the caller supplies
  /// `AppClock.now` — a device clock the user can change from Settings must
  /// not be what decides whether a hold looks live.
  ///
  /// Clamped at zero: a negative remaining time is an expired hold, and
  /// letting it go negative would render `-00:03` on the timer.
  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the server would already have released these seats.
  bool isExpired(DateTime now) => remaining(now) == Duration.zero;
}
