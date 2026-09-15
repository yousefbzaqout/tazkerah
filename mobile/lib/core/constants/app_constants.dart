/// Values that are fixed by the product or by a protocol agreement, rather
/// than by the environment.
///
/// Environment-varying values (endpoints, timeouts) belong in `AppConfig`.
abstract final class AppConstants {
  /// How long a ticket presentation code stays valid before rotating.
  ///
  /// 20s, matching the design's "Code refreshes every 20s" and "STRICT 20s
  /// TOTP cycle". The earlier 30s recommendation was withdrawn in favour of
  /// the specified interval; the concern behind it stands and is worth
  /// watching in gate testing — a 20s window can rotate mid-scan under poor
  /// lighting or an unsteady hand.
  ///
  /// This is a *display* default. The authoritative interval travels with the
  /// grant the server issues, so a backend change does not need an app
  /// release, and the screen can never advertise a cycle the gate disagrees
  /// with.
  static const Duration qrRotationInterval = Duration(seconds: 20);

  /// How long a seat hold survives before Redis releases it.
  ///
  /// Mirrors the backend TTL for display only. The authoritative deadline is
  /// the `expires_at` the server returns; never compute a deadline from this.
  static const Duration reservationHoldDuration = Duration(minutes: 10);

  /// How much longer the server extends a hold when checkout begins.
  ///
  /// The design's "+3m for checkout". Mirrors the backend policy for display
  /// only: the extension is granted server-side and comes back as a fresh
  /// `expires_at`. Never add this to a deadline on the client — only the
  /// server can actually keep the seats.
  static const Duration paymentWindowExtension = Duration(minutes: 3);

  /// How far the device clock may drift from server time before the rotating
  /// QR is withheld.
  ///
  /// 180 seconds, matching the design's "SKEW > 180s" and security policy
  /// FR-003. Beyond this a generated code falls outside the scanner's
  /// tolerance, so presenting one would produce an unexplained rejection at
  /// the gate; the manual fallback code is offered instead.
  ///
  /// This is the *client's* threshold for changing what it shows. The scanner
  /// holds the authoritative clock and its own tolerance — this only decides
  /// when to stop promising a scan that would fail.
  static const Duration clockSkewSuppressionThreshold = Duration(seconds: 180);

  /// How stale a clock sync may get before the ticket UI warns the user.
  static const Duration clockSyncStaleThreshold = Duration(hours: 48);

  /// Lead times for local event reminders.
  static const Duration reminderLeadTimeLong = Duration(hours: 24);
  static const Duration reminderLeadTimeShort = Duration(hours: 2);

  /// Debounce applied to search-as-you-type.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Page size for cursor-paginated lists.
  static const int defaultPageSize = 20;
}
