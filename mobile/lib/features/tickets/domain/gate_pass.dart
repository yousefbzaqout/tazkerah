/// A ticket that can be presented at a gate.
///
/// The pass is the durable part — who it belongs to, which seat, which gate.
/// The code shown on screen is not stored here: it rotates, and a pass that
/// carried its current code would invite that code being cached, logged, or
/// persisted. See [PresentationCode].
class GatePass {
  const GatePass({
    required this.id,
    required this.reference,
    required this.eventTitle,
    required this.venueName,
    required this.zoneLabel,
    required this.seatLabel,
    required this.holderName,
    required this.entranceLabel,
    required this.status,
    required this.rotationInterval,
    this.deviceId,
    this.isFastTrack = false,
  });

  final String id;

  /// The rule reference printed in the header: `FR-021`.
  final String reference;

  final String eventTitle;
  final String venueName;

  /// The zone as printed on the card: `ZONE 1`, `VIP PODIUM`.
  final String zoneLabel;

  /// The seat as printed: `VIP A-12`.
  final String seatLabel;

  /// Who the pass was issued to. Shown so a steward can check it against ID.
  final String holderName;

  /// Where to enter: `Gate 4`, `GATE 04 · EAST`.
  final String entranceLabel;

  final GatePassStatus status;

  /// How often the presentation code rotates.
  ///
  /// Travels with the grant rather than being read from a constant, so the
  /// backend can change the cycle without an app release — and so this screen
  /// can never advertise an interval the gate scanner disagrees with.
  final Duration rotationInterval;

  /// The device this pass is bound to: `#TZ-8841-A`. Shown because binding is
  /// the anti-sharing property, and a user should be able to see which device
  /// holds their pass.
  final String? deviceId;

  final bool isFastTrack;

  /// Whether a code may be shown at all.
  bool get canPresent => status == GatePassStatus.active;
}

/// What the gate would do with this pass right now.
enum GatePassStatus {
  /// Valid and presentable.
  active,

  /// Temporarily withheld — a screenshot was detected, or the clock is too far
  /// out of sync to trust. Recoverable.
  intercepted,

  /// Already used. Single entry means a second presentation is not valid.
  consumed,

  /// Revoked or refunded.
  invalid,
}

/// One rotation of the presentation code.
///
/// **Issued by the server, never generated here.** The ticket cryptography is
/// still an open contract — the specification's "TOTP signed with JWT" is not
/// a coherent construct, because TOTP verification requires the verifier to
/// hold the shared secret, and an offline scanner holding it could forge every
/// ticket at its event. Until that is settled, this app displays the opaque
/// payload it is handed and invents no crypto of its own.
///
/// It is deliberately memory-resident: nothing here is written to storage, and
/// the value is short-lived by construction.
class PresentationCode {
  const PresentationCode({
    required this.payload,
    required this.issuedAt,
    required this.expiresAt,
    required this.displayHash,
  });

  /// The opaque string encoded into the QR. Never logged, never persisted,
  /// never shown as text — a payload a user can read is a payload they can
  /// forward.
  final String payload;

  final DateTime issuedAt;

  /// When this rotation stops being valid, in server time.
  final DateTime expiresAt;

  /// A short hash for display: `9F21-E83A`. Safe to show, because it
  /// identifies the code without reproducing it — which is what lets the
  /// intercepted state prove *which* code was withheld without leaking it.
  final String displayHash;

  /// Time left on this rotation, against a corrected clock.
  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// How far through the rotation this code is, from 0 to 1.
  ///
  /// Drives the countdown ring. Computed from the issued and expiry times
  /// rather than from an animation, so a dropped frame or a backgrounded app
  /// cannot leave the ring disagreeing with the code it describes.
  double progress(DateTime now) {
    final total = expiresAt.difference(issuedAt);
    if (total <= Duration.zero) return 1;
    final elapsed = now.difference(issuedAt);
    return (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  bool isExpired(DateTime now) => remaining(now) == Duration.zero;
}

/// The manual code a steward can type when the QR cannot be shown.
///
/// Issued by the server alongside the pass, not derived from the rotating
/// payload. That matters: the QR is withheld precisely because the device
/// clock cannot be trusted, so a fallback computed against that same clock
/// would be wrong in exactly the situation it exists for.
///
/// Eight digits, as the design specifies — long enough not to be guessable at
/// a gate, short enough to be read aloud and typed without error.
class ManualEntryCode {
  const ManualEntryCode({
    required this.digits,
    required this.displayHash,
    required this.issuedAt,
  });

  /// The code itself: `48291703`. Spaced for reading when displayed, but
  /// stored unspaced so it matches what a steward types.
  final String digits;

  /// A short hash identifying this code, shown beside it for support to quote.
  final String displayHash;

  final DateTime issuedAt;

  /// The digits grouped for display, as the design sets them.
  String get spaced => digits.split('').join(' ');
}
