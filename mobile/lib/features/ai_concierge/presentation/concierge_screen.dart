import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../domain/chat_message.dart';
import '../domain/conversation_state.dart';
import 'controllers/concierge_controller.dart';
import 'widgets/chat_bubble.dart';

/// AI Event Concierge: a chat backed by the server-side RAG engine, with
/// streamed responses.
///
/// Has no offline mode. Retrieval happens server-side, so with no connection
/// the screen is disabled with a clear message rather than degraded — an
/// answer assembled from whatever happened to be cached would be worse than
/// none for questions about gate times and refund policy.
class ConciergeScreen extends ConsumerStatefulWidget {
  const ConciergeScreen({super.key});

  @override
  ConsumerState<ConciergeScreen> createState() => _ConciergeScreenState();
}

class _ConciergeScreenState extends ConsumerState<ConciergeScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conciergeControllerProvider);
    final controller = ref.read(conciergeControllerProvider.notifier);
    final l10n = context.l10n;

    // Keep the composer in step with state — a cleared draft after sending, or
    // a question restored by a retry.
    if (_composer.text != state.draft) {
      _composer.value = TextEditingValue(
        text: state.draft,
        selection: TextSelection.collapsed(offset: state.draft.length),
      );
    }

    // Follow the answer as it streams in.
    ref.listen(conciergeControllerProvider, (_, _) => _scrollToEnd());

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.conciergeTitle),
        actions: [
          if (!state.isEmpty)
            IconButton(
              onPressed: controller.clear,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.conciergeClear,
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.isOffline) _OfflineNotice(onRetry: controller.markOnline),
          Expanded(
            child: state.isEmpty
                ? _EmptyConversation(onAsk: (q) => _ask(controller, q))
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: state.messages.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return ChatBubble(
                        message: message,
                        onRetry:
                            message.status == MessageStatus.interrupted ||
                                message.status == MessageStatus.failed
                            ? controller.retryLast
                            : null,
                        onCitationTap: (citation) => context.go(
                          AppRoutes.eventDetailPath(citation.eventId!),
                        ),
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _composer,
            state: state,
            onChanged: controller.updateDraft,
            onSend: controller.send,
          ),
        ],
      ),
    );
  }

  void _ask(ConciergeController controller, String question) {
    controller.updateDraft(question);
    controller.send();
  }

  void _scrollToEnd() {
    // After the frame the new text is laid out in, so the extent is real.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
}

/// Shown above the conversation when there is no connection.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: semantic.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: semantic.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, size: 17, color: semantic.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.conciergeOfflineTitle,
                  style: context.textStyles.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.conciergeOfflineMessage,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: semantic.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The opening state, with a few questions worth asking.
class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    final suggestions = [
      l10n.conciergeSuggestionGates,
      l10n.conciergeSuggestionSeat,
      l10n.conciergeSuggestionRefund,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Icon(Icons.chat_bubble_outline, size: 42, color: semantic.success),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.conciergeEmptyTitle,
            style: context.textStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.conciergeEmptyMessage,
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium?.copyWith(
              color: semantic.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Suggestions rather than a blank field: a user who does not know
          // what an assistant can answer usually asks nothing at all.
          for (final suggestion in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OutlinedButton(
                onPressed: () => onAsk(suggestion),
                child: Text(suggestion),
              ),
            ),
        ],
      ),
    );
  }
}

/// The message composer.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.state,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final ConversationState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final enabled = !state.isStreaming && !state.isOffline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: semantic.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onSubmitted: (_) => state.canSend ? onSend() : null,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    style: context.textStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: l10n.conciergeComposerHint,
                      filled: true,
                      fillColor: context.colors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: BorderSide(color: semantic.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: BorderSide(color: semantic.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: state.canSend ? onSend : null,
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  tooltip: l10n.conciergeSend,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // A standing caveat rather than a one-off: the assistant answers
            // from retrieved documents and can be incomplete, and the ticket
            // is what actually governs entry.
            Text(
              l10n.conciergeDisclaimer,
              textAlign: TextAlign.center,
              style: AppTypography.mono.copyWith(
                fontSize: 10,
                color: semantic.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
