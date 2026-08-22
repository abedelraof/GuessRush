import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../models/category.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/quiz_api.dart';
import '../services/tts_service.dart';

enum AppScreen { boot, login, signup, home, categories, game, results }

enum AnswerFeedback { none, correct, wrong }

class QuizController extends ChangeNotifier {
  QuizController({AuthService? authService, QuizApi? quizApi})
      : authService = authService ?? AuthService(ApiClient.instance),
        quizApi = quizApi ?? QuizApi(ApiClient.instance);

  final AuthService authService;
  final QuizApi quizApi;

  AppScreen screen = AppScreen.boot;

  // Auth
  Player? player;
  bool authLoading = false;
  String? authError;

  // Categories / session
  List<Category> categories = [];
  Category? _lastCategory;
  int? sessionId;
  List<Question> questions = [];
  bool isCreatingSession = false;
  String? errorMessage;

  int qIndex = 0;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int correctCount = 0;
  int wrongCount = 0;
  final List<double> responseTimes = [];

  int? selected;
  bool answered = false;
  bool isGrading = false;
  int? gradedCorrectIndex;
  int timeLeft = 0;
  int clueCount = 1;
  AnswerFeedback feedback = AnswerFeedback.none;
  int xpGained = 0;
  bool isPlaying = false;
  DateTime? _qStartTs;
  int? shakeIndex;

  Timer? _timer;
  Timer? _advanceDelay;

  Question get currentQuestion => questions[qIndex];
  int get questionTotal => questions.length;

  // ---- Boot / Auth ----

  Future<void> bootstrap() async {
    screen = AppScreen.boot;
    notifyListeners();
    final existing = await authService.fetchStoredSession();
    if (existing != null) {
      player = existing;
      await _loadCategoriesAndGoHome();
    } else {
      screen = AppScreen.login;
      notifyListeners();
    }
  }

