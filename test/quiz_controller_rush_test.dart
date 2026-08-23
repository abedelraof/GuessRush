import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quizo/models/category.dart';
import 'package:quizo/models/daily_rush_status.dart';
import 'package:quizo/models/home_summary.dart';
import 'package:quizo/models/leaderboard.dart';
import 'package:quizo/models/mission.dart';
import 'package:quizo/models/player_profile.dart';
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

/// Same shape as `_untimedQuestion`, but with clues so the Phase 5 progressive
/// clue-reveal flow (server-authoritative, gated by `type == progressive`) has
/// something to exercise.
Question _progressiveQuestion(int id, {int clueCountTotal = 3}) => Question(
      id: id,
      type: QuestionType.progressive,
      label: 'Label',
      clues: List.generate(clueCountTotal, (i) => 'Clue ${i + 1}'),
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

  // Phase 3 progression overrides — default to "nothing special happened",
  // matching a server response for a Rush that's not the player's first.
  int xpAwardedOverride = 42;
  int levelOverride = 1;
  bool leveledUpOverride = false;
  int xpIntoLevelOverride = 42;
  int xpForNextLevelOverride = 100;
  List<Achievement> newlyUnlockedOverride = const [];
  int getProfileCallCount = 0;
  bool throwOnProfile = false;

  // Phase 4 (Competition & Daily Rush) overrides.
  bool isDailyRushOverride = false;
  int? dailyRankOverride;
  int? dailyPreviousBestScoreOverride;
  bool isNewDailyBestOverride = false;
  DailyRushStatus? dailyRushStatusOverride;
  int getDailyRushStatusCallCount = 0;
  int startDailyRushCallCount = 0;
  int dailyRushStartCurrentIndex = 0;
  List<Question>? dailyRushQuestionsOverride;

  // Phase 6 (Retention Systems) overrides.
  List<CompletedMission> newlyCompletedMissionsOverride = const [];
  double xpMultiplierAppliedOverride = 1.0;
  int dailyStreakCurrentOverride = 0;
  int dailyStreakLongestOverride = 0;
  HomeSummary? homeSummaryOverride;
  int getHomeCallCount = 0;

  // Phase 5 (Strategic Gameplay Mechanics) overrides.
  int cluesRevealedOverride = 1;
  double clueMultiplierOverride = 1.0;
  bool removeOneUsedOverride = false;
  int removeOneUsesRemainingOverride = 1;
  String doubleDownChoiceOverride = 'none';
  double doubleDownMultiplierOverride = 1.0;
  DoubleDownOffer? doubleDownOfferOverride;

  int revealClueCallCount = 0;
  ClueReveal? revealClueResultOverride;
  int useRemoveOneCallCount = 0;
  RemoveOneResult? useRemoveOneResultOverride;
  int chooseDoubleDownCallCount = 0;
  String? lastDoubleDownChoiceRequested;

  @override
  Future<SessionStart> createSession(int categoryId) async {
    return SessionStart(sessionId: 1, questions: rushQuestions);
  }

  @override
  Future<DailyRushStatus> getDailyRushStatus() async {
    getDailyRushStatusCallCount++;
    return dailyRushStatusOverride ??
        const DailyRushStatus(
          date: '2026-08-23',
          secondsUntilReset: 3600,
          available: true,
          completed: false,
          sessionId: null,
          todayScore: null,
          todayRank: null,
          bestScore: null,
        );
  }

  @override
  Future<SessionStart> startDailyRush() async {
    startDailyRushCallCount++;
    return SessionStart(
      sessionId: 1,
      questions: dailyRushQuestionsOverride ?? rushQuestions,
      currentIndex: dailyRushStartCurrentIndex,
    );
  }

  @override
  Future<LeaderboardPage> getLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.global,
    int? categoryId,
    int limit = 20,
    int offset = 0,
  }) async {
    return LeaderboardPage(period: period, date: null, total: 0, entries: const [], me: null);
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
      cluesRevealed: cluesRevealedOverride,
      clueMultiplier: clueMultiplierOverride,
      removeOneUsed: removeOneUsedOverride,
      removeOneUsesRemaining: removeOneUsesRemainingOverride,
      doubleDownChoice: doubleDownChoiceOverride,
      doubleDownMultiplier: doubleDownMultiplierOverride,
      doubleDownOffer: doubleDownOfferOverride,
    );
  }

  @override
  Future<ClueReveal> revealClue(int sessionId) async {
    revealClueCallCount++;
    return revealClueResultOverride ?? const ClueReveal(cluesRevealed: 2, clueText: 'Clue text', cluesTotal: 3);
  }

  @override
  Future<RemoveOneResult> useRemoveOne(int sessionId) async {
    useRemoveOneCallCount++;
    return useRemoveOneResultOverride ?? const RemoveOneResult(removedOptionIndex: 1, usesRemaining: 0);
  }

  @override
  Future<void> chooseDoubleDown(int sessionId, String choice) async {
    chooseDoubleDownCallCount++;
    lastDoubleDownChoiceRequested = choice;
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
      xpAwarded: xpAwardedOverride,
      lifetimeXp: xpIntoLevelOverride, // fine for tests: level 1 means lifetimeXp == xpIntoLevel
      level: levelOverride,
      leveledUp: leveledUpOverride,
      xpIntoLevel: xpIntoLevelOverride,
      xpForNextLevel: xpForNextLevelOverride,
      newlyUnlockedAchievements: newlyUnlockedOverride,
      isDailyRush: isDailyRushOverride,
      dailyRank: dailyRankOverride,
      dailyPreviousBestScore: dailyPreviousBestScoreOverride,
      isNewDailyBest: isNewDailyBestOverride,
      newlyCompletedMissions: newlyCompletedMissionsOverride,
      xpMultiplierApplied: xpMultiplierAppliedOverride,
      dailyStreakCurrent: dailyStreakCurrentOverride,
      dailyStreakLongest: dailyStreakLongestOverride,
    );
  }

  @override
  Future<HomeSummary> getHome() async {
    getHomeCallCount++;
    return homeSummaryOverride ??
        const HomeSummary(
          dailyStreakCurrent: 0,
          dailyStreakLongest: 0,
          missions: [],
          activeEvents: [],
          leaderboardPosition: null,
        );
  }

  @override
  Future<PlayerProfile> getProfile() async {
    getProfileCallCount++;
    if (throwOnProfile) throw ApiException('profile unavailable');
    return PlayerProfile(
      displayName: 'Test Player',
      level: levelOverride,
      lifetimeXp: xpIntoLevelOverride,
      xpIntoLevel: xpIntoLevelOverride,
      xpForNextLevel: xpForNextLevelOverride,
      stats: const ProfileStats(
        rushesCompleted: 1, questionsAnswered: 10, questionsCorrect: 5, accuracyPct: 50, avgResponseTimeMs: 1200,
      ),
      records: ProfileRecords(
        bestRushScore: _score, bestStreak: _bestStreak, bestAccuracyPct: 50,
        fastestAvgResponseTimeMs: 1200, perfectRushCount: isPerfectRushOverride ? 1 : 0,
      ),
      achievements: const [],
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

  testWidgets('finishing a Rush surfaces the server-awarded XP, level-up, and unlocked achievements', (tester) async {
    final fakeApi = FakeQuizApi()
      ..xpAwardedOverride = 268
      ..levelOverride = 2
      ..leveledUpOverride = true
      ..xpIntoLevelOverride = 18
      ..xpForNextLevelOverride = 150
      ..newlyUnlockedOverride = const [
        Achievement(key: 'first_rush', name: 'First Rush', description: 'Complete your first Rush.'),
      ];
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(controller.xpAwarded, 268);
    expect(controller.leveledUp, true);
    expect(controller.newlyUnlockedAchievements.map((a) => a.key), ['first_rush']);
  });

  testWidgets('finishing a Rush refreshes the lifetime profile', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();
    expect(fakeApi.getProfileCallCount, 0); // selectCategory itself doesn't touch the profile

    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }
    await tester.pump(); // let the fire-and-forget loadProfile() call resolve

    expect(fakeApi.getProfileCallCount, 1);
    expect(controller.profile, isNotNull);
  });

  testWidgets('goToProfile switches screens and (re)loads the profile', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    controller.goToProfile();
    await tester.pump();

    expect(controller.screen, AppScreen.profile);
    expect(fakeApi.getProfileCallCount, 1);
    expect(controller.profile, isNotNull);
    expect(controller.profile!.level, 1);
  });

  testWidgets('a failed profile load is non-fatal — it just leaves profile unset', (tester) async {
    final fakeApi = FakeQuizApi()..throwOnProfile = true;
    final controller = QuizController(quizApi: fakeApi);

    controller.goToProfile();
    await tester.pump();

    expect(controller.screen, AppScreen.profile);
    expect(controller.profile, isNull);
  });

  testWidgets('startDailyRush begins a Rush sourced from the daily-rush endpoint, not a normal category', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    await controller.startDailyRush();
    await tester.pump();

    expect(fakeApi.startDailyRushCallCount, 1);
    expect(controller.screen, AppScreen.game);
    expect(controller.isDailyRush, true);
    expect(controller.qIndex, 0);
  });

  testWidgets('resuming an in-progress Daily Rush starts the local qIndex at the server-reported current_index', (tester) async {
    final fakeApi = FakeQuizApi()..dailyRushStartCurrentIndex = 3;
    final controller = QuizController(quizApi: fakeApi);

    await controller.startDailyRush();
    await tester.pump();

    expect(controller.qIndex, 3);
  });

  testWidgets('finishing a Daily Rush surfaces rank and daily-best comparison, and refreshes the daily status', (tester) async {
    final fakeApi = FakeQuizApi()
      ..isDailyRushOverride = true
      ..dailyRankOverride = 4
      ..dailyPreviousBestScoreOverride = 300
      ..isNewDailyBestOverride = true;
    final controller = QuizController(quizApi: fakeApi);

    await controller.startDailyRush();
    await tester.pump();
    final initialStatusLoads = fakeApi.getDailyRushStatusCallCount;

    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(controller.isDailyRush, true);
    expect(controller.dailyRank, 4);
    expect(controller.dailyPreviousBestScore, 300);
    expect(controller.isNewDailyBest, true);
    // The daily status tile's data (score/rank/completed) just changed, so it's reloaded —
    // not just the lifetime profile, which was already covered by an earlier test.
    expect(fakeApi.getDailyRushStatusCallCount, greaterThan(initialStatusLoads));
  });

  testWidgets('finishing a normal (non-daily) Rush does not touch the daily status endpoint', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(controller.isDailyRush, false);
    expect(fakeApi.getDailyRushStatusCallCount, 0);
  });

  testWidgets('goToLeaderboard switches screens and loads the requested period', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    controller.goToLeaderboard(period: LeaderboardPeriod.daily);
    await tester.pump();

    expect(controller.screen, AppScreen.leaderboard);
    expect(controller.leaderboardPeriod, LeaderboardPeriod.daily);
    expect(controller.leaderboardPage, isNotNull);
  });

  testWidgets('starting a fresh (non-daily) Rush resets any leftover Daily Rush result state', (tester) async {
    final fakeApi = FakeQuizApi()
      ..isDailyRushOverride = true
      ..dailyRankOverride = 2
      ..isNewDailyBestOverride = true;
    final controller = QuizController(quizApi: fakeApi);

    await controller.startDailyRush();
    await tester.pump();
    await controller.selectAnswer(0); // just enough to reach /finish eventually isn't needed here
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));

    // Bail out of the Daily Rush mid-way and start a normal one instead.
    controller.goHome();
    await tester.pump();
    fakeApi.isDailyRushOverride = false; // the next Rush this fake grades is a normal one
    await controller.selectCategory(_testCategory);
    await tester.pump();

    expect(controller.isDailyRush, false);
    expect(controller.dailyRank, isNull);
    expect(controller.isNewDailyBest, false);
  });

  testWidgets('revealClue asks the server and advances clueCount for a progressive question', (tester) async {
    final fakeApi = FakeQuizApi()
      ..revealClueResultOverride = const ClueReveal(cluesRevealed: 2, clueText: 'Clue 2', cluesTotal: 3);
    fakeApi.rushQuestions[0] = _progressiveQuestion(1);
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    expect(controller.clueCount, 1);

    await controller.revealClue();
    await tester.pump();

    expect(fakeApi.revealClueCallCount, 1);
    expect(controller.clueCount, 2);
  });

  testWidgets('revealClue is a no-op for a non-progressive question', (tester) async {
    final fakeApi = FakeQuizApi(); // default question is plain text, has no clues
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    await controller.revealClue();
    await tester.pump();

    expect(fakeApi.revealClueCallCount, 0);
    expect(controller.clueCount, 1);
  });

  testWidgets('useRemoveOne marks an option removed and adopts the server-reported remaining count', (tester) async {
    final fakeApi = FakeQuizApi()
      ..useRemoveOneResultOverride = const RemoveOneResult(removedOptionIndex: 2, usesRemaining: 0);
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    expect(controller.removeOneUsesRemaining, 1); // from SessionStart's default

    await controller.useRemoveOne();
    await tester.pump();

    expect(fakeApi.useRemoveOneCallCount, 1);
    expect(controller.removedOptionIndex, 2);
    expect(controller.removeOneUsesRemaining, 0);
  });

  testWidgets('useRemoveOne is a no-op once already used on the current question', (tester) async {
    final fakeApi = FakeQuizApi();
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    await controller.useRemoveOne();
    await tester.pump();
    await controller.useRemoveOne(); // swallowed by the removedOptionIndex guard
    await tester.pump();

    expect(fakeApi.useRemoveOneCallCount, 1);
  });

  testWidgets('a Double Down offer surfaces before the next question, and a risky choice/outcome flow through',
      (tester) async {
    final fakeApi = FakeQuizApi()..doubleDownOfferOverride = const DoubleDownOffer(questionId: 2);
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();

    await controller.selectAnswer(0); // question id 1
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700)); // fires _nextQuestion

    expect(controller.awaitingDoubleDownChoice, true);
    expect(controller.qIndex, 1);

    await controller.chooseDoubleDown('risky');
    await tester.pump();

    expect(fakeApi.chooseDoubleDownCallCount, 1);
    expect(fakeApi.lastDoubleDownChoiceRequested, 'risky');
    expect(controller.awaitingDoubleDownChoice, false);
    expect(controller.currentDoubleDownChoice, 'risky');

    // Answer question 2 with the server reporting the risky outcome.
    fakeApi.doubleDownChoiceOverride = 'risky';
    fakeApi.doubleDownMultiplierOverride = 2.0;
    await controller.selectAnswer(0);
    await tester.pump();

    expect(controller.lastDoubleDownChoice, 'risky');
    expect(controller.lastDoubleDownMultiplier, 2.0);

    // Drain the remaining Rush so no timers are left pending at test teardown.
    await tester.pump(const Duration(milliseconds: 1700));
    for (var i = 2; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }
  });

  testWidgets('Home summary (streak/missions/events) refreshes after finishing a Rush', (tester) async {
    final fakeApi = FakeQuizApi()
      ..homeSummaryOverride = const HomeSummary(
        dailyStreakCurrent: 2,
        dailyStreakLongest: 5,
        missions: [
          Mission(
            key: 'complete_1_rush', name: 'Warm Up', description: 'Complete 1 Rush.',
            resetPeriod: 'daily', target: 1, progress: 0, completed: false, rewardXp: 30,
          ),
        ],
        activeEvents: [],
        leaderboardPosition: LeaderboardPosition(rank: 3, total: 20),
      );
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();
    expect(fakeApi.getHomeCallCount, 0, reason: 'selectCategory alone does not touch home — that only happens on boot/login and after finishing');

    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }
    await tester.pump(); // let the fire-and-forget loadHome() call resolve

    expect(fakeApi.getHomeCallCount, 1, reason: 'finishing a Rush refreshes the home summary');
    expect(controller.homeSummary?.dailyStreakCurrent, 2);
  });

  testWidgets('newly completed missions and an extended daily streak surface on the results screen state', (tester) async {
    final fakeApi = FakeQuizApi()
      ..newlyCompletedMissionsOverride = const [
        CompletedMission(key: 'complete_daily_rush', name: "Today's Challenge", rewardXp: 60),
      ]
      ..xpMultiplierAppliedOverride = 2.0
      ..dailyStreakCurrentOverride = 4;
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();
    expect(controller.dailyStreakCurrent, 0); // nothing reported yet — fresh Rush

    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }

    expect(controller.newlyCompletedMissions.map((m) => m.key), ["complete_daily_rush"]);
    expect(controller.lastXpMultiplierApplied, 2.0);
    expect(controller.dailyStreakCurrent, 4);
    expect(controller.dailyStreakJustExtended, true, reason: '4 > the previous known value of 0');
  });

  testWidgets('Play Again resets the per-Rush mission/streak-extended flags but keeps the known streak count', (tester) async {
    final fakeApi = FakeQuizApi()
      ..newlyCompletedMissionsOverride = const [
        CompletedMission(key: 'complete_1_rush', name: 'Warm Up', rewardXp: 30),
      ]
      ..dailyStreakCurrentOverride = 3;
    final controller = QuizController(quizApi: fakeApi);

    await controller.selectCategory(_testCategory);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await controller.selectAnswer(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
    }
    expect(controller.newlyCompletedMissions, isNotEmpty);
    expect(controller.dailyStreakJustExtended, true);

    controller.playAgain();
    await tester.pump();

    expect(controller.newlyCompletedMissions, isEmpty);
    expect(controller.dailyStreakJustExtended, false);
    expect(controller.dailyStreakCurrent, 3, reason: 'the known streak count itself is not a per-Rush flag');
  });
}
