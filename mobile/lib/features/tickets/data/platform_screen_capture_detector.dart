import 'dart:async';
import 'dart:io';

import 'package:no_screenshot/no_screenshot.dart';
import 'package:no_screenshot/screenshot_snapshot.dart';

import '../domain/screen_capture_detector.dart';

/// The platform-backed [ScreenCaptureDetector].
///
/// The two platforms are not symmetric, and this class does not pretend
/// otherwise:
///
/// - **Android** blocks screenshots outright with `FLAG_SECURE`, and blanks the
///   window in the recents list. A blocked capture is not reported, so on
///   Android this mostly prevents rather than detects.
/// - **iOS** cannot block a screenshot. It reports one after the fact, and
///   reports screen recording and mirroring while they run. So on iOS this
///   detector actually emits, and the pass responds by invalidating the
///   captured rotation.
///
/// That asymmetry is why the product response is rotation rather than
/// prevention: a design that relied on blocking would be honest on Android and
/// false on iOS. The app promises only what it can deliver on both.
class PlatformScreenCaptureDetector implements ScreenCaptureDetector {
  PlatformScreenCaptureDetector({NoScreenshot? plugin})
    : _plugin = plugin ?? NoScreenshot.instance;

  final NoScreenshot _plugin;

  final StreamController<ScreenCaptureEvent> _controller =
      StreamController<ScreenCaptureEvent>.broadcast();

  StreamSubscription<ScreenshotSnapshot>? _subscription;
  bool _listening = false;

  /// Whether a recording was already in progress at the last snapshot.
  ///
  /// The stream reports recording as a *state*, not an edge, so without this
  /// every snapshot during a recording would raise a fresh capture and the
  /// pass would churn through rotations for as long as it ran.
  bool _recording = false;

  @override
  Stream<ScreenCaptureEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    if (_listening) return;
    _listening = true;

    // FLAG_SECURE on Android; a no-op on iOS, where nothing can block a
    // capture. Called on both rather than branched, because the plugin already
    // reports what each platform could do.
    await _plugin.screenshotOff();

    _subscription = _plugin.screenshotStream.listen(_onSnapshot);
    await _plugin.startScreenshotListening();
    await _plugin.startScreenRecordingListening();
  }

  void _onSnapshot(ScreenshotSnapshot snapshot) {
    if (_controller.isClosed) return;

    final events = CaptureSnapshotReader.read(
      wasScreenshotTaken: snapshot.wasScreenshotTaken,
      isScreenRecording: snapshot.isScreenRecording,
      wasRecording: _recording,
      timestampMillis: snapshot.timestamp,
    );

    _recording = snapshot.isScreenRecording;
    events.forEach(_controller.add);
  }

  @override
  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    _recording = false;

    await _subscription?.cancel();
    _subscription = null;

    await _plugin.stopScreenshotListening();
    await _plugin.stopScreenRecordingListening();

    // Lifted when the pass leaves the screen. Leaving FLAG_SECURE on for the
    // life of the app would also block screenshots of screens with nothing to
    // protect — an event listing, a receipt — which users reasonably expect to
    // be able to capture.
    await _plugin.screenshotOn();
  }

  /// Releases the stream. Called when the provider is disposed.
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}

/// Turns one plugin snapshot into the capture events it represents.
///
/// Extracted from [PlatformScreenCaptureDetector] so the rules can be tested
/// without a method channel: `NoScreenshot` is a singleton with a private
/// constructor, so the detector itself cannot be handed a fake.
abstract final class CaptureSnapshotReader {
  static List<ScreenCaptureEvent> read({
    required bool wasScreenshotTaken,
    required bool isScreenRecording,
    required bool wasRecording,
    required int timestampMillis,
  }) {
    // The plugin sends 0 when the platform gave it no timing. The device clock
    // is acceptable either way: this timestamp is for display and ordering,
    // never for validating a code.
    final at = timestampMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(timestampMillis)
        : DateTime.now();

    return [
      if (wasScreenshotTaken)
        ScreenCaptureEvent(at: at, kind: CaptureKind.screenshot),
      // Edge-triggered. The stream reports recording as a *state*, so without
      // comparing against the previous snapshot every tick during a recording
      // would raise a fresh capture and the pass would churn through rotations
      // for as long as it ran.
      if (isScreenRecording && !wasRecording)
        ScreenCaptureEvent(at: at, kind: CaptureKind.recording),
    ];
  }
}

/// Whether this platform has a capture implementation.
///
/// The plugin declares desktop and web support, but the gate pass is a
/// phone screen and the guarantees differ per platform; binding the real
/// detector only where it was designed to run keeps that honest.
bool get supportsScreenCaptureDetection => Platform.isAndroid || Platform.isIOS;
