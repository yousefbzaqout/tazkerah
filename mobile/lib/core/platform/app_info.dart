import 'package:package_info_plus/package_info_plus.dart';

/// The app's own identity, as the OS reports it.
///
/// An interface so tests do not need the platform channel, and so the profile
/// screen can be rendered without one.
abstract interface class AppInfo {
  /// Version as published: `1.0.0`.
  String get version;

  /// Build number: `1`.
  String get buildNumber;

  /// Loads the values. Called once during bootstrap.
  Future<void> load();
}

/// [AppInfo] backed by `package_info_plus`.
///
/// Reads the real values rather than carrying a constant: a hard-coded version
/// drifts from pubspec without anyone noticing, and a version a user reads out
/// to support has to be true.
class PackageAppInfo implements AppInfo {
  String _version = '';
  String _buildNumber = '';

  @override
  String get version => _version;

  @override
  String get buildNumber => _buildNumber;

  @override
  Future<void> load() async {
    final info = await PackageInfo.fromPlatform();
    _version = info.version;
    _buildNumber = info.buildNumber;
  }
}

/// Fixed values, for tests and previews.
class StaticAppInfo implements AppInfo {
  const StaticAppInfo({this.version = '1.0.0', this.buildNumber = '1'});

  @override
  final String version;

  @override
  final String buildNumber;

  @override
  Future<void> load() async {}
}
