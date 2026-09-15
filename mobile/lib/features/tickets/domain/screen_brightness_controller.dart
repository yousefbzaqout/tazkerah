/// Raises and restores screen brightness while a pass is presented.
///
/// An interface for the same reason the other platform-backed types are: the
/// real one needs a method channel `flutter_test` does not provide, and the
/// gate pass screen is covered by widget tests.
///
/// **Application-scoped, never system-scoped.** Raising the device's own
/// brightness setting would outlive the app and leave the user's phone changed
/// after they walked through the gate. The platforms both offer a per-app
/// override that lapses when the app is backgrounded, which is the correct
/// scope for "make this one screen readable".
abstract interface class ScreenBrightnessController {
  /// Raises brightness for the pass. Safe to call when already boosted.
  Future<void> boost();

  /// Returns brightness to whatever the system was doing.
  ///
  /// Called when the pass leaves the screen. Holding full brightness after
  /// that would drain a battery the holder may still need to present a ticket
  /// later in the evening.
  Future<void> restore();
}

/// A controller that does nothing.
///
/// Bound where there is no platform to talk to — tests, and any target the
/// plugin does not cover. Inert rather than simulated: brightness has no
/// observable state in a widget test, so pretending would assert nothing.
class NoopScreenBrightnessController implements ScreenBrightnessController {
  const NoopScreenBrightnessController();

  @override
  Future<void> boost() async {}

  @override
  Future<void> restore() async {}
}
