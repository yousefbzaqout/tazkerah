import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/config/app_config.dart';
import 'package:tazkerah/core/network/certificate_pinning.dart';

/// Real certificates, captured from live hosts.
///
/// Real ones rather than synthesised: the SPKI is located by walking DER, and
/// a hand-made certificate would only prove the parser handles the shape the
/// test itself produced. These cover both key types in use on the web — P-256
/// ECDSA (github, cloudflare) and RSA (pub.dev) — whose SPKI encodings differ
/// in exactly the places the walk has to get right.
///
/// The expected hashes are OpenSSL's, computed independently:
///
/// ```
/// openssl s_client -connect <host>:443 -servername <host> \
///   | openssl x509 -pubkey -noout \
///   | openssl pkey -pubin -outform der \
///   | openssl dgst -sha256 -binary | openssl enc -base64
/// ```
const Map<String, String> knownPins = {
  'github_com': '/wiL5vgOLgwED41WS0DNF8QiTBVR/P41Kd163tmFxK0=',
  'pub_dev': 'hUFvzBRm81wZkOwE46OtGx+4b8wdndBqn7keglBMiBo=',
  'cloudflare_com': 'dwjmLC0WOWNMwJPMHi67GYDnrQDrLk5cFVlmeutsGCs=',
};

/// The DER bytes of a captured certificate.
///
/// Bytes rather than an [X509Certificate]: that type is an abstract interface
/// with no public constructor, obtainable only from a live TLS handshake. The
/// DER is what pinning actually reads.
List<int> load(String name) =>
    File('test/fixtures/certificates/$name.der').readAsBytesSync();

void main() {
  group('SPKI hashing', () {
    for (final entry in knownPins.entries) {
      test('${entry.key} matches the hash OpenSSL computes', () {
        // The assertion that makes this feature trustworthy: if the DER walk
        // is wrong, it produces a hash that matches nothing and pinning fails
        // closed against a certificate that was actually fine.
        expect(
          CertificatePinner.spkiSha256FromDer(load(entry.key)),
          entry.value,
        );
      });
    }

    test('different certificates hash differently', () {
      final hashes = knownPins.keys
          .map((name) => CertificatePinner.spkiSha256FromDer(load(name)))
          .toSet();

      expect(hashes, hasLength(knownPins.length));
    });

    test('hashing is stable across calls', () {
      final certificate = load('github_com');

      expect(
        CertificatePinner.spkiSha256FromDer(certificate),
        CertificatePinner.spkiSha256FromDer(certificate),
      );
    });
  });

  group('CertificatePinner', () {
    test('admits a certificate carrying a pinned key', () {
      final pinner = CertificatePinner(pins: {knownPins['github_com']!});

      expect(pinner.allowsDer(load('github_com')), isTrue);
    });

    test('refuses a certificate carrying any other key', () {
      // What an interception proxy looks like: a valid certificate for the
      // right host, carrying a key the app was never told about.
      final pinner = CertificatePinner(pins: {knownPins['github_com']!});

      expect(pinner.allowsDer(load('pub_dev')), isFalse);
      expect(pinner.allowsDer(load('cloudflare_com')), isFalse);
    });

    test('a backup pin is honoured alongside the primary', () {
      // Why more than one pin is not optional: losing a single pinned key
      // leaves no route to the server but an app-store update.
      final pinner = CertificatePinner(
        pins: {knownPins['github_com']!, knownPins['pub_dev']!},
      );

      expect(pinner.allowsDer(load('github_com')), isTrue);
      expect(pinner.allowsDer(load('pub_dev')), isTrue);
      expect(pinner.allowsDer(load('cloudflare_com')), isFalse);
    });

    test('an unconfigured pinner admits everything', () {
      // Refusing every certificate would be indistinguishable from the server
      // being down, and would be debugged as an outage.
      const pinner = CertificatePinner(pins: {});

      expect(pinner.isEnabled, isFalse);
      expect(pinner.allowsDer(load('github_com')), isTrue);
    });
  });

  group('AppConfig pinning', () {
    AppConfig config({
      AppEnvironment environment = AppEnvironment.production,
      Set<String> pins = const {},
    }) {
      return AppConfig(
        environment: environment,
        apiBaseUrl: 'https://example.test/api/v1',
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
        sendTimeout: const Duration(seconds: 1),
        certificatePins: pins,
      );
    }

    test('enforced in production once pins are configured', () {
      expect(
        config(pins: {knownPins['github_com']!}).enforceCertificatePinning,
        isTrue,
      );
    });

    test('never enforced outside production', () {
      // Proxy tools have to keep working during development.
      for (final env in [AppEnvironment.dev, AppEnvironment.staging]) {
        expect(
          config(
            environment: env,
            pins: {knownPins['github_com']!},
          ).enforceCertificatePinning,
          isFalse,
        );
      }
    });

    test('not enforced when production carries no pins', () {
      // Enforcing an empty set would refuse every certificate.
      expect(config().enforceCertificatePinning, isFalse);
    });

    test('a production build without pins is flagged', () {
      expect(config().missingProductionPins, isTrue);
      expect(
        config(pins: {knownPins['github_com']!}).missingProductionPins,
        isFalse,
      );
      expect(
        config(environment: AppEnvironment.dev).missingProductionPins,
        isFalse,
      );
    });
  });
}
