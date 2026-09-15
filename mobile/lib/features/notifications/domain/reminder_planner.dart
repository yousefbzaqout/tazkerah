import '../../tickets/domain/ticket.dart';
import 'event_reminder.dart';

/// Decides which reminders a wallet should have scheduled.
///
/// Pure: it takes tickets and a clock reading and returns a plan. No platform
/// channel, no storage, no side effects — which is what lets every rule below
/// be tested directly rather than through a scheduler fake.
///
/// The rules it enforces:
///
/// - only a **valid** ticket earns reminders. A used ticket's event is behind
///   the holder, and a cancelled one's entry will not be granted, so both
///   would be reminding someone to attend something they cannot;
/// - a reminder whose moment has **already passed** is never scheduled. The
///   platform would either fire it immediately or reject it, and a "your event
///   starts in 2 hours" arriving after the doors closed is worse than silence;
/// - **duplicate ids are impossible** by construction, because an id is
///   derived from the ticket id and the lead rather than generated.
abstract final class ReminderPlanner {
  /// The reminders that should be scheduled for [tickets], given the time is
  /// [now].
  ///
  /// [now] is passed in rather than read from a clock so the caller decides
  /// which clock applies — in practice `AppClock`, since the device clock is
  /// user-controlled and a shifted one would silently move every reminder.
  static List<EventReminder> plan({
    required List<Ticket> tickets,
    required DateTime now,
  }) {
    final reminders = <EventReminder>[];

    for (final ticket in tickets) {
      if (ticket.status != TicketStatus.valid) continue;

      for (final lead in ReminderLead.values) {
        final fireAt = ticket.startsAt.subtract(lead.offset);

        // Strictly after: a reminder due this instant has no lead time left to
        // be useful, and scheduling it races the platform's own dispatch.
        if (!fireAt.isAfter(now)) continue;

        reminders.add(
          EventReminder(
            id: reminderId(ticketId: ticket.id, lead: lead),
            ticketId: ticket.id,
            eventTitle: ticket.eventTitle,
            venueName: ticket.venueName,
            lead: lead,
            fireAt: fireAt,
            eventStartsAt: ticket.startsAt,
            timeZoneOffset: ticket.timeZoneOffset,
          ),
        );
      }
    }

    // Soonest first. The platform imposes its own limits on how many
    // notifications an app may have pending (iOS allows 64), so if a plan ever
    // has to be truncated, the reminders nearest to firing are the ones worth
    // keeping.
    reminders.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return reminders;
  }

  /// A stable notification id for a ticket and lead.
  ///
  /// Stable so that rescheduling replaces rather than duplicates, and derived
  /// rather than stored so no id registry has to be kept in sync with the
  /// wallet.
  ///
  /// Ticket ids are strings (`TK-001`, or a server uuid) and the platform
  /// wants a 32-bit int, so the id is hashed. The lead is mixed in so a
  /// ticket's two reminders cannot collide with each other, and the result is
  /// masked to 31 bits because Android rejects a negative id.
  static int reminderId({required String ticketId, required ReminderLead lead}) {
    return Object.hash(ticketId, lead.index) & 0x7fffffff;
  }
}
