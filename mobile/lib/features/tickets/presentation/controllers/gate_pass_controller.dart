import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/clock.dart';
import '../../data/dev_gate_pass_repository.dart';
import '../../domain/gate_pass_repository.dart';
import '../../domain/gate_pass_state.dart';
import '../../domain/screen_capture_detector.dart';

/// Drives the gate pass: fetch it, rotate its code, and withhold the payload
/// when a capture is detected.
///
/// Two rules shape this screen, and both are security properties rather than
/// visual ones:
///
/// 1. **The server issues every code.** Nothing here generates a payload or
///    holds key material. Rotation is a request, not a computation.
/// 2. **A captured code is withheld immediately and reported.** Withholding it
///    locally is not enough — a forwarded screenshot would still scan unless
///    the issuer invalidates it, so the capture is reported and a fresh code
///    requested before anything is shown again.
class GatePassController extends Notifier<GatePassViewState> {
  GatePassController(this._ticketId);

  final String _ticketId;

  /// How often the ring and countdown are refreshed. The *code* rotates on the
  /// grant's interval; this only redraws what is left of it.
  static const Duration tickInterval = Duration(milliseconds: 250);

  Timer? _ticker;
  StreamSubscription<ScreenCaptureEvent>? _captureSubscription;
  int _requestToken = 0;
  bool _disposed = false;

  @override
  GatePassViewState build() {
    // Resolved during build, not inside `onDispose`: Riverpod forbids reading
    // providers from a life-cycle callback, and by disposal time the container
    // may already be tearing down the very provider we would ask for.
    final detector = ref.read(screenCaptureDetectorProvider);

    ref.onDispose(() {
      _disposed = true;
      _ticker?.cancel();
      _captureSubscription?.cancel();
      // Stop watching when the pass leaves the screen, so the detector is not
      // running for the life of the app.
      detector.stop();
    });
    Future.microtask(load);
    return const GatePassViewState();
  }

  GatePassRepository get _repository => ref.read(gatePassRepositoryProvider);
  AppClock get _clock => ref.read(clockProvider);

  bool _isStale(int token) => _disposed || token != _requestToken;

  /// Fetches the pass and its first code.
  Future<void> load() async {
    final token = ++_requestToken;
    state = const GatePassViewState();

    try {
      final pass = await _repository.fetchPass(_ticketId);
      if (_isStale(token)) return;

      if (!pass.canPresent) {
        // A consumed or revoked pass gets no code at all — there is nothing
        // valid to render, and rendering something would imply otherwise.
        state = state.copyWith(
          status: GatePassViewStatus.unavailable,
          pass: pass,
        );
        return;
      }

      state = state.copyWith(
        pass: pass,
        isClockStale: _clock.isSyncStale,
        clockOffset: _clock.offset,
      );

      // Check the skew *before* asking for a code. A device this far out would
      // generate one the scanner rejects without explanation, so the fallback
      // is offered instead of a QR that looks valid and is not.
      if (_clock.isSkewExcessive) {
        await _suppressForClockDrift(token);
        return;
      }

      await _rotate(token);
      if (_isStale(token)) return;

      _startTicker();
      await _watchForCaptures();
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      state = state.copyWith(
        status: GatePassViewStatus.error,
        failure: failure,
      );
    } catch (e, stack) {
      if (_isStale(token)) return;
      _report('Gate pass load failed unexpectedly', e, stack);
      state = state.copyWith(
        status: GatePassViewStatus.error,
        failure: UnknownFailure(debugMessage: e.toString()),
      );
    }
  }

  /// Requests the next code and puts it on screen.
  Future<void> _rotate(int token) async {
    state = state.copyWith(isRefreshing: true);

    try {
      final code = await _repository.issueCode(_ticketId);
      if (_isStale(token)) return;

      final now = _clock.now;
      state = state.copyWith(
        status: GatePassViewStatus.active,
        code: code,
        remaining: code.remaining(now),
        progress: code.progress(now),
        isRefreshing: false,
        isClockStale: _clock.isSyncStale,
        clearIntercept: true,
        clearFailure: true,
      );
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      // No code means nothing to present. The screen says so rather than
      // leaving a stale code on screen past its window.
      state = state.copyWith(
        status: GatePassViewStatus.error,
        failure: failure,
        isRefreshing: false,
        clearCode: true,
      );
    }
  }

  /// Withholds the QR for clock drift and fetches the manual fallback.
  ///
  /// Distinct from a capture intercept: nothing was leaked and no code needs
  /// invalidating. The device simply cannot produce a code the gate would
  /// accept, so the screen switches to a credential that does not depend on
  /// the device clock at all.
  Future<void> _suppressForClockDrift(int token) async {
    _ticker?.cancel();

    state = state.copyWith(
      status: GatePassViewStatus.intercepted,
      clearCode: true,
      remaining: Duration.zero,
      progress: 0,
      clockOffset: _clock.offset,
      intercept: PassIntercept(
        reason: InterceptReason.clockDrift,
        detectedAt: DateTime.now().toUtc(),
      ),
    );

    try {
      final manual = await _repository.issueManualCode(_ticketId);
      if (_isStale(token)) return;
      state = state.copyWith(manualCode: manual, isRefreshing: false);
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      // Without a fallback there is no way through the gate on this device.
      // The screen says so rather than showing an empty panel where a code
      // should be.
      state = state.copyWith(failure: failure, isRefreshing: false);
    }
  }

