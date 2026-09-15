import 'gate_pass.dart';

/// What the gate pass screen needs from the backend.
///
/// Declared in domain so the controller and its tests do not depend on how it
/// is fulfilled. The endpoints below are the contract this app expects; the
/// backend has not agreed them:
///
///   GET  /tickets/{id}/pass       -> {pass, rotation_interval, ...}
///   POST /tickets/{id}/code       -> {payload, issued_at, expires_at, hash}
///   POST /tickets/{id}/intercept  -> 204   (report a capture, force rotation)
///   POST /tickets/{id}/fallback   -> {digits, hash, issued_at}
///   GET  /time                    -> server clock, for re-sync
///
/// **This app generates no codes.** The ticket cryptography is an open
/// contract — the specification's "TOTP signed with JWT" is not coherent,
/// because TOTP verification requires the verifier to hold the shared secret,
/// and an offline scanner holding it could forge every ticket at its event.
/// Until that is settled the server issues opaque payloads and the app renders
/// them, so no key material and no generation logic lives on the device.
abstract interface class GatePassRepository {
  /// Fetches the pass and its presentation rules.
  Future<GatePass> fetchPass(String ticketId);

  /// Requests the next rotation of the presentation code.
  ///
  /// Called on a schedule while the pass is on screen, and again immediately
  /// after a capture is reported — a code that has been photographed must stop
  /// being valid, which only the issuer can decide.
  Future<PresentationCode> issueCode(String ticketId);

  /// Tells the backend a screen capture happened.
  ///
  /// Reported rather than merely handled locally: the previous code must be
  /// invalidated server-side, or a forwarded screenshot would still scan. The
  /// client rotating its own display would hide the problem without fixing it.
  Future<void> reportCapture(String ticketId);

  /// Requests the manual code a steward can type at the gate.
  ///
  /// Issued server-side rather than derived on the device: this exists because
  /// the device clock is not trusted, so anything computed against that clock
  /// would be wrong in exactly the case it is needed.
  Future<ManualEntryCode> issueManualCode(String ticketId);

  /// Asks the server for its current time, so the clock offset can be
  /// relearned — the design's "Attempt Time Re-sync (NTP)".
  ///
  /// Returns the server's UTC time. The caller hands it to [AppClock], which
  /// owns the offset.
  Future<DateTime> fetchServerTime();
}
