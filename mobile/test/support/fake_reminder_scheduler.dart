import 'package:tazkerah/features/notifications/domain/event_reminder.dart';
import 'package:tazkerah/features/notifications/domain/reminder_scheduler.dart';

/// An in-memory [ReminderScheduler].
///
/// The reason [ReminderScheduler] is an interface: the real one needs a
/// platform channel `flutter_test` does not provide. It records calls rather
/// than only final state, so a test can assert that a reminder near delivery
/// was *left alone* instead of being cancelled and recreated.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.permitted = true});

  /// Whether permission is granted. False exercises the path where scheduling
  /// would silently deliver nothing.
  bool permitted;

  /// Currently scheduled, by id.
  final Map<int, EventReminder> scheduled = {};

  /// Every schedule call in order, including repeats of the same id.
  final List<EventReminder> scheduleCalls = [];

  /// Every cancelled id in order.
  final List<int> cancelledIds = [];

  int initializeCount = 0;
  int permissionRequests = 0;
  int cancelAllCount = 0;

  @override
  Future<void> initialize() async => initializeCount++;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permitted;
  }

  @override
  Future<void> schedule(EventReminder reminder) async {
    scheduleCalls.add(reminder);
    scheduled[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    cancelledIds.addAll(scheduled.keys);
    scheduled.clear();
  }

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();
}
