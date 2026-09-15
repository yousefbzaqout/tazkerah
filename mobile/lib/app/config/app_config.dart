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
    this.certificatePins = const {},
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
      certificatePins: _parsePins(
        const String.fromEnvironment('CERTIFICATE_PINS'),
      ),
    );
  }

  /// Splits the comma-separated pin list, ignoring blanks so a trailing comma
  /// or an unset define does not produce an empty pin that matches nothing.
  static Set<String> _parsePins(String raw) {
    return raw
        .split(',')
        .map((pin) => pin.trim())
        .where((pin) => pin.isNotEmpty)
        .toSet();
  }

  final AppEnvironment environment;
  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Base64 SHA-256 hashes of the SubjectPublicKeyInfo the API may present.
  ///
  /// Not a secret — a pin is a hash of a *public* key, and anyone can compute
  /// it from a TLS handshake — so it belongs in `--dart-define` alongside the
  /// endpoint rather than in secure storage.
  ///
  /// Supplied as a comma-separated list. Empty means pinning is not
  /// configured, which is the current state: the production domain does not
  /// exist yet, so there is no certificate to pin against.
  final Set<String> certificatePins;

  /// Whether verbose network logging is permitted.
  ///
  /// False in production: request and response bodies carry tokens and
  /// personal data, and on Android any app with log access could read them.
  bool get enableNetworkLogging => environment != AppEnvironment.production;

  /// Whether TLS certificate pinning is enforced.
  ///
  /// Off outside production so proxy tools (Charles, mitmproxy) still work
  /// during development.
  ///
  /// Also off when no pins are configured. That is not a loophole to be closed
  /// later: enforcing an empty pin set would refuse *every* certificate, and
  /// the resulting failure is indistinguishable from the server being down —
  /// so a release built without the define would look like an outage rather
  /// than a misconfiguration. [missingProductionPins] is the signal that this
  /// has happened, and it is asserted at startup.
  bool get enforceCertificatePinning =>
      environment == AppEnvironment.production && certificatePins.isNotEmpty;

  /// A production build that carries no pins.
  ///
  /// Checked at startup rather than left to be noticed in a pen test: this is
  /// exactly the condition where the app silently loses the protection it
  /// claims to have.
  bool get missingProductionPins =>
      environment == AppEnvironment.production && certificatePins.isEmpty;
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
