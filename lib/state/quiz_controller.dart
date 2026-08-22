import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/quiz_data.dart';
import '../models/question.dart';
import '../services/tts_service.dart';

enum AppScreen { home, categories, game, results }

enum AnswerFeedback { none, correct, wrong }

class QuizController extends ChangeNotifier {
  AppScreen screen = AppScreen.home;

  int qIndex = 0;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int correctCount = 0;
  int wrongCount = 0;
  final List<double> responseTimes = [];

  int? selected;
  bool answered = false;
  int timeLeft = 0;
  int clueCount = 1;
  AnswerFeedback feedback = AnswerFeedback.none;
  int xpGained = 0;
  bool isPlaying = false;
  DateTime? _qStartTs;
  int? shakeIndex;

  Timer? _timer;
  Timer? _feedbackDelay;
  Timer? _advanceDelay;

  Question get currentQuestion => kQuestions[qIndex];
  int get questionTotal => kQuestions.length;

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _clearAllTimers() {
    _clearTimer();
    _feedbackDelay?.cancel();
    _advanceDelay?.cancel();
  }

  void startQuestion(int idx) {
    _clearTimer();
    final q = kQuestions[idx];
    selected = null;
    answered = false;
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
    notifyListeners();
    _feedbackDelay = Timer(const Duration(milliseconds: 300), () {
      _showFeedback(false);
    });
  }

  void selectAnswer(int i) {
    if (answered) return;
    _clearTimer();
    final q = currentQuestion;
    final correct = i == q.correct;
    final rt = _qStartTs == null
        ? 0.0
        : DateTime.now().difference(_qStartTs!).inMilliseconds / 1000.0;
    selected = i;
    answered = true;
    shakeIndex = correct ? null : i;
    responseTimes.add(rt);
    notifyListeners();
    _feedbackDelay = Timer(const Duration(milliseconds: 400), () {
      _showFeedback(correct);
    });
  }

  void _showFeedback(bool correct) {
    if (correct) {
      const xp = 250;
      streak += 1;
      bestStreak = streak > bestStreak ? streak : bestStreak;
      score += xp;
      correctCount += 1;
      xpGained = xp;
      feedback = AnswerFeedback.correct;
      TtsService.instance.speak('Correct! Plus $xp XP.');
    } else {
      streak = 0;
      wrongCount += 1;
      feedback = AnswerFeedback.wrong;
      final answer = currentQuestion.options[currentQuestion.correct];
      TtsService.instance.speak('Not this time. The answer was $answer.');
    }
    notifyListeners();
    _advanceDelay = Timer(const Duration(milliseconds: 1600), _nextQuestion);
  }

  void _nextQuestion() {
    final next = qIndex + 1;
    if (next >= kQuestions.length) {
      screen = AppScreen.results;
      feedback = AnswerFeedback.none;
      notifyListeners();
      TtsService.instance.speak(
        'Game complete! You scored $score points, with $correctCount correct '
        'and $wrongCount wrong. Best streak: $bestStreak.',
      );
    } else {
      qIndex = next;
      feedback = AnswerFeedback.none;
      notifyListeners();
      startQuestion(next);
    }
  }

  void playNow() {
    screen = AppScreen.categories;
    notifyListeners();
  }

  void goHome() {
    _clearAllTimers();
    TtsService.instance.stop();
    screen = AppScreen.home;
    notifyListeners();
  }

  void selectCategory() {
    qIndex = 0;
    score = 0;
    streak = 0;
    bestStreak = 0;
    correctCount = 0;
    wrongCount = 0;
    responseTimes.clear();
    feedback = AnswerFeedback.none;
    screen = AppScreen.game;
    notifyListeners();
    startQuestion(0);
  }

  void playAgain() => selectCategory();

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

  double get progressPct => qIndex / kQuestions.length;

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
