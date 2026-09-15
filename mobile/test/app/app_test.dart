import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/app.dart';
import 'package:tazkerah/features/auth/presentation/auth_screen.dart';
import 'package:tazkerah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/auth_harness.dart';

/// Builds the app with platform-backed dependencies replaced, in whichever
/// session state the test needs.
///
/// Returns the container so the test can wait on the startup session check.
(Widget, ProviderContainer) buildTestApp({required bool signedIn}) {
  final container = signedIn ? signedInContainer() : signedOutContainer();
  return (
    UncontrolledProviderScope(container: container, child: const TazkerahApp()),
    container,
  );
}

void main() {
  group('TazkerahApp auth gate', () {
    testWidgets('sends a signed-out user to auth, not home', (tester) async {
      // The whole point of the gate: home must never be reachable without a
      // session, including on a cold launch.
      final (app, container) = buildTestApp(signedIn: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await settleAuth(tester, container);

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('lets a signed-in user through to the shell', (tester) async {
      final (app, container) = buildTestApp(signedIn: true);
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await settleAuth(tester, container);

      expect(find.byType(AuthScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('moves to the shell the moment a session appears', (
      tester,
    ) async {
      // Signing in must not require the screen to navigate itself — the
      // router's refreshListenable does it.
      final (app, container) = buildTestApp(signedIn: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await settleAuth(tester, container);
      expect(find.byType(AuthScreen), findsOneWidget);

      await container
          .read(authControllerProvider)
          .markAuthenticated(refreshToken: 'granted');
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('returns to auth on sign-out', (tester) async {
      final (app, container) = buildTestApp(signedIn: true);
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await settleAuth(tester, container);
      expect(find.byType(NavigationBar), findsOneWidget);

      await container.read(authControllerProvider).signOut();
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });

  group('TazkerahApp shell', () {
    testWidgets('shows the four destinations', (tester) async {
      final (app, container) = buildTestApp(signedIn: true);
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await settleAuth(tester, container);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets('switches tabs without losing the shell', (tester) async {
      final (app, container) = buildTestApp(signedIn: true);
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await settleAuth(tester, container);

      await tester.tap(find.byIcon(Icons.confirmation_number_outlined));
      await tester.pumpAndSettle();

      expect(find.text('My Tickets'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('Localization', () {
    testWidgets('supports English and Arabic', (tester) async {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(<String>['en', 'ar']),
      );
    });

    testWidgets('renders Arabic strings right-to-left', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Text(AppLocalizations.of(context).navTickets),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تذاكري'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('تذاكري'))),
        TextDirection.rtl,
      );
    });
  });
}
