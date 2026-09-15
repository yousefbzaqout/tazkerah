import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/features/notifications/domain/event_reminder.dart';
import 'package:tazkerah/features/notifications/domain/reminder_planner.dart';
import 'package:tazkerah/features/notifications/domain/reminder_service.dart';
import 'package:tazkerah/features/tickets/domain/ticket.dart';

import '../support/fake_reminder_scheduler.dart';

/// Fixed so every expectation below is arithmetic rather than relative to the
/// machine's clock.
final DateTime now = DateTime.utc(2026, 9, 15, 12);

Ticket ticket({
  String id = 'TK-001',
  DateTime? startsAt,
  TicketStatus status = TicketStatus.valid,
  Duration timeZoneOffset = const Duration(hours: 3),
}) {
  return Ticket(
    id: id,
    orderReference: 'BR-001',
    eventId: 'EV-001',
    eventTitle: 'Desert Sessions',
    venueName: 'Al Bidda Hall',
    startsAt: startsAt ?? now.add(const Duration(days: 3)),
    timeZoneOffset: timeZoneOffset,
    seatLabel: 'A-12',
    zoneLabel: 'VIP',
    status: status,
    totalMinor: 25000,
    currency: 'QAR',
  );
}

void main() {
  group('ReminderPlanner', () {
    test('plans both leads for a valid future ticket', () {
      final plan = ReminderPlanner.plan(tickets: [ticket()], now: now);

      expect(plan, hasLength(2));
      expect(
        plan.map((r) => r.lead),
        containsAll(<ReminderLead>[
          ReminderLead.dayBefore,
          ReminderLead.hoursBefore,
        ]),
      );
    });

    test('fires each lead exactly its offset before the event', () {
      final start = now.add(const Duration(days: 3));
      final plan = ReminderPlanner.plan(
        tickets: [ticket(startsAt: start)],
        now: now,
      );

      final dayBefore = plan.firstWhere(
        (r) => r.lead == ReminderLead.dayBefore,
      );
      final hoursBefore = plan.firstWhere(
        (r) => r.lead == ReminderLead.hoursBefore,
      );

      expect(dayBefore.fireAt, start.subtract(const Duration(hours: 24)));
      expect(hoursBefore.fireAt, start.subtract(const Duration(hours: 2)));
    });

    test('skips a lead whose moment has already passed', () {
      // 90 minutes out: the 24h reminder is long gone, the 2h one has passed
      // too. Scheduling either would fire immediately or be rejected.
      final plan = ReminderPlanner.plan(
        tickets: [ticket(startsAt: now.add(const Duration(minutes: 90)))],
        now: now,
      );

      expect(plan, isEmpty);
    });

    test('keeps only the lead still ahead when the event is within a day', () {
      final plan = ReminderPlanner.plan(
        tickets: [ticket(startsAt: now.add(const Duration(hours: 5)))],
        now: now,
      );

      expect(plan, hasLength(1));
      expect(plan.single.lead, ReminderLead.hoursBefore);
    });

    test('a reminder due exactly now is not scheduled', () {
      // Boundary: no lead time left to be useful, and it races the platform's
      // own dispatch.
      final plan = ReminderPlanner.plan(
        tickets: [ticket(startsAt: now.add(const Duration(hours: 2)))],
        now: now,
      );

      expect(plan.where((r) => r.lead == ReminderLead.hoursBefore), isEmpty);
    });

    test('ignores every ticket that is not valid', () {
      final plan = ReminderPlanner.plan(
        tickets: [
          ticket(id: 'TK-used', status: TicketStatus.used),
          ticket(id: 'TK-refunded', status: TicketStatus.refunded),
          ticket(id: 'TK-expired', status: TicketStatus.expired),
        ],
        now: now,
      );

      expect(plan, isEmpty);
    });

    test('ids are stable across runs, so rescheduling cannot duplicate', () {
      final first = ReminderPlanner.plan(tickets: [ticket()], now: now);
      final second = ReminderPlanner.plan(tickets: [ticket()], now: now);

      expect(
        first.map((r) => r.id).toList(),
        second.map((r) => r.id).toList(),
      );
    });

    test('a ticket\'s two leads do not collide', () {
      final plan = ReminderPlanner.plan(tickets: [ticket()], now: now);
      expect(plan.map((r) => r.id).toSet(), hasLength(2));
    });

    test('different tickets do not collide', () {
      final plan = ReminderPlanner.plan(
        tickets: [ticket(id: 'TK-001'), ticket(id: 'TK-002')],
        now: now,
      );

      expect(plan.map((r) => r.id).toSet(), hasLength(4));
    });

    test('ids are non-negative, which Android requires', () {
      for (final id in ['TK-001', 'a', 'ticket-with-a-much-longer-id', '9']) {
        for (final lead in ReminderLead.values) {
          expect(
            ReminderPlanner.reminderId(ticketId: id, lead: lead),
            greaterThanOrEqualTo(0),
          );
        }
      }
    });

    test('soonest first, so a truncated plan keeps the most urgent', () {
      final plan = ReminderPlanner.plan(
        tickets: [
          ticket(id: 'far', startsAt: now.add(const Duration(days: 30))),
          ticket(id: 'near', startsAt: now.add(const Duration(days: 2))),
        ],
        now: now,
      );

      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].fireAt.isBefore(plan[i - 1].fireAt), isFalse);
      }
    });

    test('carries the venue offset rather than the device zone', () {
      final start = DateTime.utc(2026, 9, 20, 17);
      final plan = ReminderPlanner.plan(
        tickets: [
          ticket(startsAt: start, timeZoneOffset: const Duration(hours: 3)),
        ],
        now: now,
      );

      // 17:00 UTC is 20:00 at an AST venue. A traveller must read the time
      // they will walk through the gate.
      expect(plan.first.localEventStartsAt, DateTime.utc(2026, 9, 20, 20));
    });
  });

  group('ReminderService', () {
    test('schedules the planned reminders', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(scheduler: scheduler);

      await service.sync(tickets: [ticket()], now: now);

      expect(scheduler.scheduled, hasLength(2));
    });

    test('schedules nothing without permission', () async {
      final scheduler = FakeReminderScheduler(permitted: false);
      final service = ReminderService(scheduler: scheduler);

      final result = await service.sync(tickets: [ticket()], now: now);

      // Scheduling into a revoked permission succeeds silently and delivers
      // nothing, which would leave the app believing reminders are set.
      expect(result, isEmpty);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.scheduleCalls, isEmpty);
    });

    test('a second sync leaves existing reminders untouched', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(scheduler: scheduler);

      await service.sync(tickets: [ticket()], now: now);
      final afterFirst = List.of(scheduler.scheduleCalls);
      await service.sync(tickets: [ticket()], now: now);

      // The important assertion in this feature: re-scheduling would cancel a
      // notification the OS may be about to deliver, losing it.
      expect(scheduler.scheduleCalls, afterFirst);
      expect(scheduler.cancelledIds, isEmpty);
    });

    test('cancels reminders for a ticket that has been used', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(scheduler: scheduler);

      await service.sync(tickets: [ticket()], now: now);
      expect(scheduler.scheduled, hasLength(2));

      await service.sync(
        tickets: [ticket(status: TicketStatus.used)],
        now: now,
      );

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelledIds, hasLength(2));
    });

    test('cancels reminders for a ticket that disappeared', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(scheduler: scheduler);

      await service.sync(
        tickets: [ticket(id: 'TK-001'), ticket(id: 'TK-002')],
        now: now,
      );
      expect(scheduler.scheduled, hasLength(4));

      await service.sync(tickets: [ticket(id: 'TK-001')], now: now);

      expect(scheduler.scheduled, hasLength(2));
      expect(
        scheduler.scheduled.values.every((r) => r.ticketId == 'TK-001'),
        isTrue,
      );
    });

    test('reschedules everything after the platform loses its queue', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(scheduler: scheduler);

      await service.sync(tickets: [ticket()], now: now);

      // What a reboot or reinstall looks like: the app still holds the wallet,
      // the OS has dropped the alarms.
      scheduler.scheduled.clear();

      await service.sync(tickets: [ticket()], now: now);

      expect(scheduler.scheduled, hasLength(2));
    });

    test('drops a lead that has passed between syncs', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(scheduler: scheduler);
      final start = now.add(const Duration(days: 2));

      await service.sync(tickets: [ticket(startsAt: start)], now: now);
      expect(scheduler.scheduled, hasLength(2));

      // A day later the 24h reminder has already fired.
      await service.sync(
        tickets: [ticket(startsAt: start)],
        now: now.add(const Duration(days: 1, hours: 1)),
      );

      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.values.single.lead, ReminderLead.hoursBefore);
    });

    test('cancelForTicket clears both leads', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(scheduler: scheduler);

      await service.sync(tickets: [ticket()], now: now);
      await service.cancelForTicket('TK-001');

      expect(scheduler.scheduled, isEmpty);
    });

    test('cancelAll clears everything, as sign-out requires', () async {
      final scheduler = FakeReminderScheduler();
      final service = ReminderService(scheduler: scheduler);

      await service.sync(
        tickets: [ticket(id: 'TK-001'), ticket(id: 'TK-002')],
        now: now,
      );
      await service.cancelAll();

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelAllCount, 1);
    });
  });
}
