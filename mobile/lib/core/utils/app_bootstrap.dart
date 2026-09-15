import 'dart:developer' as developer;

import 'package:flutter/services.dart';

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

  // Phase 6 adds timezone-database initialization here, alongside the
  // notification scheduler. It must run before anything is scheduled:
  // reminders fire relative to the *event's* timezone, not the device's, so a
  // ticket bought in Riyadh for a Dubai event alerts on Dubai time and a
  // traveller crossing zones does not have reminders silently shift.
}

/// What startup produced, for the provider scope to be seeded with.
class BootstrapResult {
  const BootstrapResult({required this.appInfo});

  final AppInfo appInfo;
}
