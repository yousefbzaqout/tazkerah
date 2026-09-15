import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_colors.dart';
import 'package:tazkerah/app/theme/app_semantic_colors.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/extensions/build_context_x.dart';
import 'package:tazkerah/core/widgets/app_status_pill.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

/// Renders [child] under the real theme, for both locales.
Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('AppTheme', () {
    test('is dark, matching a design that has no light frames', () {
      final theme = AppTheme.dark();

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('carries the semantic colour extension', () {
      // Without this, every `context.semantic` read falls back rather than
      // reading the theme, and the token layer is silently bypassed.
      final theme = AppTheme.dark();

      expect(theme.extension<AppSemanticColors>(), isNotNull);
    });

    test('uses the design palette, not a generated scheme', () {
      final scheme = AppTheme.dark().colorScheme;

      expect(scheme.primary, AppColors.primary);
      expect(scheme.onPrimary, AppColors.onPrimary);
      expect(scheme.error, AppColors.danger);
    });

    test('primary foreground is dark enough to read on emerald', () {
      // The emerald is bright; white-on-emerald fails contrast, which is why
      // onPrimary is near-black. Guard it so a future palette edit cannot
      // quietly reintroduce unreadable buttons.
      final scheme = AppTheme.dark().colorScheme;
      final contrast =
          (scheme.primary.computeLuminance() + 0.05) /
          (scheme.onPrimary.computeLuminance() + 0.05);

      expect(contrast, greaterThan(4.5), reason: 'WCAG AA for body text');
    });

    test('gives buttons a touch target of at least 44dp', () {
      final size = AppTheme.dark().filledButtonTheme.style?.minimumSize
          ?.resolve({});

      expect(size, isNotNull);
      expect(size!.height, greaterThanOrEqualTo(44));
    });
  });

  group('context.semantic', () {
    testWidgets('reads the extension from the app theme', (tester) async {
      late AppSemanticColors resolved;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              resolved = context.semantic;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved.success, AppColors.primary);
      expect(resolved.warning, AppColors.warning);
    });

    testWidgets('falls back instead of crashing without the extension', (
      tester,
    ) async {
      // A bare MaterialApp is what tests and previews produce. Crashing there
      // would make every such harness unusable.
      late AppSemanticColors resolved;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = context.semantic;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved.success, AppColors.primary);
    });
  });

  group('AppStatusPill', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(wrap(const AppStatusPill(label: 'CACHED')));

      expect(find.text('CACHED'), findsOneWidget);
    });

    testWidgets('colours by tone, not by a caller-passed hex', (tester) async {
      for (final (tone, expected) in [
        (AppStatusTone.live, AppColors.primary),
        (AppStatusTone.degraded, AppColors.warning),
        (AppStatusTone.failed, AppColors.danger),
      ]) {
        await tester.pumpWidget(wrap(AppStatusPill(label: 'X', tone: tone)));
        await tester.pump();

        final text = tester.widget<Text>(find.text('X'));
        expect(text.style?.color, expected, reason: 'for $tone');
      }
    });

    testWidgets('lays out under RTL', (tester) async {
      await tester.pumpWidget(
        wrap(const AppStatusPill(label: 'نشط'), locale: const Locale('ar')),
      );

      expect(find.text('نشط'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('نشط'))),
        TextDirection.rtl,
      );
    });
  });
}
