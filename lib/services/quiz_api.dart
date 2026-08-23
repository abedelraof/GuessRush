import '../models/category.dart';
import '../models/daily_rush_status.dart';
import '../models/home_summary.dart';
import '../models/leaderboard.dart';
import '../models/mission.dart';
import '../models/player_profile.dart';
import '../models/question.dart';
import 'api_client.dart';

class SessionStart {
  final int sessionId;
  final List<Question> questions;
  // Only meaningful for a resumed Daily Rush (an in-progress attempt from earlier
  // today) — 0 for every freshly-created session, normal or daily.
  final int currentIndex;
  final int removeOneUsesRemaining;

  SessionStart({
    required this.sessionId,
    required this.questions,
    this.currentIndex = 0,
    this.removeOneUsesRemaining = 1,
  });
}

/// A Double Down offer is a one-time-per-Rush prompt: safe (normal scoring)
/// or risky (2x score if correct, no additional penalty if not) — always for
/// a specific upcoming question, never a standing option.
class DoubleDownOffer {
  final int questionId;

  const DoubleDownOffer({required this.questionId});

  factory DoubleDownOffer.fromJson(Map<String, dynamic> json) =>
      DoubleDownOffer(questionId: json['question_id'] as int);
}

class AnswerResult {
  final bool isCorrect;
  final bool timedOut;
  final int correctIndex;
  final String difficulty;
  final int baseScore;
  final double speedMultiplier;
  final double streakMultiplier;
  final int answerScore;
  final int score;
  final int streak;
  final int bestStreak;
  final int xpGained;
  final int serverElapsedMs;
  final int questionsRemaining;
  final bool rushComplete;

  // Strategic mechanics (Phase 5) — all server-authoritative breakdown of this answer.
  final int cluesRevealed;
  final double clueMultiplier;
  final bool removeOneUsed;
  final int removeOneUsesRemaining;
  final String doubleDownChoice; // 'none' | 'safe' | 'risky'
  final double doubleDownMultiplier;
  final DoubleDownOffer? doubleDownOffer; // a NEW offer, for the next question

  AnswerResult({
    required this.isCorrect,
    required this.timedOut,
    required this.correctIndex,
    required this.difficulty,
    required this.baseScore,
    required this.speedMultiplier,
    required this.streakMultiplier,
    required this.answerScore,
    required this.score,
    required this.streak,
    required this.bestStreak,
    required this.xpGained,
    required this.serverElapsedMs,
    required this.questionsRemaining,
    required this.rushComplete,
    required this.cluesRevealed,
    required this.clueMultiplier,
    required this.removeOneUsed,
    required this.removeOneUsesRemaining,
    required this.doubleDownChoice,
    required this.doubleDownMultiplier,
    required this.doubleDownOffer,
  });

  factory AnswerResult.fromJson(Map<String, dynamic> json) => AnswerResult(
        isCorrect: json['is_correct'] as bool,
        timedOut: json['timed_out'] as bool? ?? false,
        correctIndex: json['correct_index'] as int,
        difficulty: json['difficulty'] as String? ?? 'easy',
        baseScore: json['base_score'] as int? ?? 0,
        speedMultiplier: (json['speed_multiplier'] as num?)?.toDouble() ?? 1.0,
        streakMultiplier: (json['streak_multiplier'] as num?)?.toDouble() ?? 1.0,
        answerScore: json['answer_score'] as int? ?? (json['xp_gained'] as int? ?? 0),
        score: json['score'] as int,
        streak: json['streak'] as int,
        bestStreak: json['best_streak'] as int,
        xpGained: json['xp_gained'] as int,
        serverElapsedMs: json['server_elapsed_ms'] as int? ?? 0,
        questionsRemaining: json['questions_remaining'] as int? ?? 0,
        rushComplete: json['rush_complete'] as bool? ?? false,
        cluesRevealed: json['clues_revealed'] as int? ?? 1,
        clueMultiplier: (json['clue_multiplier'] as num?)?.toDouble() ?? 1.0,
        removeOneUsed: json['remove_one_used'] as bool? ?? false,
        removeOneUsesRemaining: json['remove_one_uses_remaining'] as int? ?? 0,
        doubleDownChoice: json['double_down_choice'] as String? ?? 'none',
        doubleDownMultiplier: (json['double_down_multiplier'] as num?)?.toDouble() ?? 1.0,
        doubleDownOffer: json['double_down_offer'] != null
            ? DoubleDownOffer.fromJson(json['double_down_offer'] as Map<String, dynamic>)
            : null,
      );
}

