import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/platform/app_info.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/core/storage/storage_keys.dart';
import 'package:tazkerah/features/auth/domain/auth_state.dart';
import 'package:tazkerah/features/auth/domain/profile_state.dart';
import 'package:tazkerah/features/auth/domain/user_profile.dart';
import 'package:tazkerah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tazkerah/features/auth/presentation/controllers/profile_controller.dart';
import 'package:tazkerah/features/auth/presentation/controllers/sign_in_controller.dart';
import 'package:tazkerah/features/auth/presentation/profile_screen.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

import '../support/fake_auth_repository.dart';

(ProviderContainer, FakeAuthRepository, InMemorySecureStorage) build() {
  final repo = FakeAuthRepository();
  final storage = InMemorySecureStorage();
  // A signed-in device: a refresh token plus the key material sign-out must
  // also wipe.
  storage.write(StorageKeys.refreshToken, 'refresh');
  storage.write(StorageKeys.devicePrivateKey, 'private-key');
  storage.write(StorageKeys.deviceId, 'TZ-8841-A');

  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repo),
      appInfoProvider.overrideWithValue(
        const StaticAppInfo(version: '1.4.2', buildNumber: '77'),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container, repo, storage);
}

Widget wrap(ProviderContainer container, {Locale? locale}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProfileScreen(),
    ),
  );
}

Future<void> settle(ProviderContainer c) async {
  c.read(profileControllerProvider);
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
    if (c.read(profileControllerProvider) is! ProfileLoading) return;
  }
}

void main() {
  group('UserProfile', () {
    test('initials take the first and last words', () {
      const profile = UserProfile(
        id: 'u',
        displayName: 'Tariq Al-Mansoor',
        identifier: 't@example.com',
      );
      expect(profile.initials, 'TA');
    });

    test('a single name yields one initial', () {
      const profile = UserProfile(
        id: 'u',
        displayName: 'Tariq',
        identifier: 't@example.com',
      );
      expect(profile.initials, 'T');
    });

    test('initials work on Arabic names', () {
      const profile = UserProfile(
        id: 'u',
        displayName: 'طارق المنصور',
        identifier: 't@example.com',
      );
      // Arabic has no case, so `toUpperCase` leaves the letters as they are.
      expect(profile.initials, 'طا');
    });

    test('an empty name does not crash', () {
      const profile = UserProfile(
        id: 'u',
        displayName: '   ',
        identifier: 't@example.com',
      );
      expect(profile.initials, '?');
    });
  });

  group('ProfileController', () {
    test('loads the account', () async {
      final (container, _, _) = build();
      await settle(container);

      final state = container.read(profileControllerProvider);
      expect(state, isA<ProfileReady>());
      expect((state as ProfileReady).profile.displayName, 'Tariq Al-Mansoor');
    });

    test('a failure is retryable', () async {
      final (container, repo, _) = build();
      repo.profileFailure = const NetworkFailure();
      await settle(container);

      expect(container.read(profileControllerProvider), isA<ProfileFailed>());

      repo.profileFailure = null;
      await container.read(profileControllerProvider.notifier).load();
      expect(container.read(profileControllerProvider), isA<ProfileReady>());
    });

    test('signing out revokes the session and wipes key material', () async {
      final (container, repo, storage) = build();
      await settle(container);

      await container.read(profileControllerProvider.notifier).signOut();

      expect(repo.revokeCalls, 1);
      // All three must go together: a session ended with key material left
      // behind would leave a device that could still present passes.
      expect(await storage.read(StorageKeys.refreshToken), isNull);
      expect(await storage.read(StorageKeys.devicePrivateKey), isNull);
      expect(await storage.read(StorageKeys.deviceId), isNull);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('a failed revocation still signs out locally', () async {
      final (container, repo, storage) = build();
      await settle(container);

      // The server is unreachable. The user tapped sign out and must not be
      // left signed in on the device in front of them.
      repo.revokeFailure = const NetworkFailure();
      await container.read(profileControllerProvider.notifier).signOut();

      expect(await storage.read(StorageKeys.refreshToken), isNull);
      expect(await storage.read(StorageKeys.devicePrivateKey), isNull);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });
  });

  group('ProfileScreen', () {
    testWidgets('renders the account and device binding', (tester) async {
      final (container, _, _) = build();

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      expect(find.text('Tariq Al-Mansoor'), findsOneWidget);
      expect(find.text('TA'), findsOneWidget);
      expect(find.text('tariq@example.com'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('#TZ-8841-A'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('shows the real app version', (tester) async {
      final (container, _, _) = build();

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      // Read from the platform, not a constant: a hard-coded version would
      // drift from pubspec, and a version read out to support must be true.
      // It sits at the foot of a scrolling list, past the sign-out button.
      await tester.dragUntilVisible(
        find.text('Version 1.4.2 (77)'),
        find.byType(ListView),
        const Offset(0, -120),
      );
      expect(find.text('Version 1.4.2 (77)'), findsOneWidget);
    });

    testWidgets('sign out asks before wiping', (tester) async {
      final (container, repo, storage) = build();

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      // The button sits at the foot of a scrolling list; on a short test
      // surface it starts below the fold.
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out of Tazkerah?'), findsOneWidget);

      // Backing out must leave the session intact.
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();

      expect(repo.revokeCalls, 0);
      expect(await storage.read(StorageKeys.refreshToken), 'refresh');
    });

    testWidgets('renders right-to-left in Arabic', (tester) async {
      final (container, _, _) = build();

      await tester.pumpWidget(wrap(container, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('الملف الشخصي'), findsOneWidget);
      expect(find.text('الحساب'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('الحساب'))),
        TextDirection.rtl,
      );
    });
  });
}
