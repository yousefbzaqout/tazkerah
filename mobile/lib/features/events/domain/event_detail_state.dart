import '../../../core/errors/failure.dart';
import 'event_detail.dart';

/// What the event detail screen is showing.
///
/// Smaller than [DiscoveryState] on purpose: there is no cache, no pagination
/// and no search here — one event either loaded or it did not. Modelling it as
/// a sealed hierarchy rather than a status enum plus nullable fields means the
/// screen cannot read `detail` in a state where it was never set.
sealed class EventDetailState {
  const EventDetailState();
}

/// The first load is in flight.
class EventDetailLoading extends EventDetailState {
  const EventDetailLoading();
}

/// The event is on screen.
class EventDetailReady extends EventDetailState {
  const EventDetailReady(this.detail, {this.isRefreshing = false});

  final EventDetail detail;

  /// A refresh is running behind the content already shown. Kept distinct from
  /// [EventDetailLoading] so a pull-to-refresh never replaces a rendered
  /// screen with a spinner.
  final bool isRefreshing;

  EventDetailReady copyWith({EventDetail? detail, bool? isRefreshing}) =>
      EventDetailReady(
        detail ?? this.detail,
        isRefreshing: isRefreshing ?? this.isRefreshing,
      );
}

/// The event could not be loaded and there is nothing to show.
class EventDetailError extends EventDetailState {
  const EventDetailError(this.failure);

  final Failure failure;

  /// Whether this is a missing event rather than a transient fault.
  ///
  /// The distinction changes what the screen offers: a network error gets
  /// "Retry", while a 404 gets a way back to the feed, because retrying a
  /// deleted event will fail the same way every time.
  bool get isMissing => failure is NotFoundFailure;
}
