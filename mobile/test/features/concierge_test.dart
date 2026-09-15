import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/app/theme/app_theme.dart';
import 'package:tazkerah/core/errors/failure.dart';
import 'package:tazkerah/core/providers/core_providers.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/features/ai_concierge/domain/chat_message.dart';
import 'package:tazkerah/features/ai_concierge/domain/concierge_repository.dart';
import 'package:tazkerah/features/ai_concierge/presentation/concierge_screen.dart';
import 'package:tazkerah/features/ai_concierge/presentation/controllers/concierge_controller.dart';
import 'package:tazkerah/features/ai_concierge/presentation/widgets/chat_bubble.dart';
import 'package:tazkerah/l10n/generated/app_localizations.dart';

/// A [ConciergeRepository] a test drives chunk by chunk.
class FakeConciergeRepository implements ConciergeRepository {
  /// Chunks to emit, in order.
  List<ChatChunk> chunks = const [];

  /// Thrown after [failAfter] chunks, when set.
  Failure? failure;
  int failAfter = 0;

  /// Every question asked, and the history sent with the last one.
  final List<String> questions = [];
  List<ChatMessage> lastHistory = const [];

  @override
  Stream<ChatChunk> ask({
    required String question,
    required List<ChatMessage> history,
  }) async* {
    questions.add(question);
    lastHistory = history;

    for (var i = 0; i < chunks.length; i++) {
      if (failure != null && i == failAfter) throw failure!;
      yield chunks[i];
      await Future<void>.delayed(Duration.zero);
    }
    if (failure != null && failAfter >= chunks.length) throw failure!;
  }
}

(ProviderContainer, FakeConciergeRepository) build() {
  final repo = FakeConciergeRepository();
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      conciergeRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return (container, repo);
}

Widget wrap(ProviderContainer container, {Locale? locale}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ConciergeScreen(),
    ),
  );
}

ConciergeController notifier(ProviderContainer c) =>
    c.read(conciergeControllerProvider.notifier);