class SessionSummary {
  final int score;
  final int questionsTotal;
  final int questionsAnswered;
  final int correctCount;
  final int wrongCount;
  final int bestStreak;
  final int accuracyPct;
  final int avgResponseTimeMs;
  final int durationMs;
  final int? personalBestScore;
  final bool isNewPersonalBest;
  final int? personalBestStreak;
  final bool isNewBestStreak;
  final bool isPerfectRush;

  // Lifetime progression, applied server-side exactly once per Rush (Phase 3).
  final int xpAwarded;
  final int lifetimeXp;
  final int level;
  final bool leveledUp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final List<Achievement> newlyUnlockedAchievements;

  // Only present when this session was the official Daily Rush attempt (Phase 4).
  final bool isDailyRush;
  final int? dailyRank;
  final int? dailyPreviousBestScore;
  final bool isNewDailyBest;

  // Retention systems (Phase 6) — mission rewards/XP multiplier are already
  // folded into xpAwarded above; these are just the "what happened" detail.
  final List<CompletedMission> newlyCompletedMissions;
  final double xpMultiplierApplied;
  final int dailyStreakCurrent;
  final int dailyStreakLongest;

  SessionSummary({
    required this.score,
    required this.questionsTotal,
    required this.questionsAnswered,
    required this.correctCount,
    required this.wrongCount,
    required this.bestStreak,
    required this.accuracyPct,
    required this.avgResponseTimeMs,
    required this.durationMs,
    required this.personalBestScore,
    required this.isNewPersonalBest,
    required this.personalBestStreak,
    required this.isNewBestStreak,
    required this.isPerfectRush,
    required this.xpAwarded,
    required this.lifetimeXp,
    required this.level,
    required this.leveledUp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.newlyUnlockedAchievements,
    required this.isDailyRush,
    required this.dailyRank,
    required this.dailyPreviousBestScore,
    required this.isNewDailyBest,
    required this.newlyCompletedMissions,
    required this.xpMultiplierApplied,
    required this.dailyStreakCurrent,
    required this.dailyStreakLongest,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        score: json['score'] as int,
        questionsTotal: json['questions_total'] as int? ?? 0,
        questionsAnswered: json['questions_answered'] as int? ?? 0,
        correctCount: json['correct_count'] as int,
        wrongCount: json['wrong_count'] as int,
        bestStreak: json['best_streak'] as int,
        accuracyPct: json['accuracy_pct'] as int,
        avgResponseTimeMs: json['avg_response_time_ms'] as int? ?? 0,
        durationMs: json['duration_ms'] as int? ?? 0,
        personalBestScore: json['personal_best_score'] as int?,
        isNewPersonalBest: json['is_new_personal_best'] as bool? ?? false,
        personalBestStreak: json['personal_best_streak'] as int?,
        isNewBestStreak: json['is_new_best_streak'] as bool? ?? false,
        isPerfectRush: json['is_perfect_rush'] as bool? ?? false,
        xpAwarded: json['xp_awarded'] as int? ?? 0,
        lifetimeXp: json['lifetime_xp'] as int? ?? 0,
        level: json['level'] as int? ?? 1,
        leveledUp: json['leveled_up'] as bool? ?? false,
        xpIntoLevel: json['xp_into_level'] as int? ?? 0,
        xpForNextLevel: json['xp_for_next_level'] as int? ?? 1,
        newlyUnlockedAchievements: (json['newly_unlocked_achievements'] as List? ?? [])
            .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
            .toList(),
        isDailyRush: json['is_daily_rush'] as bool? ?? false,
        dailyRank: json['daily_rank'] as int?,
        dailyPreviousBestScore: json['daily_previous_best_score'] as int?,
        isNewDailyBest: json['is_new_daily_best'] as bool? ?? false,
        newlyCompletedMissions: (json['newly_completed_missions'] as List? ?? [])
            .map((m) => CompletedMission.fromJson(m as Map<String, dynamic>))
            .toList(),
        xpMultiplierApplied: (json['xp_multiplier_applied'] as num?)?.toDouble() ?? 1.0,
        dailyStreakCurrent: json['daily_streak_current'] as int? ?? 0,
        dailyStreakLongest: json['daily_streak_longest'] as int? ?? 0,
      );
}

class ClueReveal {
  final int cluesRevealed;
  final String clueText;
  final int cluesTotal;

  const ClueReveal({required this.cluesRevealed, required this.clueText, required this.cluesTotal});

  factory ClueReveal.fromJson(Map<String, dynamic> json) => ClueReveal(
        cluesRevealed: json['clues_revealed'] as int,
        clueText: json['clue_text'] as String,
        cluesTotal: json['clues_total'] as int,
      );
}

class RemoveOneResult {
  final int removedOptionIndex;
  final int usesRemaining;

  const RemoveOneResult({required this.removedOptionIndex, required this.usesRemaining});

