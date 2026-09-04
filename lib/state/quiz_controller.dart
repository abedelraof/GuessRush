import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/painting.dart';

import '../models/category.dart';
import '../models/daily_rush_status.dart';
import '../models/game_mode.dart';
import '../models/home_summary.dart';
import '../models/leaderboard.dart';
import '../models/match.dart';
import '../models/mission.dart';
import '../models/player.dart';
import '../models/player_profile.dart';
import '../models/question.dart';
import '../services/api_client.dart';
import '../services/audio_player_service.dart';
import '../services/auth_service.dart';
import '../services/haptics_service.dart';
import '../services/match_socket_service.dart';
import '../services/notification_service.dart';
import '../services/quiz_api.dart';
import '../services/settings_service.dart';

enum AppScreen {
  boot,
  login,
  signup,
  home,
  pickRush,
  playWithFriends,
  matchWaiting,
  game,
  feedback,
  results,
  profile,
  leaderboard,
  events,
  settings,
}

/// Which sub-flow matchWaitingScreen is showing — set by whichever
/// controller method navigated there.
enum MatchFlowKind { random, friend }

enum AnswerFeedback { none, correct, wrong, timeout }

/// Streak counts that trigger a slightly bigger celebration in the feedback overlay.
const kStreakMilestones = {3, 5, 7, 10};

/// Rush Momentum (0-100): a lightweight, purely-presentational read on how
/// well the current Rush is going overall. Distinct from streak — streak is
/// consecutive correct answers only; momentum also reflects speed and dips
/// (gently) on wrong answers and (sharply) on timeouts, so a rough patch
/// shows up even mid-streak-rebuild. Never affects scoring.
enum MomentumTier { low, medium, high, max }

MomentumTier momentumTierFor(double momentum) {
  if (momentum >= 75) return MomentumTier.max;
  if (momentum >= 50) return MomentumTier.high;
  if (momentum >= 25) return MomentumTier.medium;
  return MomentumTier.low;
}

/// Qualitative read on how fast a correct answer was, from the server's
/// speed_multiplier (1.0 at the deadline, up to 1.5 for a near-instant answer).
/// Empty for untimed questions, where speed isn't meaningful.
String speedLabelFor(double speedMultiplier, {required bool hasTimer}) {
  if (!hasTimer) return '';
  if (speedMultiplier >= 1.4) return 'INSANE!';
  if (speedMultiplier >= 1.25) return 'FAST!';
  if (speedMultiplier >= 1.05) return 'GOOD!';
  return 'CLOSE!';
}

/// Mirrors server mechanics.config.js's CLUE_SCORE_MULTIPLIERS — display only,
/// so the reveal-clue button can show "next clue: 60% score" up front. The
/// server remains the sole source of truth for the actual multiplier applied.
const kClueScoreMultipliers = [1.0, 0.8, 0.6, 0.4, 0.2];

double clueMultiplierHintFor(int cluesRevealed) {
  final index = cluesRevealed.clamp(1, kClueScoreMultipliers.length) - 1;
  return kClueScoreMultipliers[index];
}

class QuizController extends ChangeNotifier {
  QuizController({
    AuthService? authService,
    QuizApi? quizApi,
    Stream<MatchEvent>? matchEvents,
  }) : authService = authService ?? AuthService(ApiClient.instance),
       quizApi = quizApi ?? QuizApi(ApiClient.instance),
       _matchEvents = matchEvents ?? MatchSocketService.instance.events,
       // Only the real MatchSocketService singleton actually needs connecting/
       // disconnecting — a test-injected stream is already "live" on its own,
       // and must never touch the real singleton's state.
       _usesRealMatchSocket = matchEvents == null;

  final AuthService authService;
  final QuizApi quizApi;
  final Stream<MatchEvent> _matchEvents;
  final bool _usesRealMatchSocket;
  final SettingsService _settings = SettingsService();

  AppScreen screen = AppScreen.boot;

  // Auth
  Player? player;
  bool authLoading = false;
  String? authError;

  // Categories / session. Categories stay internal (used server-side to keep a Pick Your
  // Rush session varied) — `selectCategory`/`categories` have no UI entry point anymore,
  // but stay wired up for anything that still starts a Rush by category directly.
  List<Category> categories = [];
  Category? _lastCategory;
  GameMode? _lastMode;
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
  String? audioError;
  DateTime? _qStartTs;
  int? shakeIndex;

  // Server-authoritative Rush result, populated once /finish returns.
  int avgResponseTimeMs = 0;
  int durationMs = 0;
  int? personalBestScore;
  bool isNewPersonalBest = false;
  int? personalBestStreak;
  bool isNewBestStreak = false;
  bool isPerfectRush = false;

