import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/extensions/build_context_x.dart';

/// The "Terms of Service · Privacy Policy" footer.
///
/// Uses [Wrap] rather than [Row] so the two links stack instead of overflowing
/// when a translation runs long or the user raises the system text size — the
/// Arabic strings are wider than the English at the same size.
class AuthFooterLinks extends StatelessWidget {
  const AuthFooterLinks({super.key, this.onOpenTerms, this.onOpenPrivacy});

  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    final linkStyle = context.textStyles.bodySmall?.copyWith(
      color: semantic.textTertiary,
    );

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          _FooterLink(
            label: l10n.legalTerms,
            style: linkStyle,
            onTap: onOpenTerms,
          ),
          Text('•', style: linkStyle?.copyWith(color: AppColors.textFaint)),
          _FooterLink(
            label: l10n.legalPrivacy,
            style: linkStyle,
            onTap: onOpenPrivacy,
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.style, this.onTap});

  final String label;
  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        // Small inset so the tap target exceeds the glyph bounds without
        // visibly spacing the links apart.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Text(label, style: style),
      ),
    );
  }
}