  /// Re-learns the clock offset from the server — "Attempt Time Re-sync".
  ///
  /// On success the skew is re-checked: if it is now within tolerance the QR
  /// comes back, and if not the fallback stays. The decision is made from the
  /// *new* offset rather than assumed, because a re-sync that did not fix the
  /// drift must not restore a code the gate would still reject.
  Future<void> attemptTimeResync() async {
    if (state.isRefreshing) return;
    final token = ++_requestToken;
    state = state.copyWith(isRefreshing: true);

    try {
      final serverTime = await _repository.fetchServerTime();
      if (_isStale(token)) return;
      _clock.syncTo(serverTime);

      if (_clock.isSkewExcessive) {
        state = state.copyWith(
          isRefreshing: false,
          clockOffset: _clock.offset,
          isClockStale: _clock.isSyncStale,
        );
        return;
      }

      // Back within tolerance: drop the fallback and resume rotation.
      state = state.copyWith(
        clockOffset: _clock.offset,
        isClockStale: _clock.isSyncStale,
        clearManualCode: true,
        clearIntercept: true,
      );
      await _rotate(token);
      if (_isStale(token)) return;
      if (state.status == GatePassViewStatus.active) {
        _startTicker();
        await _watchForCaptures();
      }
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      // The offset is unchanged, so the fallback stays exactly as it was.
      state = state.copyWith(isRefreshing: false, failure: failure);
    }
  }

  /// Subscribes to capture events for as long as the pass is shown.
  Future<void> _watchForCaptures() async {
    final detector = ref.read(screenCaptureDetectorProvider);
    await detector.start();
    _captureSubscription?.cancel();
    _captureSubscription = detector.events.listen(_onCaptureDetected);
  }

  /// Withholds the payload and asks the server to invalidate it.
  void _onCaptureDetected(ScreenCaptureEvent event) {
    if (_disposed) return;
    final withheldHash = state.code?.displayHash;

    // The payload is dropped from state, not merely hidden: there is then
    // nothing on the screen's side to leak, and no flag whose inversion would
    // reveal it.
    state = state.copyWith(
      status: GatePassViewStatus.intercepted,
      clearCode: true,
      remaining: Duration.zero,
      progress: 0,
      intercept: PassIntercept(
        reason: InterceptReason.screenCapture,
        detectedAt: event.at,
        withheldHash: withheldHash,
      ),
    );
    _ticker?.cancel();

    // Reported so the issuer invalidates the captured code. Failures are
    // logged rather than surfaced — the user has already been told the code
    // was withheld, and a second error would not change what they do next.
    unawaited(
      _repository.reportCapture(_ticketId).catchError((Object e, StackTrace s) {
        _report('Capture report failed', e, s);
      }),
    );
  }

  /// Reveals a fresh code after an intercept — the design's "Reveal fresh
  /// dynamic QR".
  ///
  /// Deliberately manual. An automatic re-reveal would put the payload back on
  /// screen while a recording was still running, and while the phone may still
  /// be pointed at whoever took the shot.
  Future<void> revealFreshCode() async {
    if (state.status != GatePassViewStatus.intercepted) return;
    final token = ++_requestToken;

    await _rotate(token);
    if (_isStale(token)) return;
    if (state.status == GatePassViewStatus.active) _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  /// Redraws the countdown, and rotates when the window closes.
  void _tick() {
    final code = state.code;
    if (code == null || _disposed) {
      _ticker?.cancel();
      return;
    }

    final now = _clock.now;
    if (code.isExpired(now)) {
      // The rotation elapsed. Ask for the next code rather than counting into
      // the negative or leaving a dead code on screen.
      unawaited(_rotate(_requestToken));
      return;
    }

    state = state.copyWith(
      remaining: code.remaining(now),
      progress: code.progress(now),
    );
  }

  void _report(String message, Object error, StackTrace stack) {
    developer.log(message, name: 'tickets', error: error, stackTrace: stack);
  }
}

/// Binds a concrete [GatePassRepository].
final gatePassRepositoryProvider = Provider<GatePassRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.environment == AppEnvironment.production) {
    throw UnimplementedError(
      'No production GatePassRepository is bound. The ticket cryptography '
      'contract is still open — see GatePassRepository and the architecture '
      'review.',
    );
  }

  final repository = DevGatePassRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Binds the capture detector.
///
/// Inert until the platform implementation lands. Overridden in tests to reach
/// the intercepted frame without taking a real screenshot.
final screenCaptureDetectorProvider = Provider<ScreenCaptureDetector>((ref) {
  return const NoopScreenCaptureDetector();
});

/// Auto-disposed so the rotation timer and the capture subscription stop when
/// the pass leaves the screen. A gate pass left rotating in the background
/// would request a fresh code every 20 seconds for the life of the app.
final gatePassControllerProvider =
    NotifierProvider.family<GatePassController, GatePassViewState, String>(
      GatePassController.new,
      isAutoDispose: true,
    );
