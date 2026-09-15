/// Route paths and names, in one place.
///
/// Names are used for navigation ([GoRouter.goNamed]) so call sites do not
/// hard-code paths; paths are what the deep-link configuration must match.
/// Keeping both here means a URL change is one edit and cannot desynchronise
/// from the native intent filters and associated-domains entries.
abstract final class AppRoutes {
  /// The public web origin these paths mirror.
  ///
  /// Universal links and app links are configured against it, so a shared
  /// link opens the app when installed and the website when not. Kept here
  /// beside the paths so the two cannot drift.
  static const String webOrigin = 'https://tazkerah.app';

  // Bootstrap
  static const String splash = '/';
  static const String splashName = 'splash';

  // Auth
  static const String login = '/login';
  static const String loginName = 'login';

  /// Code verification. Reached only from [login], which passes the
  /// identifier it just submitted.
  static const String otp = '/login/verify';
  static const String otpName = 'otp';

  static const String register = '/register';
  static const String registerName = 'register';

  // Main shell
  static const String home = '/home';
  static const String homeName = 'home';

  static const String events = '/events';
  static const String eventsName = 'events';

  /// Deep-link target: `https://tazkerah.app/events/{id}`.
  static const String eventDetail = '/events/:id';
  static const String eventDetailName = 'eventDetail';

  /// Seat selection for an event: `/events/{id}/seats`.
  static const String eventSeats = 'seats';
  static const String eventSeatsName = 'eventSeats';

  /// Checkout for a granted hold: `/checkout/{holdReference}`.
  static const String checkout = '/checkout/:hold';
  static const String checkoutName = 'checkout';

  /// Order confirmation after returning from the payment gateway.
  static const String orderConfirmation = '/orders/:reference';
  static const String orderConfirmationName = 'orderConfirmation';

  static const String tickets = '/tickets';
  static const String ticketsName = 'tickets';

  /// Deep-link target: `https://tazkerah.app/tickets/{id}`.
  static const String ticketDetail = '/tickets/:id';
  static const String ticketDetailName = 'ticketDetail';

  /// The rotating gate pass for a ticket: `/tickets/{id}/pass`.
  static const String ticketPass = 'pass';
  static const String ticketPassName = 'ticketPass';

  static const String concierge = '/concierge';
  static const String conciergeName = 'concierge';

  static const String profile = '/profile';
  static const String profileName = 'profile';

  /// Builds the path for an event, for use with `context.go`.
  static String eventDetailPath(String id) => '/events/$id';

  /// Builds the public, shareable URL for an event.
  static Uri eventShareUrl(String id) =>
      Uri.parse('$webOrigin${eventDetailPath(id)}');

  /// Builds the seat-selection path for an event.
  static String eventSeatsPath(String id) => '/events/$id/seats';

  /// Builds the order confirmation path.
  static String orderConfirmationPath(String reference) => '/orders/$reference';

  /// Builds the gate pass path for a ticket.
  static String ticketPassPath(String id) => '/tickets/$id/pass';

  /// Builds the checkout path for a hold reference.
  static String checkoutPath(String holdReference) =>
      '/checkout/$holdReference';

  /// Builds the path for a ticket, for use with `context.go`.
  static String ticketDetailPath(String id) => '/tickets/$id';
}
