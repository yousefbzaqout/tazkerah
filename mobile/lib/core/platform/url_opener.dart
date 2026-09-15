import 'package:url_launcher/url_launcher.dart';

/// Opens URLs outside the app.
///
/// An interface for the same reason [SecureStorage] is one: `url_launcher`
/// needs a platform channel that `flutter_test` does not provide, so a test
/// that exercised the checkout handoff would fail on the plugin rather than on
/// the logic. [RecordingUrlOpener] is the reason those tests run at all.
///
/// It deliberately does nothing but open a URL. Deciding *which* URL, and what
/// it means, stays in the feature that knows — this is plumbing.
abstract interface class UrlOpener {
  /// Opens [url], returning whether the platform accepted it.
  ///
  /// Returns false rather than throwing for a URL no installed app can handle:
  /// that is a normal outcome on a device without a browser or mail client,
  /// and the caller decides whether it is worth telling the user about.
  Future<bool> open(Uri url);

  /// Shares [text] through the OS share sheet.
  ///
  /// Implemented as a `mailto:`-free share only where the platform supports
  /// it; see [UrlLauncherOpener.share] for what this actually does today.
  Future<bool> share({required String text, required Uri url});
}

/// [UrlOpener] backed by `url_launcher`.
class UrlLauncherOpener implements UrlOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> open(Uri url) async {
    if (!await canLaunchUrl(url)) return false;
    return launchUrl(
      url,
      // An external application, not an in-app web view: a hosted payment
      // gateway must be able to show its own address bar and certificate, and
      // a user who cannot see the domain they are paying has no way to tell a
      // real gateway from a convincing one.
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<bool> share({required String text, required Uri url}) async {
    // `url_launcher` has no share sheet. Rather than pull in `share_plus` for
    // one button, this opens the link — which on both platforms offers the
    // system share affordance from the browser.
    //
    // A real share sheet is a small follow-up once someone specifies the share
    // copy; this is honest in the meantime because the link genuinely opens.
    return open(url);
  }
}

/// An [UrlOpener] that records instead of launching.
///
/// Used by tests, which have no platform channel and no browser to launch
/// into.
class RecordingUrlOpener implements UrlOpener {
  RecordingUrlOpener({this.succeeds = true});

  /// What [open] and [share] return.
  bool succeeds;

  final List<Uri> opened = [];
  final List<String> shared = [];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeeds;
  }

  @override
  Future<bool> share({required String text, required Uri url}) async {
    shared.add(text);
    opened.add(url);
    return succeeds;
  }
}
