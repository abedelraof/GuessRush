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

/// Stands in for the server: by default grades questions with an odd id as
/// correct and even as wrong, tracking cumulative score/streak exactly like
/// the real API would, so the controller is exercised against a believable
/// sequence of server responses without a network dependency or mocking
/// package. `timeoutQuestionIds` and `speedMultipliers` let individual tests
/// override that default per question to exercise timeout/speed behavior.
class FakeQuizApi extends QuizApi {
  FakeQuizApi({Set<int>? timeoutQuestionIds, Map<int, double>? speedMultipliers})
      : timeoutQuestionIds = timeoutQuestionIds ?? const {},
        speedMultipliers = speedMultipliers ?? const {},
        super(ApiClient.instance);

  final Set<int> timeoutQuestionIds;
  final Map<int, double> speedMultipliers;

  final List<Question> rushQuestions = List.generate(10, (i) => _untimedQuestion(i + 1));
  final List<int> submittedQuestionIds = [];
  bool finishCalled = false;

  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;

  int? personalBestScoreOverride = 400;
  int? personalBestStreakOverride;
  bool isNewBestStreakOverride = false;
  bool isPerfectRushOverride = false;

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
    final timedOut = timeoutQuestionIds.contains(questionId);
    final isCorrect = !timedOut && questionId.isOdd;
    final speedMultiplier = speedMultipliers[questionId] ?? 1.0;
    final answerScore = isCorrect ? (100 * speedMultiplier).round() : 0;
    if (isCorrect) {
      _score += answerScore;
      _streak += 1;
      _bestStreak = _streak > _bestStreak ? _streak : _bestStreak;
    } else {
      _streak = 0;
    }
    final answered = submittedQuestionIds.length;
    return AnswerResult(
      isCorrect: isCorrect,
      timedOut: timedOut,
      correctIndex: 0,
      difficulty: 'easy',
      baseScore: 100,
      speedMultiplier: speedMultiplier,
      streakMultiplier: 1.0,
      answerScore: answerScore,
      score: _score,
      streak: _streak,
      bestStreak: _bestStreak,
      xpGained: answerScore,
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
      correctCount: submittedQuestionIds.where((id) => id.isOdd && !timeoutQuestionIds.contains(id)).length,
      wrongCount: submittedQuestionIds
          .where((id) => id.isEven || timeoutQuestionIds.contains(id))
          .length,
      bestStreak: _bestStreak,
      accuracyPct: 50,
      avgResponseTimeMs: 1200,
      durationMs: 15000,
      personalBestScore: personalBestScoreOverride,
      isNewPersonalBest: personalBestScoreOverride == null || _score > personalBestScoreOverride!,
      personalBestStreak: personalBestStreakOverride,
      isNewBestStreak: isNewBestStreakOverride,
      isPerfectRush: isPerfectRushOverride,
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

  test('speedLabelFor: thresholds and untimed questions', () {
    expect(speedLabelFor(1.45, hasTimer: true), 'INSANE!');
    expect(speedLabelFor(1.3, hasTimer: true), 'FAST!');
    expect(speedLabelFor(1.1, hasTimer: true), 'GOOD!');
    expect(speedLabelFor(1.0, hasTimer: true), 'CLOSE!');
    expect(speedLabelFor(1.45, hasTimer: false), ''); // no speed read on untimed questions
  });

  test('momentumTierFor: matches the 0-25/25-50/50-75/75-100 bracket spec', () {
    expect(momentumTierFor(0), MomentumTier.low);
    expect(momentumTierFor(24.9), MomentumTier.low);
    expect(momentumTierFor(25), MomentumTier.medium);
    expect(momentumTierFor(49.9), MomentumTier.medium);
    expect(momentumTierFor(50), MomentumTier.high);
    expect(momentumTierFor(74.9), MomentumTier.high);
    expect(momentumTierFor(75), MomentumTier.max);
    expect(momentumTierFor(100), MomentumTier.max);
  });

  testWidgets('momentum rises more on a fast correct answer than a normal-speed one', (tester) async {
    final fastApi = FakeQuizApi(speedMultipliers: {1: 1.4}); // >= 1.25 counts as "fast"
    final fastController = QuizController(quizApi: fastApi);
    await fastController.selectCategory(_testCategory);
    await tester.pump();
    await fastController.selectAnswer(0); // question id 1: fast correct
    await tester.pump();

    final normalApi = FakeQuizApi(); // default speedMultiplier 1.0 — not fast
    final normalController = QuizController(quizApi: normalApi);
    await normalController.selectCategory(_testCategory);
    await tester.pump();
    await normalController.selectAnswer(0); // question id 1: normal-speed correct
    await tester.pump();

    expect(fastController.momentum, 18); // fast correct: +18 from 0
    expect(normalController.momentum, 12); // normal correct: +12 from 0
    expect(fastController.momentum, greaterThan(normalController.momentum));

    // Drain the pending post-answer advance timers before the test ends.
    await tester.pump(const Duration(milliseconds: 1700));
  });

  testWidgets('a timeout drops momentum more sharply than a wrong answer, and resets streak', (tester) async {
    // Deck: id=1 and id=3 (odd -> correct, fast) build momentum to 36, then
    // id=4 (even) is the divergence point — graded wrong in one run, timed
    // out in the other — so the -15 vs -25 drop is visible without either
    // run hitting the 0 floor.
    final deckIds = [1, 3, 4];

    Future<QuizController> playThroughDivergencePoint(FakeQuizApi api) async {
      api.rushQuestions
        ..clear()
        ..addAll(deckIds.map(_untimedQuestion));
      final controller = QuizController(quizApi: api);
      await controller.selectCategory(_testCategory);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await controller.selectAnswer(0);
        await tester.pump();
        if (i < 2) await tester.pump(const Duration(milliseconds: 1700));
      }
      return controller;
    }

    final wrongController = await playThroughDivergencePoint(FakeQuizApi(speedMultipliers: {1: 1.4, 3: 1.4}));
    final timeoutController = await playThroughDivergencePoint(
      FakeQuizApi(speedMultipliers: {1: 1.4, 3: 1.4}, timeoutQuestionIds: {4}),
    );

    expect(timeoutController.feedback, AnswerFeedback.timeout);
    expect(timeoutController.streak, 0);
    expect(wrongController.momentum, 21); // 18 + 18 - 15
    expect(timeoutController.momentum, 11); // 18 + 18 - 25
    expect(timeoutController.momentum, lessThan(wrongController.momentum));

    // Drain the pending post-answer advance timers before the test ends.
    await tester.pump(const Duration(milliseconds: 1700));
  });

