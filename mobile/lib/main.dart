import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/providers/core_providers.dart';
import 'core/utils/app_bootstrap.dart';

/// Entry point.
///
/// Runs inside a guarded zone so that asynchronous errors escaping the widget
/// tree are captured rather than lost. Both handlers currently log; Phase 8
/// points them at the crash reporter, and this is the single place that
/// changes.
Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Errors raised during build, layout and paint.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        developer.log(
          'Flutter error',
          name: 'app',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      // Errors from the engine that never reach the framework.
      PlatformDispatcher.instance.onError = (error, stack) {
        developer.log(
          'Platform error',
          name: 'app',
          error: error,
          stackTrace: stack,
        );
        return true;
      };

      final bootstrap = await AppBootstrap.run();

      runApp(
        // The single ProviderScope for the app. Everything resolvable lives
        // under it; tests build their own with overrides.
        ProviderScope(
          // Seeded with what startup already read, so no screen has to await
          // a platform value it needs on its first frame.
          overrides: [appInfoProvider.overrideWithValue(bootstrap.appInfo)],
          child: const TazkerahApp(),
        ),
      );
    },
    (error, stack) {
      developer.log(
        'Uncaught zone error',
        name: 'app',
        error: error,
        stackTrace: stack,
      );
    },
  );
}
