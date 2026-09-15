import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/event_reminder.dart';
import '../domain/reminder_scheduler.dart';

/// The platform-backed [ReminderScheduler].
///
/// The only place in the feature that knows a notification plugin exists.
/// Everything above it works in [EventReminder]s, which is what lets the
/// scheduling rules be tested without a platform channel.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    required this.channelName,
    required this.channelDescription,
    required this.titleForLead,
    required this.bodyFor,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Channel copy, passed in already localized.
  ///
  /// The channel is created here but its text comes from ARB like every other
  /// user-facing string — this layer must not hold copy of its own. Note that
  /// Android keeps the name it first saw: a user who changes language will see
  /// the original until the app is reinstalled, because renaming a live
  /// channel is not something the platform supports.
  final String channelName;
  final String channelDescription;

  /// Builds a localized title for a lead time, and a body from the event's
  /// local start and venue. Passed as functions so this class needs no
  /// `BuildContext` and stays constructible in a background isolate.
  final String Function(ReminderLead lead, String eventTitle) titleForLead;
  final String Function(DateTime localStart, String venue) bodyFor;

  static const String _channelId = 'event_reminders';

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // Loads the IANA database. Required before any TZDateTime is constructed,
    // and cheap enough to do unconditionally at startup.
    tz_data.initializeTimeZones();

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested later, when the wallet first holds a ticket
        // — not here. A prompt at launch, before the user knows what the app
        // is, is the reliable way to earn a permanent refusal.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  @override
  Future<bool> hasPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    // iOS has no "check without prompting" API in this plugin, so an
    // unprompted check cannot be answered honestly. Reporting false would make
    // the caller prompt again on every launch; the caller records its own
    // "asked already" state instead.
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return false;
  }

  @override
  Future<void> schedule(EventReminder reminder) async {
    await initialize();

    await _plugin.zonedSchedule(
      reminder.id,
      titleForLead(reminder.lead, reminder.eventTitle),
      bodyFor(reminder.localEventStartsAt, reminder.venueName),
      _venueTime(reminder),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Inexact is deliberate. Exact alarms need SCHEDULE_EXACT_ALARM, which
      // Play restricts to apps whose core function is alarms — a ticketing app
      // would not qualify. A reminder that lands a few minutes late still does
      // its job, and this keeps the app off a permission it cannot justify.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.ticketId,
    );
  }

  /// The fire time as a zoned value the plugin will accept.
  ///
  /// Built from a fixed offset rather than a named zone: a ticket carries the
  /// venue's offset, not its IANA name, so the offset is what can be honoured.
  /// The consequence is that a DST transition between scheduling and firing
  /// would shift the reminder by an hour — acceptable for a reminder, and the
  /// alternative would be inventing a zone name the backend never sent.
  tz.TZDateTime _venueTime(EventReminder reminder) {
    final location = tz.getLocation('UTC');
    return tz.TZDateTime.from(reminder.fireAt, location);
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toSet();
  }
}
