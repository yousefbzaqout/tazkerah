import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/features/auth/presentation/otp_screen.dart';
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
  group('OtpScreen', () {
    testWidgets('submits automatically on the final digit', (tester) async {
      // Saves a tap at the point the user is most likely to be hurrying.
      String? verified;
      await tester.pumpWidget(
        wrap(
          OtpScreen(
            identifier: 'user@domain.com',
            onVerify: (code) => verified = code,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).last, '704918');
      await tester.pumpAndSettle();

      expect(verified, '704918');
    });

    testWidgets('does not submit a partial code', (tester) async {
      var called = false;
      await tester.pumpWidget(
        wrap(
          OtpScreen(
            identifier: 'user@domain.com',
            onVerify: (_) => called = true,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).last, '7049');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify'));
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('rejects non-digits', (tester) async {
      await tester.pumpWidget(
        wrap(const OtpScreen(identifier: 'user@domain.com')),
      );

      await tester.enterText(find.byType(TextField).last, '7a4b9c');
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller?.text, '749');
    });

    testWidgets('caps input at the code length', (tester) async {
      await tester.pumpWidget(
        wrap(const OtpScreen(identifier: 'user@domain.com')),
      );

      await tester.enterText(find.byType(TextField).last, '1234567890');
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller?.text, '123456');
    });

    testWidgets('shows an inline error when the caller supplies one', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OtpScreen(
            identifier: 'user@domain.com',
            errorText: 'Invalid code. Try again.',
          ),
        ),
      );

      expect(find.text('Invalid code. Try again.'), findsOneWidget);
    });

    testWidgets('clears the error once the user starts correcting', (
      tester,
    ) async {
      // Leaving the boxes red under fresh input reads as "still wrong" before
      // anything has been checked.
      await tester.pumpWidget(
        wrap(
          const OtpScreen(
            identifier: 'user@domain.com',
            errorText: 'Invalid code. Try again.',
          ),
        ),
      );
      expect(find.text('Invalid code. Try again.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '1');
      await tester.pumpAndSettle();

      expect(find.text('Invalid code. Try again.'), findsNothing);
    });

    testWidgets('holds the resend link behind a cooldown', (tester) async {
      await tester.pumpWidget(
        wrap(
          OtpScreen(
            identifier: 'user@domain.com',
            resendCooldown: const Duration(seconds: 3),
            onResend: () {},
          ),
        ),
      );

      expect(find.text('Resend Code'), findsNothing);
      expect(find.textContaining('Resend in'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Resend Code'), findsOneWidget);
    });

    testWidgets('resending clears whatever was typed', (tester) async {
      var resent = false;
      await tester.pumpWidget(
        wrap(
          OtpScreen(
            identifier: 'user@domain.com',
            resendCooldown: Duration.zero,
            onResend: () => resent = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(resent, isTrue);
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('blocks input while submitting', (tester) async {
      await tester.pumpWidget(
        wrap(
          const OtpScreen(identifier: 'user@domain.com', isSubmitting: true),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.enabled, isFalse);
    });

    testWidgets('renders in Arabic right-to-left', (tester) async {
      await tester.pumpWidget(
        wrap(
          const OtpScreen(identifier: 'user@domain.com'),
          locale: const Locale('ar'),
        ),
      );

      expect(find.text('تحقّق'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('تحقّق'))),
        TextDirection.rtl,
      );
    });

    testWidgets('keeps the identifier left-to-right under Arabic', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OtpScreen(identifier: 'user@domain.com'),
          locale: const Locale('ar'),
        ),
      );

      final text = tester.widget<Text>(find.text('user@domain.com'));
      expect(text.textDirection, TextDirection.ltr);
    });
  });
}
