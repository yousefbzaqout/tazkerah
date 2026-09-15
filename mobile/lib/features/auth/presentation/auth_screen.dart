import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shadows.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/brand_emblem.dart';
import 'widgets/auth_footer_links.dart';
import 'widgets/auth_offline_notice.dart';
import 'widgets/brand_lockup.dart';

/// Sign-in entry point: the user identifies themselves with an email address
/// or phone number.
///
/// Presentation only. It validates that the field is non-empty and
/// well-formed — that is input hygiene, not business logic — and hands the
/// value to [onSubmit]. Deciding what an identifier means, sending it, and
/// what happens next belong to the auth controller in Phase 2.
///
/// The design specifies an offline variant of this same screen rather than a
/// separate route, so [isOffline] switches between them: the field and button
/// go inert, an explanation replaces the empty space, and a retry link
/// appears. Sign-in genuinely cannot proceed without a network — the server
/// issues the session — so blocking is correct here rather than queuing.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.isOffline = false,
    this.isSubmitting = false,
    this.errorText,
    this.onSubmit,
    this.onRetryConnection,
    this.onOpenTerms,
    this.onOpenPrivacy,
  });

  /// Renders the offline variant.
  final bool isOffline;

  /// Shows progress in the button and blocks re-submission.
  final bool isSubmitting;

  /// Server-side error, already localized by the caller. Field-level
  /// validation is handled internally.
  final String? errorText;

  /// Receives the trimmed identifier once it passes validation.
  final ValueChanged<String>? onSubmit;

  final VoidCallback? onRetryConnection;
  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.isOffline || widget.isSubmitting) return;
    if (_formKey.currentState?.validate() != true) return;

    FocusScope.of(context).unfocus();
    widget.onSubmit?.call(_controller.text.trim());
  }

  /// Accepts an email address or an international phone number.
  ///
  /// Deliberately permissive: the server is the authority on whether an
  /// identifier exists, and a strict client regex mostly succeeds at
  /// rejecting valid addresses. This catches typos, nothing more.
  String? _validate(String? value) {
    final l10n = context.l10n;
    final input = value?.trim() ?? '';

    if (input.isEmpty) return l10n.authIdentifierRequired;

    final looksLikeEmail = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(input);
    // Optional +, then 8-15 digits, allowing spaces and dashes as separators.
    final digits = input.replaceAll(RegExp(r'[\s\-()]'), '');
    final looksLikePhone = RegExp(r'^\+?\d{8,15}$').hasMatch(digits);

    if (!looksLikeEmail && !looksLikePhone) {
      return l10n.authIdentifierInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final isOffline = widget.isOffline;

    return Scaffold(
      body: DecoratedBox(
        // The faint emerald bloom behind the brand mark.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.76),
            radius: 0.55,
            colors: AppShadows.ambientBloomColors,
            stops: [0, 0.7],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // Keeps the footer pinned low on tall screens while still
                // scrolling when the keyboard shrinks the viewport.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl + AppSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            height: AppSpacing.xxl + AppSpacing.sm,
                          ),
                          const BrandEmblem(),
                          const SizedBox(height: AppSpacing.xxl),
                          const BrandLockup(),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.authTagline,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: semantic.textSecondary,
                              letterSpacing: 0.35,
                              height: 1.63,
                            ),
                          ),
                          if (isOffline) ...[
                            const SizedBox(height: AppSpacing.lg),
                            AuthOfflineNotice(label: l10n.authOfflineBadge),
                          ],

                          // Pushes the form toward the lower third, as the
                          // design lays it out.
                          const Spacer(),

                          if (isOffline) ...[
                            Text(
                              l10n.authOfflineExplanation,
                              style: context.textStyles.bodySmall?.copyWith(
                                color: semantic.textSecondary,
                                height: 1.63,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],

                          _IdentifierForm(
                            formKey: _formKey,
                            controller: _controller,
                            isOffline: isOffline,
                            isSubmitting: widget.isSubmitting,
                            errorText: widget.errorText,
                            validator: _validate,
                            onSubmit: _submit,
                          ),

                          if (isOffline) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Center(
                              child: TextButton.icon(
                                onPressed: widget.onRetryConnection,
                                icon: const Icon(Icons.refresh, size: 14),
                                label: Text(l10n.authCheckConnection),
                                style: TextButton.styleFrom(
                                  foregroundColor: semantic.warning.withValues(
                                    alpha: 0.8,
                                  ),
                                  textStyle: context.textStyles.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ],

                          const Spacer(),
                          AuthFooterLinks(
                            onOpenTerms: widget.onOpenTerms,
                            onOpenPrivacy: widget.onOpenPrivacy,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The label, field and submit button.
class _IdentifierForm extends StatelessWidget {
  const _IdentifierForm({
    required this.formKey,
    required this.controller,
    required this.isOffline,
    required this.isSubmitting,
    required this.errorText,
    required this.validator,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isOffline;
  final bool isSubmitting;
  final String? errorText;
  final FormFieldValidator<String> validator;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final isEnabled = !isOffline && !isSubmitting;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The whole field group dims offline, as in the design.
          Opacity(
            opacity: isOffline ? 0.5 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.authIdentifierLabel,
                  style: AppTypography.monoEyebrow.copyWith(
                    color: semantic.textTertiary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: controller,
                  enabled: isEnabled,
                  validator: validator,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  // An account identifier is never a password, but it is
                  // personal — suggestions here leak it into the keyboard's
                  // learned dictionary.
                  enableSuggestions: false,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  onFieldSubmitted: (_) => onSubmit(),
                  // The identifier is always LTR even in Arabic: an email
                  // address and a +966 number are machine values, and bidi
                  // reordering would scramble how they read.
                  textDirection: TextDirection.ltr,
                  style: context.textStyles.bodyLarge?.copyWith(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: l10n.authIdentifierHint,
                    errorText: errorText,
                    // Struck-through connectivity glyph, per the design.
                    suffixIcon: isOffline
                        ? const Icon(
                            Icons.wifi_off_outlined,
                            size: 16,
                            color: AppColors.textDisabled,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: isEnabled ? onSubmit : null,
            child: isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onPrimary,
                    ),
                  )
                : Text(l10n.authContinue),
          ),
        ],
      ),
    );
  }
}
