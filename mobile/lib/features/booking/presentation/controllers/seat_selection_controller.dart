import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/clock.dart';
import '../../data/dev_booking_repository.dart';
import '../../domain/booking_repository.dart';
import '../../domain/seat.dart';
import '../../domain/seat_selection_state.dart';

/// Drives seat selection: load the map, choose a seat, hold it, and run the
/// countdown until the server would release it.
///
/// Two rules shape everything here:
///
/// 1. **The server owns the deadline.** The countdown is recomputed each tick
///    from the hold's absolute `expires_at` against [AppClock], never
///    decremented locally. A subtracted counter drifts while backgrounded and
///    would keep showing time on a hold the server has already released.
///
/// 2. **409 and 423 are answers, not errors.** Losing a seat race or hitting a
///    locked sector produces the designed toast and sheet over a working map,
///    not an error screen. Only a failure to load the map at all is an error.
class SeatSelectionController extends Notifier<SeatSelectionState> {
  SeatSelectionController(this._eventId);

  /// The event whose hall this is, handed over by the family.
  final String _eventId;

  /// How often the hold countdown is refreshed.
  ///
  /// One second, because the design prints whole seconds. The value is *read*
  /// from the clock each tick rather than accumulated, so a late or coalesced
  /// tick corrects itself instead of compounding.
  static const Duration tickInterval = Duration(seconds: 1);

  Timer? _ticker;
  int _requestToken = 0;
  bool _disposed = false;

  @override
  SeatSelectionState build() {
    ref.onDispose(() {
      _disposed = true;
      _ticker?.cancel();
    });
    Future.microtask(load);
    return const SeatSelectionState();
  }

  BookingRepository get _repository => ref.read(bookingRepositoryProvider);
  AppClock get _clock => ref.read(clockProvider);

  bool _isStale(int token) => _disposed || token != _requestToken;

  /// Fetches the hall layout.
  Future<void> load() async {
    final token = ++_requestToken;
    state = const SeatSelectionState();

    try {
      final sectors = await _repository.fetchSeatMap(_eventId);
      if (_isStale(token)) return;
      state = state.copyWith(
        phase: SeatSelectionPhase.selecting,
        sectors: sectors,
      );
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      state = state.copyWith(phase: SeatSelectionPhase.error, failure: failure);
    } catch (e, stack) {
      if (_isStale(token)) return;
      _report('Seat map load failed unexpectedly', e, stack);
      state = state.copyWith(
        phase: SeatSelectionPhase.error,
        failure: UnknownFailure(debugMessage: e.toString()),
      );
    }
  }

  /// Selects a seat, or opens the locked-sector sheet if its sector is
  /// withheld.
  ///
  /// Selecting is purely local — no request is made until [holdSelectedSeat].
  /// That keeps tapping around the map free, and confines the race to the one
  /// moment it genuinely exists.
  void selectSeat(String seatId) {
    if (!state.isMapInteractive) return;

    final sector = _sectorFor(seatId);
    if (sector == null) return;

    // A locked sector answers before anything is selected: the design shows
    // the sheet on the attempt, not after a failed hold.
    if (sector.isLocked) {
      state = state.copyWith(lockedSector: sector, clearConflict: true);
      return;
    }
    if (sector.isContextOnly) return;

    final seat = state.allSeats.firstWhere(
      (s) => s.id == seatId,
      orElse: () => throw StateError('Unknown seat $seatId'),
    );
    if (!seat.isSelectable) return;

    // Choosing a different seat clears a previous conflict: the toast is
    // about the seat that was lost, and it has been answered by moving on.
    state = state.copyWith(selectedSeatId: seatId, clearConflict: true);
  }

  /// Clears the current selection without holding.
  void clearSelection() {
    if (state.selectedSeatId == null) return;
    state = state.copyWith(clearSelection: true);
  }

  /// Reserves the selected seat.
  ///
  /// On 409 the seat is marked [SeatStatus.conflict] in place, the selection
  /// is cleared, and the toast is raised — which is exactly what the design
  /// shows: the map stays usable and the lost seat is marked on it.
  Future<void> holdSelectedSeat() async {
    final seatId = state.selectedSeatId;
    if (seatId == null || state.isSubmitting) return;

    final token = ++_requestToken;
    state = state.copyWith(isSubmitting: true, clearConflict: true);

    try {
      final hold = await _repository.holdSeat(
        eventId: _eventId,
        seatId: seatId,
      );
      if (_isStale(token)) return;

      state = state.copyWith(
        phase: SeatSelectionPhase.held,
        hold: hold,
        sectors: _withSeatStatus(seatId, SeatStatus.held),
        isSubmitting: false,
        remaining: hold.remaining(_clock.now),
        clearSelection: true,
      );
      _startTicker();
    } on ConflictFailure {
      if (_isStale(token)) return;
      _onSeatLost(seatId);
    } on LockedFailure {
      if (_isStale(token)) return;
      state = state.copyWith(
        lockedSector: _sectorFor(seatId),
        isSubmitting: false,
        clearSelection: true,
      );
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      // A transport failure leaves the map alone and reports itself; the seat
      // is neither held nor lost, so the selection survives for a retry.
      state = state.copyWith(isSubmitting: false, failure: failure);
    } catch (e, stack) {
      if (_isStale(token)) return;
      _report('Seat hold failed unexpectedly', e, stack);
      state = state.copyWith(
        isSubmitting: false,
        failure: UnknownFailure(debugMessage: e.toString()),
      );
    }
  }

