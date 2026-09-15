import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_shadows.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/brand_emblem.dart';
import 'widgets/auth_footer_links.dart';
import 'widgets/brand_lockup.dart';
import 'widgets/identifier_preview.dart';
import 'widgets/otp_input.dart';

/// Step two of sign-in: the user enters the code sent to their identifier.
///
/// Presentation only, like [AuthScreen]. It owns the entry field, the resend
/// cooldown timer, and when to auto-submit; it does not know what a valid code
/// is. [onVerify] and [onResend] carry that to the controller.
///
/// [errorText] comes from the caller already localized, because the distinction
/// between "invalid", "expired" and "too many attempts" is the server's to
/// make — the screen cannot tell them apart from the digits alone.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.identifier,
    this.codeLength = 6,
    this.isSubmitting = false,
    this.errorText,
    this.resendCooldown = const Duration(seconds: 30),
    this.onVerify,
    this.onResend,
    this.onEditIdentifier,
    this.onOpenTerms,
    this.onOpenPrivacy,
  });

  /// The email or phone the code was sent to, shown back to the user.
  final String identifier;

  final int codeLength;
  final bool isSubmitting;

  /// Localized server-side error. Null clears the error state.
  final String? errorText;

  /// How long the resend link stays disabled after a send. Server-side rate
  /// limiting is the real control; this only stops obvious hammering.
  final Duration resendCooldown;

  final ValueChanged<String>? onVerify;
  final VoidCallback? onResend;
  final VoidCallback? onEditIdentifier;
  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();

  Timer? _cooldownTimer;
  int _secondsRemaining = 0;

  /// Set when the user edits after a rejection, so the red boxes clear as soon
  /// as they start correcting rather than staying red under fresh input.
  bool _errorDismissed = false;
  String _lastSubmitted = '';

  bool get _showError => widget.errorText != null && !_errorDismissed;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _controller.addListener(_onInputChanged);
  }

  @override
  void didUpdateWidget(OtpScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A newly arrived error must show even if a previous one was dismissed.
    if (widget.errorText != oldWidget.errorText && widget.errorText != null) {
      setState(() => _errorDismissed = false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    _controller.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _onInputChanged() {
    if (_showError && _controller.text != _lastSubmitted) {
      setState(() => _errorDismissed = true);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsRemaining = widget.resendCooldown.inSeconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) timer.cancel();
    });
  }

  void _verify() {
    if (widget.isSubmitting) return;
    final code = _controller.text;
    if (code.length != widget.codeLength) return;

    FocusScope.of(context).unfocus();
    _lastSubmitted = code;
    widget.onVerify?.call(code);
  }

  void _resend() {
    if (_secondsRemaining > 0) return;
    _controller.clear();
    _startCooldown();
    widget.onResend?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final canResend = _secondsRemaining <= 0 && widget.onResend != null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.8),
            radius: 0.5,
            colors: AppShadows.ambientBloomColors,
            stops: [0, 0.7],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        const BrandEmblem(size: 48),
                        const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
                        const BrandLockup(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.authTagline,
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: semantic.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        IdentifierPreview(
                          identifier: widget.identifier,
                          onEdit: widget.onEditIdentifier,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        _CodeLabelRow(codeLength: widget.codeLength),
                        const SizedBox(height: AppSpacing.sm + 2),
                        OtpInput(
                          controller: _controller,
                          length: widget.codeLength,
                          hasError: _showError,
                          enabled: !widget.isSubmitting,
                          // Submitting on the last digit saves a tap; the
                          // button stays for anyone who pastes or corrects.
                          onCompleted: (_) => _verify(),
                        ),

                        if (_showError) ...[
                          const SizedBox(height: AppSpacing.sm + 2),
                          _InlineError(message: widget.errorText!),
                        ],

                        const SizedBox(height: AppSpacing.lg),
                        _ResendRow(
                          canResend: canResend,
                          secondsRemaining: _secondsRemaining,
                          onResend: _resend,
                        ),

                        const SizedBox(height: AppSpacing.xxl),
                        FilledButton(
                          onPressed: widget.isSubmitting ? null : _verify,
                          child: widget.isSubmitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.onPrimary,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(l10n.otpVerify),
                                    const SizedBox(width: AppSpacing.sm),
                                    // Directional: the arrow points toward
                                    // "forward", which flips in Arabic.
                                    const Icon(Icons.arrow_forward, size: 16),
                                  ],
                                ),
                        ),

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
            ),
          ),
        ),
      ),
    );
  }
}

/// "SECURITY CODE" with the expected length opposite it.
class _CodeLabelRow extends StatelessWidget {
  const _CodeLabelRow({required this.codeLength});

  final int codeLength;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.otpCodeLabel,
            style: AppTypography.monoEyebrow.copyWith(
              color: semantic.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.55,
            ),
          ),
        ),
        Text(
          context.l10n.otpDigitsHint,
          style: AppTypography.mono.copyWith(
            fontSize: 11,
            color: semantic.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// The red message under the boxes.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error, size: 16, color: context.colors.error),
        const SizedBox(width: AppSpacing.sm - 2),
        Expanded(
          child: Text(
            message,
            style: context.textStyles.bodySmall?.copyWith(
              color: context.colors.error,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Didn't receive code?" with the resend link or its cooldown.
class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.canResend,
    required this.secondsRemaining,
    required this.onResend,
  });

  final bool canResend;
  final int secondsRemaining;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            l10n.otpNoCode,
            style: context.textStyles.bodySmall?.copyWith(
              color: semantic.textSecondary,
            ),
          ),
        ),
        if (canResend)
          InkWell(
            onTap: onResend,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                l10n.otpResend,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              l10n.otpResendIn(secondsRemaining),
              style: context.textStyles.bodySmall?.copyWith(
                color: semantic.textDisabled,
              ),
            ),
          ),
      ],
    );
  }
}
