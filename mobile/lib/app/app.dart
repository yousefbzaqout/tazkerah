import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/presentation/reminder_providers.dart';
import '../l10n/generated/app_localizations.dart';
import 'reminder_sync.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// The root widget.
///
/// A [ConsumerWidget] so the router comes from the provider graph rather than
/// a global: Phase 2 adds auth-driven redirects, and this needs to rebuild
/// when that state changes.
class TazkerahApp extends ConsumerWidget {
  const TazkerahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      // Resolved per locale rather than hard-coded, so the Arabic title shows
      // in the task switcher on an Arabic device.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,

      routerConfig: router,

      // The design is dark only — no light frames exist — so the app pins the
      // dark theme rather than following the OS. Generating a light scheme
      // would invent surfaces nobody designed, and the ticket screens rely on
      // a dark field for scanner contrast.
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,

      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      // Reminder scheduling is mounted above the router, not on the wallet
      // screen. The OS drops pending notifications on reboot and reinstall, so
      // the reconcile has to run whenever the app runs rather than only when
      // the user happens to open a particular tab.
      //
      // Deliberately not a nested ProviderScope: that would build a second
      // container, and ReminderSync would then watch a different wallet than
      // the screens do. The locale reaches the scheduler through a provider
      // this widget keeps current instead.
      builder: (context, child) {
        final locale = Localizations.localeOf(context);
        return Consumer(
          builder: (context, ref, _) {
            // Set during build, so deferred to avoid mutating a provider
            // while the tree is being built.
            Future.microtask(
              () => ref.read(reminderLocaleProvider.notifier).set(locale),
            );
            return ReminderSync(child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}
