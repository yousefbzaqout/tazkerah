import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';

/// Six-box verification code entry.
///
/// A single hidden [EditableText] backs all six boxes rather than one field
/// each. That is what makes paste, autofill from an SMS, and backspace across
/// boundaries behave correctly — six separate fields each handle those badly
/// and have to fight each other for focus.
///
/// The boxes are painted from the controller's text, so they are a view of
/// one value, not six pieces of state that can disagree.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;

  /// Paints every box in the error colour. Driven by the caller, since only
  /// it knows whether the server rejected the code.
  final bool hasError;

  final bool enabled;
  final bool autofocus;

  /// Fires once the final digit is entered, so the caller can submit without
  /// the user reaching for the button.
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final text = widget.controller.text;
    if (text.length == widget.length) {
      widget.onCompleted?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return Stack(
      children: [
        // The real field, held offstage. Opacity rather than Offstage or
        // Visibility: it must stay laid out and focusable to receive input,
        // and the system autofill overlay anchors to its position.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              // Lets the platform offer the code straight from an SMS.
              autofillHints: const [AutofillHints.oneTimeCode],
              enableSuggestions: false,
              autocorrect: false,
              showCursor: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _OtpBox(
                    digit: i < text.length ? text[i] : null,
                    // The cursor sits in the first unfilled box, and only
                    // while the field actually has focus.
                    isActive: _focusNode.hasFocus && i == text.length,
                    hasError: widget.hasError,
                    enabled: widget.enabled,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One box: filled, awaiting input, or empty.
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
    required this.enabled,
  });

  final String? digit;
  final bool isActive;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final colors = context.colors;
    final isFilled = digit != null;

    final Color border;
    if (hasError) {
      border = isFilled || isActive
          ? colors.error
          : colors.error.withValues(alpha: 0.8);
    } else if (isActive) {
      border = colors.primary;
    } else if (isFilled) {
      border = semantic.borderStrong;
    } else {
      border = semantic.border;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isFilled || isActive
              ? colors.surfaceContainerLow
              : colors.surfaceContainerLow.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border),
          boxShadow: hasError && (isFilled || isActive)
              ? [
                  BoxShadow(
                    color: colors.error.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: _content(context, semantic.textDisabled),
      ),
    );
  }

  Widget _content(BuildContext context, Color placeholder) {
    final digit = this.digit;

    if (digit != null) {
      return Text(
        digit,
        // A digit is a machine value: LTR even in Arabic, so a partially
        // entered code does not visually reverse.
        textDirection: TextDirection.ltr,
        style: AppTypography.monoOtpDigit.copyWith(
          color: context.colors.onSurface,
        ),
      );
    }

    if (isActive) {
      return Container(
        width: 2,
        height: 24,
        decoration: BoxDecoration(
          color: hasError ? context.colors.error : context.colors.primary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      );
    }

    return Text(
      '·',
      style: AppTypography.monoOtpDigit.copyWith(color: placeholder),
    );
  }
}
