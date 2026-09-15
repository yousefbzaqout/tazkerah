import 'dart:async';

import '../../../core/errors/failure.dart';
import '../domain/chat_message.dart';
import '../domain/concierge_repository.dart';

/// A stand-in [ConciergeRepository] for running the concierge before the
/// backend exists.
///
/// **Not a production implementation.** [AppConfig] gates it to non-production
/// builds. It runs no model and retrieves nothing: it replays canned answers
/// token by token so the streaming UI can be built and tested against
/// something that behaves like a stream.
///
/// The answers are deliberately generic and hedged. A stub that confidently
/// stated a gate time or a refund window would be inventing policy, and
/// someone testing the screen could easily mistake it for real guidance.
class DevConciergeRepository implements ConciergeRepository {
  DevConciergeRepository({this.tokenDelay = const Duration(milliseconds: 40)});

  /// Gap between emitted tokens, so the stream is visible rather than
  /// arriving in one frame.
  final Duration tokenDelay;

  /// A question that always fails mid-answer, so the interrupted path is
  /// reachable by hand.
  static const String failQuestion = 'fail';

  @override
  Stream<ChatChunk> ask({
    required String question,
    required List<ChatMessage> history,
  }) async* {
    final normalized = question.trim().toLowerCase();
    final answer = _answerFor(normalized);

    // A brief pause before the first token: a real model takes a moment to
    // start, and a stream that begins instantly hides the "thinking" state
    // the UI needs to handle.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final words = answer.split(' ');
    for (var i = 0; i < words.length; i++) {
      await Future<void>.delayed(tokenDelay);

      // Fail partway through, leaving the partial answer on screen.
      if (normalized == failQuestion && i == words.length ~/ 2) {
        throw const NetworkFailure(
          debugMessage: 'DevConciergeRepository: simulated stream drop',
        );
      }

      yield ChatChunk(text: i == 0 ? words[i] : ' ${words[i]}');
    }

    yield ChatChunk(citations: _citationsFor(normalized), isDone: true);
  }

  String _answerFor(String question) {
    if (question.contains('gate') || question.contains('entry')) {
      return 'Gates usually open about ninety minutes before the start time, '
          'and the exact time is printed on your ticket. Have your pass ready '
          'on screen before you reach the reader — it refreshes every few '
          'seconds, so a screenshot will not scan.';
    }
    if (question.contains('refund') || question.contains('cancel')) {
      return 'Refund terms are set by each organizer rather than by Tazkerah, '
          'so they differ between events. The terms that apply to your order '
          'are shown on the event page and in your confirmation.';
    }
    if (question.contains('seat') || question.contains('where')) {
      return 'Your seat and zone are on the ticket in My Tickets, along with '
          'the gate to use. Stewards at the entrance can direct you from '
          'there.';
    }
    return 'I can help with gate times, seating, and what your ticket covers. '
        'This is a development build, so the answers are placeholders rather '
        'than real guidance.';
  }

  List<Citation> _citationsFor(String question) {
    if (question.contains('gate') || question.contains('entry')) {
      return const [
        Citation(
          label: 'Soundstorm Live Arena 2025 — Gate policy',
          reference: 'doc_gate_policy#3',
          eventId: 'evt_soundstorm_2025',
        ),
      ];
    }
    if (question.contains('refund') || question.contains('cancel')) {
      return const [
        Citation(
          label: 'Organizer refund terms',
          reference: 'doc_refund_terms#1',
        ),
      ];
    }
    return const [];
  }
}
