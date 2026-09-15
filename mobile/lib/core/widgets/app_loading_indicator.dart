import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Centred progress indicator with an optional caption.
///
/// One implementation so loading looks the same everywhere, and so a future
/// switch to skeleton placeholders is a single change.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
