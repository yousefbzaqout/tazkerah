import '../constants/app_constants.dart';

/// The app's source of time.
///
/// Nothing security-relevant should call `DateTime.now()` directly. A user can
/// change the device clock from Settings; if rotating ticket codes were
/// generated against it, they could shift the rotation window at will. This
/// class keeps an offset learned from server `Date` headers and hands out
/// corrected time instead.
///
/// Two clocks are in play, deliberately:
///
/// - **Wall time** ([now]) answers "what time is it", corrected by the offset.
///   Used to pick the rotation bucket a code belongs to.
/// - **Monotonic elapsed time** ([elapsed]) answers "how long since", and
///   cannot move backwards or jump. Used to drive the rotation timer, so that
///   changing the clock mid-session cannot skip or stall it.
///
/// The offset is a best effort, never an authority. The gate scanner holds the
/// trusted clock and rejects proofs outside its own tolerance, so a device with
/// a wrong clock gets a clear failure rather than a way through.
class AppClock {
  AppClock() : _monotonic = Stopwatch()..start();

  final Stopwatch _monotonic;

  Duration _offset = Duration.zero;
  DateTime? _syncedAt;

  /// Difference between server time and device time, as last observed.
  Duration get offset => _offset;

  /// When the offset was last refreshed, in corrected UTC. `null` if never.
  DateTime? get syncedAt => _syncedAt;

  /// Whether the offset is old enough to be worth warning about.
  ///
  /// A device offline for days may have drifted; the ticket UI should say so
  /// rather than let a scan fail unexplained at the gate.
  bool get isSyncStale {
    final syncedAt = _syncedAt;
    if (syncedAt == null) return true;
    return now.difference(syncedAt) > const Duration(hours: 48);
  }

  /// Whether the learned offset is large enough that generated codes would
  /// fall outside a gate scanner's tolerance.
  ///
  /// Distinct from [isSyncStale], which asks how *old* the offset is. A device
  /// synced a minute ago can still be badly skewed, and a device synced two
  /// days ago may be perfectly accurate — the two conditions warrant different
  /// responses, so they are separate questions.
  bool get isSkewExcessive =>
      _offset.abs() > AppConstants.clockSkewSuppressionThreshold;

  /// Current time in UTC, corrected by the server offset.
  ///
  /// Use this for anything a server or scanner will also reason about.
  DateTime get now => DateTime.now().toUtc().add(_offset);

  /// Time elapsed since this clock was created.
  ///
  /// Backed by a monotonic source, so it is immune to clock changes. Use it
  /// for durations and timers, never for "what time is it".
  Duration get elapsed => _monotonic.elapsed;

  /// Records the offset implied by [serverTime].
  void syncTo(DateTime serverTime) {
    _offset = serverTime.toUtc().difference(DateTime.now().toUtc());
    _syncedAt = serverTime.toUtc();
  }

  /// Restores a previously persisted offset at startup, so the first launch
  /// after being offline still generates codes against corrected time.
  void restore({required Duration offset, DateTime? syncedAt}) {
    _offset = offset;
    _syncedAt = syncedAt?.toUtc();
  }
}
