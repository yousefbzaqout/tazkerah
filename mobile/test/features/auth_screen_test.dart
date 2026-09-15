import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/features/auth/presentation/auth_screen.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group('AuthScreen online', () {
    testWidgets('shows the brand lockup in both scripts', (tester) async {
      await tester.pumpWidget(wrap(const AuthScreen()));

      expect(find.text('Tazkerah'), findsOneWidget);
      expect(find.text('تذكرة'), findsOneWidget);
    });

    testWidgets('submits a valid email', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        wrap(AuthScreen(onSubmit: (value) => submitted = value)),
      );

      await tester.enterText(find.byType(TextFormField), 'user@domain.com');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(submitted, 'user@domain.com');
    });

    testWidgets('submits a valid phone number', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        wrap(AuthScreen(onSubmit: (value) => submitted = value)),
      );

      await tester.enterText(find.byType(TextFormField), '+966512345678');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(submitted, '+966512345678');
    });

    testWidgets('trims surrounding whitespace before submitting', (
      tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        wrap(AuthScreen(onSubmit: (value) => submitted = value)),
      );

      await tester.enterText(find.byType(TextFormField), '  user@domain.com  ');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(submitted, 'user@domain.com');
    });

    testWidgets('blocks an empty submission', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(AuthScreen(onSubmit: (_) => called = true)));

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(called, isFalse);
      expect(find.text('Enter your email or phone number.'), findsOneWidget);
    });

    testWidgets('blocks a malformed identifier', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(AuthScreen(onSubmit: (_) => called = true)));

      await tester.enterText(find.byType(TextFormField), 'not-an-identifier');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(called, isFalse);
      expect(
        find.text('Enter a valid email address or phone number.'),
        findsOneWidget,
      );
    });

    testWidgets('surfaces a server error passed in by the caller', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const AuthScreen(errorText: 'That account is locked.')),
      );

      expect(find.text('That account is locked.'), findsOneWidget);
    });

    testWidgets('shows progress and blocks input while submitting', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        wrap(AuthScreen(isSubmitting: true, onSubmit: (_) => called = true)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(called, isFalse);
    });
  });

  group('AuthScreen offline', () {
    testWidgets('explains why sign-in is unavailable', (tester) async {
      await tester.pumpWidget(wrap(const AuthScreen(isOffline: true)));

      expect(
        find.text('Offline — Network connection required'),
        findsOneWidget,
      );
      expect(find.textContaining('Network unavailable.'), findsOneWidget);
      expect(find.text('Check connection'), findsOneWidget);
    });

    testWidgets('does not submit while offline', (tester) async {
      // Sign-in needs the server to issue a session, so offline must block
      // rather than queue — a queued attempt would look accepted and fail
      // later with no obvious cause.
      var called = false;
      await tester.pumpWidget(
        wrap(AuthScreen(isOffline: true, onSubmit: (_) => called = true)),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('disables the input field', (tester) async {
      await tester.pumpWidget(wrap(const AuthScreen(isOffline: true)));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.enabled, isFalse);
    });

    testWidgets('retries the connectivity check on tap', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        wrap(
          AuthScreen(isOffline: true, onRetryConnection: () => retried = true),
        ),
      );

      await tester.tap(find.text('Check connection'));
      await tester.pump();

      expect(retried, isTrue);
    });
  });

  group('AuthScreen localization', () {
    testWidgets('renders Arabic strings right-to-left', (tester) async {
      await tester.pumpWidget(
        wrap(const AuthScreen(), locale: const Locale('ar')),
      );

      expect(find.text('متابعة'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('متابعة'))),
        TextDirection.rtl,
      );
    });

    testWidgets('keeps the brand lockup left-to-right under Arabic', (
      tester,
    ) async {
      // The wordmark is a logo lockup, not prose: "Tazkerah تذكرة" must keep
      // its order even when the surrounding layout mirrors.
      await tester.pumpWidget(
        wrap(const AuthScreen(), locale: const Locale('ar')),
      );

      expect(
        Directionality.of(tester.element(find.text('Tazkerah'))),
        TextDirection.ltr,
      );
    });

    testWidgets('keeps the identifier field left-to-right under Arabic', (
      tester,
    ) async {
      // An email address or +966 number is a machine value; bidi reordering
      // would scramble how it reads back to the user.
      await tester.pumpWidget(
        wrap(const AuthScreen(), locale: const Locale('ar')),
      );

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.textDirection, TextDirection.ltr);
    });

    testWidgets('validates in Arabic', (tester) async {
      await tester.pumpWidget(
        wrap(const AuthScreen(), locale: const Locale('ar')),
      );

      await tester.tap(find.text('متابعة'));
      await tester.pump();

      expect(find.text('أدخل بريدك الإلكتروني أو رقم جوالك.'), findsOneWidget);
    });
  });
}