void main() {
  group('ConciergeController', () {
    test('streams an answer into one growing message', () async {
      final (container, repo) = build();
      repo.chunks = const [
        ChatChunk(text: 'Gates open'),
        ChatChunk(text: ' ninety minutes'),
        ChatChunk(text: ' before.'),
        ChatChunk(isDone: true),
      ];

      notifier(container).updateDraft('when do gates open?');
      await notifier(container).send();

      final state = container.read(conciergeControllerProvider);
      expect(state.messages, hasLength(2));
      expect(state.messages.first.isUser, isTrue);
      // One message, assembled from four chunks.
      expect(state.messages.last.content, 'Gates open ninety minutes before.');
      expect(state.messages.last.status, MessageStatus.complete);
      expect(state.isStreaming, isFalse);
    });

    test('a dropped stream keeps the partial answer', () async {
      final (container, repo) = build();
      repo.chunks = const [
        ChatChunk(text: 'Gates open'),
        ChatChunk(text: ' ninety'),
      ];
      repo.failure = const NetworkFailure();
      repo.failAfter = 2;

      notifier(container).updateDraft('when?');
      await notifier(container).send();

      final answer = container.read(conciergeControllerProvider).messages.last;
      // Half an answer the user can read beats a message that vanishes.
      expect(answer.content, 'Gates open ninety');
      expect(answer.status, MessageStatus.interrupted);
      expect(container.read(conciergeControllerProvider).isOffline, isTrue);
    });

    test('a failure before any token marks the answer failed', () async {
      final (container, repo) = build();
      repo.failure = const NetworkFailure();
      repo.failAfter = 0;

      notifier(container).updateDraft('hello');
      await notifier(container).send();

      final answer = container.read(conciergeControllerProvider).messages.last;
      expect(answer.content, isEmpty);
      expect(answer.status, MessageStatus.failed);
    });

    test('citations arrive with the final chunk', () async {
      final (container, repo) = build();
      repo.chunks = const [
        ChatChunk(text: 'Gates open early.'),
        ChatChunk(
          citations: [
            Citation(
              label: 'Gate policy',
              reference: 'doc#1',
              eventId: 'evt_a',
            ),
          ],
          isDone: true,
        ),
      ];

      notifier(container).updateDraft('gates?');
      await notifier(container).send();

      final answer = container.read(conciergeControllerProvider).messages.last;
      expect(answer.citations.single.label, 'Gate policy');
      expect(answer.citations.single.eventId, 'evt_a');
    });

    test('history excludes the in-flight exchange', () async {
      final (container, repo) = build();
      repo.chunks = const [ChatChunk(text: 'First.'), ChatChunk(isDone: true)];

      notifier(container).updateDraft('one');
      await notifier(container).send();

      notifier(container).updateDraft('two');
      await notifier(container).send();

      // The second question sends the first exchange as history, not the
      // question being asked or its empty placeholder.
      expect(repo.lastHistory, hasLength(2));
      expect(repo.lastHistory.first.content, 'one');
      expect(repo.lastHistory.last.content, 'First.');
    });

    test('cannot send while streaming or offline', () async {
      final (container, repo) = build();
      repo.failure = const NetworkFailure();
      repo.failAfter = 0;

      notifier(container).updateDraft('hi');
      await notifier(container).send();
      expect(container.read(conciergeControllerProvider).isOffline, isTrue);

      // Offline: a second question would go nowhere.
      notifier(container).updateDraft('again');
      expect(container.read(conciergeControllerProvider).canSend, isFalse);
      await notifier(container).send();
      expect(repo.questions, hasLength(1));
    });

    test('retry replaces the failed exchange rather than stacking', () async {
      final (container, repo) = build();
      repo.failure = const NetworkFailure();
      repo.failAfter = 0;

      notifier(container).updateDraft('when?');
      await notifier(container).send();
      expect(
        container.read(conciergeControllerProvider).messages,
        hasLength(2),
      );

      repo.failure = null;
      repo.chunks = const [ChatChunk(text: 'Soon.'), ChatChunk(isDone: true)];
      await notifier(container).retryLast();

      final state = container.read(conciergeControllerProvider);
      // Still one exchange, not two copies of the question.
      expect(state.messages, hasLength(2));
      expect(state.messages.first.content, 'when?');
      expect(state.messages.last.content, 'Soon.');
    });

    test('clearing empties the conversation', () async {
      final (container, repo) = build();
      repo.chunks = const [ChatChunk(text: 'Hi.'), ChatChunk(isDone: true)];

      notifier(container).updateDraft('hello');
      await notifier(container).send();
      notifier(container).clear();

      expect(container.read(conciergeControllerProvider).isEmpty, isTrue);
    });
  });

  group('ConciergeScreen', () {
    testWidgets('opens with suggestions rather than a blank field', (
      tester,
    ) async {
      final (container, _) = build();

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      expect(find.text('How can I help?'), findsOneWidget);
      expect(find.text('When do gates open?'), findsOneWidget);
      expect(find.byType(ChatBubble), findsNothing);
    });

    testWidgets('tapping a suggestion asks it', (tester) async {
      final (container, repo) = build();
      repo.chunks = const [
        ChatChunk(text: 'Ninety minutes before.'),
        ChatChunk(isDone: true),
      ];

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('When do gates open?'));
      await tester.pumpAndSettle();

      expect(repo.questions, ['When do gates open?']);
      expect(find.text('Ninety minutes before.'), findsOneWidget);
      expect(find.byType(ChatBubble), findsNWidgets(2));
    });

    testWidgets('an interrupted answer offers a retry', (tester) async {
      final (container, repo) = build();
      repo.chunks = const [ChatChunk(text: 'Partial')];
      repo.failure = const NetworkFailure();
      repo.failAfter = 1;

      await tester.pumpWidget(wrap(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'when?');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Answer interrupted'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // Offline: retrieval is server-side, so there is nothing to answer from.
      expect(find.text('Concierge needs a connection'), findsOneWidget);
    });

    testWidgets('renders right-to-left in Arabic', (tester) async {
      final (container, _) = build();

      await tester.pumpWidget(wrap(container, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('كيف يمكنني المساعدة؟'), findsOneWidget);
      expect(find.text('متى تُفتح البوابات؟'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('كيف يمكنني المساعدة؟'))),
        TextDirection.rtl,
      );
    });
  });
}
