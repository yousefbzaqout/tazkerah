/// One turn in the concierge conversation.
///
/// Plain Dart, per the architecture's `domain` rule. An assistant message is
/// built incrementally as tokens stream in, so [content] grows over the life
/// of a single message rather than arriving whole.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.sentAt,
    this.status = MessageStatus.complete,
    this.citations = const [],
  });

  final String id;
  final MessageRole role;

  /// What has arrived so far. For a streaming assistant message this is a
  /// partial answer, and the UI renders it as it grows.
  final String content;

  final DateTime sentAt;
  final MessageStatus status;

  /// What the answer was drawn from.
  ///
  /// Retrieval happens server-side, and the sources come back with the
  /// answer. They are shown rather than hidden because a concierge that
  /// states an event's start time should be able to say where that came from
  /// — an unattributed answer about a ticket someone paid for is not
  /// something a user can check.
  final List<Citation> citations;

  bool get isUser => role == MessageRole.user;

  /// Whether more tokens are still expected.
  bool get isStreaming => status == MessageStatus.streaming;

  ChatMessage copyWith({
    String? content,
    MessageStatus? status,
    List<Citation>? citations,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      sentAt: sentAt,
      status: status ?? this.status,
      citations: citations ?? this.citations,
    );
  }
}

enum MessageRole { user, assistant }

/// Where a message is in its life.
enum MessageStatus {
  /// Fully delivered.
  complete,

  /// Tokens are still arriving.
  streaming,

  /// The stream ended before the answer did — a dropped connection, or a
  /// server-side error mid-answer. The partial text is kept: half an answer
  /// the user can see is more useful than a message that vanishes, and the UI
  /// marks it as incomplete rather than passing it off as finished.
  interrupted,

  /// The user's message never reached the server, so it can be retried.
  failed,
}

/// A source the answer drew on.
class Citation {
  const Citation({required this.label, required this.reference, this.eventId});

  /// What to show: "Soundstorm Live Arena 2025 — Gate policy".
  final String label;

  /// The backend's identifier for the passage, so support can trace an
  /// answer back to what produced it.
  final String reference;

  /// Set when the source is an event the app can open, so a citation can be
  /// a link rather than a dead label.
  final String? eventId;
}
