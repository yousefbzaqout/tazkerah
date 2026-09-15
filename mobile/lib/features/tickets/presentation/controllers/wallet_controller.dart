import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/dev_tickets_repository.dart';
import '../../domain/ticket.dart';
import '../../domain/tickets_repository.dart';
import '../../domain/wallet_state.dart';

/// Drives the ticket wallet.
///
/// Splits tickets into upcoming and past against the corrected clock rather
/// than the device's: a user whose phone is set wrong should still see their
/// evening's ticket in the right section.
class WalletController extends Notifier<WalletState> {
  int _requestToken = 0;
  bool _disposed = false;

  @override
  WalletState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(load);
    return const WalletLoading();
  }

  bool _isStale(int token) => _disposed || token != _requestToken;

  Future<void> load() async {
    final token = ++_requestToken;
    state = const WalletLoading();
    await _fetch(token);
  }

  /// Reloads without blanking the list already on screen.
  Future<void> refresh() async {
    final current = state;
    if (current is! WalletReady || current.isRefreshing) return load();

    final token = ++_requestToken;
    state = current.copyWith(isRefreshing: true);
    await _fetch(token, previous: current);
  }

  Future<void> _fetch(int token, {WalletReady? previous}) async {
    try {
      final tickets = await ref.read(ticketsRepositoryProvider).fetchTickets();
      if (_isStale(token)) return;

      final now = ref.read(clockProvider).now;
      final upcoming = <Ticket>[];
      final past = <Ticket>[];

      for (final ticket in tickets) {
        // A used ticket belongs to the past even for a future event: it has
        // been scanned, and showing it as upcoming would imply a second entry
        // that will not be granted.
        final isPast =
            ticket.status != TicketStatus.valid || ticket.hasStarted(now);
        (isPast ? past : upcoming).add(ticket);
      }

      // Soonest first among upcoming; most recent first among past.
      upcoming.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      past.sort((a, b) => b.startsAt.compareTo(a.startsAt));

      state = WalletReady(upcoming: upcoming, past: past);
    } on Failure catch (failure) {
      if (_isStale(token)) return;
      // A failed refresh keeps the tickets already on screen — the same rule
      // discovery follows.
      state = previous?.copyWith(isRefreshing: false) ?? WalletError(failure);
    } catch (e, stack) {
      if (_isStale(token)) return;
      developer.log(
        'Wallet load failed unexpectedly',
        name: 'tickets',
        error: e,
        stackTrace: stack,
      );
      state =
          previous?.copyWith(isRefreshing: false) ??
          WalletError(UnknownFailure(debugMessage: e.toString()));
    }
  }
}

/// Binds a concrete [TicketsRepository].
final ticketsRepositoryProvider = Provider<TicketsRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.environment == AppEnvironment.production) {
    throw UnimplementedError(
      'No production TicketsRepository is bound. The backend contract '
      '(GET /tickets) is still open — see TicketsRepository.',
    );
  }

  final repository = DevTicketsRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final walletControllerProvider =
    NotifierProvider<WalletController, WalletState>(WalletController.new);
