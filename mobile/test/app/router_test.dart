import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tazkerah/app/router/app_router.dart';
import 'package:tazkerah/app/router/routes.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/auth_harness.dart';

/// Pumps the router at [location], the way an incoming deep link arrives.
Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
  // Signed in: these tests exercise routing and deep links, which sit behind
  // the auth gate.
  final container = signedInContainer();
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  router.go(location);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        // The real theme, so routed screens render against the same tokens
        // and theme extensions they will have in the app.
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await settleAuth(tester, container);
  // The gate resolves onto its destination first; only then is the requested
  // location honoured.
  router.go(location);
  await tester.pumpAndSettle();

  return router;
}

void main() {
  group('AppRoutes', () {
    test('builds detail paths that match the declared route patterns', () {
      expect(AppRoutes.eventDetailPath('evt_123'), '/events/evt_123');
      expect(AppRoutes.ticketDetailPath('tkt_456'), '/tickets/tkt_456');
    });
  });

  group('Router deep links', () {
    testWidgets('opens an event detail and passes the id through', (
      tester,
    ) async {
      await pumpAt(tester, AppRoutes.eventDetailPath('evt_123'));

      // The placeholder renders the id, which proves the path parameter
      // reached the screen rather than being dropped.
      expect(find.text('Event evt_123'), findsWidgets);
    });

    testWidgets('opens a ticket detail and passes the id through', (
      tester,
    ) async {
      await pumpAt(tester, AppRoutes.ticketDetailPath('tkt_456'));

      expect(find.text('Ticket tkt_456'), findsWidgets);
    });

    testWidgets('shows the not-found screen for an unknown link', (
      tester,
    ) async {
      // Stale campaign links and hand-edited URLs will happen; a blank screen
      // would read as a crash.
      await pumpAt(tester, '/this/route/does/not/exist');

      expect(find.text('Page not found'), findsWidgets);
      expect(find.text('Go to home'), findsOneWidget);
    });

    testWidgets('the not-found screen routes back to a real page', (
      tester,
    ) async {
      final router = await pumpAt(tester, '/nowhere');

      await tester.tap(find.text('Go to home'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.events,
      );
    });

    testWidgets('each tab keeps its own stack', (tester) async {
      // Push a detail in Events, switch tabs, come back: the detail should
      // still be there. This is the reason for StatefulShellRoute.
      await pumpAt(tester, AppRoutes.eventDetailPath('evt_789'));
      expect(find.text('Event evt_789'), findsWidgets);

      await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
      await tester.pumpAndSettle();
      expect(find.text('My Tickets'), findsWidgets);

      await tester.tap(find.byIcon(Icons.explore_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Event evt_789'), findsWidgets);
    });
  });
}
