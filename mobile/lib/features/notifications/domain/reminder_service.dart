import '../../tickets/domain/ticket.dart';
import 'event_reminder.dart';
import 'reminder_planner.dart';
import 'reminder_scheduler.dart';

/// Keeps the device's scheduled reminders matching the wallet.
///
/// Reconciles rather than re-schedules: it compares what [ReminderPlanner]
/// says should exist against what the platform reports pending, then schedules
/// only what is missing and cancels only what is stale.
///
/// Reconciliation is the point. The naive alternative — cancel everything and
/// reschedule — is wrong in a way that is invisible in testing: cancelling a
/// notification the OS is about to deliver loses it, and the app syncs on
/// every launch, so a user who opens the app two hours before an event could
/// silently lose that reminder.
///
/// It also handles the two cases where the platform's state disappears without
/// the app being told:
///
/// - **reboot** — the OS clears the alarm queue. The Android boot receiver
///   restores most of it, but reconciling on launch covers what it misses and
///   is the only recovery on iOS;
/// - **reinstall** — nothing survives, and the first sync rebuilds everything.
class ReminderService {
  const ReminderService({required this.scheduler});

  final ReminderScheduler scheduler;

  /// Brings scheduled reminders in line with [tickets].
  ///
  /// Returns what is scheduled afterwards, which is what the tests assert on.
  ///
  /// Does nothing when permission is absent — scheduling into a revoked
  /// permission silently succeeds and delivers nothing, so the app would
  /// believe reminders are set when none can arrive.
  Future<List<EventReminder>> sync({
    required List<Ticket> tickets,
    required DateTime now,
  }) async {
    if (!await scheduler.hasPermission()) return const [];

    await scheduler.initialize();

    final wanted = ReminderPlanner.plan(tickets: tickets, now: now);
    final wantedIds = {for (final reminder in wanted) reminder.id};
    final pending = await scheduler.pendingIds();

    // Cancel what should no longer fire: a ticket that was used or refunded,
    // an event that has passed, or a reminder whose moment has gone by.
    for (final id in pending.difference(wantedIds)) {
      await scheduler.cancel(id);
    }

    // Schedule what is missing. Already-pending ids are left alone rather than
    // rewritten, so a reminder near delivery is never cancelled and recreated.
    for (final reminder in wanted) {
      if (pending.contains(reminder.id)) continue;
      await scheduler.schedule(reminder);
    }

    return wanted;
  }

  /// Drops every reminder for one ticket.
  ///
  /// Called when a ticket is used or refunded, so the reminder goes away at
  /// that moment rather than at the next sync — a "your event is tomorrow"
  /// arriving after a refund is a support ticket.
  Future<void> cancelForTicket(String ticketId) async {
    for (final lead in ReminderLead.values) {
      await scheduler.cancel(
        ReminderPlanner.reminderId(ticketId: ticketId, lead: lead),
      );
    }
  }

  /// Clears everything. Called on sign-out, alongside the credential wipe:
  /// reminders name events the signed-out user was attending, and leaving them
  /// on a handed-over device would leak that.
  Future<void> cancelAll() => scheduler.cancelAll();
}
