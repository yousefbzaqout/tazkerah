/// Build-time configuration.
///
/// Values arrive via `--dart-define`, so a build can be pointed at a different
/// environment without a code change:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://staging.api.tazkerah.app/api/v1
/// ```
///
/// This file must never hold a secret. Anything compiled into the binary is
/// readable by anyone who downloads it — `--dart-define` included. It carries
/// endpoints and timeouts, nothing that would matter if published.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.sendTimeout,
  });

  /// Reads configuration from the compile-time environment, with defaults
  /// aimed at local development.
  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

    return AppConfig(
      environment: AppEnvironment.from(env),
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        // 10.0.2.2 is the host machine as seen from the Android emulator.
        // iOS simulators reach the host on localhost; override per platform
        // when running there.
        defaultValue: 'http://10.0.2.2:8000/api/v1',
      ),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    );
  }

  final AppEnvironment environment;
  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Whether verbose network logging is permitted.
  ///
  /// False in production: request and response bodies carry tokens and
  /// personal data, and on Android any app with log access could read them.
  bool get enableNetworkLogging => environment != AppEnvironment.production;

  /// Whether TLS certificate pinning must be enforced.
  ///
  /// Off outside production so proxy tools (Charles, mitmproxy) still work
  /// during development. Wiring lands in Phase 8.
  bool get enforceCertificatePinning =>
      environment == AppEnvironment.production;
}

enum AppEnvironment {
  dev,
  staging,
  production;

  static AppEnvironment from(String value) => switch (value.toLowerCase()) {
    'prod' || 'production' => AppEnvironment.production,
    'staging' || 'stage' => AppEnvironment.staging,
    _ => AppEnvironment.dev,
  };
}
