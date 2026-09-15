import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/features/tickets/data/platform_screen_capture_detector.dart';
import 'package:tazkerah/features/tickets/domain/screen_capture_detector.dart';

/// Reads one snapshot, defaulting everything the case does not care about.
List<ScreenCaptureEvent> read({
  bool screenshot = false,
  bool recording = false,
  bool wasRecording = false,
  int timestamp = 0,
}) {
  return CaptureSnapshotReader.read(
    wasScreenshotTaken: screenshot,
    isScreenRecording: recording,
    wasRecording: wasRecording,
    timestampMillis: timestamp,
  );
}

void main() {
  group('CaptureSnapshotReader', () {
    test('a quiet snapshot produces nothing', () {
      expect(read(), isEmpty);
    });

    test('a screenshot is reported', () {
      final events = read(screenshot: true);

      expect(events, hasLength(1));
      expect(events.single.kind, CaptureKind.screenshot);
    });

    test('a recording that has just started is reported', () {
      final events = read(recording: true);

      expect(events, hasLength(1));
      expect(events.single.kind, CaptureKind.recording);
    });

    test('a recording already under way is not reported again', () {
      // The rule this feature depends on: the plugin reports recording as a
      // state, so a level-triggered reader would invalidate a fresh code on
      // every tick and the pass would churn rotations for as long as the
      // recording ran.
      expect(read(recording: true, wasRecording: true), isEmpty);
    });

    test('a recording that has stopped is not a capture', () {
      expect(read(recording: false, wasRecording: true), isEmpty);
    });

    test('a second recording after one stopped is reported', () {
      // Having stopped, `wasRecording` is false again, so the next start is a
      // fresh edge.
      final events = read(recording: true, wasRecording: false);

      expect(events.single.kind, CaptureKind.recording);
    });

    test('a screenshot during a recording still reports the screenshot', () {
      final events = read(
        screenshot: true,
        recording: true,
        wasRecording: true,
      );

      expect(events, hasLength(1));
      expect(events.single.kind, CaptureKind.screenshot);
    });

    test('a screenshot as a recording starts reports both', () {
      final events = read(screenshot: true, recording: true);

      expect(
        events.map((e) => e.kind),
        containsAll(<CaptureKind>[
          CaptureKind.screenshot,
          CaptureKind.recording,
        ]),
      );
    });

    test('uses the platform timestamp when it has one', () {
      final at = DateTime(2026, 9, 15, 20, 30);
      final events = read(
        screenshot: true,
        timestamp: at.millisecondsSinceEpoch,
      );

      expect(events.single.at, at);
    });

    test('falls back to now when the platform gave no timing', () {
      // The plugin sends 0 rather than omitting the field, and an epoch
      // timestamp on screen would read as 1970.
      final before = DateTime.now();
      final events = read(screenshot: true);

      expect(
        events.single.at.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });
  });
}
