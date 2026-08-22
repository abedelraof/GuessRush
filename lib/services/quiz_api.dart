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
  final int correctIndex;
  final int score;
  final int streak;
  final int bestStreak;
  final int xpGained;

  AnswerResult({
    required this.isCorrect,
    required this.correctIndex,
    required this.score,
    required this.streak,
    required this.bestStreak,
    required this.xpGained,
  });

  factory AnswerResult.fromJson(Map<String, dynamic> json) => AnswerResult(
        isCorrect: json['is_correct'] as bool,
        correctIndex: json['correct_index'] as int,
        score: json['score'] as int,
        streak: json['streak'] as int,
        bestStreak: json['best_streak'] as int,
        xpGained: json['xp_gained'] as int,
      );
}

class SessionSummary {
  final int score;
  final int correctCount;
  final int wrongCount;
  final int bestStreak;
  final int accuracyPct;

  SessionSummary({
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.bestStreak,
    required this.accuracyPct,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        score: json['score'] as int,
        correctCount: json['correct_count'] as int,
        wrongCount: json['wrong_count'] as int,
        bestStreak: json['best_streak'] as int,
        accuracyPct: json['accuracy_pct'] as int,
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
