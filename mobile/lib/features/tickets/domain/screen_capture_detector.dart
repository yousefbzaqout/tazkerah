/// Reports screen captures while a gate pass is on screen.
///
/// An interface because real detection is platform work that does not exist
/// yet, and because it must be fakeable: the intercepted frame is one of the
/// two designed states, and a test that could only reach it by taking an
/// actual screenshot would never run.
///
/// **What a real implementation can and cannot do**, which matters for how
/// much this screen should promise:
///
/// - **iOS** posts `userDidTakeScreenshot` *after* the capture, and
///   `isCaptured` reports screen recording and mirroring. So a screenshot is
///   detected, never prevented — the response is to invalidate the captured
///   code, not to stop the capture.
/// - **Android** can set `FLAG_SECURE`, which genuinely blocks screenshots and
///   blanks the window in the recents list, plus a detection callback on
///   API 34+.
///
/// The asymmetry is why the product response is rotation rather than blocking:
/// a design that relied on prevention would be honest on one platform and
/// false on the other.
abstract interface class ScreenCaptureDetector {
  /// Fires whenever a capture is detected while listening.
  Stream<ScreenCaptureEvent> get events;

  /// Begins watching. Called when a pass is shown.
  Future<void> start();

  /// Stops watching. Called when the pass leaves the screen, so the detector
  /// is not running for the life of the app.
  Future<void> stop();
}

/// One detected capture.
class ScreenCaptureEvent {
  const ScreenCaptureEvent({required this.at, this.kind = CaptureKind.unknown});

  final DateTime at;
  final CaptureKind kind;
}

enum CaptureKind {
  screenshot,

  /// Recording or mirroring — continuous, so the pass stays withheld rather
  /// than rotating once.
  recording,

  unknown,
}

/// A detector that never fires.
///
/// Bound until the platform implementation exists. Deliberately inert rather
/// than simulated: a stub that invented captures would make the intercepted
/// state appear at random on a real device, and one that silently claimed to
/// be watching would be worse — it would let the app display "ANTI-SCREENSHOT
/// WATERMARKED" while nothing was actually monitoring.
class NoopScreenCaptureDetector implements ScreenCaptureDetector {
  const NoopScreenCaptureDetector();

  @override
  Stream<ScreenCaptureEvent> get events => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
