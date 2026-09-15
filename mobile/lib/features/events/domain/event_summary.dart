/// One event as it appears in the discovery feed.
///
/// A *summary*, not the full event: the feed shows a card, and a card needs a
/// title, a venue line, a date range, cover art and a starting price. Anything
/// the detail screen needs and this does not carry — description, seat map,
/// ticket tiers — belongs to a separate entity fetched by id, so the list
/// endpoint is not forced to return a payload sized for the detail screen.
///
/// Plain Dart, per the architecture's `domain` rule: no Flutter import, no
/// wire format. Formatting decisions (how `DEC 14–16` is rendered, which
/// currency symbol is shown) belong to presentation, which knows the locale.
class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.venue,
    required this.city,
    required this.startsAt,
    this.endsAt,
    required this.priceFrom,
    required this.currency,
    this.imageUrl,
    this.soldOut = false,
  });

  /// Server identifier. Also the deep-link segment: `/events/{id}`.
  final String id;

  final String title;

  /// The named place: "Banban District", "Desert Pavilion".
  final String venue;

  /// The city it sits in. Kept separate from [venue] rather than pre-joined so
  /// the separator between them is a presentation choice — the design's
  /// "Banban District • Riyadh" is a bullet in both locales, but the *order*
  /// reverses under RTL, which a pre-joined string could not do.
  final String city;

  /// When the event opens, in UTC.
  ///
  /// UTC on purpose: an event's local day is a property of the venue's
  /// timezone, not the device's. Presentation converts once, at the edge.
  final DateTime startsAt;

  /// When it closes, for multi-day events. Null for single-day ones, which is
  /// what makes the design's `DEC 14–16` versus `JAN 08` distinction possible
  /// without a separate flag.
  final DateTime? endsAt;

  /// Lowest available ticket price, in [currency]'s major unit.
  ///
  /// The design labels this `FROM`, and it is the cheapest *available* tier —
  /// a sold-out cheaper tier must not be advertised here.
  final num priceFrom;

  /// ISO-4217 code: `SAR`. Carried rather than assumed so a second market
  /// does not require a schema change.
  final String currency;

  /// Cover art. Null is a normal case, not an error: the card falls back to a
  /// tinted placeholder rather than leaving a hole in the feed.
  final String? imageUrl;

  /// Whether every tier is gone. The card still renders — an event the user
  /// missed is information — but it reads as unavailable.
  final bool soldOut;

  /// Whether the event spans more than one calendar day in [timeZoneOffset].
  ///
  /// Drives the date chip's range-versus-single rendering. Compares calendar
  /// days rather than elapsed hours, because an event running 22:00–02:00 is
  /// two days by the calendar and one night to a human — and the design's
  /// chip follows the calendar.
  bool spansMultipleDays(Duration timeZoneOffset) {
    final end = endsAt;
    if (end == null) return false;
    final localStart = startsAt.add(timeZoneOffset);
    final localEnd = end.add(timeZoneOffset);
    return localStart.year != localEnd.year ||
        localStart.month != localEnd.month ||
        localStart.day != localEnd.day;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is EventSummary && other.id == id);

  /// Identity is the server id alone. Two payloads for the same event are the
  /// same event; a refreshed price does not make it a different row, which is
  /// what keeps list diffing and scroll position stable across a refresh.
  @override
  int get hashCode => id.hashCode;
}