  Future<void> _loadCategoriesAndGoHome() async {
    try {
      categories = await quizApi.getCategories();
    } on ApiException catch (e) {
      errorMessage = e.message;
    }
    screen = AppScreen.home;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      player = await authService.login(email: email, password: password);
      authLoading = false;
      await _loadCategoriesAndGoHome();
    } on ApiException catch (e) {
      authLoading = false;
      authError = e.message;
      notifyListeners();
    }
  }

  Future<void> signup(String email, String password, String displayName) async {
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      player = await authService.signup(email: email, password: password, displayName: displayName);
      authLoading = false;
      await _loadCategoriesAndGoHome();
    } on ApiException catch (e) {
      authLoading = false;
      authError = e.message;
      notifyListeners();
    }
  }

  void goToSignup() {
    authError = null;
    screen = AppScreen.signup;
    notifyListeners();
  }

  void goToLogin() {
    authError = null;
    screen = AppScreen.login;
    notifyListeners();
  }

  Future<void> logout() async {
    _clearAllTimers();
    TtsService.instance.stop();
    await authService.logout();
    player = null;
    categories = [];
    screen = AppScreen.login;
    notifyListeners();
  }

  // ---- Timers ----

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _clearAllTimers() {
    _clearTimer();
    _advanceDelay?.cancel();
  }

  int _elapsedMs() => _qStartTs == null ? 0 : DateTime.now().difference(_qStartTs!).inMilliseconds;

  // ---- Game flow ----

  void startQuestion(int idx) {
    _clearTimer();
    final q = questions[idx];
    selected = null;
    answered = false;
    isGrading = false;
    gradedCorrectIndex = null;
    errorMessage = null;
    timeLeft = q.timerSeconds;
    clueCount = 1;
    isPlaying = false;
    shakeIndex = null;
    _qStartTs = DateTime.now();
    notifyListeners();
    TtsService.instance.speak(q.prompt ?? '');

    if (q.hasTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (answered) return;
        final t = timeLeft - 1;
        if (t <= 0) {
          _clearTimer();
          timeLeft = 0;
          _handleTimeout();
        } else {
          timeLeft = t;
          notifyListeners();
        }
      });
    }
  }

  void _handleTimeout() {
    answered = true;
    selected = -1;
    isGrading = true;
    errorMessage = null;
    notifyListeners();
    _submitAnswer(-1, _elapsedMs());
  }

  Future<void> selectAnswer(int i) async {
    if (answered || isGrading) return;
    _clearTimer();
    final rt = _elapsedMs();
    selected = i;
    answered = true;
    isGrading = true;
    errorMessage = null;
    notifyListeners();
    await _submitAnswer(i, rt);
  }

  Future<void> _submitAnswer(int selectedIndex, int responseTimeMs) async {
    try {
      final result = await quizApi.submitAnswer(
        sessionId: sessionId!,
        questionId: currentQuestion.id,
        selectedIndex: selectedIndex,
        responseTimeMs: responseTimeMs,
      );
      isGrading = false;
      gradedCorrectIndex = result.correctIndex;
      shakeIndex = (!result.isCorrect && selectedIndex >= 0) ? selectedIndex : null;
      score = result.score;
      streak = result.streak;
      bestStreak = result.bestStreak;
      xpGained = result.xpGained;
      if (result.isCorrect) {
        correctCount += 1;
      } else {
        wrongCount += 1;
      }
      responseTimes.add(responseTimeMs / 1000.0);
      feedback = result.isCorrect ? AnswerFeedback.correct : AnswerFeedback.wrong;
      notifyListeners();

      if (result.isCorrect) {
        TtsService.instance.speak('Correct! Plus ${result.xpGained} XP.');
      } else {
        final answerText = currentQuestion.options[result.correctIndex];
        TtsService.instance.speak('Not this time. The answer was $answerText.');
      }
      _advanceDelay = Timer(const Duration(milliseconds: 1600), _nextQuestion);
    } on ApiException catch (e) {
      // No local fallback grading — that would reopen the cheat vector
      // server-authoritative grading exists to close. Re-enable the
      // options so the user can just tap again to retry.
      isGrading = false;
      answered = false;
      selected = null;
      errorMessage = e.message;
      notifyListeners();
    }
  }

  void _nextQuestion() {
    final next = qIndex + 1;
    if (next >= questions.length) {
      _finishSession();
    } else {
      qIndex = next;
      feedback = AnswerFeedback.none;
      notifyListeners();
      startQuestion(next);
    }
  }

  Future<void> _finishSession() async {
    screen = AppScreen.results;
    feedback = AnswerFeedback.none;
    notifyListeners();
    TtsService.instance.speak(
      'Game complete! You scored $score points, with $correctCount correct '
      'and $wrongCount wrong. Best streak: $bestStreak.',
    );
    try {
      await quizApi.finishSession(sessionId!);
    } on ApiException {
      // Non-fatal: the results screen already shows the locally-tracked
      // totals, which mirror the server's authoritative per-answer
      // responses. /finish just marks the session row completed.
    }
  }

  void playNow() {
    screen = AppScreen.categories;
    notifyListeners();
  }

  void goHome() {
    _clearAllTimers();
    TtsService.instance.stop();
    sessionId = null;
    questions = [];
    screen = AppScreen.home;
    notifyListeners();
  }

  Future<void> selectCategory(Category category) async {
    _lastCategory = category;
    errorMessage = null;
    isCreatingSession = true;
    notifyListeners();
    try {
      final start = await quizApi.createSession(category.id);
      sessionId = start.sessionId;
      questions = start.questions;
      qIndex = 0;
      score = 0;
      streak = 0;
      bestStreak = 0;
      correctCount = 0;
      wrongCount = 0;
      responseTimes.clear();
      feedback = AnswerFeedback.none;
      isCreatingSession = false;
      screen = AppScreen.game;
      notifyListeners();
      startQuestion(0);
    } on ApiException catch (e) {
      isCreatingSession = false;
      errorMessage = e.message;
      notifyListeners();
    }
  }

  void playAgain() {
    final cat = _lastCategory;
    if (cat != null) selectCategory(cat);
  }

  void revealClue() {
    final clues = currentQuestion.clues;
    if (clues == null) return;
    if (clueCount < clues.length) {
      clueCount += 1;
      notifyListeners();
    }
  }

  void togglePlay() {
    isPlaying = !isPlaying;
    notifyListeners();
  }

  double get progressPct => questions.isEmpty ? 0 : qIndex / questions.length;

  double get accuracyPct {
    final total = correctCount + wrongCount;
    return total > 0 ? correctCount / total * 100 : 0;
  }

  double get avgResponseTime {
    if (responseTimes.isEmpty) return 0;
    return responseTimes.reduce((a, b) => a + b) / responseTimes.length;
  }

  @override
  void dispose() {
    _clearAllTimers();
    TtsService.instance.stop();
    super.dispose();
  }
}
