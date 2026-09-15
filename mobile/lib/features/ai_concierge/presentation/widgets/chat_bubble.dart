import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../domain/chat_message.dart';

/// One message in the conversation.
///
/// A streaming answer shows a caret after its text, which is what makes the
/// difference between "still arriving" and "this is the whole answer" visible
/// without a spinner competing with the words.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onCitationTap,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;
  final ValueChanged<Citation>? onCitationTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final isUser = message.isUser;

    // An answer with no text yet is the assistant thinking — say so, rather
    // than showing an empty bubble that reads as a delivered blank reply.
    final isThinking =
        !isUser && message.content.isEmpty && message.isStreaming;

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md + 2,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? semantic.successContainer
                    : context.colors.surfaceContainerLow,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(isUser ? AppRadius.md : 4),
                  bottomRight: Radius.circular(isUser ? 4 : AppRadius.md),
                ),
                border: Border.all(
                  color: isUser
                      ? semantic.success.withValues(alpha: 0.35)
                      : semantic.border,
                ),
              ),
              child: isThinking
                  ? _Thinking(label: l10n.conciergeThinking)
                  : _MessageText(message: message),
            ),
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _Citations(citations: message.citations, onTap: onCitationTap),
            ],
            if (message.status == MessageStatus.interrupted ||
                message.status == MessageStatus.failed) ...[
              const SizedBox(height: AppSpacing.sm - 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 13, color: semantic.warning),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    l10n.conciergeInterrupted,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: semantic.warning,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    InkWell(
                      onTap: onRetry,
                      child: Text(
                        l10n.conciergeRetry,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: semantic.success,
                          decoration: TextDecoration.underline,
                          decorationColor: semantic.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The message text, with a caret while tokens are still arriving.
class _MessageText extends StatelessWidget {
  const _MessageText({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: message.content),
          if (message.isStreaming)
            TextSpan(
              text: ' ▌',
              style: TextStyle(color: context.semantic.success),
            ),
        ],
      ),
      style: context.textStyles.bodyMedium,
    );
  }
}

/// The pre-token state.
class _Thinking extends StatelessWidget {
  const _Thinking({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: semantic.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: context.textStyles.bodySmall?.copyWith(
            color: semantic.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// What the answer drew on.
class _Citations extends StatelessWidget {
  const _Citations({required this.citations, this.onTap});

  final List<Citation> citations;
  final ValueChanged<Citation>? onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.conciergeSources,
          style: AppTypography.monoLabel.copyWith(
            fontSize: 8,
            color: semantic.textDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final citation in citations)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: InkWell(
              // Only a citation that names something the app can open is
              // tappable; the rest are labels, and a dead link would be worse
              // than plain text.
              onTap: citation.eventId == null || onTap == null
                  ? null
                  : () => onTap!(citation),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 12,
                    color: semantic.textDisabled,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Flexible(
                    child: Text(
                      citation.label,
                      style: context.textStyles.bodySmall?.copyWith(
                        fontSize: 11,
                        color: citation.eventId == null
                            ? semantic.textTertiary
                            : semantic.success,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