  /// Marks a seat as lost to another guest and raises the conflict toast.
  void _onSeatLost(String seatId) {
    final seat = state.allSeats.where((s) => s.id == seatId).firstOrNull;
    final sector = _sectorFor(seatId);

    state = state.copyWith(
      sectors: _withSeatStatus(seatId, SeatStatus.conflict),
      conflict: SeatConflict(
        seatLabel: seat?.label ?? seatId,
        sectorName: _shortSectorName(sector),
      ),
      isSubmitting: false,
      clearSelection: true,
    );
  }

  /// Dismisses the conflict toast, leaving the lost seat marked on the map.
  void dismissConflict() {
    if (state.conflict == null) return;
    state = state.copyWith(clearConflict: true);
  }

  /// Closes the locked-sector sheet.
  void dismissLockedSector() {
    if (state.lockedSector == null) return;
    state = state.copyWith(clearLockedSector: true);
  }

  /// Releases the current hold and returns to selection.
  Future<void> releaseHold() async {
    final hold = state.hold;
    if (hold == null) return;

    _ticker?.cancel();
    final heldIds = hold.seatIds.toSet();
    state = state.copyWith(
      phase: SeatSelectionPhase.selecting,
      sectors: _withSeatsReleased(heldIds),
      clearHold: true,
      remaining: Duration.zero,
    );

    try {
      await _repository.releaseHold(hold.reference);
    } catch (e, stack) {
      // Deliberately swallowed: the hold expires on its own within minutes,
      // so a failed release costs the user nothing and is not worth an
      // interruption.
      _report('Hold release failed', e, stack);
    }
  }

  /// Starts the countdown against the corrected clock.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  /// Recomputes the remaining time from the server's deadline.
  void _tick() {
    final hold = state.hold;
    if (hold == null || _disposed) {
      _ticker?.cancel();
      return;
    }

    final now = _clock.now;
    if (hold.isExpired(now)) {
      _ticker?.cancel();
      // The server has released these seats, so the map must stop claiming
      // they are held. They return to available rather than staying emerald.
      state = state.copyWith(
        phase: SeatSelectionPhase.expired,
        sectors: _withSeatsReleased(hold.seatIds.toSet()),
        remaining: Duration.zero,
      );
      return;
    }

    state = state.copyWith(remaining: hold.remaining(now));
  }

  /// Restarts selection after a hold expired.
  Future<void> restartSelection() async {
    _ticker?.cancel();
    state = state.copyWith(clearHold: true, remaining: Duration.zero);
    await load();
  }

  /// Returns the sectors with one seat's status replaced.
  List<Sector> _withSeatStatus(String seatId, SeatStatus status) {
    return _mapSeats(
      (seat) => seat.id == seatId ? seat.copyWith(status: status) : seat,
    );
  }

  /// Returns the sectors with the given seats back on sale.
  List<Sector> _withSeatsReleased(Set<String> seatIds) {
    return _mapSeats(
      (seat) => seatIds.contains(seat.id)
          ? seat.copyWith(status: SeatStatus.available)
          : seat,
    );
  }

  List<Sector> _mapSeats(Seat Function(Seat) transform) {
    return [
      for (final sector in state.sectors)
        Sector(
          id: sector.id,
          name: sector.name,
          tierLabel: sector.tierLabel,
          priceMinor: sector.priceMinor,
          currency: sector.currency,
          isLocked: sector.isLocked,
          lockReason: sector.lockReason,
          isContextOnly: sector.isContextOnly,
          rows: [
            for (final row in sector.rows)
              SeatRow(
                label: row.label,
                seats: [for (final seat in row.seats) transform(seat)],
              ),
          ],
        ),
    ];
  }

  Sector? _sectorFor(String seatId) {
    for (final sector in state.sectors) {
      if (sector.seats.any((s) => s.id == seatId)) return sector;
    }
    return null;
  }

  /// The short sector name used on the conflict toast: `SECTOR VIP PRIME`
  /// reads as `VIP` beside a seat id.
  String? _shortSectorName(Sector? sector) {
    if (sector == null) return null;
    final withoutPrefix = sector.name.replaceFirst(
      RegExp(r'^SECTOR\s+', caseSensitive: false),
      '',
    );
    return withoutPrefix.split(' ').first;
  }

  /// Logs an unexpected failure. Phase 8 points this at the crash reporter.
  void _report(String message, Object error, StackTrace stack) {
    developer.log(message, name: 'booking', error: error, stackTrace: stack);
  }
}

/// Binds a concrete [BookingRepository].
///
/// No real implementation exists yet — the endpoints in [BookingRepository]
/// have not been agreed. Binds the dev stub outside production and throws
/// inside it, so a release cannot ship against simulated seat inventory.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.environment == AppEnvironment.production) {
    throw UnimplementedError(
      'No production BookingRepository is bound. The backend contract '
      '(GET /events/{id}/seats, POST /events/{id}/holds) is still open — '
      'see BookingRepository.',
    );
  }

  final repository = DevBookingRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Auto-disposed, for the same reason as [checkoutControllerProvider].
///
/// Keyed on the event id, a cached controller outlives the screen, and
/// [SeatSelectionPhase.expired] is terminal unless something calls
/// [SeatSelectionController.restartSelection]. Returning to the same event
/// after a hold lapsed would otherwise re-attach to that dead state — the map
/// still expired, the seats still unbuyable — because [build] runs only once
/// per key.
final seatSelectionControllerProvider =
    NotifierProvider.family<
      SeatSelectionController,
      SeatSelectionState,
      String
    >(SeatSelectionController.new, isAutoDispose: true);
