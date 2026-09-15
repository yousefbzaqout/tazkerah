/// A reminder to be delivered before an event starts.
///
/// Plain Dart, like everything in `domain`: the scheduler that delivers these
/// needs a platform channel, but deciding *what* to schedule does not, so that
/// decision stays testable without a widget binding.
class EventReminder {
  const EventReminder({
    required this.id,
    required this.ticketId,
    required this.eventTitle,
    required this.venueName,
    required this.lead,
    required this.fireAt,
    required this.eventStartsAt,
    required this.timeZoneOffset,
  });

  /// Stable across reschedules.
  ///
  /// Derived from the ticket and the lead time rather than generated, so
  /// rescheduling the same reminder replaces it instead of adding a duplicate.
  /// The platform keys pending notifications by id, and a random id would let
  /// a user collect several copies of the same reminder by reopening the app.
  final int id;

  /// The ticket this belongs to, so it can be cancelled when that ticket is
  /// refunded or used.
  final String ticketId;

  final String eventTitle;
  final String venueName;

  /// How far before the event this fires.
  final ReminderLead lead;

  /// When to deliver, in UTC.
  ///
  /// UTC because the scheduler converts to the venue's zone at the boundary.
  /// Holding a local time here would make the value ambiguous the moment a
  /// user crosses a timezone.
  final DateTime fireAt;

  /// Event start in UTC, carried so the notification body can state the time.
  final DateTime eventStartsAt;

  /// The venue's offset from UTC.
  ///
  /// An event's start time is a property of *where it happens*: someone who
  /// flies in the night before must read the time they will walk through the
  /// gate, not the time on a phone that has re-homed to a new zone.
  final Duration timeZoneOffset;

  /// Event start expressed in the venue's zone.
  DateTime get localEventStartsAt => eventStartsAt.add(timeZoneOffset);

  @override
  bool operator ==(Object other) =>
      other is EventReminder &&
      other.id == id &&
      other.ticketId == ticketId &&
      other.fireAt == fireAt;

  @override
  int get hashCode => Object.hash(id, ticketId, fireAt);

  @override
  String toString() =>
      'EventReminder($id, $ticketId, ${lead.name}, fires $fireAt)';
}

/// How far ahead of an event a reminder fires.
///
/// Two leads, both from the specification: a day out, when travel and
/// childcare can still be arranged, and two hours out, when it is time to
/// leave. They are an enum rather than raw [Duration]s so the notification
/// copy can differ — "tomorrow" and "in two hours" are not the same message —
/// and so the id derivation has a small, closed set to work with.
enum ReminderLead {
  dayBefore(Duration(hours: 24)),
  hoursBefore(Duration(hours: 2));

  const ReminderLead(this.offset);

  /// How far before the event start this fires.
  final Duration offset;
}
