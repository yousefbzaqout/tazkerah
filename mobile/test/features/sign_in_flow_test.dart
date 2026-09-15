import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/config/app_config.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/core/storage/storage_keys.dart';
import 'package:tazkerah/features/auth/data/dev_auth_repository.dart';
import 'package:tazkerah/features/auth/domain/sign_in_flow_state.dart';
import 'package:tazkerah/features/auth/presentation/auth_screen.dart';
import 'package:tazkerah/features/auth/presentation/controllers/sign_in_controller.dart';
import 'package:tazkerah/features/auth/presentation/otp_screen.dart';
import 'package:tazkerah/features/auth/presentation/sign_in_flow.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/fake_auth_repository.dart';

(Widget, ProviderContainer, FakeAuthRepository) buildFlow({
  Locale locale = const Locale('en'),
  FakeAuthRepository? repository,
}) {
  final repo = repository ?? FakeAuthRepository();
  final storage = InMemorySecureStorage();
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repo),
    ],
  );

  return (
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SignInFlow(),
      ),
    ),
    container,
    repo,
  );
}

/// Enters [code] into the OTP field.
Future<void> enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField).last, code);
  await tester.pumpAndSettle();
}

void main() {
  group('Sign-in flow', () {
    testWidgets('starts on identifier entry', (tester) async {
      final (app, container, _) = buildFlow();
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
    });

    testWidgets('advances to code entry after requesting a code', (
      tester,
    ) async {
      final (app, container, repo) = buildFlow();
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repo.requestedIdentifiers, ['user@domain.com']);
      expect(find.byType(OtpScreen), findsOneWidget);
    });

    testWidgets('shows the identifier the code was sent to', (tester) async {
      // A mistyped address should be obvious before the user waits for a
      // message that will never arrive.
      final (app, container, _) = buildFlow();
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('user@domain.com'), findsOneWidget);
    });

    testWidgets('a verified code establishes a session', (tester) async {
      final (app, container, repo) = buildFlow();
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await enterCode(tester, '704918');

      expect(repo.verifiedCodes, ['704918']);
      // The token reaching secure storage is what flips the router.
      final stored = await container
          .read(secureStorageProvider)
          .read(StorageKeys.refreshToken);
      expect(stored, 'fake-refresh-token');
    });

    testWidgets('a rejected code shows the invalid message', (tester) async {
      final repo = FakeAuthRepository(verifyFailure: SignInFailure.invalidCode);
      final (app, container, _) = buildFlow(repository: repo);
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await enterCode(tester, '704911');

      expect(find.text('Invalid code. Try again.'), findsOneWidget);
    });

    testWidgets('an expired code gets its own message, not the generic one', (
      tester,
    ) async {
      // The right action differs: a wrong code means retype, an expired one
      // means resend. One shared message would misdirect.
      final repo = FakeAuthRepository(verifyFailure: SignInFailure.expiredCode);
      final (app, container, _) = buildFlow(repository: repo);
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await enterCode(tester, '704911');

      expect(
        find.text('That code expired. Request a new one.'),
        findsOneWidget,
      );
    });

    testWidgets('editing the identifier returns to step one', (tester) async {
      final (app, container, _) = buildFlow();
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(OtpScreen), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('renders the flow in Arabic', (tester) async {
      final (app, container, _) = buildFlow(locale: const Locale('ar'));
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      expect(find.text('تحقّق'), findsOneWidget);
    });
  });

  group('authRepositoryProvider', () {
    test('binds the dev stub outside production', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(authRepositoryProvider), isA<DevAuthRepository>());
    });

    test('refuses to resolve in production', () {
      // The stub must never reach a release build. Riverpod 3 wraps a
      // provider's error, so match on the message rather than the bare type.
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.production,
              apiBaseUrl: 'https://api.tazkerah.app/api/v1',
              connectTimeout: Duration(seconds: 15),
              receiveTimeout: Duration(seconds: 30),
              sendTimeout: Duration(seconds: 30),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(authRepositoryProvider),
        throwsA(
          predicate(
            (e) => e.toString().contains('No production AuthRepository'),
          ),
        ),
      );
    });
  });

  group('Unexpected failures', () {
    testWidgets('surface in the UI instead of crashing the app', (
      tester,
    ) async {
      // Regression: an unbound provider threw out of submitIdentifier as an
      // uncaught zone error and took the app down on first tap.
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
          authRepositoryProvider.overrideWith(
            (ref) => throw StateError('boom'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SignInFlow(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('An unexpected error occurred.'), findsOneWidget);
      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });
}
