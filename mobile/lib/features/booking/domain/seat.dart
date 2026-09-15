/// One seat in a sector's grid.
///
/// Plain Dart, per the architecture's `domain` rule. It carries position and
/// availability; how a seat is drawn is presentation's decision.
class Seat {
  const Seat({
    required this.id,
    required this.row,
    required this.number,
    required this.status,
    this.priceMinor,
  });

  /// Server identifier, used when holding: `seat_a12`.
  final String id;

  /// Row label as printed: `A`.
  final String row;

  /// Seat number as printed, zero-padded: `08`.
  final String number;

  final SeatStatus status;

  /// Price in minor units, when seats within a sector differ. Null means the
  /// sector's own price applies.
  final int? priceMinor;

  /// The human-readable seat reference: `A-12`.
  String get label => '$row-$number';

  /// Whether this seat can be chosen right now.
  bool get isSelectable => status == SeatStatus.available;

  Seat copyWith({SeatStatus? status}) => Seat(
    id: id,
    row: row,
    number: number,
    status: status ?? this.status,
    priceMinor: priceMinor,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Seat && other.id == id && other.status == status);

  @override
  int get hashCode => Object.hash(id, status);
}

/// What the server says about one seat.
///
/// [conflict] is deliberately a *seat* status rather than a screen-level flag:
/// the design marks the specific seat that lost the race, and a boolean on the
/// controller could not say which one.
enum SeatStatus {
  available,

  /// Held by this user, in the current order.
  held,

  /// Taken by someone else.
  sold,

  /// This user just lost a reservation race for it — the 409 case.
  conflict,

  /// Present in the layout but not sellable in the active tier.
  unavailableInTier,
}

/// A block of seats sold as one tier.
class Sector {
  const Sector({
    required this.id,
    required this.name,
    required this.tierLabel,
    required this.rows,
    required this.priceMinor,
    required this.currency,
    this.isLocked = false,
    this.lockReason,
    this.isContextOnly = false,
  });

  final String id;

  /// Display name: `SECTOR VIP PRIME`.
  final String name;

  /// Tier as printed beside the name: `Tier 1`.
  final String tierLabel;

  final List<SeatRow> rows;

  /// Sector price in minor units.
  final int priceMinor;
  final String currency;

  /// Withheld by the organizer — the 423 case. Its seats render but none can
  /// be chosen, and tapping one opens the locked-sector sheet.
  final bool isLocked;

  /// Backend reason code shown in that sheet: `Organizer Hold (BR-007)`.
  final String? lockReason;

  /// Drawn only to orient the user, as the design's greyed "UPPER MEZZANINE
  /// (CONTEXT)" block is. Never interactive, and excluded from availability
  /// counts, because it is scenery rather than inventory.
  final bool isContextOnly;

  /// Every seat in the sector, flattened.
  Iterable<Seat> get seats => rows.expand((row) => row.seats);

  /// Whether anything here can still be bought.
  bool get hasAvailability =>
      !isLocked && !isContextOnly && seats.any((s) => s.isSelectable);
}

/// One row of seats, with its label.
class SeatRow {
  const SeatRow({required this.label, required this.seats});

  /// Row letter as printed: `A`.
  final String label;

  final List<Seat> seats;
}
