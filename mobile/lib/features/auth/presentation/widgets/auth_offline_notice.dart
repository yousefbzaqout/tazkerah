import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/extensions/build_context_x.dart';

/// The amber "Offline — Network connection required" badge under the tagline.
///
/// Not built on [AppBanner]: this is a compact single-line badge sized to its
/// content, where the shared banner is a block with an icon, title and body.
/// Forcing one to serve both would mean a pile of flags on the shared widget.
class AuthOfflineNotice extends StatelessWidget {
  const AuthOfflineNotice({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 1,
        vertical: AppSpacing.sm + 1,
      ),
      decoration: BoxDecoration(
        color: semantic.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: semantic.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: semantic.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Flexible(
            child: Text(
              label,
              style: context.textStyles.bodySmall?.copyWith(
                color: AppColors.warningText,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
