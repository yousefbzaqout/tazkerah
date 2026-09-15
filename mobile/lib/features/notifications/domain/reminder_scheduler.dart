import 'event_reminder.dart';

/// Schedules and cancels local notifications.
///
/// An interface for the same reason [SecureStorage] is one: the real
/// implementation needs a platform channel that `flutter_test` does not
/// provide. [FakeReminderScheduler] in `test/support` is what lets the
/// scheduling rules be tested at all.
///
/// **Delivery is local.** Nothing here contacts the backend — the ticket data
/// the app already holds is enough to decide when to fire, which is why this
/// feature works with no network and is not blocked on an API contract.
abstract interface class ReminderScheduler {
  /// Prepares the platform scheduler. Safe to call more than once.
  Future<void> initialize();

  /// Whether the user has granted permission to post notifications.
  ///
  /// Separate from [requestPermission] so the caller can check without
  /// prompting: asking at launch, before the user knows what the app is,
  /// is the reliable way to get a permanent refusal.
  Future<bool> hasPermission();

  /// Asks the user for permission, returning whether it was granted.
  ///
  /// On a second call after a refusal the platform may not show a prompt at
  /// all, so a `false` here can mean "declined just now" or "declined
  /// previously" — the caller must not treat it as a reason to ask again.
  Future<bool> requestPermission();

  /// Schedules [reminder], replacing any already scheduled with the same id.
  ///
  /// Replacement rather than addition is what makes rescheduling idempotent:
  /// the app reschedules on every launch, and appending would let a user
  /// accumulate duplicate reminders by opening the app repeatedly.
  Future<void> schedule(EventReminder reminder);

  /// Cancels one reminder by id. A no-op if it is not scheduled.
  Future<void> cancel(int id);

  /// Cancels every reminder this app scheduled.
  Future<void> cancelAll();

  /// The ids currently scheduled with the platform.
  ///
  /// Used to reconcile: the OS drops pending notifications on reboot and on
  /// reinstall, so what the app believes is scheduled and what actually is
  /// can differ.
  Future<Set<int>> pendingIds();
}
