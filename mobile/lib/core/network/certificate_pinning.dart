import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Decides whether a server certificate may be trusted.
///
/// Pinning exists because the platform trust store is not sufficient on its
/// own: a device with a user-installed CA — a corporate MDM profile, or an
/// interception proxy someone was talked into installing — will happily
/// validate a certificate the app should refuse. For an app that carries
/// session tokens and ticket grants, that is the difference between a private
/// channel and a readable one.
///
/// **Pins are SPKI hashes, not certificate hashes.** A certificate is reissued
/// on every renewal — every 90 days with Let's Encrypt — and pinning the
/// certificate itself would brick every installed app at the first renewal.
/// The public key normally survives renewal, so hashing the SubjectPublicKeyInfo
/// survives it too.
class CertificatePinner {
  const CertificatePinner({required this.pins});

  /// Accepted SPKI SHA-256 hashes, base64-encoded.
  ///
  /// More than one is not optional in practice: at least one backup pin for a
  /// key that has not been deployed yet. With a single pin, losing that key —
  /// a compromise, a provider migration — leaves no way to reach the server
  /// except an app-store update that every user must install.
  final Set<String> pins;

  /// Whether pinning is active. An empty pin set means "not configured".
  bool get isEnabled => pins.isNotEmpty;

  /// Whether [certificate] carries one of the pinned keys.
  ///
  /// Returns true when no pins are configured: an unconfigured pinner must not
  /// silently refuse every connection, because that failure looks like a
  /// network outage and would be debugged as one.
  bool allows(X509Certificate certificate) => allowsDer(certificate.der);

  /// Whether a DER-encoded certificate carries one of the pinned keys.
  ///
  /// Takes bytes rather than an [X509Certificate] because that type is an
  /// abstract interface with no public constructor — it can only be obtained
  /// from a live TLS handshake, which a test cannot perform. The only member
  /// pinning needs is `der`, so the bytes are the real input.
  bool allowsDer(List<int> der) {
    if (!isEnabled) return true;
    return pins.contains(spkiSha256FromDer(der));
  }

  /// The base64 SHA-256 of a DER certificate's SubjectPublicKeyInfo.
  ///
  /// Dart exposes the certificate only in DER/PEM form, with no parsed public
  /// key, so the SPKI is located by walking the DER rather than read from a
  /// field. See [_extractSpki].
  ///
  /// Returns an empty string when the SPKI cannot be located, which
  /// [allowsDer] treats as a mismatch — failing closed, since a certificate
  /// this cannot parse is not one to trust.
  static String spkiSha256FromDer(List<int> der) {
    final spki = _extractSpki(der);
    if (spki == null) return '';
    return base64.encode(sha256.convert(spki).bytes);
  }

  /// Pulls the SubjectPublicKeyInfo out of a DER-encoded certificate.
  ///
  /// SPKI is the only SEQUENCE in a certificate whose first element is itself
  /// a SEQUENCE of an OID — the algorithm identifier — followed by a BIT
  /// STRING. This walks the structure looking for exactly that shape rather
  /// than pulling in an ASN.1 parser for one field.
  ///
  /// Returns null when the shape is not found, which [allows] treats as a
  /// mismatch — failing closed, since an unparseable certificate is not one to
  /// trust.
  static List<int>? _extractSpki(List<int> der) {
    for (var i = 0; i < der.length - 1; i++) {
      if (der[i] != _sequence) continue;

      final header = _readLength(der, i + 1);
      if (header == null) continue;

      final contentStart = header.offset;
      final end = contentStart + header.length;
      if (end > der.length) continue;

      // First element of the candidate must be an AlgorithmIdentifier
      // SEQUENCE, and its first element in turn an OID.
      if (contentStart >= der.length || der[contentStart] != _sequence) {
        continue;
      }
      final algorithm = _readLength(der, contentStart + 1);
      if (algorithm == null) continue;
      if (algorithm.offset >= der.length || der[algorithm.offset] != _oid) {
        continue;
      }

      // Second element must be the BIT STRING holding the key itself.
      final afterAlgorithm = algorithm.offset + algorithm.length;
      if (afterAlgorithm >= der.length) continue;
      if (der[afterAlgorithm] != _bitString) continue;

      final bits = _readLength(der, afterAlgorithm + 1);
      if (bits == null) continue;
      if (bits.offset + bits.length != end) continue;

      return der.sublist(i, end);
    }

    return null;
  }

  static const int _sequence = 0x30;
  static const int _bitString = 0x03;
  static const int _oid = 0x06;

  /// Reads a DER length at [start], returning it with the offset of the first
  /// content byte. Null when the encoding is malformed or larger than this
  /// parser handles.
  static _Der? _readLength(List<int> der, int start) {
    if (start >= der.length) return null;

    final first = der[start];

    // Short form: the byte is the length.
    if (first < 0x80) return _Der(offset: start + 1, length: first);

    final byteCount = first & 0x7f;
    // 0x80 is indefinite length, invalid in DER; more than four bytes is a
    // certificate far larger than anything real.
    if (byteCount == 0 || byteCount > 4) return null;
    if (start + 1 + byteCount > der.length) return null;

    var length = 0;
    for (var i = 0; i < byteCount; i++) {
      length = (length << 8) | der[start + 1 + i];
    }

    return _Der(offset: start + 1 + byteCount, length: length);
  }
}

/// A DER element's content offset and length.
class _Der {
  const _Der({required this.offset, required this.length});

  final int offset;
  final int length;
}
