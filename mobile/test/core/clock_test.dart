import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/core/network/interceptors/clock_sync_interceptor.dart';
import 'package:tazkerah/core/utils/clock.dart';

void main() {
  group('AppClock', () {
    test('starts unsynced and reports its sync as stale', () {
      final clock = AppClock();

      expect(clock.offset, Duration.zero);
      expect(clock.syncedAt, isNull);
      // Never synced counts as stale: the ticket UI should warn rather than
      // imply the clock is trustworthy.
      expect(clock.isSyncStale, isTrue);
    });

    test('adopts the offset implied by server time', () {
      final clock = AppClock();
      final serverTime = DateTime.now().toUtc().add(const Duration(minutes: 5));

      clock.syncTo(serverTime);

      // Roughly five minutes ahead, allowing for execution time.
      expect(clock.offset.inSeconds, closeTo(300, 2));
      expect(clock.isSyncStale, isFalse);
    });

    test(
      'corrects `now` by the offset, so a wrong device clock is absorbed',
      () {
        final clock = AppClock();
        final serverTime = DateTime.now().toUtc().add(const Duration(hours: 2));

        clock.syncTo(serverTime);

        final corrected = clock.now;
        expect(
          corrected.difference(serverTime).inSeconds.abs(),
          lessThan(2),
          reason: 'corrected time should track the server, not the device',
        );
      },
    );

    test('handles a device clock set ahead of the server', () {
      // The attack shape: a user winds the clock forward to reach a future
      // rotation window. The offset must go negative and pull it back.
      final clock = AppClock();
      final serverTime = DateTime.now().toUtc().subtract(
        const Duration(hours: 6),
      );

      clock.syncTo(serverTime);

      expect(clock.offset.isNegative, isTrue);
      expect(clock.now.difference(serverTime).inSeconds.abs(), lessThan(2));
    });

    test(
      'restores a persisted offset so the first offline launch is corrected',
      () {
        final clock = AppClock();
        final syncedAt = DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        );

        clock.restore(offset: const Duration(seconds: 42), syncedAt: syncedAt);

        expect(clock.offset, const Duration(seconds: 42));
        expect(clock.isSyncStale, isFalse);
      },
    );

    test('treats an offset older than 48 hours as stale', () {
      final clock = AppClock();

      clock.restore(
        offset: Duration.zero,
        syncedAt: DateTime.now().toUtc().subtract(const Duration(hours: 49)),
      );

      expect(clock.isSyncStale, isTrue);
    });

    test(
      'elapsed advances monotonically and is not tied to wall time',
      () async {
        final clock = AppClock();
        final first = clock.elapsed;

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(clock.elapsed, greaterThan(first));
      },
    );
  });

  group('HttpDateParser', () {
    test('parses the IMF-fixdate format servers must send', () {
      final parsed = HttpDateParser.parse('Sun, 06 Nov 1994 08:49:37 GMT');

      expect(parsed, DateTime.utc(1994, 11, 6, 8, 49, 37));
      expect(parsed.isUtc, isTrue);
    });

    test('parses each month name', () {
      const months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };

      months.forEach((name, number) {
        final parsed = HttpDateParser.parse('Mon, 01 $name 2026 00:00:00 GMT');
        expect(parsed.month, number, reason: 'for $name');
      });
    });

    test('rejects formats it does not understand', () {
      const invalid = [
        '',
        'not a date',
        '2026-09-09T12:00:00Z', // ISO-8601, not IMF-fixdate
        'Sun, 06 Nov 1994 08:49:37', // missing GMT
        'Sun, 06 Xxx 1994 08:49:37 GMT', // unknown month
      ];

      for (final value in invalid) {
        expect(
          () => HttpDateParser.parse(value),
          throwsFormatException,
          reason: 'for "$value"',
        );
      }
    });
  });
}