  testWidgets('streak milestones (3, 5, 7, 10) are flagged for the celebratory feedback state', (tester) async {
    // Every question answered correctly (all odd ids) by always selecting index 0
    // against a category whose questions are all odd-numbered.
    final allCorrect = FakeQuizApi();
    allCorrect.rushQuestions
      ..clear()
      ..addAll(List.generate(10, (i) => _untimedQuestion(2 * i + 1))); // 1,3,5,...,19 — all odd
    final controller = QuizController(quizApi: allCorrect);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    final milestonesSeen = <int>[];
    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      if (controller.lastIsMilestone) milestonesSeen.add(controller.streak);
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(milestonesSeen, [3, 5, 7, 10]);
  });

  testWidgets('a perfect Rush (no wrong answers) is reflected in the finish summary', (tester) async {
    final allCorrect = FakeQuizApi()..isPerfectRushOverride = true;
    allCorrect.rushQuestions
      ..clear()
      ..addAll(List.generate(10, (i) => _untimedQuestion(2 * i + 1)));
    final controller = QuizController(quizApi: allCorrect);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(controller.wrongCount, 0);
    expect(controller.isPerfectRush, true);
  });

  testWidgets('a new best streak is surfaced separately from a new personal-best score', (tester) async {
    final fakeApi = FakeQuizApi()
      ..personalBestScoreOverride = 999999 // this run can't beat the score record
      ..isNewBestStreakOverride = true; // but it does beat the streak record
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(controller.isNewPersonalBest, false);
    expect(controller.isNewBestStreak, true);
  });

  testWidgets('repeated Rushes (Play Again) reset momentum and per-Rush achievement flags', (tester) async {
    // Play a full, all-correct Rush to completion with every achievement flag
    // true, so resetting them on the next Rush is an actual reset, not a no-op.
    final firstRunApi = FakeQuizApi()
      ..isNewBestStreakOverride = true
      ..isPerfectRushOverride = true
      ..personalBestScoreOverride = 0
      ..rushQuestions.setAll(0, List.generate(10, (i) => _untimedQuestion(2 * i + 1))); // all odd -> all correct
    final controller = QuizController(quizApi: firstRunApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(controller.momentum, greaterThan(0));
    expect(controller.isNewPersonalBest, true);
    expect(controller.isNewBestStreak, true);
    expect(controller.isPerfectRush, true);
    expect(controller.screen, AppScreen.results); // Play Again is only reachable from here

    controller.playAgain();
    await tester.pump();

    expect(controller.momentum, 0);
    expect(controller.isNewPersonalBest, false);
    expect(controller.isNewBestStreak, false);
    expect(controller.isPerfectRush, false);
  });
}
