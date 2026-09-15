import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/ticket.dart';
import 'wallet_controller.dart';

/// One ticket, loaded by id.
sealed class TicketDetailState {
  const TicketDetailState();
}

class TicketDetailLoading extends TicketDetailState {
  const TicketDetailLoading();
}

class TicketDetailReady extends TicketDetailState {
  const TicketDetailReady(this.ticket);
  final Ticket ticket;
}

class TicketDetailFailed extends TicketDetailState {
  const TicketDetailFailed(this.failure);
  final Failure failure;

  /// A ticket that does not exist gets a way back rather than a retry.
  bool get isMissing => failure is NotFoundFailure;
}

/// Loads one ticket for the detail screen.
class TicketDetailController extends Notifier<TicketDetailState> {
  TicketDetailController(this._ticketId);

  final String _ticketId;
  int _requestToken = 0;
  bool _disposed = false;

  @override
  TicketDetailState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(load);
    return const TicketDetailLoading();
  }

  Future<void> load() async {
    final token = ++_requestToken;
    state = const TicketDetailLoading();

    try {
      final ticket = await ref
          .read(ticketsRepositoryProvider)
          .fetchTicket(_ticketId);
      if (_disposed || token != _requestToken) return;
      state = TicketDetailReady(ticket);
    } on Failure catch (failure) {
      if (_disposed || token != _requestToken) return;
      state = TicketDetailFailed(failure);
    } catch (e, stack) {
      if (_disposed || token != _requestToken) return;
      developer.log(
        'Ticket load failed unexpectedly',
        name: 'tickets',
        error: e,
        stackTrace: stack,
      );
      state = TicketDetailFailed(UnknownFailure(debugMessage: e.toString()));
    }
  }
}

final ticketDetailControllerProvider =
    NotifierProvider.family<TicketDetailController, TicketDetailState, String>(
      TicketDetailController.new,
      isAutoDispose: true,
    );
