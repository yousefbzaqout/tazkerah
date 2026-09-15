import 'event_summary.dart';

/// One event, in the depth the detail screen needs.
///
/// Separate from [EventSummary] rather than an extension of it, because the two
/// come from different endpoints and the list payload must not be forced to
/// carry an overview paragraph and a gates time for every row it returns.
///
/// It *contains* a summary rather than duplicating its fields: the detail screen
/// shows the same title, venue, date and price the card did, and two copies of
/// those would be two things to keep in step.
///
/// Plain Dart, per the architecture's `domain` rule — no Flutter import, no wire
/// format. How `20:30 AST (Gates 19:00)` is rendered is presentation's problem.
class EventDetail {
  const EventDetail({
    required this.summary,
    required this.subtitle,
    required this.overview,
    required this.venueAddress,
    this.doorsOpenAt,
    this.timeZoneAbbreviation = '',
    this.timeZoneOffset = Duration.zero,
    this.availability = TicketAvailability.available,
    this.tierLabel,
    this.heroImageUrl,
    this.securityNote,
    this.antiPassbackEnabled = true,
  });

  /// The fields the card already showed. Identity, title, venue, date, price.
  final EventSummary summary;

  /// The line under the title: "AlUla Desert Pavilion • Exclusive Concert
  /// Series". A single string, not a composed pair — unlike the card's venue
  /// line, its two halves are editorial rather than structured, and the
  /// backend owns the wording.
  final String subtitle;

  /// The OVERVIEW paragraph.
  final String overview;

  /// The postal-ish location shown in the location card: "Ashar Valley" over
  /// "AlUla, Saudi Arabia".
  final String venueAddress;

  /// When gates open, if earlier than the start. Null when there is no
  /// separate admission time, which is what lets the design's
  /// "(Gates 19:00)" suffix appear only when it means something.
  final DateTime? doorsOpenAt;

  /// The venue's timezone label, as the design prints it: `AST`.
  ///
  /// Carried as a string rather than derived from an offset, because an
  /// abbreviation is a political and regional fact, not an arithmetic one —
  /// the same +03:00 is AST in Riyadh and MSK in Moscow.
  final String timeZoneAbbreviation;

  /// The venue's offset from UTC. Times are stored in UTC and rendered in the
  /// *venue's* zone, not the device's: an event's start time is a property of
  /// where it happens, and a traveller reading "20:30" must see the time they
  /// will walk through the gate, not that time shifted into another zone.
  final Duration timeZoneOffset;

  final TicketAvailability availability;

  /// The status beside the pill: "Tier 1 Selling Fast". Supplied already
  /// worded by the backend, because which tier is selling and how fast is
  /// inventory state this app does not compute.
  final String? tierLabel;

  /// Full-bleed hero art. Falls back to the summary's card image, then to a
  /// placeholder — the screen must render with no artwork at all.
  final String? heroImageUrl;

  /// The assurance row's headline: "Encrypted Dynamic QR Ticket". Null hides
  /// the row rather than inventing a security claim, which is the one kind of
  /// copy this app must never make up.
  final String? securityNote;

  /// Whether the pass is bound against re-entry sharing.
  final bool antiPassbackEnabled;

  String get id => summary.id;
  String get title => summary.title;

  /// The start time expressed in the venue's zone, ready to format.
  DateTime get localStartsAt => summary.startsAt.add(timeZoneOffset);

  /// Gates time in the venue's zone, or null when there is none.
  DateTime? get localDoorsOpenAt => doorsOpenAt?.add(timeZoneOffset);

  /// Whether seat selection should be offered at all.
  ///
  /// Both on-sale states qualify. `sellingFast` is a *marketing* signal about
  /// remaining inventory, not a restriction — an event that is nearly gone is
  /// precisely the one a user most needs to be able to buy — so only a genuine
  /// absence of purchasable tickets closes the flow.
  bool get canSelectSeats =>
      availability == TicketAvailability.available ||
      availability == TicketAvailability.sellingFast;
}

/// What the inventory allows right now.
///
/// Drives both the status line and whether the bottom bar's action is live, so
/// a sold-out event cannot present a working "Select seats" button.
enum TicketAvailability {
  /// On sale.
  available,

  /// On sale, but nearly gone — the design's "Selling Fast" treatment.
  sellingFast,

  /// Nothing left.
  soldOut,

  /// Not yet open. The date is announced; the tiers are not.
  notYetOnSale,
}
