import 'ticket.dart';

/// What the ticket wallet needs from the backend.
///
/// Declared in domain so the controllers and their tests do not depend on how
/// it is fulfilled. The endpoints below are the contract this app expects; the
/// backend has not agreed them:
///
///   GET /tickets            -> {data: [...]}
///   GET /tickets/{id}       -> {ticket}
///   GET /orders/{reference} -> {ticket, ...}   (after payment returns)
abstract interface class TicketsRepository {
  /// Every ticket the signed-in user holds, newest event first.
  Future<List<Ticket>> fetchTickets();

  /// One ticket in full.
  ///
  /// Throws [NotFoundFailure] for an id that does not exist — a stale link or
  /// a ticket transferred away.
  Future<Ticket> fetchTicket(String ticketId);

  /// The ticket issued for a completed order.
  ///
  /// Called when the user returns from the payment gateway. Throws
  /// [NotFoundFailure] while the payment is still settling, which the
  /// confirmation screen treats as "not yet" rather than as an error.
  Future<Ticket> fetchTicketForOrder(String orderReference);
}
