import '../../../core/errors/failure.dart';
import 'chat_message.dart';

/// What the concierge screen is showing.
///
/// One object rather than scattered flags: "sending while offline",
/// "streaming with no assistant message" and "an error over a live stream"
/// are all nonsense, and this makes them unrepresentable.
class ConversationState {
  const ConversationState({
    this.messages = const [],
    this.isStreaming = false,
    this.isOffline = false,
    this.failure,
    this.draft = '',
  });

  /// Oldest first. The UI reverses for display so new messages appear at the
  /// bottom without the list jumping as it grows.
  final List<ChatMessage> messages;

  /// An answer is arriving. The composer is disabled: a second question sent
  /// mid-answer would interleave two streams into one conversation.
  final bool isStreaming;

  /// No connection. The concierge is disabled rather than degraded, because
  /// retrieval is server-side and there is nothing local to answer from.
  final bool isOffline;

  /// A failure worth showing above the composer.
  final Failure? failure;

  /// What is typed but not yet sent. Held in state so switching tabs and
  /// returning does not lose a half-written question.
  final String draft;

  bool get isEmpty => messages.isEmpty;

  /// Whether a question can be sent right now.
  bool get canSend => !isStreaming && !isOffline && draft.trim().isNotEmpty;

  ConversationState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    bool? isOffline,
    Failure? failure,
    String? draft,
    bool clearFailure = false,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isOffline: isOffline ?? this.isOffline,
      failure: clearFailure ? null : (failure ?? this.failure),
      draft: draft ?? this.draft,
    );
  }
}
