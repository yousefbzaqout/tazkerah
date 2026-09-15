import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../network/api_client.dart';
import '../platform/app_info.dart';
import '../platform/url_opener.dart';
import '../storage/secure_storage.dart';
import '../utils/clock.dart';

/// Build-time configuration.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// Corrected time source. Held app-wide so the offset learned by one request
/// is visible to every later ticket-code generation.
final clockProvider = Provider<AppClock>((ref) {
  return AppClock();
});

/// Encrypted key-value storage.
///
/// Overridden with [InMemorySecureStorage] in tests, which is the reason
/// [SecureStorage] is an interface at all.
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return FlutterSecureStorageAdapter();
});

/// Supplies the current access token to the auth interceptor.
///
/// A placeholder until Phase 2 brings the session controller. It stays here so
/// [apiClientProvider] can be finished now and overridden later without the
/// network layer knowing anything about auth.
///
/// The access token is memory-resident by design — it is short-lived, and
/// writing it to disk would widen its exposure for no benefit. Only the
/// refresh token is persisted.
final accessTokenProvider = Provider<Future<String?> Function()>((ref) {
  return () async => null;
});

/// Opens URLs outside the app — the payment gateway, a shared event link.
///
/// Overridden with [RecordingUrlOpener] in tests, which is the reason
/// [UrlOpener] is an interface: `url_launcher` needs a platform channel that
/// `flutter_test` does not provide.
final urlOpenerProvider = Provider<UrlOpener>((ref) {
  return const UrlLauncherOpener();
});

/// The app's own version, loaded once at bootstrap.
///
/// Overridden in tests and previews with [StaticAppInfo]; the real one is
/// installed by [AppBootstrap] after it has read the platform values.
final appInfoProvider = Provider<AppInfo>((ref) {
  return const StaticAppInfo();
});

/// The configured HTTP client. Repositories depend on this; presentation
/// must not.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    clock: ref.watch(clockProvider),
    tokenProvider: ref.watch(accessTokenProvider),
  );
});
