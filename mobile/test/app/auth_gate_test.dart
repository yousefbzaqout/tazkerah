import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tazkerah/app/router/app_router.dart';
import 'package:tazkerah/app/router/routes.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/storage_keys.dart';
import 'package:tazkerah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/auth_harness.dart';

/// Boots the router at [location] in the given session state.
Future<(GoRouter, ProviderContainer)> boot(
  WidgetTester tester, {
  required bool signedIn,
  String? location,
}) async {
  final container = signedIn ? signedInContainer() : signedOutContainer();
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  if (location != null) router.go(location);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await settleAuth(tester, container);

  return (router, container);
}

String currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  group('Auth gate', () {
    testWidgets('a cold launch lands on auth, never on home', (tester) async {
      final (router, _) = await boot(tester, signedIn: false);

      expect(currentPath(router), AppRoutes.login);
    });

    testWidgets('a cold launch with a session lands on events', (tester) async {
      final (router, _) = await boot(tester, signedIn: true);

      expect(currentPath(router), AppRoutes.events);
    });

    testWidgets('blocks a signed-out user from reaching a shell route', (
      tester,
    ) async {
      final (router, _) = await boot(
        tester,
        signedIn: false,
        location: AppRoutes.tickets,
      );

      expect(currentPath(router), AppRoutes.login);
    });

    testWidgets('keeps the intended destination through sign-in', (
      tester,
    ) async {
      // A push notification or universal link for a specific ticket must not
      // be lost just because the session had expired.
      final (router, container) = await boot(
        tester,
        signedIn: false,
        location: AppRoutes.ticketDetailPath('tkt_42'),
      );

      expect(currentPath(router), AppRoutes.login);
      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters['from'],
        AppRoutes.ticketDetailPath('tkt_42'),
      );

      await container
          .read(authControllerProvider)
          .markAuthenticated(refreshToken: 'granted');
      await tester.pumpAndSettle();

      expect(currentPath(router), AppRoutes.ticketDetailPath('tkt_42'));
    });

    testWidgets('sends a signed-in user away from the auth screen', (
      tester,
    ) async {
      final (router, _) = await boot(
        tester,
        signedIn: true,
        location: AppRoutes.login,
      );

      expect(currentPath(router), AppRoutes.events);
    });

    testWidgets('signing out from a deep route returns to auth', (
      tester,
    ) async {
      final (router, container) = await boot(
        tester,
        signedIn: true,
        location: AppRoutes.ticketDetailPath('tkt_7'),
      );
      expect(currentPath(router), AppRoutes.ticketDetailPath('tkt_7'));

      await container.read(authControllerProvider).signOut();
      await tester.pumpAndSettle();

      expect(currentPath(router), AppRoutes.login);
    });
  });

  group('AuthController', () {
    testWidgets('clears the device key on sign-out', (tester) async {
      // The signing key is bound to this account. Leaving it behind would let
      // the next user of the handset hold key material that is not theirs.
      final container = signedInContainer();
      addTearDown(container.dispose);

      final storage = container.read(secureStorageProvider);
      await storage.write(StorageKeys.devicePrivateKey, 'secret');

      await container.read(authControllerProvider).signOut();

      expect(await storage.read(StorageKeys.refreshToken), isNull);
      expect(await storage.read(StorageKeys.devicePrivateKey), isNull);
    });
  });
}
