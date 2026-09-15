/// The order under review at checkout.
///
/// Assembled by the server when the hold is promoted to a payment window, not
/// by the client. Totals are quoted, never computed here: VAT rates, booking
/// fees and municipal charges are policy that changes without an app release,
/// and a client that added up its own total would eventually disagree with the
/// invoice the customer is charged.
class CheckoutOrder {
  const CheckoutOrder({
    required this.reference,
    required this.eventTitle,
    required this.venueLine,
    required this.startsAt,
    required this.timeZoneOffset,
    required this.seatLabel,
    required this.lineItems,
    required this.totalMinor,
    required this.currency,
    required this.expiresAt,
    this.vatRegistration,
    this.totalNote,
    this.gatewayNote,
  });

  /// Booking reference: `BR-003`.
  final String reference;

  final String eventTitle;

  /// "Maraya Concert Pavilion · AlUla, Saudi Arabia".
  final String venueLine;

  /// Event start, in UTC.
  final DateTime startsAt;

  /// The venue's offset, so the date renders in the venue's own time — the
  /// same rule the detail screen follows.
  final Duration timeZoneOffset;

  /// The reserved seat as printed: `VIP · Sector A · Row 12`.
  final String seatLabel;

  /// The breakdown, in the order the server wants it shown. A list rather than
  /// named fields, because which charges apply is jurisdictional: a market
  /// without a booking fee should send one fewer row, not a zero.
  final List<OrderLineItem> lineItems;

  /// The amount that will actually be charged, in minor units.
  final int totalMinor;
  final String currency;

  /// When the payment window closes, in UTC. Authoritative, exactly as
  /// [SeatHold.expiresAt] is — this screen renders the deadline, never
  /// computes one.
  final DateTime expiresAt;

  /// The seller's VAT registration number, shown beside the breakdown. A legal
  /// requirement on a tax invoice in this market, so it is carried rather than
  /// hard-coded.
  final String? vatRegistration;

  /// "Includes all municipal fees & VAT".
  final String? totalNote;

  /// The redirect notice: "Redirects to secure hosted payment gateway."
  final String? gatewayNote;

  /// Event start expressed in the venue's zone.
  DateTime get localStartsAt => startsAt.add(timeZoneOffset);

  /// Time left in the payment window, against a corrected clock.
  ///
  /// Clamped at zero for the same reason the seat hold is: a negative value
  /// would render as `-00:03` on a timer meant to reassure.
  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isExpired(DateTime now) => remaining(now) == Duration.zero;
}

/// One row of the price breakdown.
class OrderLineItem {
  const OrderLineItem({
    required this.label,
    required this.amountMinor,
    this.isTax = false,
  });

  /// As the server worded it: "VIP Prime Admission (1× Seat A-12)".
  ///
  /// Supplied already localized. The client cannot word these itself — it does
  /// not know the tier names, the seat, or the tax regime.
  final String label;

  final int amountMinor;

  /// Marks a tax row, in case a jurisdiction requires them set apart.
  final bool isTax;
}
