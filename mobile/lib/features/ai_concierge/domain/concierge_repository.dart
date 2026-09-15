import 'chat_message.dart';

/// What the AI concierge needs from the backend.
///
/// Declared in domain so the controller and its tests do not depend on how it
/// is fulfilled. The endpoint below is the contract this app expects; the
/// backend has not agreed it:
///
///   POST /concierge/messages  -> text/event-stream
///
/// **Retrieval is server-side.** The app sends a question and renders what
/// comes back; it holds no index, runs no model, and has no offline mode. A
/// client-side answer would be drawn from whatever happened to be cached,
/// which for questions about gate times and refund policy is worse than no
/// answer at all.
abstract interface class ConciergeRepository {
  /// Asks a question and streams the answer back.
  ///
  /// Yields [ChatChunk]s as they arrive. The stream completes when the answer
  /// is finished, and emits an error for a failure the caller should surface —
  /// a dropped connection mid-answer arrives this way, and the partial text
  /// already yielded is kept.
  ///
  /// [history] is sent with each question because the server holds no session:
  /// a stateless endpoint is simpler to reason about and cannot serve one
  /// user's conversation to another.
  Stream<ChatChunk> ask({
    required String question,
    required List<ChatMessage> history,
  });
}

/// One piece of a streamed answer.
class ChatChunk {
  const ChatChunk({this.text, this.citations, this.isDone = false});

  /// Text to append. Null on a chunk that carries only metadata.
  final String? text;

  /// Sources, which arrive once the server knows what it drew on — usually
  /// with the final chunk rather than the first.
  final List<Citation>? citations;

  /// Marks the last chunk.
  final bool isDone;
}
