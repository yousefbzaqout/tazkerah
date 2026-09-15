import 'package:tazkerah/features/tickets/domain/screen_brightness_controller.dart';

/// Records brightness calls in order.
///
/// The reason [ScreenBrightnessController] is an interface: the real one needs
/// a method channel `flutter_test` does not provide, and brightness has no
/// observable state in a widget test, so the call sequence is the only thing
/// worth asserting on.
class FakeScreenBrightnessController implements ScreenBrightnessController {
  /// Every call in order: `'boost'` or `'restore'`.
  final List<String> calls = [];

  bool get isBoosted => calls.isNotEmpty && calls.last == 'boost';

  @override
  Future<void> boost() async => calls.add('boost');

  @override
  Future<void> restore() async => calls.add('restore');
}
