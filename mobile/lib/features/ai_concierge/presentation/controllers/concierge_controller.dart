import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/dev_concierge_repository.dart';
import '../../domain/chat_message.dart';
import '../../domain/concierge_repository.dart';
import '../../domain/conversation_state.dart';

/// Drives the concierge conversation.
///
/// The rule that shapes it: **a partial answer is kept, never discarded.** If
/// a stream drops halfway the text already received stays on screen, marked
/// incomplete. Throwing it away would lose something the user was mid-way
/// through reading, and would make a flaky connection look like the assistant
/// had said nothing at all.
class ConciergeController extends Notifier<ConversationState> {
  StreamSubscription<ChatChunk>? _subscription;
  int _requestToken = 0;
  bool _disposed = false;

  @override
  ConversationState build() {
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });
    return const ConversationState();
  }

  /// Updates the draft as the user types.
  void updateDraft(String value) {
    if (value == state.draft) return;
    state = state.copyWith(draft: value, clearFailure: true);
  }

  /// Sends the draft and streams the answer.
  Future<void> send() async {
    if (!state.canSend) return;

    final question = state.draft.trim();
    final token = ++_requestToken;
    final now = ref.read(clockProvider).now;

    final userMessage = ChatMessage(
      id: 'u_${now.microsecondsSinceEpoch}',
      role: MessageRole.user,
      content: question,
      sentAt: now,
    );
    final answerId = 'a_${now.microsecondsSinceEpoch}';
    final placeholder = ChatMessage(
      id: answerId,
      role: MessageRole.assistant,
      content: '',
      sentAt: now,
      status: MessageStatus.streaming,
    );

    // The question and an empty answer go up together, so the conversation
    // shows the assistant is working rather than appearing to swallow the
    // question until the first token lands.
    state = state.copyWith(
      messages: [...state.messages, userMessage, placeholder],
      isStreaming: true,
      draft: '',
      clearFailure: true,
    );

    // History excludes the two messages just added: the question is sent
    // separately, and the empty placeholder is not part of the conversation
    // the model should see.
    final history = state.messages
        .sublist(0, state.messages.length - 2)
        .where((m) => m.status == MessageStatus.complete)
        .toList();

    await _subscription?.cancel();
    final completer = Completer<void>();

    _subscription = ref
        .read(conciergeRepositoryProvider)
        .ask(question: question, history: history)
        .listen(
          (chunk) => _onChunk(token, answerId, chunk),
          onError: (Object error, StackTrace stack) {
            _onStreamError(token, answerId, error, stack);
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            _onStreamDone(token, answerId);
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    await completer.future;
  }

  void _onChunk(int token, String answerId, ChatChunk chunk) {
    if (_disposed || token != _requestToken) return;

    state = state.copyWith(
      messages: _updateMessage(answerId, (message) {
        return message.copyWith(
          content: chunk.text == null
              ? message.content
              : message.content + chunk.text!,
          citations: chunk.citations ?? message.citations,
          status: chunk.isDone
              ? MessageStatus.complete
              : MessageStatus.streaming,
        );
      }),
      isStreaming: !chunk.isDone,
    );
  }

  void _onStreamError(
    int token,
    String answerId,
    Object error,
    StackTrace stack,
  ) {
    if (_disposed || token != _requestToken) return;

    final failure = error is Failure
        ? error
        : UnknownFailure(debugMessage: error.toString());
    if (error is! Failure) {
      developer.log(
        'Concierge stream failed unexpectedly',
        name: 'concierge',
        error: error,
        stackTrace: stack,
      );
    }

    state = state.copyWith(
      // The partial answer survives, marked incomplete.
      messages: _updateMessage(
        answerId,
        (message) => message.copyWith(
          status: message.content.isEmpty
              ? MessageStatus.failed
              : MessageStatus.interrupted,
        ),
      ),
      isStreaming: false,
      failure: failure,
      isOffline: failure is NetworkFailure,
    );
  }

  void _onStreamDone(int token, String answerId) {
    if (_disposed || token != _requestToken) return;
    if (!state.isStreaming) return;

    // The stream closed without a final chunk. Whatever arrived is what there
    // is, so it is marked complete rather than left spinning forever.
    state = state.copyWith(
      messages: _updateMessage(
        answerId,
        (message) => message.copyWith(status: MessageStatus.complete),
      ),
      isStreaming: false,
    );
  }

  /// Re-asks the last question after a failure.
  Future<void> retryLast() async {
    final lastUser = state.messages.lastWhere(
      (m) => m.isUser,
      orElse: () => throw StateError('nothing to retry'),
    );

    // Drop everything from that question onward, then ask it again — so a
    // retry replaces the failed exchange rather than stacking a second copy
    // of the question underneath it.
    final index = state.messages.indexOf(lastUser);
    state = state.copyWith(
      messages: state.messages.sublist(0, index),
      draft: lastUser.content,
      clearFailure: true,
      isOffline: false,
    );
    await send();
  }

  /// Clears the conversation.
  void clear() {
    _subscription?.cancel();
    state = const ConversationState();
  }

  /// Marks the connection as restored, so the composer re-enables.
  void markOnline() {
    if (!state.isOffline) return;
    state = state.copyWith(isOffline: false, clearFailure: true);
  }

  List<ChatMessage> _updateMessage(
    String id,
    ChatMessage Function(ChatMessage) transform,
  ) {
    return [
      for (final message in state.messages)
        if (message.id == id) transform(message) else message,
    ];
  }
}

/// Binds a concrete [ConciergeRepository].
final conciergeRepositoryProvider = Provider<ConciergeRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.environment == AppEnvironment.production) {
    throw UnimplementedError(
      'No production ConciergeRepository is bound. The backend contract '
      '(POST /concierge/messages, text/event-stream) is still open — see '
      'ConciergeRepository.',
    );
  }

  return DevConciergeRepository();
});

final conciergeControllerProvider =
    NotifierProvider<ConciergeController, ConversationState>(
      ConciergeController.new,
    );
