import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/extensions/build_context_x.dart';

/// Free-text filter over the feed.
///
/// **Not in the Figma frames.** The three states supplied — skeleton,
/// populated, offline — draw no search affordance. It is here because the
/// brief asks for a working discovery screen and a feed that can only be
/// scrolled is not one: with a paginated catalogue, finding a known event
/// otherwise means scrolling until it appears.
///
/// It is therefore built to sit *under* the design rather than beside it —
/// the same surface, border and radius as the cards, no new colours — so
/// dropping it costs one widget and changes nothing else if the designer
/// decides discovery should stay scroll-only.
class DiscoverySearchField extends StatefulWidget {
  const DiscoverySearchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  /// The controller's current query. The field synchronises to this, so a
  /// state change from elsewhere — a cleared search, a restored tab — is
  /// reflected in the text.
  final String value;

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<DiscoverySearchField> createState() => _DiscoverySearchFieldState();
}

class _DiscoverySearchFieldState extends State<DiscoverySearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(DiscoverySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only touch the field when the incoming value genuinely differs from
    // what is typed. Assigning unconditionally would fight the user's cursor
    // on every keystroke, since each one round-trips through the controller.
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final l10n = context.l10n;

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: context.textStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: l10n.discoverySearchHint,
        hintStyle: context.textStyles.bodyMedium?.copyWith(
          color: semantic.textDisabled,
        ),
        prefixIcon: Icon(Icons.search, size: 18, color: semantic.textTertiary),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: semantic.textTertiary,
                tooltip: l10n.discoverySearchClear,
                onPressed: () {
                  _controller.clear();
                  widget.onClear();
                },
              ),
        filled: true,
        fillColor: context.colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantic.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantic.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantic.borderStrong),
        ),
      ),
    );
  }
}
