import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_concierge/presentation/concierge_screen.dart';
import '../../features/auth/presentation/sign_in_flow.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../core/navigation/seat_selection_args.dart';
import '../../features/booking/presentation/checkout_screen.dart';
import '../../features/booking/presentation/seat_selection_screen.dart';
import '../../features/events/presentation/events_screen.dart';
import '../../features/tickets/presentation/gate_pass_screen.dart';
import '../../features/tickets/presentation/order_confirmation_screen.dart';
import '../../features/tickets/presentation/ticket_detail_screen.dart';
import '../../features/tickets/presentation/tickets_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'app_shell.dart';
import 'routes.dart';

/// Navigator key for the root stack.
///
/// Held here so full-screen routes can opt out of the shell — the QR
/// presentation screen in Phase 5 must cover the navigation bar.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app's router.
///
/// Reads [authControllerProvider] so every navigation is gated on session
/// state, and passes the same controller as `refreshListenable` so the gate
/// re-runs the moment that state changes — signing in or out moves the user
/// without any screen calling `go` itself.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Launch on the splash screen, which shows while the session check runs.
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: auth,
    redirect: (context, state) => _guard(auth, state),
    errorBuilder: (context, state) => _RouteErrorScreen(uri: state.uri),
    routes: [
      // Outside the shell: neither screen has bottom navigation.
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const SignInFlow(),
      ),
      // Outside the shell: checkout is a focused, time-limited flow, and a
      // tab bar inviting the user away mid-payment would cost them the seats.
      GoRoute(
        path: AppRoutes.checkout,
        name: AppRoutes.checkoutName,
        builder: (context, state) {
          final extra = state.extra;
          return CheckoutScreen(
            holdReference: state.pathParameters['hold']!,
            eventId: extra is String ? extra : null,
          );
        },
      ),
      // Outside the shell: the user has just paid and is waiting on a result.
      // A tab bar inviting them elsewhere mid-settlement would be careless.
      GoRoute(
        path: AppRoutes.orderConfirmation,
        name: AppRoutes.orderConfirmationName,
        builder: (context, state) => OrderConfirmationScreen(
          orderReference: state.pathParameters['reference']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Each branch keeps an independent stack, so a detail screen pushed
          // in one tab survives a visit to another.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.events,
                name: AppRoutes.eventsName,
                builder: (context, state) => const EventsScreen(),
                routes: [
                  GoRoute(
                    // Relative to the parent, so the full path is /events/:id.
                    path: ':id',
                    name: AppRoutes.eventDetailName,
                    builder: (context, state) =>
                        EventDetailScreen(eventId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: AppRoutes.eventSeats,
                        name: AppRoutes.eventSeatsName,
                        builder: (context, state) {
                          // Title and venue ride along as `extra` so seat
                          // selection renders its header without refetching an
                          // event the previous screen already had. Absent on a
                          // cold deep link, which the screen handles.
                          final extra = state.extra;
                          final args = extra is SeatSelectionArgs
                              ? extra
                              : null;
                          return SeatSelectionScreen(
                            eventId: state.pathParameters['id']!,
                            eventTitle: args?.title,
                            venueLabel: args?.venue,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tickets,
                name: AppRoutes.ticketsName,
                builder: (context, state) => const TicketsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: AppRoutes.ticketDetailName,
                    builder: (context, state) => TicketDetailScreen(
                      ticketId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: AppRoutes.ticketPass,
                        name: AppRoutes.ticketPassName,
                        // Outside the shell: the pass is held under a scanner,
                        // and a tab bar is both a distraction and a strip of
                        // light the reader has to cope with.
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => GatePassScreen(
                          ticketId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.concierge,
                name: AppRoutes.conciergeName,
                builder: (context, state) => const ConciergeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: AppRoutes.profileName,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Decides where a navigation is allowed to land.
///
/// Returns `null` to allow the requested location, or a path to send the user
/// to instead. Runs on every navigation, including the first, so it is the
/// single place that enforces "auth before home".
///
/// Deep links are preserved across the gate: a signed-out user who opens
/// `/tickets/abc` is sent to login with that path kept in `?from=`, and lands
/// on the ticket once signed in rather than being dumped on the home tab.
String? _guard(AuthController auth, GoRouterState state) {
  final location = state.matchedLocation;
  final onSplash = location == AppRoutes.splash;
  final onLogin = location == AppRoutes.login;

  switch (auth.status) {
    // Hold on the splash while secure storage is read. Guessing either way
    // here flashes the wrong screen for a frame.
    case AuthStatus.unknown:
      return onSplash ? null : AppRoutes.splash;

    case AuthStatus.unauthenticated:
      if (onLogin) return null;
      // Remember where they were headed, unless it was the splash — there is
      // nothing to return to there.
      final from = onSplash ? null : state.uri.toString();
      return Uri(
        path: AppRoutes.login,
        queryParameters: from == null ? null : {'from': from},
      ).toString();

    case AuthStatus.authenticated:
      if (onSplash || onLogin) {
        // Honour a pending deep link if one survived the gate.
        final from = state.uri.queryParameters['from'];
        if (from != null && from.isNotEmpty) return from;
        return AppRoutes.events;
      }
      return null;
  }
}

/// Shown when a deep link does not match any route.
///
/// Not optional polish: the app advertises universal links, so it will be
/// handed URLs from outside — old campaign links, hand-edited addresses,
/// paths from a newer app version. Landing on a blank screen looks like a
/// crash, so this offers a way back.
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeNotFoundTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_off_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.routeNotFoundMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                uri.toString(),
                textAlign: TextAlign.center,
                // The offending URL is always shown LTR: it is a machine
                // identifier, and bidi reordering would misrepresent it.
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => context.goNamed(AppRoutes.eventsName),
                child: Text(l10n.routeGoHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
