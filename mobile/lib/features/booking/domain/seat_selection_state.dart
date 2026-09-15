import '../../../core/errors/failure.dart';
import 'seat.dart';
import 'seat_hold.dart';

/// What the seat selection screen is showing.
///
/// The three designed frames are not independent flags — they are phases of
/// one flow, and several combinations are nonsense: a conflict toast over a
/// held order, a running hold timer with no hold, a locked-sector sheet while
/// seats are being reserved. One object with a [SeatSelectionPhase] keeps
/// those unrepresentable.
class SeatSelectionState {
  const SeatSelectionState({
    this.phase = SeatSelectionPhase.loading,
    this.sectors = const [],
    this.selectedSeatId,
    this.hold,
    this.conflict,
    this.lockedSector,
    this.failure,
    this.isSubmitting = false,
    this.remaining = Duration.zero,
  });

  final SeatSelectionPhase phase;

  /// Every sector in the hall, including locked and context-only ones — the
  /// design draws those to orient the user rather than hiding them.
  final List<Sector> sectors;

  /// The seat the user has tapped but not yet held. Null in every phase except
  /// [SeatSelectionPhase.selecting].
  final String? selectedSeatId;

  /// The granted reservation. Present only in [SeatSelectionPhase.held].
  final SeatHold? hold;

  /// The seat that just lost a race, for the 409 toast. Cleared when the user
  /// dismisses it or picks another seat.
  final SeatConflict? conflict;

  /// The sector whose lock opened the 423 sheet.
  final Sector? lockedSector;

  /// A transport failure with nothing to show. Distinct from [conflict] and
  /// [lockedSector], which are *answers* rather than faults.
  final Failure? failure;

  /// A hold or release request is in flight; the map stops accepting taps.
  final bool isSubmitting;

  /// Time left on [hold], recomputed each tick against the corrected clock.
  /// Zero in every other phase.
  final Duration remaining;

  /// Every seat across every sector.
  Iterable<Seat> get allSeats => sectors.expand((s) => s.seats);

  /// The seat currently selected, if any.
  Seat? get selectedSeat {
    final id = selectedSeatId;
    if (id == null) return null;
    for (final seat in allSeats) {
      if (seat.id == id) return seat;
    }
    return null;
  }

  /// The sector the selected seat belongs to, for pricing.
  Sector? get selectedSector {
    final id = selectedSeatId;
    if (id == null) return null;
    for (final sector in sectors) {
      if (sector.seats.any((s) => s.id == id)) return sector;
    }
    return null;
  }

  /// Whether the map should accept taps.
  ///
  /// Locked during a hold, as the design's "Seat selection locked while timer
  /// is running" note states: the order is already reserved, and letting the
  /// user reshuffle seats underneath it would desynchronise the client from
  /// the reservation the server is holding.
  bool get isMapInteractive =>
      phase == SeatSelectionPhase.selecting && !isSubmitting;

  SeatSelectionState copyWith({
    SeatSelectionPhase? phase,
    List<Sector>? sectors,
    String? selectedSeatId,
    SeatHold? hold,
    SeatConflict? conflict,
    Sector? lockedSector,
    Failure? failure,
    bool? isSubmitting,
    Duration? remaining,
    bool clearSelection = false,
    bool clearHold = false,
    bool clearConflict = false,
    bool clearLockedSector = false,
    bool clearFailure = false,
  }) {
    return SeatSelectionState(
      phase: phase ?? this.phase,
      sectors: sectors ?? this.sectors,
      selectedSeatId: clearSelection
          ? null
          : (selectedSeatId ?? this.selectedSeatId),
      hold: clearHold ? null : (hold ?? this.hold),
      conflict: clearConflict ? null : (conflict ?? this.conflict),
      lockedSector: clearLockedSector
          ? null
          : (lockedSector ?? this.lockedSector),
      failure: clearFailure ? null : (failure ?? this.failure),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      remaining: remaining ?? this.remaining,
    );
  }
}

/// The mutually exclusive phases of seat selection.
enum SeatSelectionPhase {
  /// Fetching the seat map.
  loading,

  /// The map is up and the user may choose.
  selecting,

  /// A hold is granted and the countdown is running.
  held,

  /// The countdown reached zero and the server released the seats.
  expired,

  /// The map could not be loaded at all.
  error,
}

/// The seat that was lost to another guest, and how it is described.
class SeatConflict {
  const SeatConflict({required this.seatLabel, this.sectorName});

  /// The seat as printed on the toast: `A-12`.
  final String seatLabel;

  /// Its sector, so the toast can read `VIP · A-12`.
  final String? sectorName;

  /// The combined reference shown to the user.
  String get displayLabel =>
      sectorName == null ? seatLabel : '$sectorName · $seatLabel';
}
