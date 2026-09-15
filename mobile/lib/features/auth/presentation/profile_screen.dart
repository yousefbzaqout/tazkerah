import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/platform/app_info.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_status_pill.dart';
import '../domain/profile_state.dart';
import '../domain/user_profile.dart';
import 'controllers/profile_controller.dart';

/// Profile, account details, and sign-out.
///
/// Sits in the auth feature because its content is the signed-in user's own
/// account. It is deliberately sparse: this is a ticket wallet, and a profile
/// screen that collected more than sign-in and a purchase already required
/// would be asking for data the product has no use for.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: switch (state) {
        ProfileLoading() => const AppLoadingIndicator(),
        ProfileFailed(:final failure) => AppErrorView(
          failure: failure,
          onRetry: controller.load,
        ),
        ProfileReady() => _ProfileBody(
          state: state,
          appInfo: ref.read(appInfoProvider),
          onSignOut: () => _confirmSignOut(context, controller),
        ),
      },
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    ProfileController controller,
  ) async {
    final l10n = context.l10n;

    // Confirmed rather than immediate: signing out wipes this device's key
    // material, so the passes on it stop working until the user signs in
    // again. That is not something to do on a mis-tap.
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: l10n.profileSignOutTitle,
        message: l10n.profileSignOutMessage,
        confirmLabel: l10n.profileSignOutConfirm,
        cancelLabel: l10n.profileStay,
        tone: AppStatusTone.failed,
        icon: Icons.logout,
      ),
    );
    if (confirmed != true) return;

    // Not guarded on `context.mounted`: the router moves the user the moment
    // auth state flips, and this screen going away is the expected outcome
    // rather than a reason to skip the wipe.
    await controller.signOut();
  }
}

/// The loaded profile.
class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.state,
    required this.appInfo,
    required this.onSignOut,
  });

  final ProfileReady state;
  final AppInfo appInfo;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final profile = state.profile;
    final locale = Localizations.localeOf(context).toString();
    final memberSince = profile.memberSince;
    final email = profile.email;
    final phone = profile.phone;
    final deviceId = profile.deviceId;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Identity(profile: profile),
        if (memberSince != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              l10n.profileMemberSince(
                DateFormat.yMMMM(locale).format(memberSince),
              ),
              style: context.textStyles.bodySmall?.copyWith(
                color: semantic.textTertiary,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        _Section(label: l10n.profileAccountSection),
        _Panel(
          children: [
            if (email != null)
              _Row(
                label: l10n.profileEmailLabel,
                value: email,
                // An address is a machine value: bidi reordering would
                // scramble it in Arabic.
                valueDirection: TextDirection.ltr,
              ),
            if (phone != null)
              _Row(
                label: l10n.profilePhoneLabel,
                value: phone,
                valueDirection: TextDirection.ltr,
              ),
            if (email == null && phone == null)
              _Row(
                label: l10n.authIdentifierLabel,
                value: profile.identifier,
                valueDirection: TextDirection.ltr,
              ),
          ],
        ),

        if (deviceId != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _Section(label: l10n.profileSecuritySection),
          _Panel(
            children: [
              _Row(
                label: l10n.profileDeviceLabel,
                value: deviceId,
                valueDirection: TextDirection.ltr,
                valueColor: semantic.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Binding is the anti-sharing property of the whole ticket design.
          // A user who cannot see it cannot reason about why a new phone
          // loses their passes.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 13,
                color: semantic.textDisabled,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.profileDeviceNote,
                  style: context.textStyles.bodySmall?.copyWith(
                    fontSize: 11,
                    color: semantic.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        _Section(label: l10n.profileAppSection),
        _Panel(
          children: [
            _Row(
              label: l10n.profileLanguageLabel,
              // The app follows the device language; there is no in-app
              // switcher yet, so this reports rather than offers a control
              // that does nothing.
              value: l10n.profileLanguageSystem,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xxl),
        OutlinedButton(
          onPressed: state.isSigningOut ? null : onSignOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.error,
            side: BorderSide(
              color: context.colors.error.withValues(alpha: 0.5),
            ),
          ),
          child: state.isSigningOut
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.profileSignOut),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (appInfo.version.isNotEmpty)
          Center(
            child: Text(
              l10n.profileVersion(appInfo.version, appInfo.buildNumber),
              // A version is a machine value someone may read out to support:
              // LTR in any locale so the digits are not reordered.
              textDirection: TextDirection.ltr,
              style: AppTypography.mono.copyWith(
                fontSize: 10,
                color: semantic.textDisabled,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// The avatar, name and identifier.
class _Identity extends StatelessWidget {
  const _Identity({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: semantic.successContainer,
            shape: BoxShape.circle,
            border: Border.all(color: semantic.success.withValues(alpha: 0.4)),
          ),
          child: Text(
            profile.initials,
            style: AppTypography.monoValue.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: semantic.success,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          profile.displayName,
          style: context.textStyles.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// One uppercase mono section label.
class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTypography.monoEyebrow.copyWith(
          color: context.semantic.textTertiary,
        ),
      ),
    );
  }
}

/// A grouped block of rows.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: semantic.border),
      ),
      child: Column(children: children),
    );
  }
}

/// One label/value row.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueDirection,
    this.valueColor,
  });

  final String label;
  final String value;
  final TextDirection? valueDirection;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textStyles.bodyMedium?.copyWith(
                color: semantic.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textDirection: valueDirection,
              textAlign: TextAlign.end,
              style: valueDirection == null
                  ? context.textStyles.bodyMedium?.copyWith(color: valueColor)
                  : AppTypography.monoValue.copyWith(
                      fontSize: 13,
                      color: valueColor ?? context.colors.onSurface,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
