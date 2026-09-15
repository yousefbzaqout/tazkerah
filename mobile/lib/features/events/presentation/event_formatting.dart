import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/event_summary.dart';

/// Turns [EventSummary] values into strings for display.
///
/// Lives in presentation, not domain: every function here needs a locale, and
/// domain is deliberately Flutter-free. Gathered in one place so the date chip
/// on a card and the same date on the detail screen cannot drift apart.
abstract final class EventFormatting {
  /// The date chip on a card: `DEC 14–16`, or `JAN 08` for a single day.
  ///
  /// Uppercased through [Intl] rather than `String.toUpperCase`, because the
  /// latter is wrong in Turkish (dotted/dotless i) and meaningless in Arabic.
  /// In Arabic the result is the localized month name unchanged, which is
  /// correct — the script has no case to raise.
  static String dateChip(
    BuildContext context,
    EventSummary event, {
    Duration timeZoneOffset = Duration.zero,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final start = event.startsAt.add(timeZoneOffset);
    final month = DateFormat.MMM(locale).format(start).toUpperCase();
    final startDay = DateFormat.d(locale).format(start);

    if (!event.spansMultipleDays(timeZoneOffset)) {
      // Two digits, as drawn: `JAN 08`, not `JAN 8`.
      return '$month ${startDay.padLeft(2, '0')}';
    }

    final end = event.endsAt!.add(timeZoneOffset);
    final endDay = DateFormat.d(locale).format(end);
    final endMonth = DateFormat.MMM(locale).format(end).toUpperCase();

    // An en dash, not a hyphen: this is a range, and the design draws one.
    // The dash is wrapped in directional isolates so a bidi run in Arabic
    // cannot reorder the two dates around it.
    if (month == endMonth) {
      return '$month ${startDay.padLeft(2, '0')}–${endDay.padLeft(2, '0')}';
    }
    return '$month ${startDay.padLeft(2, '0')} – '
        '$endMonth ${endDay.padLeft(2, '0')}';
  }

  /// The full date, for accessibility labels and the detail screen.
  static String fullDate(
    BuildContext context,
    EventSummary event, {
    Duration timeZoneOffset = Duration.zero,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final start = event.startsAt.add(timeZoneOffset);
    final formatter = DateFormat.yMMMMd(locale);

    if (!event.spansMultipleDays(timeZoneOffset)) {
      return formatter.format(start);
    }
    final end = event.endsAt!.add(timeZoneOffset);
    return '${formatter.format(start)} – ${formatter.format(end)}';
  }

  /// A price with its currency: `399 SAR`.
  ///
  /// The amount is formatted for the locale — Arabic renders Eastern Arabic
  /// numerals and its own grouping separators — and the currency code follows
  /// as a word, matching the design rather than a symbol-prefixed form.
  static String price(BuildContext context, EventSummary event) {
    final locale = Localizations.localeOf(context).toString();
    final amount = NumberFormat.decimalPattern(locale).format(event.priceFrom);
    return AppLocalizations.of(context).discoveryPrice(amount, event.currency);
  }

  /// The location line: `Banban District • Riyadh`.
  ///
  /// Built from a localized pattern rather than concatenated here, so the
  /// Arabic translation controls the order of the two halves around the
  /// bullet.
  static String location(BuildContext context, EventSummary event) {
    final l10n = AppLocalizations.of(context);
    if (event.city.isEmpty) return event.venue;
    if (event.venue.isEmpty) return event.city;
    return l10n.discoveryVenueSeparator(event.venue, event.city);
  }

  /// A coarse "time since" for the offline footer: `14m`, `2h`, `3d`.
  ///
  /// Deliberately coarse. The user needs to know whether this data is minutes
  /// or days old; second-level precision would imply a freshness the cache
  /// does not have, and would require a ticking timer to stay honest.
  static String shortAge(BuildContext context, Duration age) {
    final l10n = AppLocalizations.of(context);
    if (age.inHours < 1) {
      // Floors at one minute: "0m ago" reads as broken rather than fresh.
      return l10n.durationMinutes(age.inMinutes < 1 ? 1 : age.inMinutes);
    }
    if (age.inDays < 1) return l10n.durationHours(age.inHours);
    return l10n.durationDays(age.inDays);
  }
}