  // Persistent progression (Phase 3) — server-authoritative, applied exactly once per
  // completed Rush. `profile` is the full lifetime profile (level/XP/stats/achievements),
  // refreshed on boot and after every finished Rush; the rest are this Rush's own
  // XP/level-up/achievement-unlock outcome, for the results screen's subtle feedback.
  PlayerProfile? profile;
  int xpAwarded = 0;
  bool leveledUp = false;
  List<Achievement> newlyUnlockedAchievements = [];

  // Competition (Phase 4). `dailyRushStatus` drives the Home screen's Daily Rush
  // tile — refreshed on boot and after every finished Rush, same lifecycle as
  // `profile`. `isDailyRush`/`dailyRank`/etc are this Rush's own outcome, only
  // meaningful when it was today's official Daily Rush attempt.
  DailyRushStatus? dailyRushStatus;
  bool isDailyRush = false;
  int? dailyRank;
  int? dailyPreviousBestScore;
  bool isNewDailyBest = false;

  LeaderboardPage? leaderboardPage;
  LeaderboardPeriod leaderboardPeriod = LeaderboardPeriod.global;
  bool isLoadingLeaderboard = false;
  String? leaderboardError;

  // Retention systems (Phase 6) — daily streak, missions, and active events for
  // the Home screen. `homeSummary` refreshes on the same lifecycle as `profile`/
  // `dailyRushStatus` (boot and after every finished Rush). `newlyCompletedMissions`
  // and the streak fields below are this Rush's own outcome from /finish, kept
  // separate from homeSummary so the results screen doesn't wait on a second
  // network round-trip to show what just happened.
  HomeSummary? homeSummary;
  List<CompletedMission> newlyCompletedMissions = [];
  double lastXpMultiplierApplied = 1.0;
  int dailyStreakCurrent = 0;
  bool dailyStreakJustExtended = false;

  // Strategic mechanics (Phase 5) — clues, the Remove One power-up, and the
  // Double Down risk/reward decision. All server-authoritative: the client only
  // ever reflects what the last server response said, and asks permission
  // (via the reveal-clue/remove-one/double-down endpoints) before assuming
  // anything changed. `clueCount` continues to double as "clues revealed for
  // the current question", now kept in sync with the server instead of purely local.
  int removeOneUsesRemaining = 0;
  bool isUsingRemoveOne = false;
  int? removedOptionIndex;
  bool isRevealingClue = false;
  DoubleDownOffer?
  pendingDoubleDownOffer; // set once submitAnswer reports a new offer
  bool awaitingDoubleDownChoice =
      false; // true while the decision overlay should show
  bool isChoosingDoubleDown = false;
  String currentDoubleDownChoice =
      'none'; // this question's committed choice, if any
  String lastDoubleDownChoice = 'none';
  double lastDoubleDownMultiplier = 1.0;
  int lastCluesRevealed = 1;
  double lastClueMultiplier = 1.0;
  bool lastRemoveOneUsed = false;

  // Rush Momentum (0-100) and the breakdown behind the most recent answer,
  // used by the feedback overlay/HUD — never affects scoring.
  double momentum = 0;
  String lastSpeedLabel = '';
  String lastDifficulty = 'easy';
  double lastSpeedMultiplier = 1.0;
  double lastStreakMultiplier = 1.0;
  int lastStreakBeforeAnswer = 0;
  bool lastIsMilestone = false;

  // Server-authoritative "is the Rush over" signal from the last answer. For every
  // fixed-length mode this always agrees with qIndex reaching the end of `questions`,
  // but Streak Rush can end early (on the first miss) while `questions` still has more
  // entries left — _nextQuestion checks this rather than only the length comparison.
  bool lastRushComplete = false;

  // Play With Friends (1v1 matches). `activeMatchId` is the one flag everything
  // else here hangs off — null for an ordinary solo/Daily Rush, so none of this
  // affects normal play. A match's own gameplay is otherwise an entirely
  // ordinary Rush session (see _beginMatch) — this is purely the presentational
  // layer on top: opponent identity/progress and the eventual head-to-head result.
  int? activeMatchId;
  MatchOpponent? opponent;
  int opponentQuestionIndex = 0;
  MatchFlowKind matchFlowKind = MatchFlowKind.random;
  bool isSearchingMatch = false;
  String? friendInviteCode;
  String? matchError;
  MatchResultEvent? matchResult;
  StreamSubscription<MatchEvent>? _matchEventsSub;

  Timer? _timer;
  Timer? _advanceDelay;
  Timer? _tickTimer;

  Question get currentQuestion => questions[qIndex];
  int get questionTotal => questions.length;

  // ---- Boot / Auth ----

  /// True once a real account is needed — i.e. there's no player yet, or the
  /// current one is just an auto-provisioned guest. Solo play never checks
  /// this; only Play With Friends does (see [goToPlayWithFriends]).
  bool get needsAccountForFriends => player?.isGuest ?? true;

  // Where to return to after login/signup completes, when it was reached via
  // an account gate (Play With Friends, or "Create Account" from Settings)
  // rather than head-on.
  AppScreen? _pendingScreenAfterAuth;

