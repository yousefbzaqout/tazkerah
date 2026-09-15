import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import '../../app/config/app_config.dart';
import '../platform/app_info.dart';

/// Work that must complete before the first frame.
///
/// Kept out of `main` so each step is named, ordered and individually
/// testable, and out of the widget tree so no screen depends on initialization
/// having happened.
///
/// Anything that can wait belongs elsewhere: this runs on the splash screen,
/// and every millisecond here is time the user spends staring at it.
abstract final class AppBootstrap {
  /// Runs every startup step in order.
  ///
  /// Returns the platform values the provider scope must be seeded with.
  /// Reading them here rather than lazily inside a provider keeps the first
  /// frame synchronous — a screen that has to await its own version number
  /// would flicker.
  static Future<BootstrapResult> run() async {
    _assertTransportSecurity();
    await _lockOrientation();

    final appInfo = PackageAppInfo();
    try {
      await appInfo.load();
    } catch (e, stack) {
      // A missing package identity is not worth blocking launch over: the
      // version is shown in one place on the profile screen, and an app that
      // refused to start because it could not read its own build number would
      // be a worse failure than a blank field.
      developer.log(
        'Could not read package info',
        name: 'bootstrap',
        error: e,
        stackTrace: stack,
      );
      return const BootstrapResult(appInfo: StaticAppInfo(version: ''));
    }

    return BootstrapResult(appInfo: appInfo);
  }

  /// Locks the app to portrait.
  ///
  /// The ticket QR screen is designed portrait-only — rotating it mid-scan at
  /// a gate helps nobody. Set globally now rather than per-screen so no
  /// feature has to remember.
  static Future<void> _lockOrientation() {
    return SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// Fails a debug build that would ship without certificate pinning.
  ///
  /// An assert rather than a thrown error, so it stops a developer and a CI
  /// run but never a user's release: by the time a build is in someone's
  /// hands, crashing on launch is a worse outcome than an unpinned connection.
  ///
  /// This exists because the failure it catches is silent. A production build
  /// without `CERTIFICATE_PINS` connects perfectly happily and simply has no
  /// pinning — there is nothing to notice unless something checks.
  static void _assertTransportSecurity() {
    assert(() {
      final config = AppConfig.fromEnvironment();
      if (config.missingProductionPins) {
        throw StateError(
          'Production build has no certificate pins. Pass them with '
          '--dart-define=CERTIFICATE_PINS=<base64 SPKI sha256>,<backup>. '
          'See CertificatePinner for how to compute one.',
        );
      }
      return true;
    }());
  }

  // Timezone-database initialization lives in LocalReminderScheduler rather
  // than here: it is only needed once something is actually scheduled, and
  // loading the IANA database on the splash screen would be startup cost paid
  // by every launch for a feature most of them never reach.
}

/// What startup produced, for the provider scope to be seeded with.
class BootstrapResult {
  const BootstrapResult({required this.appInfo});

  final AppInfo appInfo;
}
