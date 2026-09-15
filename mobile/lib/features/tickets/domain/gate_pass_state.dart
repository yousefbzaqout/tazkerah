import '../../../core/errors/failure.dart';
import 'gate_pass.dart';

/// What the gate pass screen is showing.
///
/// The two designed frames — an active rotating code and a capture-intercepted
/// one — are states of the same screen, not separate screens: the intercept
/// happens while the user is standing at the gate holding the phone up, and a
/// navigation there would be jarring and slow.
class GatePassViewState {
  const GatePassViewState({
    this.status = GatePassViewStatus.loading,
    this.pass,
    this.code,
    this.remaining = Duration.zero,
    this.progress = 0,
    this.intercept,
    this.failure,
    this.isRefreshing = false,
    this.isClockStale = false,
    this.manualCode,
    this.clockOffset = Duration.zero,
  });

  final GatePassViewStatus status;

  final GatePass? pass;

  /// The code currently on screen. Null whenever the payload is withheld —
  /// which is what makes "suppressed" unforgeable in the UI: there is nothing
  /// to render, not merely something hidden behind a flag.
  final PresentationCode? code;

  /// Time left on this rotation.
  final Duration remaining;

  /// Rotation progress from 0 to 1, driving the ring.
  final double progress;

  /// Why the payload is being withheld, when it is.
  final PassIntercept? intercept;

  final Failure? failure;

  /// A fresh code is being fetched.
  final bool isRefreshing;

  /// The typed code offered when the QR is withheld for clock drift.
  ///
  /// Only ever set alongside [InterceptReason.clockDrift]: a screenshot
  /// intercept is recoverable by revealing a new code, and offering a manual
  /// fallback there would hand out a gate credential to answer a problem that
  /// has already been solved.
  final ManualEntryCode? manualCode;

  /// How far the device clock is from server time, for the offset readout.
  final Duration clockOffset;

  /// The corrected clock is too old to trust. Shown as a warning rather than a
  /// block: the scanner holds the authoritative clock, so a drifted device
  /// should be told why a scan may fail, not prevented from trying.
  final bool isClockStale;

  /// Whether a payload may be drawn right now.
  bool get isPresentable => status == GatePassViewStatus.active && code != null;

  GatePassViewState copyWith({
    GatePassViewStatus? status,
    GatePass? pass,
    PresentationCode? code,
    Duration? remaining,
    double? progress,
    PassIntercept? intercept,
    Failure? failure,
    bool? isRefreshing,
    bool? isClockStale,
    ManualEntryCode? manualCode,
    Duration? clockOffset,
    bool clearCode = false,
    bool clearManualCode = false,
    bool clearIntercept = false,
    bool clearFailure = false,
  }) {
    return GatePassViewState(
      status: status ?? this.status,
      pass: pass ?? this.pass,
      code: clearCode ? null : (code ?? this.code),
      remaining: remaining ?? this.remaining,
      progress: progress ?? this.progress,
      intercept: clearIntercept ? null : (intercept ?? this.intercept),
      failure: clearFailure ? null : (failure ?? this.failure),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isClockStale: isClockStale ?? this.isClockStale,
      manualCode: clearManualCode ? null : (manualCode ?? this.manualCode),
      clockOffset: clockOffset ?? this.clockOffset,
    );
  }
}

/// The mutually exclusive states of the pass screen.
enum GatePassViewStatus {
  /// Fetching the pass and its first code.
  loading,

  /// A code is on screen and rotating.
  active,

  /// The payload is withheld and a new one is ready to reveal.
  intercepted,

  /// The pass cannot be presented at all — consumed, revoked, or refunded.
  unavailable,

  /// The pass could not be loaded.
  error,
}

/// Why a payload was withheld.
class PassIntercept {
  const PassIntercept({
    required this.reason,
    required this.detectedAt,
    this.withheldHash,
  });

  final InterceptReason reason;

  /// When it happened, for the "JUST NOW" stamp.
  final DateTime detectedAt;

  /// The hash of the code that was withheld — never the code. Shown so the
  /// user can see that a specific rotation was invalidated, without the value
  /// itself being recoverable from the screen.
  final String? withheldHash;
}

/// What triggered an intercept.
enum InterceptReason {
  /// A screenshot or screen recording was detected. The code is rotated
  /// immediately, because a captured code is a code that can be forwarded —
  /// which is precisely what a single-entry pass must prevent.
  screenCapture,

  /// The device clock is too far from server time for a generated code to fall
  /// inside the scanner's tolerance.
  clockDrift,
}
