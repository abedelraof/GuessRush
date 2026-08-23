import '../models/category.dart';
import '../models/question.dart';
import 'api_client.dart';

class SessionStart {
  final int sessionId;
  final List<Question> questions;

  SessionStart({required this.sessionId, required this.questions});
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
    return SessionStart(sessionId: res['session_id'] as int, questions: questions);
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
}
