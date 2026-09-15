import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../event_formatting.dart';

/// The cache notice that closes the offline frame: how old the data is, and a
/// way to try the network again.
///
/// The age is computed against [DateTime.now] at build time, not held in
/// state. It is intentionally coarse — `14m`, `2h` — so it stays accurate
/// enough without a ticking timer keeping the widget tree awake behind a
/// screen the user may simply be parked on.
class OfflineFooter extends StatelessWidget {
  const OfflineFooter({
    super.key,
    required this.cachedAt,
    this.onReconnect,
    this.isReconnecting = false,
  });

  /// When the shown rows were captured.
  final DateTime cachedAt;

  final VoidCallback? onReconnect;

  /// Swaps the button for a spinner while a retry is in flight, so the tap
  /// visibly did something on a connection that is slow rather than absent.
  final bool isReconnecting;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final l10n = context.l10n;

    final age = DateTime.now().toUtc().difference(cachedAt.toUtc());

    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.md + 1),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: semantic.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: semantic.warning.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: Text(
              l10n.discoveryLastSynchronized(
                EventFormatting.shortAge(context, age),
              ),
              style: AppTypography.mono.copyWith(
                fontSize: 11,
                color: semantic.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isReconnecting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: semantic.warning,
              ),
            )
          else
            TextButton.icon(
              onPressed: onReconnect,
              icon: Icon(Icons.refresh, size: 12, color: semantic.warning),
              label: Text(
                l10n.discoveryReconnect,
                style: AppTypography.mono.copyWith(
                  fontSize: 11,
                  color: semantic.warning,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
