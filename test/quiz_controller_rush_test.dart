import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quizo/models/category.dart';
import 'package:quizo/models/question.dart';
import 'package:quizo/services/api_client.dart';
import 'package:quizo/services/quiz_api.dart';
import 'package:quizo/state/quiz_controller.dart';

/// timerSeconds: 0 throughout — keeps these tests focused on Rush progression
/// and score/streak bookkeeping without touching the countdown timer or the
/// audioplayers platform channel (neither of which is available in a plain
/// widget test).
Question _untimedQuestion(int id) => Question(
      id: id,
      type: QuestionType.text,
      label: 'Label',
      prompt: 'Prompt $id',
      options: const ['A', 'B', 'C', 'D'],
      timerSeconds: 0,
    );

/// Stands in for the server: grades questions with an odd id as correct,
/// even as wrong, and tracks cumulative score/streak exactly like the real
/// API would, so the controller is exercised against a believable sequence
/// of server responses without a network dependency or mocking package.
class FakeQuizApi extends QuizApi {
  FakeQuizApi() : super(ApiClient.instance);

  final List<Question> rushQuestions = List.generate(10, (i) => _untimedQuestion(i + 1));
  final List<int> submittedQuestionIds = [];
  bool finishCalled = false;

  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;

  @override
  Future<SessionStart> createSession(int categoryId) async {
    return SessionStart(sessionId: 1, questions: rushQuestions);
  }

  @override
  Future<void> startQuestion({required int sessionId, required int questionId}) async {}

  @override
  Future<AnswerResult> submitAnswer({
    required int sessionId,
    required int questionId,
    required int selectedIndex,
    required int responseTimeMs,
  }) async {
    submittedQuestionIds.add(questionId);
    final isCorrect = questionId.isOdd;
    if (isCorrect) {
      _score += 100;
      _streak += 1;
      _bestStreak = _streak > _bestStreak ? _streak : _bestStreak;
    } else {
      _streak = 0;
    }
    final answered = submittedQuestionIds.length;
    return AnswerResult(
      isCorrect: isCorrect,
      timedOut: false,
      correctIndex: 0,
      difficulty: 'easy',
      baseScore: 100,
      speedMultiplier: 1.0,
      streakMultiplier: 1.0,
      answerScore: isCorrect ? 100 : 0,
      score: _score,
      streak: _streak,
      bestStreak: _bestStreak,
      xpGained: isCorrect ? 100 : 0,
      serverElapsedMs: 500,
      questionsRemaining: rushQuestions.length - answered,
      rushComplete: answered >= rushQuestions.length,
    );
  }

  @override
  Future<SessionSummary> finishSession(int sessionId) async {
    finishCalled = true;
    return SessionSummary(
      score: _score,
      questionsTotal: rushQuestions.length,
      questionsAnswered: submittedQuestionIds.length,
      correctCount: submittedQuestionIds.where((id) => id.isOdd).length,
      wrongCount: submittedQuestionIds.where((id) => id.isEven).length,
      bestStreak: _bestStreak,
      accuracyPct: 50,
      avgResponseTimeMs: 1200,
      durationMs: 15000,
      personalBestScore: 400,
      isNewPersonalBest: _score > 400,
    );
  }
}

const _testCategory = Category(id: 1, key: 'movies', name: 'Movies', emoji: '🎬', bg: Color(0xFFA24AFF));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Rush progresses through all 10 questions in server-assigned order and completes', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    expect(controller.screen, AppScreen.game);
    expect(controller.questionTotal, 10);

    for (var i = 0; i < 10; i++) {
      expect(controller.qIndex, i, reason: 'should be on question ${i + 1}');
      final expectedQuestionId = controller.currentQuestion.id;

      await controller.selectAnswer(0);
      await tester.pump();

      expect(fakeApi.submittedQuestionIds.last, expectedQuestionId);
      await tester.pump(const Duration(milliseconds: 1700)); // past the feedback-overlay delay
    }

    expect(controller.screen, AppScreen.results);
    expect(fakeApi.finishCalled, true);
    // Questions were submitted in exactly the order the server returned them — the
    // client never reorders or skips, it just walks the server-assigned sequence.
    expect(fakeApi.submittedQuestionIds, fakeApi.rushQuestions.map((q) => q.id).toList());
  });

  testWidgets('wrong answers break the streak; score/streak reflect server-graded totals', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    // ids 1,3,5,7,9 graded correct; 2,4,6,8,10 graded wrong — streak never exceeds 1.
    expect(controller.score, 500);
    expect(controller.correctCount, 5);
    expect(controller.wrongCount, 5);
    expect(controller.bestStreak, 1);
    expect(controller.streak, 0); // Rush ended on a wrong answer (id 10)
  });

  testWidgets('Rush result carries the server-authoritative summary (avg time, duration, personal best)', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(controller.avgResponseTimeMs, 1200);
    expect(controller.durationMs, 15000);
    expect(controller.personalBestScore, 400);
    expect(controller.isNewPersonalBest, true); // 500 > previous best of 400
  });
}
