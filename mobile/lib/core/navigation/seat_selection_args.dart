/// What a caller hands to the seat selection route.
///
/// Lives in `core/` rather than in either feature because both sides touch it:
/// `features/events` constructs it when opening seat selection, and
/// `features/booking` reads it. The architecture forbids one feature importing
/// another, and this is exactly the case that rule anticipates — when two
/// features need the same thing, it moves here.
///
/// Everything on it is optional display text the previous screen already
/// holds, passed as GoRouter `extra` rather than encoded in the path: a title
/// in a URL would make the link fragile, and a cold deep link simply arrives
/// without it. This is an optimisation that saves a refetch, never a
/// requirement.
class SeatSelectionArgs {
  const SeatSelectionArgs({this.title, this.venue});

  /// The event name shown in the seat selection header.
  final String? title;

  /// The hall line: `BANBAN ARENA · HALL 01`.
  final String? venue;
}
