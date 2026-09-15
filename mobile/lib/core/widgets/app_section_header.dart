import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../extensions/build_context_x.dart';

/// The header that opens a section: a mono eyebrow with optional trailing
/// status, then a sans title.
///
/// From the design: `EXCLUSIVE GATE ENTRIES` / `● LIVE PASSES` above
/// "Select Experience", and `LOCAL CRYPTOGRAPHIC CACHE` / `● 2 PASSES READY`
/// in the offline variant.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;

  /// Uppercase mono label above the title. Callers pass it already localized
  /// and already uppercased — Dart's `toUpperCase` is not correct for every
  /// locale, and Arabic has no case at all.
  final String? eyebrow;

  /// Status widget aligned to the eyebrow, typically an [AppStatusPill].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final eyebrow = this.eyebrow;
    final trailing = this.trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null || trailing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                if (eyebrow != null)
                  Expanded(
                    child: Text(
                      eyebrow,
                      style: AppTypography.monoEyebrow.copyWith(
                        color: context.semantic.textTertiary,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
          ),
        Text(title, style: context.textStyles.headlineSmall),
      ],
    );
  }
}
