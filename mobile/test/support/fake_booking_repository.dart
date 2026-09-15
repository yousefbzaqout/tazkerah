import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/features/booking/domain/booking_repository.dart';
import 'package:tazkerah/features/booking/domain/checkout_order.dart';
import 'package:tazkerah/features/booking/domain/seat.dart';
import 'package:tazkerah/features/booking/domain/seat_hold.dart';

/// A [BookingRepository] a test can steer.
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    this.sectors = const [],
    this.hold,
    this.order,
    this.checkoutFailure,
    this.paymentFailure,
    this.mapFailure,
    this.holdFailure,
    this.delay,
  });

  List<Sector> sectors;

  /// Returned by a successful [holdSeat]. A default is supplied on demand so
  /// most tests need not build one.
  SeatHold? hold;

  /// Thrown by [fetchSeatMap] when set.
  Failure? mapFailure;

  /// Thrown by [holdSeat] when set — how a test reaches 409 and 423.
  Failure? holdFailure;

  /// Returned by [startCheckout]. A default is built on demand.
  CheckoutOrder? order;

  /// Thrown by [startCheckout] when set.
  Failure? checkoutFailure;

  /// Thrown by [startPayment] when set.
  Failure? paymentFailure;

  final List<String> checkoutReferences = [];
  final List<String> paymentReferences = [];

  Duration? delay;

  final List<String> heldSeatIds = [];
  final List<String> releasedReferences = [];

  @override
  Future<List<Sector>> fetchSeatMap(String eventId) async {
    if (delay != null) await Future<void>.delayed(delay!);
    final failure = mapFailure;
    if (failure != null) throw failure;
    return sectors;
  }

  @override
  Future<SeatHold> holdSeat({
    required String eventId,
    required String seatId,
  }) async {
    heldSeatIds.add(seatId);
    if (delay != null) await Future<void>.delayed(delay!);

    final failure = holdFailure;
    if (failure != null) throw failure;

    return hold ??
        SeatHold(
          reference: 'BR-003',
          seatIds: [seatId],
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
          totalMinor: 39900,
          currency: 'SAR',
        );
  }

  @override
  Future<void> releaseHold(String reference) async {
    releasedReferences.add(reference);
    if (delay != null) await Future<void>.delayed(delay!);
  }

  @override
  Future<CheckoutOrder> startCheckout(String holdReference) async {
    checkoutReferences.add(holdReference);
    if (delay != null) await Future<void>.delayed(delay!);

    final failure = checkoutFailure;
    if (failure != null) throw failure;

    return order ?? testOrder(reference: holdReference);
  }

  @override
  Future<String> startPayment(String orderReference) async {
    paymentReferences.add(orderReference);
    if (delay != null) await Future<void>.delayed(delay!);

    final failure = paymentFailure;
    if (failure != null) throw failure;

    return 'https://pay.test/$orderReference';
  }
}

/// A throwaway priced order.
CheckoutOrder testOrder({
  String reference = 'BR-003',
  String eventTitle = 'AlUla Desert Nocturne',
  String seatLabel = 'VIP · Sector A · Row 12',
  int totalMinor = 100625,
  Duration remaining = const Duration(minutes: 3),
  List<OrderLineItem>? lineItems,
}) {
  return CheckoutOrder(
    reference: reference,
    eventTitle: eventTitle,
    venueLine: 'Maraya Concert Pavilion · AlUla, Saudi Arabia',
    startsAt: DateTime.utc(2026, 4, 18, 17, 30),
    timeZoneOffset: const Duration(hours: 3),
    seatLabel: seatLabel,
    vatRegistration: '310892019',
    lineItems:
        lineItems ??
        const [
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
    totalMinor: totalMinor,
    currency: 'SAR',
    expiresAt: DateTime.now().toUtc().add(remaining),
    totalNote: 'Includes all municipal fees & VAT',
    gatewayNote: 'Redirects to secure hosted payment gateway.',
  );
}

/// A sector with a simple single row, for tests that only need somewhere to
/// tap.
Sector testSector({
  String id = 'sector_vip',
  String name = 'SECTOR VIP PRIME',
  String tierLabel = 'Tier 1',
  int priceMinor = 39900,
  bool isLocked = false,
  String? lockReason,
  bool isContextOnly = false,
  List<SeatStatus> statuses = const [
    SeatStatus.available,
    SeatStatus.available,
    SeatStatus.sold,
  ],
}) {
  return Sector(
    id: id,
    name: name,
    tierLabel: tierLabel,
    priceMinor: priceMinor,
    currency: 'SAR',
    isLocked: isLocked,
    lockReason: lockReason,
    isContextOnly: isContextOnly,
    rows: [
      SeatRow(
        label: 'A',
        seats: [
          for (var i = 0; i < statuses.length; i++)
            Seat(
              id: '${id}_a_${i + 8}',
              row: 'A',
              number: (i + 8).toString().padLeft(2, '0'),
              status: statuses[i],
            ),
        ],
      ),
    ],
  );
}
