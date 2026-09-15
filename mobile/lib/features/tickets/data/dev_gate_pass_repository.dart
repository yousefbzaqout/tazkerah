import 'dart:async';
import 'dart:math';

import '../../../core/constants/app_constants.dart';
import '../domain/gate_pass.dart';
import '../domain/gate_pass_repository.dart';

/// A stand-in [GatePassRepository] for running the gate pass before the
/// backend exists.
///
/// **Not a production implementation.** [AppConfig] gates it to non-production
/// builds. The payloads it issues are random strings, not credentials: they
/// would not scan at a real gate, which is the correct behaviour for a stub —
/// a fake that produced something scanner-shaped would invite someone testing
/// it against a real reader and drawing the wrong conclusion.
class DevGatePassRepository implements GatePassRepository {
  DevGatePassRepository({this.latency = const Duration(milliseconds: 300)});

  final Duration latency;

  final Random _random = Random();
  Timer? _pending;
  int _issued = 0;

  /// Cancels a simulated request still in flight.
  void dispose() {
    _pending?.cancel();
    _pending = null;
  }

  Future<void> _sleep() {
    if (latency == Duration.zero) return Future<void>.value();
    final completer = Completer<void>();
    _pending = Timer(latency, () {
      _pending = null;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  @override
  Future<GatePass> fetchPass(String ticketId) async {
    await _sleep();
    return GatePass(
      id: ticketId,
      reference: 'FR-021',
      eventTitle: 'Soundstorm 2025: Big Beast',
      venueName: 'AlUla Starlight Pavilion',
      zoneLabel: 'ZONE 1',
      seatLabel: 'VIP A-12',
      holderName: 'Tariq Al-Mansoor',
      entranceLabel: 'Gate 4',
      status: GatePassStatus.active,
      // The interval travels with the grant, so the backend owns the cycle.
      rotationInterval: AppConstants.qrRotationInterval,
      deviceId: '#TZ-8841-A',
      isFastTrack: true,
    );
  }

  @override
  Future<PresentationCode> issueCode(String ticketId) async {
    await _sleep();

    final now = DateTime.now().toUtc();
    _issued++;
    final hash = _hash();

    return PresentationCode(
      // Opaque and meaningless by design — see the class comment.
      payload: 'TZK:$ticketId:$_issued:${_random.nextInt(1 << 32)}',
      issuedAt: now,
      expiresAt: now.add(AppConstants.qrRotationInterval),
      displayHash: hash,
    );
  }

  @override
  Future<void> reportCapture(String ticketId) async {
    await _sleep();
  }

  @override
  Future<ManualEntryCode> issueManualCode(String ticketId) async {
    await _sleep();
    return ManualEntryCode(
      // Eight digits, as the design sets them. Random rather than derived:
      // the stub must not imply a derivation the backend has not agreed.
      digits: List.generate(8, (_) => _random.nextInt(10)).join(),
      displayHash: _hash(),
      issuedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<DateTime> fetchServerTime() async {
    await _sleep();
    // The stub has no clock of its own to disagree with, so a re-sync here
    // always succeeds and clears the skew.
    return DateTime.now().toUtc();
  }

  /// A `9F21-E83A`-shaped display hash.
  String _hash() {
    const alphabet = '0123456789ABCDEF';
    String block() => List.generate(
      4,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return '${block()}-${block()}';
  }
}
