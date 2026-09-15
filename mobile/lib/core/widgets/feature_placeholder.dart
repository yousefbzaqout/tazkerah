import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Scaffolding for a feature that has not been built yet.
///
/// Exists so the router, the shell navigation and the localization pipeline
/// can be exercised end to end before any feature UI lands. Every use of this
/// is a slot for real work in a later phase, and each is deleted as that
/// phase completes.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.title,
    required this.phase,
    this.icon = Icons.construction_outlined,
  });

  /// Screen name, shown in the app bar.
  final String title;

  /// The delivery phase that will replace this, e.g. `'Phase 3'`.
  final String phase;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                phase,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
