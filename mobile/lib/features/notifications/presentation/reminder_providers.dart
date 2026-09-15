import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/local_reminder_scheduler.dart';
import '../domain/event_reminder.dart';
import '../domain/reminder_scheduler.dart';
import '../domain/reminder_service.dart';

/// The platform scheduler.
///
/// Overridden with a fake in tests, which is the reason [ReminderScheduler] is
/// an interface: `flutter_local_notifications` needs a platform channel that
/// `flutter_test` does not provide.
///
/// It is built with a [Locale] rather than a `BuildContext` so it can be
/// constructed outside the widget tree — the copy is resolved here, once,
/// because the scheduler must not hold user-facing strings of its own.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final locale = ref.watch(reminderLocaleProvider);
  final l10n = lookupAppLocalizations(locale);

  return LocalReminderScheduler(
    channelName: l10n.notificationChannelRemindersName,
    channelDescription: l10n.notificationChannelRemindersDescription,
    titleForLead: (lead, eventTitle) => switch (lead) {
      ReminderLead.dayBefore => l10n.reminderDayBeforeTitle(eventTitle),
      ReminderLead.hoursBefore => l10n.reminderHoursBeforeTitle(eventTitle),
    },
    bodyFor: (localStart, venue) => l10n.reminderBody(
      // Formatted in the locale the notification will be read in, from a time
      // already shifted to the venue's zone by EventReminder.
      DateFormat.jm(locale.toLanguageTag()).format(localStart),
      venue,
    ),
  );
});

/// Which locale reminder copy is written in.
///
/// A notification is composed when it is *scheduled* but read up to a day
/// later, so it cannot follow a locale change the way a screen does: a
/// reminder already scheduled keeps the wording it was created with until the
/// next sync rewrites it.
///
/// Kept current by the app root, which is the only place that knows the
/// resolved locale. Defaults to the template locale so the scheduler is
/// constructible before the widget tree exists — in a test, or a background
/// isolate.
final reminderLocaleProvider = NotifierProvider<ReminderLocale, Locale>(
  ReminderLocale.new,
);

class ReminderLocale extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');

  void set(Locale locale) {
    if (state != locale) state = locale;
  }
}

/// Reconciles scheduled reminders against the wallet.
final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(scheduler: ref.watch(reminderSchedulerProvider));
});