  Future<void> bootstrap() async {
    screen = AppScreen.boot;
    notifyListeners();
    await _settings.load();
    HapticsService.instance.enabled = _settings.hapticsEnabled;
    final existing = await authService.fetchStoredSession();
    if (existing != null) {
      player = existing;
      await _loadCategoriesAndGoHome();
      return;
    }
    // No session yet: play as a guest immediately rather than asking to log
    // in — an account is only needed later, if they try Play With Friends.
    try {
      player = await authService.guest();
      await _loadCategoriesAndGoHome();
    } on ApiException catch (e) {
      authError = e.message;
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
    // Fire-and-forget: home screen renders fine before any of these resolve.
    loadProfile();
    loadDailyRushStatus();
    loadHome();
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
      _continueAfterAuthGate();
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
      // Currently a guest? Upgrade that same account in place so whatever
      // was played as a guest (XP, level, stats) carries over, instead of
      // abandoning it for a brand-new player row.
      player = (player?.isGuest ?? false)
          ? await authService.upgrade(email: email, password: password, displayName: displayName)
          : await authService.signup(email: email, password: password, displayName: displayName);
      authLoading = false;
      await _loadCategoriesAndGoHome();
      _continueAfterAuthGate();
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

  /// Entry point for the "Create Account" CTA on the Settings screen (a
  /// guest upgrading in place) — same signup screen as everywhere else, just
  /// remembers to return to Settings afterward instead of Home.
  void goToSignupFromSettings() {
    _pendingScreenAfterAuth = AppScreen.settings;
    goToSignup();
  }

  /// Backs out of a login/signup screen reached via an account gate, without
  /// completing it — back to home, same guest session as before.
  void cancelAuthGate() {
    authError = null;
    _pendingScreenAfterAuth = null;
    screen = AppScreen.home;
    notifyListeners();
  }

  void _continueAfterAuthGate() {
    final target = _pendingScreenAfterAuth;
    _pendingScreenAfterAuth = null;
    if (target == AppScreen.playWithFriends) {
      goToPlayWithFriends();
    } else if (target == AppScreen.settings) {
      goToSettings();
    }
  }

  Future<void> logout() async {
    _clearAllTimers();
    AudioPlayerService.instance.stop();
    await authService.logout();
    player = null;
    categories = [];
    screen = AppScreen.boot;
    notifyListeners();
    // Land back on home as a fresh guest, same as first launch, rather than
    // forcing a login screen the app no longer opens with.
    try {
      player = await authService.guest();
      await _loadCategoriesAndGoHome();
    } on ApiException catch (e) {
      authError = e.message;
      screen = AppScreen.login;
      notifyListeners();
    }
  }

  // ---- Timers ----

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _clearAllTimers() {
    _clearTimer();
    _advanceDelay?.cancel();
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  int _elapsedMs() => _qStartTs == null
      ? 0
      : DateTime.now().difference(_qStartTs!).inMilliseconds;

  // ---- Game flow ----

  void startQuestion(int idx) {
    _clearTimer();
    _tickTimer?.cancel();
    _tickTimer = null;
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
    audioError = null;
    removedOptionIndex = null;
    currentDoubleDownChoice = 'none';
    _qStartTs = DateTime.now();
    notifyListeners();
    _playQuestionAudio(q.audioUrl, q.hasTimer);

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

  Future<void> _playQuestionAudio(String? url, bool hasTimer) async {
    if (url == null) {
      audioError = 'No narration generated for this question yet.';
      notifyListeners();
      if (hasTimer) _startTicking();
      return;
    }
    try {
      // Waits for the clip to actually finish (not just start) so the
      // countdown tick only kicks in once the narrator stops speaking.
      if (_settings.narrationEnabled) await AudioPlayerService.instance.playUrl(url);
    } catch (e) {
      audioError = 'Audio failed to play: $e';
      notifyListeners();
    } finally {
      if (hasTimer) _startTicking();
    }
  }

  // Countdown tick sound: starts once narration finishes, and re-schedules
  // itself faster as time runs low so it audibly speeds up near the end.
  void _startTicking() {
    _tickTimer?.cancel();
    _scheduleTick();
    _pingQuestionStart();
  }

  // Tells the server the countdown is actually starting now, so its
  // authoritative timing clock for this question lines up with what the
  // player sees rather than the moment the question merely became current.
  // Fire-and-forget: if it fails, grading still works off the earlier
  // server-side fallback timestamp, just less generously.
  Future<void> _pingQuestionStart() async {
    try {
      await quizApi.startQuestion(
        sessionId: sessionId!,
        questionId: currentQuestion.id,
      );
    } on ApiException {
      // Ignored — see comment above.
    }
  }

  void _scheduleTick() {
    if (answered || timeLeft <= 0) return;
    if (_settings.soundEffectsEnabled) AudioPlayerService.instance.playTick();
    final Duration interval;
    if (timeLeft <= 3) {
      interval = const Duration(milliseconds: 250);
      HapticsService.instance.selectionClick(); // final-seconds urgency cue
    } else if (timeLeft <= 5) {
      interval = const Duration(milliseconds: 500);
    } else {
      interval = const Duration(seconds: 1);
    }
    _tickTimer = Timer(interval, _scheduleTick);
  }

  void _handleTimeout() {
    _tickTimer?.cancel();
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
    _tickTimer?.cancel();
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
      final hasTimer = currentQuestion.hasTimer;
      final result = await quizApi.submitAnswer(
        sessionId: sessionId!,
        questionId: currentQuestion.id,
        selectedIndex: selectedIndex,
        responseTimeMs: responseTimeMs,
      );
      isGrading = false;
      gradedCorrectIndex = result.correctIndex;
      shakeIndex = (!result.isCorrect && selectedIndex >= 0)
          ? selectedIndex
          : null;

      lastStreakBeforeAnswer = streak;
      score = result.score;
      streak = result.streak;
      bestStreak = result.bestStreak;
      xpGained = result.xpGained;
      lastDifficulty = result.difficulty;
      lastSpeedMultiplier = result.speedMultiplier;
      lastStreakMultiplier = result.streakMultiplier;
      lastSpeedLabel = result.isCorrect
          ? speedLabelFor(result.speedMultiplier, hasTimer: hasTimer)
          : '';
      lastIsMilestone = result.isCorrect && kStreakMilestones.contains(streak);
      lastRushComplete = result.rushComplete;
      _applyMomentum(
        isCorrect: result.isCorrect,
        timedOut: result.timedOut,
        speedMultiplier: result.speedMultiplier,
      );

      lastCluesRevealed = result.cluesRevealed;
      lastClueMultiplier = result.clueMultiplier;
      lastRemoveOneUsed = result.removeOneUsed;
      removeOneUsesRemaining = result.removeOneUsesRemaining;
      lastDoubleDownChoice = result.doubleDownChoice;
      lastDoubleDownMultiplier = result.doubleDownMultiplier;
      // A new offer (if any) applies to the NEXT question — _nextQuestion below
      // decides whether to show the decision overlay before that question starts.
      pendingDoubleDownOffer = result.doubleDownOffer ?? pendingDoubleDownOffer;

      if (result.isCorrect) {
        correctCount += 1;
      } else {
        wrongCount += 1;
      }
      responseTimes.add(responseTimeMs / 1000.0);

      if (result.timedOut) {
        feedback = AnswerFeedback.timeout;
        HapticsService.instance.heavyImpact();
      } else if (result.isCorrect) {
        feedback = AnswerFeedback.correct;
        lastIsMilestone
            ? HapticsService.instance.mediumImpact()
            : HapticsService.instance.lightImpact();
      } else {
        feedback = AnswerFeedback.wrong;
        HapticsService.instance.mediumImpact();
      }
      screen = AppScreen.feedback;
      _prefetchNextQuestionAssets();
      notifyListeners();

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

  // Momentum deltas are intentionally simple flat amounts, not another scoring
  // formula: correct nudges it up (more if fast), wrong nudges it down, and a
  // timeout knocks it down hard — reflecting an overall rough patch even if
  // streak recovers quickly afterward.
  void _applyMomentum({
    required bool isCorrect,
    required bool timedOut,
    required double speedMultiplier,
  }) {
    if (timedOut) {
      momentum = (momentum - 25).clamp(0, 100);
    } else if (!isCorrect) {
      momentum = (momentum - 15).clamp(0, 100);
    } else {
      final fast = speedMultiplier >= 1.25;
      momentum = (momentum + (fast ? 18 : 12)).clamp(0, 100);
    }
  }

  void _nextQuestion() {
    final next = qIndex + 1;
    if (lastRushComplete || next >= questions.length) {
      _finishSession();
    } else {
      qIndex = next;
      feedback = AnswerFeedback.none;
      screen = AppScreen.game;
      // If the last answer just unlocked a Double Down offer, it's for THIS
      // question — hold here with the decision overlay instead of starting the
      // timer/narration; startQuestion runs once the player picks (see below).
      if (pendingDoubleDownOffer?.questionId == questions[next].id) {
        awaitingDoubleDownChoice = true;
        notifyListeners();
      } else {
        notifyListeners();
        startQuestion(next);
      }
    }
  }

  /// Kicks off best-effort prefetch of the next question's real network media
  /// (option-thumbnail images + narration audio) during the feedback screen's
  /// display window, so it's already cached/buffered by the time that question
  /// actually appears. Fire-and-forget — must never throw or delay the caller.
  void _prefetchNextQuestionAssets() {
    try {
      final next = qIndex + 1;
      if (lastRushComplete || next >= questions.length) return;
      final nextQuestion = questions[next];

      for (final url in nextQuestion.optionImageUrls) {
        if (url == null || url.isEmpty) continue;
        try {
          final stream = NetworkImage(url).resolve(const ImageConfiguration());
          late final ImageStreamListener listener;
          listener = ImageStreamListener(
            (_, _) => stream.removeListener(listener),
            onError: (_, _) => stream.removeListener(listener),
          );
          stream.addListener(listener);
        } catch (_) {
          // best-effort — one bad image URL must not block the others
        }
      }

      AudioPlayerService.instance.preload(nextQuestion.audioUrl);
    } catch (_) {
      // best-effort — prefetch must never surface an error into the answer flow
    }
  }

  /// Records Safe or Risky for the currently-offered Double Down question, then
  /// starts it. Declining is just choosing 'safe' — either way the offer is spent.
  Future<void> chooseDoubleDown(String choice) async {
    if (!awaitingDoubleDownChoice || isChoosingDoubleDown) return;
    isChoosingDoubleDown = true;
    notifyListeners();
    var appliedChoice = choice;
    try {
      await quizApi.chooseDoubleDown(sessionId!, choice);
    } on ApiException catch (e) {
      // Non-fatal: proceed as safe (the server default when no choice is on record)
      // rather than stranding the player on the decision screen.
      errorMessage = e.message;
      appliedChoice = 'safe';
    } finally {
      isChoosingDoubleDown = false;
      awaitingDoubleDownChoice = false;
      pendingDoubleDownOffer = null;
      // startQuestion resets per-question state (including currentDoubleDownChoice),
      // so the applied choice must be set after it runs, not before.
      startQuestion(qIndex);
      currentDoubleDownChoice = appliedChoice;
      notifyListeners();
    }
  }

  Future<void> _finishSession() async {
    screen = AppScreen.results;
    feedback = AnswerFeedback.none;
    notifyListeners();
    try {
      final summary = await quizApi.finishSession(sessionId!);
      avgResponseTimeMs = summary.avgResponseTimeMs;
      durationMs = summary.durationMs;
      personalBestScore = summary.personalBestScore;
      isNewPersonalBest = summary.isNewPersonalBest;
      personalBestStreak = summary.personalBestStreak;
      isNewBestStreak = summary.isNewBestStreak;
      isPerfectRush = summary.isPerfectRush;
      xpAwarded = summary.xpAwarded;
      leveledUp = summary.leveledUp;
      newlyUnlockedAchievements = summary.newlyUnlockedAchievements;
      isDailyRush = summary.isDailyRush;
      dailyRank = summary.dailyRank;
      dailyPreviousBestScore = summary.dailyPreviousBestScore;
      isNewDailyBest = summary.isNewDailyBest;
      newlyCompletedMissions = summary.newlyCompletedMissions;
      lastXpMultiplierApplied = summary.xpMultiplierApplied;
      dailyStreakJustExtended = summary.dailyStreakCurrent > dailyStreakCurrent;
      dailyStreakCurrent = summary.dailyStreakCurrent;
      if (isNewPersonalBest ||
          isNewBestStreak ||
          isPerfectRush ||
          leveledUp ||
          newlyUnlockedAchievements.isNotEmpty ||
          isNewDailyBest ||
          newlyCompletedMissions.isNotEmpty) {
        HapticsService.instance.heavyImpact();
      }
      notifyListeners();
      loadProfile(); // lifetime XP/level/records/achievements just changed — refresh for later screens
      if (isDailyRush) loadDailyRushStatus(); // today's tile (score/rank/completed) just changed too
      loadHome(); // missions/streak/leaderboard position may all have just changed too
    } on ApiException {
      // Non-fatal: the results screen already shows the locally-tracked
      // totals, which mirror the server's authoritative per-answer
      // responses. /finish just adds a few summary-only fields (avg
      // response time, duration, personal best) on top of those.
    }
  }

  void playNow() {
    screen = AppScreen.pickRush;
    notifyListeners();
  }

  // ---- Play With Friends ----

  void goToPlayWithFriends() {
    if (needsAccountForFriends) {
      authError = null;
      _pendingScreenAfterAuth = AppScreen.playWithFriends;
      screen = AppScreen.login;
      notifyListeners();
      return;
    }
    matchError = null;
    screen = AppScreen.playWithFriends;
    notifyListeners();
    _connectMatchSocket();
  }

  void _connectMatchSocket() {
    _matchEventsSub ??= _matchEvents.listen(_onMatchEvent);
    if (_usesRealMatchSocket) MatchSocketService.instance.connect();
  }

  /// Leaves the whole Play With Friends flow — the queue (if in it), the
  /// socket connection, and any in-progress friend-invite state. Safe to
  /// call even if none of that was active (e.g. backing out of the mode-select
  /// screen itself, before ever queueing).
  void _leavePlayWithFriends() {
    if (isSearchingMatch) {
      quizApi.leaveQueue().catchError((_) {}); // best-effort — leaving anyway
    }
    isSearchingMatch = false;
    friendInviteCode = null;
    matchError = null;
    _matchEventsSub?.cancel();
    _matchEventsSub = null;
    if (_usesRealMatchSocket) MatchSocketService.instance.disconnect();
  }

  void backFromPlayWithFriends() {
    _leavePlayWithFriends();
    screen = AppScreen.home;
    notifyListeners();
  }

  /// Joins the random 1v1 queue. Pairs immediately if someone else is
  /// already waiting; otherwise shows the searching state until a
  /// MatchPairedEvent arrives over the socket (or the queue times out).
  Future<void> startRandomQueue() async {
    matchFlowKind = MatchFlowKind.random;
    matchError = null;
    isSearchingMatch = true;
    screen = AppScreen.matchWaiting;
    notifyListeners();
    try {
      final result = await quizApi.joinRandomQueue();
      if (result.status == 'matched') {
        _beginMatch(
          matchId: result.matchId!,
          sessionId: result.sessionId!,
          questions: result.questions!,
          removeOneUsesRemaining: result.removeOneUsesRemaining ?? 1,
          opponentInfo: result.opponent!,
        );
      }
      // status == 'waiting': stay on the searching screen; _onMatchEvent
      // handles the eventual match:paired push.
    } on ApiException catch (e) {
      isSearchingMatch = false;
      matchError = e.message;
      notifyListeners();
    }
  }

  Future<void> cancelQueue() async {
    isSearchingMatch = false;
    screen = AppScreen.playWithFriends;
    notifyListeners();
    try {
      await quizApi.leaveQueue();
    } on ApiException {
      // Non-fatal — worst case the server evicts us on its own queue timeout.
    }
  }

  /// Shows the friend-invite screen (create a code, or enter one). No
  /// network call yet — that happens on createFriendInvite/joinFriendMatch.
  void goToFriendMatch() {
    matchFlowKind = MatchFlowKind.friend;
    matchError = null;
    friendInviteCode = null;
    screen = AppScreen.matchWaiting;
    notifyListeners();
  }

  Future<void> createFriendInvite() async {
    matchError = null;
    notifyListeners();
    try {
      friendInviteCode = await quizApi.createFriendMatch();
      notifyListeners();
    } on ApiException catch (e) {
      matchError = e.message;
      notifyListeners();
    }
  }

  Future<void> joinFriendMatch(String code) async {
    matchError = null;
    notifyListeners();
    try {
      final result = await quizApi.joinFriendMatch(code);
      _beginMatch(
        matchId: result.matchId!,
        sessionId: result.sessionId!,
        questions: result.questions!,
        removeOneUsesRemaining: result.removeOneUsesRemaining ?? 1,
        opponentInfo: result.opponent!,
      );
    } on ApiException catch (e) {
      matchError = e.message;
      notifyListeners();
    }
  }

  void _onMatchEvent(MatchEvent event) {
    switch (event) {
      case MatchPairedEvent e:
        // A no-op if this side already began the match via its own REST response
        // (the player whose request completed the pairing gets both).
        if (activeMatchId != null) return;
        _beginMatch(
          matchId: e.matchId,
          sessionId: e.sessionId,
          questions: e.questions,
          removeOneUsesRemaining: e.removeOneUsesRemaining,
          opponentInfo: e.opponent,
        );
      case MatchOpponentProgressEvent e:
        if (e.matchId != activeMatchId) return;
        opponentQuestionIndex = e.currentIndex;
        notifyListeners();
      case MatchResultEvent e:
        if (e.matchId != activeMatchId) return;
        matchResult = e;
        notifyListeners();
      case MatchCancelledEvent e:
        if (e.matchId != activeMatchId && screen != AppScreen.matchWaiting)
          return;
        isSearchingMatch = false;
        matchError = 'Your opponent left before the match started.';
        screen = AppScreen.playWithFriends;
        notifyListeners();
      case QueueTimeoutEvent():
        isSearchingMatch = false;
        matchError =
            "Couldn't find an opponent right now — try again in a bit.";
        screen = AppScreen.playWithFriends;
        notifyListeners();
      case UnknownMatchEvent():
        break; // forward-compatible no-op for an event type this build doesn't know yet
    }
  }

  /// Shared by both ways a match can start (random pairing or a friend
  /// invite) and by both ways the *client* can learn about it (the direct
  /// REST response, or the socket push) — feeds straight into the same
  /// _beginRush every solo/Daily Rush uses. A match session is an ordinary
  /// Rush session under the hood; this only sets up the presentational layer
  /// on top (opponent identity, live progress, eventual result).
  void _beginMatch({
    required int matchId,
    required int sessionId,
    required List<Question> questions,
    required int removeOneUsesRemaining,
    required MatchOpponent opponentInfo,
  }) {
    activeMatchId = matchId;
    opponent = opponentInfo;
    opponentQuestionIndex = 0;
    matchResult = null;
    isSearchingMatch = false;
    friendInviteCode = null;
    _beginRush(
      SessionStart(
        sessionId: sessionId,
        questions: questions,
        removeOneUsesRemaining: removeOneUsesRemaining,
      ),
      isDaily: false,
    );
  }

  Future<void> loadProfile() async {
    try {
      profile = await quizApi.getProfile();
      notifyListeners();
    } on ApiException {
      // Non-fatal: whatever screen needs it (home badge, Profile screen) just
      // keeps showing its last-known value, or its own "couldn't load" state.
    }
  }

  Future<void> loadDailyRushStatus() async {
    try {
      dailyRushStatus = await quizApi.getDailyRushStatus();
      notifyListeners();
    } on ApiException {
      // Non-fatal — same as loadProfile above.
    }
  }

  Future<void> loadHome() async {
    try {
      homeSummary = await quizApi.getHome();
      notifyListeners();
    } on ApiException {
      // Non-fatal — same as loadProfile above.
    }
  }

  void goToProfile() {
    screen = AppScreen.profile;
    notifyListeners();
    loadProfile(); // refresh in case it's been a while since boot/last Rush
  }

  void goToEvents() {
    screen = AppScreen.events;
    notifyListeners();
    loadHome(); // refresh missions/streak/events in case it's been a while
    loadDailyRushStatus();
  }

  void goToLeaderboard({LeaderboardPeriod? period}) {
    screen = AppScreen.leaderboard;
    notifyListeners();
    loadLeaderboard(period: period);
  }

  Future<void> loadLeaderboard({LeaderboardPeriod? period}) async {
    if (period != null) leaderboardPeriod = period;
    isLoadingLeaderboard = true;
    leaderboardError = null;
    notifyListeners();
    try {
      leaderboardPage = await quizApi.getLeaderboard(period: leaderboardPeriod);
    } on ApiException catch (e) {
      leaderboardError = e.message;
    }
    isLoadingLeaderboard = false;
    notifyListeners();
  }

  // ---- Settings ----

  bool get soundEffectsEnabled => _settings.soundEffectsEnabled;
  bool get narrationEnabled => _settings.narrationEnabled;
  bool get hapticsEnabled => _settings.hapticsEnabled;
  bool get dailyRushReminderEnabled => _settings.dailyRushReminderEnabled;
  int get reminderHour => _settings.reminderHour;
  int get reminderMinute => _settings.reminderMinute;

  void goToSettings() {
    screen = AppScreen.settings;
    notifyListeners();
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    await _settings.setSoundEffectsEnabled(value);
    notifyListeners();
  }

  Future<void> setNarrationEnabled(bool value) async {
    await _settings.setNarrationEnabled(value);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    await _settings.setHapticsEnabled(value);
    HapticsService.instance.enabled = value;
    notifyListeners();
  }

  /// Turning the reminder on requests OS notification permission first — if
  /// denied, the setting stays off (nothing was persisted as true, so the
  /// toggle just reflects reality on the next rebuild).
  Future<void> setDailyRushReminderEnabled(bool value) async {
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        notifyListeners();
        return;
      }
      await NotificationService.instance.scheduleDailyReminder(
        _settings.reminderHour,
        _settings.reminderMinute,
      );
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }
    await _settings.setDailyRushReminderEnabled(value);
    notifyListeners();
  }

  Future<void> setDailyRushReminderTime(int hour, int minute) async {
    await _settings.setReminderTime(hour, minute);
    if (_settings.dailyRushReminderEnabled) {
      await NotificationService.instance.scheduleDailyReminder(hour, minute);
    }
    notifyListeners();
  }

  void goHome() {
    _clearAllTimers();
    AudioPlayerService.instance.stop();
    sessionId = null;
    questions = [];
    if (activeMatchId != null) _leavePlayWithFriends();
    activeMatchId = null;
    opponent = null;
    matchResult = null;
    screen = AppScreen.home;
    notifyListeners();
  }

  /// Shared by a normal Rush (selectCategory) and Daily Rush (startDailyRush) —
  /// both just fetch a SessionStart from a different endpoint; everything about
  /// actually playing it (this reset + the question flow) is identical.
  void _beginRush(SessionStart start, {required bool isDaily}) {
    sessionId = start.sessionId;
    questions = start.questions;
    qIndex = start.currentIndex;
    isDailyRush = isDaily;
    score = 0;
    streak = 0;
    bestStreak = 0;
    correctCount = 0;
    wrongCount = 0;
    responseTimes.clear();
    avgResponseTimeMs = 0;
    durationMs = 0;
    personalBestScore = null;
    isNewPersonalBest = false;
    personalBestStreak = null;
    isNewBestStreak = false;
    isPerfectRush = false;
    xpAwarded = 0;
    leveledUp = false;
    newlyUnlockedAchievements = [];
    dailyRank = null;
    dailyPreviousBestScore = null;
    isNewDailyBest = false;
    momentum = 0;
    lastSpeedLabel = '';
    lastStreakBeforeAnswer = 0;
    lastIsMilestone = false;
    lastRushComplete = false;
    removeOneUsesRemaining = start.removeOneUsesRemaining;
    removedOptionIndex = null;
    pendingDoubleDownOffer = null;
    awaitingDoubleDownChoice = false;
    currentDoubleDownChoice = 'none';
    lastDoubleDownChoice = 'none';
    lastDoubleDownMultiplier = 1.0;
    lastCluesRevealed = 1;
    lastClueMultiplier = 1.0;
    lastRemoveOneUsed = false;
    newlyCompletedMissions = [];
    lastXpMultiplierApplied = 1.0;
    dailyStreakJustExtended = false;
    feedback = AnswerFeedback.none;
    isCreatingSession = false;
    screen = AppScreen.game;
    notifyListeners();
    startQuestion(start.currentIndex);
  }

  Future<void> selectCategory(Category category) async {
    _lastCategory = category;
    errorMessage = null;
    isCreatingSession = true;
    notifyListeners();
    try {
      final start = await quizApi.createSession(category.id);
      _beginRush(start, isDaily: false);
    } on ApiException catch (e) {
      isCreatingSession = false;
      errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Starts a Pick Your Rush session for [mode] — the game-mode counterpart to
  /// selectCategory, and the only way a Rush is started from the "Pick Your Rush"
  /// screen. Question selection is cross-category on the server; this never asks
  /// the player about categories at all.
  Future<void> startRush(GameMode mode) async {
    _lastMode = mode;
    errorMessage = null;
    isCreatingSession = true;
    notifyListeners();
    try {
      final start = await quizApi.startRush(mode);
      _beginRush(start, isDaily: false);
    } on ApiException catch (e) {
      isCreatingSession = false;
      errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Starts today's Daily Rush, or resumes it if there's an unfinished attempt
  /// from earlier today (see QuizApi.startDailyRush). Rejected by the server
  /// (surfaced via errorMessage) if today's attempt is already completed —
  /// the Home screen shouldn't offer this in that state, but stay defensive.
  Future<void> startDailyRush() async {
    errorMessage = null;
    isCreatingSession = true;
    notifyListeners();
    try {
      final start = await quizApi.startDailyRush();
      _beginRush(start, isDaily: true);
    } on ApiException catch (e) {
      isCreatingSession = false;
      errorMessage = e.message;
      notifyListeners();
    }
  }

  void playAgain() {
    final mode = _lastMode;
    if (mode != null) {
      startRush(mode);
      return;
    }
    final cat = _lastCategory;
    if (cat != null) selectCategory(cat);
  }

  /// Reveals the next clue via the server — clueCount only ever advances once
  /// the server confirms it, since that same count is what determines the
  /// score reduction at answer time (see scoring.service.js's clueMultiplierFor).
  Future<void> revealClue() async {
    final clues = currentQuestion.clues;
    if (clues == null || isRevealingClue || answered) return;
    if (clueCount >= clues.length) return;
    isRevealingClue = true;
    notifyListeners();
    try {
      final result = await quizApi.revealClue(sessionId!);
      clueCount = result.cluesRevealed;
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isRevealingClue = false;
      notifyListeners();
    }
  }

  /// Spends a Remove One charge on the current question, if any remain.
  Future<void> useRemoveOne() async {
    if (isUsingRemoveOne ||
        answered ||
        removeOneUsesRemaining <= 0 ||
        removedOptionIndex != null)
      return;
    isUsingRemoveOne = true;
    notifyListeners();
    try {
      final result = await quizApi.useRemoveOne(sessionId!);
      removedOptionIndex = result.removedOptionIndex;
      removeOneUsesRemaining = result.usesRemaining;
      HapticsService.instance.selectionClick();
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isUsingRemoveOne = false;
      notifyListeners();
    }
  }

  void togglePlay() {
    isPlaying = !isPlaying;
    notifyListeners();
  }

  double get progressPct => questions.isEmpty ? 0 : qIndex / questions.length;

  MomentumTier get momentumTier => momentumTierFor(momentum);

  double get accuracyPct {
    final total = correctCount + wrongCount;
    return total > 0 ? correctCount / total * 100 : 0;
  }

  double get avgResponseTime {
    // Prefer the server-authoritative figure once /finish has returned;
    // falls back to the locally-tracked (client-reported) average until then.
    if (avgResponseTimeMs > 0) return avgResponseTimeMs / 1000.0;
    if (responseTimes.isEmpty) return 0;
    return responseTimes.reduce((a, b) => a + b) / responseTimes.length;
  }

  @override
  void dispose() {
    _clearAllTimers();
    AudioPlayerService.instance.stop();
    _matchEventsSub?.cancel();
    if (_usesRealMatchSocket) MatchSocketService.instance.disconnect();
    super.dispose();
  }
}
