/// A purchased ticket, as it appears in the wallet.
///
/// Distinct from [GatePass]: this is the durable record a user owns — what
/// they bought, for which event, at what price. The pass is the *presentation*
/// of that record at a gate, and it carries rotating codes and security state
/// this must not.
///
/// Keeping them apart matters for storage: the wallet is cached locally so it
/// works offline, while nothing about a presentation code is ever persisted.
class Ticket {
  const Ticket({
    required this.id,
    required this.orderReference,
    required this.eventId,
    required this.eventTitle,
    required this.venueName,
    required this.startsAt,
    required this.timeZoneOffset,
    required this.seatLabel,
    required this.zoneLabel,
    required this.status,
    required this.totalMinor,
    required this.currency,
    this.purchasedAt,
    this.entranceLabel,
  });

  final String id;

  /// The order it came from: `BR-003`. Shown so support can be given a
  /// reference the backend also knows.
  final String orderReference;

  /// The event, so the wallet can link back to it.
  final String eventId;

  final String eventTitle;
  final String venueName;

  /// Event start in UTC. Rendered in the venue's zone, as everywhere else.
  final DateTime startsAt;
  final Duration timeZoneOffset;

  final String seatLabel;
  final String zoneLabel;

  final TicketStatus status;

  /// What was paid, in minor units.
  final int totalMinor;
  final String currency;

  final DateTime? purchasedAt;
  final String? entranceLabel;

  /// Event start expressed in the venue's zone.
  DateTime get localStartsAt => startsAt.add(timeZoneOffset);

  /// Whether a gate pass can be presented for this ticket.
  ///
  /// Only a valid, unused ticket opens the pass screen. A consumed or refunded
  /// ticket still appears in the wallet — it is part of the user's history —
  /// but offering a QR for it would imply an entry that will not happen.
  bool get canPresent => status == TicketStatus.valid;

  /// Whether the event has already started, against a corrected clock.
  bool hasStarted(DateTime now) => now.isAfter(startsAt);
}

/// Where a ticket is in its life.
enum TicketStatus {
  /// Paid for and not yet used.
  valid,

  /// Already scanned at a gate. Single entry, so it cannot be presented again.
  used,

  /// Refunded or cancelled by the organizer.
  refunded,

  /// The event happened and this was never scanned.
  expired,
}