  factory RemoveOneResult.fromJson(Map<String, dynamic> json) => RemoveOneResult(
        removedOptionIndex: json['removed_option_index'] as int,
        usesRemaining: json['uses_remaining'] as int,
      );
}

class QuizApi {
  QuizApi(this._api);

  final ApiClient _api;

  Future<List<Category>> getCategories() async {
    final rows = await _api.getList('/api/categories');
    return rows.map((r) => Category.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<SessionStart> createSession(int categoryId) async {
    final res = await _api.post('/api/sessions', {'category_id': categoryId});
    final questions = (res['questions'] as List)
        .map((q) => Question.fromJson(q as Map<String, dynamic>))
        .toList();
    return SessionStart(
      sessionId: res['session_id'] as int,
      questions: questions,
      removeOneUsesRemaining: res['remove_one_uses_remaining'] as int? ?? 1,
    );
  }

  /// Pings the server once the question actually starts counting down
  /// client-side (e.g. once narration finishes), so its authoritative timing
  /// clock for this question reflects when the player could realistically
  /// start answering rather than the moment it merely became current.
  Future<void> startQuestion({required int sessionId, required int questionId}) async {
    await _api.post('/api/sessions/$sessionId/start', {'question_id': questionId});
  }

  Future<AnswerResult> submitAnswer({
    required int sessionId,
    required int questionId,
    required int selectedIndex,
    required int responseTimeMs,
  }) async {
    final res = await _api.post('/api/sessions/$sessionId/answers', {
      'question_id': questionId,
      'selected_index': selectedIndex,
      'response_time_ms': responseTimeMs,
    });
    return AnswerResult.fromJson(res);
  }

  Future<SessionSummary> finishSession(int sessionId) async {
    final res = await _api.post('/api/sessions/$sessionId/finish');
    return SessionSummary.fromJson(res);
  }

  Future<PlayerProfile> getProfile() async {
    final res = await _api.get('/api/profile');
    return PlayerProfile.fromJson(res);
  }

  Future<DailyRushStatus> getDailyRushStatus() async {
    final res = await _api.get('/api/daily-rush/today');
    return DailyRushStatus.fromJson(res);
  }

  /// Retention-system data (Phase 6) the Home screen needs beyond what
  /// getProfile/getDailyRushStatus already cover — daily streak, today's
  /// mission progress, active events, and global leaderboard position.
  Future<HomeSummary> getHome() async {
    final res = await _api.get('/api/home');
    return HomeSummary.fromJson(res);
  }

  /// Starts today's Daily Rush, or — if the player already has an unfinished
  /// attempt from earlier today — resumes it (same session_id, current_index
  /// tells the caller which question to continue from). Rejected server-side
  /// (ApiException) if today's attempt is already completed.
  Future<SessionStart> startDailyRush() async {
    final res = await _api.post('/api/daily-rush/start');
    final questions = (res['questions'] as List)
        .map((q) => Question.fromJson(q as Map<String, dynamic>))
        .toList();
    return SessionStart(
      sessionId: res['session_id'] as int,
      questions: questions,
      currentIndex: res['current_index'] as int? ?? 0,
      removeOneUsesRemaining: res['remove_one_uses_remaining'] as int? ?? 1,
    );
  }

  /// Reveals the next clue of the current progressive question. Server-persisted
  /// and reflected in the score the next /answers call reports — the client never
  /// decides the clue-based multiplier itself.
  Future<ClueReveal> revealClue(int sessionId) async {
    final res = await _api.post('/api/sessions/$sessionId/reveal-clue');
    return ClueReveal.fromJson(res);
  }

  /// Spends one Remove One charge (if any remain) on the current question.
  /// Safe to call more than once before answering — the server returns the
  /// same removed option rather than spending a second charge.
  Future<RemoveOneResult> useRemoveOne(int sessionId) async {
    final res = await _api.post('/api/sessions/$sessionId/power-ups/remove-one');
    return RemoveOneResult.fromJson(res);
  }

  /// Records Safe or Risky for a currently-active Double Down offer. Fails
  /// (ApiException) if there's no matching offer for the current question.
  Future<void> chooseDoubleDown(int sessionId, String choice) async {
    await _api.post('/api/sessions/$sessionId/double-down', {'choice': choice});
  }

  Future<LeaderboardPage> getLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.global,
    int? categoryId,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = {
      'period': period == LeaderboardPeriod.daily ? 'daily' : 'global',
      'limit': '$limit',
      'offset': '$offset',
      if (categoryId != null) 'category_id': '$categoryId',
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final res = await _api.get('/api/leaderboard?$query');
    return LeaderboardPage.fromJson(res);
  }
}
