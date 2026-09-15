import '../../../core/errors/failure.dart';
import 'ticket.dart';

/// What the ticket wallet is showing.
sealed class WalletState {
  const WalletState();
}

class WalletLoading extends WalletState {
  const WalletLoading();
}

/// Tickets are on screen, split into what is coming and what has passed.
class WalletReady extends WalletState {
  const WalletReady({
    required this.upcoming,
    required this.past,
    this.isRefreshing = false,
  });

  /// Tickets for events still to come, soonest first — the ones a user opens
  /// the app to find.
  final List<Ticket> upcoming;

  /// Used, expired and refunded tickets. Kept rather than hidden: a receipt
  /// the user can no longer find is a support request.
  final List<Ticket> past;

  final bool isRefreshing;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;

  WalletReady copyWith({
    List<Ticket>? upcoming,
    List<Ticket>? past,
    bool? isRefreshing,
  }) {
    return WalletReady(
      upcoming: upcoming ?? this.upcoming,
      past: past ?? this.past,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

/// The wallet could not be loaded.
class WalletError extends WalletState {
  const WalletError(this.failure);

  final Failure failure;
}
