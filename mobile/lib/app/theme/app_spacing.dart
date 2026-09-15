/// Spacing and radius scale.
///
/// A fixed scale rather than ad-hoc numbers: it keeps rhythm consistent across
/// screens built by different people, and makes a global adjustment one edit.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// For the ticket card's cut-out notches.
  static const double ticketNotch = 12;
}
