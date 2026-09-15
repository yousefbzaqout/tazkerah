import 'dart:async';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../domain/booking_repository.dart';
import '../domain/checkout_order.dart';
import '../domain/seat.dart';
import '../domain/seat_hold.dart';

/// A stand-in [BookingRepository] for running seat selection before the
/// backend exists.
///
/// **Not a production implementation.** [AppConfig] gates it to non-production
/// builds. Like the other dev repositories, it is deliberately capable of
/// failing: the 409 and 423 paths are two of the three designed frames, and a
/// stub that always succeeded would leave them unreachable by hand.
///
/// Seats are wired so every state can be produced on a device:
///
/// - `A-12` in VIP  → always answers 409, the conflict toast
/// - any seat in Sector B (Mezzanine) → answers 423, the locked sheet
/// - anything else  → holds successfully and starts the timer
class DevBookingRepository implements BookingRepository {
  DevBookingRepository({this.latency = const Duration(milliseconds: 450)});

  /// Simulated round-trip, so in-flight states are visible rather than
  /// flashing past.
  final Duration latency;

  /// The seat that always loses its race, so the 409 frame is reachable.
  /// Matches the design's `VIP · A-12`: row A is numbered from 08, so the
  /// fifth seat carries the number 12.
  static const String conflictSeatId = 'vip_a_12';

  /// The sector the organizer has withheld, so the 423 frame is reachable.
  static const String lockedSectorId = 'sector_b';

  Timer? _pending;

  /// Makes each granted hold reference distinct within a session.
  int _holdSequence = 0;

  /// Cancels a simulated request still in flight, so a disposed provider does
  /// not leave a timer running behind it.
  void dispose() {
    _pending?.cancel();
    _pending = null;
  }

  Future<void> _sleep() {
    if (latency == Duration.zero) return Future<void>.value();
    final completer = Completer<void>();
    _pending = Timer(latency, () {
      _pending = null;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  @override
  Future<List<Sector>> fetchSeatMap(String eventId) async {
    await _sleep();
    return _buildHall();
  }

  @override
  Future<SeatHold> holdSeat({
    required String eventId,
    required String seatId,
  }) async {
    await _sleep();

    if (seatId == conflictSeatId) {
      throw const ConflictFailure(
        code: 'SEAT_UNAVAILABLE',
        debugMessage: 'DevBookingRepository: simulated reservation race',
      );
    }
    if (seatId.startsWith(lockedSectorId)) {
      throw const LockedFailure(
        reason: 'BR-007',
        code: 'SECTOR_LOCKED',
        debugMessage: 'DevBookingRepository: simulated organizer hold',
      );
    }

    return SeatHold(
      // Unique per hold. A real server never reuses a live reference, and the
      // reference is the key checkout is scoped by — handing out one constant
      // made every booking in a session share a single checkout controller,
      // so one expired window poisoned the next booking. The designed `BR-003`
      // stays as the prefix, because the header pill is specified to show it.
      reference: 'BR-003-${++_holdSequence}',
      seatIds: [seatId],
      // The deadline is absolute and server-issued, exactly as the real
      // contract requires — the client never computes one from a duration.
      expiresAt: DateTime.now().toUtc().add(
        AppConstants.reservationHoldDuration,
      ),
      totalMinor: 39900,
      currency: 'SAR',
    );
  }

  @override
  Future<void> releaseHold(String reference) async {
    await _sleep();
  }

  /// A hold reference that always answers "already gone", so the expired
  /// checkout frame is reachable by hand.
  static const String expiredHoldReference = 'BR-EXPIRED';

  @override
  Future<CheckoutOrder> startCheckout(String holdReference) async {
    await _sleep();

    if (holdReference == expiredHoldReference) {
      throw const ConflictFailure(
        code: 'HOLD_EXPIRED',
        debugMessage: 'DevBookingRepository: simulated expired hold',
      );
    }

    return CheckoutOrder(
      reference: holdReference,
      eventTitle: 'AlUla Desert Nocturne: Ambient Horizons',
      venueLine: 'Maraya Concert Pavilion · AlUla, Saudi Arabia',
      startsAt: DateTime.now().toUtc().add(const Duration(days: 30)),
      timeZoneOffset: const Duration(hours: 3),
      seatLabel: 'VIP · Sector A · Row 12',
      vatRegistration: '310892019',
      lineItems: const [
        OrderLineItem(
          label: 'VIP Prime Admission (1× Seat A-12)',
          amountMinor: 85000,
        ),
        OrderLineItem(label: 'Platform Booking Fee', amountMinor: 2500),
        OrderLineItem(
          label: 'Value Added Tax (15% VAT)',
          amountMinor: 13125,
          isTax: true,
        ),
      ],
      // Quoted by the server, not summed here — see CheckoutOrder.
      totalMinor: 100625,
      currency: 'SAR',
      // The extended window, as the server would return it.
      expiresAt: DateTime.now().toUtc().add(
        AppConstants.paymentWindowExtension,
      ),
      totalNote: 'Includes all municipal fees & VAT',
      gatewayNote:
          'Redirects to secure hosted payment gateway. No card storage '
          'required.',
    );
  }

  @override
  Future<String> startPayment(String orderReference) async {
    await _sleep();
    return 'https://pay.example.test/checkout/$orderReference';
  }

  /// The hall drawn in the design: a bookable VIP sector, a locked mezzanine,
  /// and a context-only block below it.
  static List<Sector> _buildHall() {
    return [
      Sector(
        id: 'sector_vip',
        name: 'SECTOR VIP PRIME',
        tierLabel: 'Tier 1',
        priceMinor: 39900,
        currency: 'SAR',
        rows: [
          _row('A', 'vip_a', const [
            SeatStatus.sold,
            SeatStatus.sold,
            SeatStatus.sold,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.sold,
            SeatStatus.sold,
          ]),
          _row('B', 'vip_b', const [
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.sold,
            SeatStatus.sold,
            SeatStatus.available,
          ]),
          _row('C', 'vip_c', const [
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
          ]),
          _row('D', 'vip_d', const [
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
            SeatStatus.unavailableInTier,
          ]),
        ],
      ),
      Sector(
        id: lockedSectorId,
        name: 'SECTOR B (Mezzanine)',
        tierLabel: 'Rows 1–12',
        priceMinor: 24900,
        currency: 'SAR',
        isLocked: true,
        lockReason: 'BR-007',
        rows: [
          _row('A', '${lockedSectorId}_a', const [
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
          ]),
          _row('B', '${lockedSectorId}_b', const [
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
            SeatStatus.available,
          ]),
        ],
      ),
      Sector(
        id: 'sector_upper',
        name: 'SECTOR B · UPPER MEZZANINE',
        tierLabel: 'Context',
        priceMinor: 0,
        currency: 'SAR',
        isContextOnly: true,
        rows: [
          _row('U1', 'upper_1', List.filled(11, SeatStatus.unavailableInTier)),
          _row('U2', 'upper_2', List.filled(11, SeatStatus.unavailableInTier)),
        ],
      ),
    ];
  }

  /// Builds one row, numbering seats from 08 as the design does.
  static SeatRow _row(String label, String idPrefix, List<SeatStatus> states) {
    return SeatRow(
      label: label,
      seats: [
        for (var i = 0; i < states.length; i++)
          Seat(
            id: '${idPrefix}_${(i + 8)}',
            row: label,
            number: (i + 8).toString().padLeft(2, '0'),
            status: states[i],
          ),
      ],
    );
  }
}
