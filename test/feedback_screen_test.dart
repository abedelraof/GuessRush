import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quizo/models/game_mode.dart';
import 'package:quizo/models/question.dart';
import 'package:quizo/screens/feedback_screen.dart';
import 'package:quizo/services/api_client.dart';
import 'package:quizo/services/quiz_api.dart';
import 'package:quizo/state/quiz_controller.dart';

/// Minimal fake — only startRush/submitAnswer are needed to drive the
/// controller into AppScreen.feedback. timerSeconds: 0 throughout keeps the
/// countdown timer and the startQuestion ping (only fired for timed
/// questions) out of scope, avoiding the audioplayers/network platform
/// channels not available in a plain widget test.
class _FakeQuizApi extends QuizApi {
  _FakeQuizApi() : super(ApiClient.instance);

  final List<Question> rushQuestions = List.generate(
    2,
    (i) => Question(
      id: i + 1,
      type: QuestionType.text,
      label: 'Label',
      prompt: 'Prompt ${i + 1}',
      options: const ['Paris', 'London', 'Rome', 'Berlin'],
      timerSeconds: 0,
    ),
  );

  @override
  Future<SessionStart> startRush(GameMode mode) async {
    return SessionStart(sessionId: 1, questions: rushQuestions);
  }

  @override
  Future<AnswerResult> submitAnswer({
    required int sessionId,
    required int questionId,
    required int selectedIndex,
    required int responseTimeMs,
  }) async {
    return AnswerResult(
      isCorrect: true,
      timedOut: false,
      correctIndex: 0,
      difficulty: 'easy',
      baseScore: 100,
      speedMultiplier: 1.0,
      streakMultiplier: 1.0,
      answerScore: 100,
      score: 100,
      streak: 1,
      bestStreak: 1,
      xpGained: 10,
      serverElapsedMs: 0,
      questionsRemaining: rushQuestions.length - 1,
      rushComplete: false,
      cluesRevealed: 1,
      clueMultiplier: 1.0,
      removeOneUsed: false,
      removeOneUsesRemaining: 1,
      doubleDownChoice: 'none',
      doubleDownMultiplier: 1.0,
      doubleDownOffer: null,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'FeedbackScreen renders the correct-answer copy and score after answering',
    (tester) async {
      final controller = QuizController(quizApi: _FakeQuizApi());

      await controller.startRush(GameMode.quickRush);
      await tester.pump();

      await controller.selectAnswer(0);
      await tester.pump();

      expect(controller.screen, AppScreen.feedback);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FeedbackScreen(controller: controller)),
        ),
      );
      await tester.pump();

      expect(find.text('CORRECT!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.dispose(); // cancels the pending 1.6s advance timer
    },
  );
}
