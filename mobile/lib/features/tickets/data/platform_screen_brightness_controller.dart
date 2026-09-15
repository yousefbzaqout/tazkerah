import 'dart:developer' as developer;
import 'dart:io';

import 'package:screen_brightness/screen_brightness.dart';

import '../domain/screen_brightness_controller.dart';

/// The platform-backed [ScreenBrightnessController].
class PlatformScreenBrightnessController
    implements ScreenBrightnessController {
  PlatformScreenBrightnessController({ScreenBrightness? plugin})
    : _plugin = plugin ?? ScreenBrightness.instance;

  final ScreenBrightness _plugin;

  /// Full, not merely raised.
  ///
  /// A gate scanner reads a QR off a screen under hall lighting that the app
  /// cannot predict, and a partially-raised screen that still fails to scan
  /// helps nobody — the cost of going all the way is a brighter screen for the
  /// few seconds the pass is open.
  static const double _passBrightness = 1;

  bool _boosted = false;

  @override
  Future<void> boost() async {
    if (_boosted) return;

    try {
      // Application-scoped: lapses when the app is backgrounded and never
      // touches the user's own brightness setting.
      await _plugin.setApplicationScreenBrightness(_passBrightness);
      _boosted = true;
    } catch (e, stack) {
      // A pass that cannot brighten the screen is still a usable pass — the
      // user can raise brightness by hand. Failing the screen over this would
      // trade a readable QR for no QR at all.
      _report('Raising screen brightness failed', e, stack);
    }
  }

  @override
  Future<void> restore() async {
    if (!_boosted) return;
    _boosted = false;

    try {
      await _plugin.resetApplicationScreenBrightness();
    } catch (e, stack) {
      _report('Restoring screen brightness failed', e, stack);
    }
  }

  void _report(String message, Object error, StackTrace stack) {
    developer.log(message, name: 'tickets', error: error, stackTrace: stack);
  }
}

/// Whether this platform has a brightness implementation.
///
/// The plugin also declares desktop targets, but the gate pass is a phone
/// screen held up to a scanner; binding it only where it was designed to run
/// keeps the promise honest.
bool get supportsScreenBrightnessControl =>
    Platform.isAndroid || Platform.isIOS;
