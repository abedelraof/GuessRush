import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quizo/models/match.dart';
import 'package:quizo/models/player_profile.dart';
import 'package:quizo/models/question.dart';
import 'package:quizo/screens/match_waiting_screen.dart';
import 'package:quizo/screens/play_with_friends_screen.dart';
import 'package:quizo/screens/results_screen.dart';
import 'package:quizo/services/api_client.dart';
import 'package:quizo/services/quiz_api.dart';
import 'package:quizo/state/quiz_controller.dart';

Question _untimedQuestion(int id) => Question(
  id: id,
  type: QuestionType.text,
  label: 'Label',
  prompt: 'Prompt $id',
  options: const ['A', 'B', 'C', 'D'],
  timerSeconds: 0,
);

List<Question> _matchQuestions() => List.generate(10, (i) => _untimedQuestion(i + 1));

const _opponent = MatchOpponent(id: 99, displayName: 'Rival');

/// Minimal fake — only the Play With Friends surface of QuizApi. Gameplay
/// itself (submitAnswer/finish/...) is exercised elsewhere (see
/// quiz_controller_rush_test.dart's FakeQuizApi); a match session is an
/// ordinary Rush session under the hood, so nothing new to verify there.
class _FakeMatchApi extends QuizApi {
  _FakeMatchApi() : super(ApiClient.instance);

  QueueJoinResult joinQueueResult = const QueueJoinResult(status: 'waiting');
  ApiException? joinQueueError;
  int leaveQueueCallCount = 0;
  String createFriendMatchCodeResult = 'ABC123';
  QueueJoinResult? joinFriendMatchResult;
  ApiException? joinFriendMatchError;
  String? lastJoinedCode;

  @override
  Future<QueueJoinResult> joinRandomQueue() async {
    if (joinQueueError != null) throw joinQueueError!;
    return joinQueueResult;
  }

  @override
  Future<void> leaveQueue() async {
    leaveQueueCallCount++;
  }

  @override
  Future<String> createFriendMatch() async => createFriendMatchCodeResult;

  @override
  Future<QueueJoinResult> joinFriendMatch(String code) async {
    lastJoinedCode = code;
    if (joinFriendMatchError != null) throw joinFriendMatchError!;
    return joinFriendMatchResult!;
  }

  @override
  Future<MatchStatusResult> getMatch(int matchId) async => const MatchStatusResult(status: 'in_progress');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  QuizController buildController(_FakeMatchApi api, StreamController<MatchEvent> events) {
    return QuizController(quizApi: api, matchEvents: events.stream);
  }

  testWidgets('goToPlayWithFriends navigates to the mode-select screen', (tester) async {
    final api = _FakeMatchApi();
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await tester.pump();

    expect(controller.screen, AppScreen.playWithFriends);
  });

  testWidgets('startRandomQueue with no one waiting shows the searching state', (tester) async {
    final api = _FakeMatchApi()..joinQueueResult = const QueueJoinResult(status: 'waiting');
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue();
    await tester.pump();

    expect(controller.screen, AppScreen.matchWaiting);
    expect(controller.matchFlowKind, MatchFlowKind.random);
    expect(controller.isSearchingMatch, true);
  });

  testWidgets('startRandomQueue matched immediately begins the match without waiting for a socket event', (
    tester,
  ) async {
    final api = _FakeMatchApi()
      ..joinQueueResult = QueueJoinResult(
        status: 'matched',
        matchId: 1,
        sessionId: 42,
        questions: _matchQuestions(),
        removeOneUsesRemaining: 1,
        opponent: _opponent,
      );
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue();
    await tester.pump();

    expect(controller.screen, AppScreen.game);
    expect(controller.activeMatchId, 1);
    expect(controller.sessionId, 42);
    expect(controller.opponent?.displayName, 'Rival');
    expect(controller.isSearchingMatch, false);
  });

  testWidgets('a match:paired push begins the match for the player who was already waiting', (tester) async {
    final api = _FakeMatchApi();
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue(); // status: 'waiting'
    await tester.pump();
    expect(controller.screen, AppScreen.matchWaiting);

    events.add(
      MatchPairedEvent(
        matchId: 7,
        sessionId: 100,
        questions: _matchQuestions(),
        removeOneUsesRemaining: 1,
        opponent: _opponent,
      ),
    );
    await tester.pump();

    expect(controller.screen, AppScreen.game);
    expect(controller.activeMatchId, 7);
    expect(controller.sessionId, 100);
  });

  testWidgets('opponent_progress events update opponentQuestionIndex without touching own state', (tester) async {
    final api = _FakeMatchApi()
      ..joinQueueResult = QueueJoinResult(
        status: 'matched',
        matchId: 1,
        sessionId: 42,
        questions: _matchQuestions(),
        removeOneUsesRemaining: 1,
        opponent: _opponent,
      );
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue();
    await tester.pump();

    events.add(const MatchOpponentProgressEvent(matchId: 1, currentIndex: 4));
    await tester.pump();

    expect(controller.opponentQuestionIndex, 4);
    expect(controller.qIndex, 0, reason: "opponent's progress never touches this player's own qIndex");
  });

  testWidgets('a match:result event for the active match populates matchResult', (tester) async {
    final api = _FakeMatchApi()
      ..joinQueueResult = QueueJoinResult(
        status: 'matched',
        matchId: 1,
        sessionId: 42,
        questions: _matchQuestions(),
        removeOneUsesRemaining: 1,
        opponent: _opponent,
      );
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue();
    await tester.pump();
    expect(controller.matchResult, isNull);

    events.add(const MatchResultEvent(matchId: 1, winnerPlayerId: 99));
    await tester.pump();

    expect(controller.matchResult?.winnerPlayerId, 99);
  });

  testWidgets('a match:result event for a different match id is ignored', (tester) async {
    final api = _FakeMatchApi()
      ..joinQueueResult = QueueJoinResult(
        status: 'matched',
        matchId: 1,
        sessionId: 42,
        questions: _matchQuestions(),
        removeOneUsesRemaining: 1,
        opponent: _opponent,
      );
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue();
    await tester.pump();

    events.add(const MatchResultEvent(matchId: 999, winnerPlayerId: 1));
    await tester.pump();

    expect(controller.matchResult, isNull);
  });

  testWidgets('a queue:timeout event while searching surfaces an error and returns to mode-select', (tester) async {
    final api = _FakeMatchApi();
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue();
    await tester.pump();

    events.add(const QueueTimeoutEvent());
    await tester.pump();

    expect(controller.screen, AppScreen.playWithFriends);
    expect(controller.isSearchingMatch, false);
    expect(controller.matchError, isNotNull);
  });

  testWidgets('a match:cancelled event while waiting surfaces an error and returns to mode-select', (tester) async {
    final api = _FakeMatchApi();
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue();
    await tester.pump();

    events.add(const MatchCancelledEvent(matchId: 5));
    await tester.pump();

    expect(controller.screen, AppScreen.playWithFriends);
    expect(controller.matchError, isNotNull);
  });

  testWidgets('cancelQueue leaves the queue and returns to mode-select', (tester) async {
    final api = _FakeMatchApi();
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToPlayWithFriends();
    await controller.startRandomQueue();
    await tester.pump();

    await controller.cancelQueue();
    await tester.pump();

    expect(api.leaveQueueCallCount, 1);
    expect(controller.screen, AppScreen.playWithFriends);
    expect(controller.isSearchingMatch, false);
  });

  testWidgets('createFriendInvite sets the shareable code', (tester) async {
    final api = _FakeMatchApi()..createFriendMatchCodeResult = 'ZZZTOP';
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToFriendMatch();
    await controller.createFriendInvite();
    await tester.pump();

    expect(controller.friendInviteCode, 'ZZZTOP');
  });

  testWidgets('joinFriendMatch success begins the match', (tester) async {
    final api = _FakeMatchApi()
      ..joinFriendMatchResult = QueueJoinResult(
        status: 'matched',
        matchId: 3,
        sessionId: 77,
        questions: _matchQuestions(),
        removeOneUsesRemaining: 1,
        opponent: _opponent,
      );
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToFriendMatch();
    await controller.joinFriendMatch('ABC123');
    await tester.pump();

    expect(api.lastJoinedCode, 'ABC123');
    expect(controller.screen, AppScreen.game);
    expect(controller.activeMatchId, 3);
  });

  testWidgets('joinFriendMatch failure surfaces the error without changing screens', (tester) async {
    final api = _FakeMatchApi()..joinFriendMatchError = ApiException('This invite has already been used or expired.');
    final events = StreamController<MatchEvent>.broadcast();
    addTearDown(events.close);
    final controller = buildController(api, events);

    controller.goToFriendMatch();
    await controller.joinFriendMatch('DEAD00');
    await tester.pump();

    expect(controller.screen, AppScreen.matchWaiting);
    expect(controller.matchError, 'This invite has already been used or expired.');
    expect(controller.activeMatchId, isNull);
  });

  testWidgets('Play With Friends screen renders both mode cards without layout overflow', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;

    final controller = buildController(_FakeMatchApi(), StreamController<MatchEvent>.broadcast());

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlayWithFriendsScreen(controller: controller))));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Play With Friends'), findsOneWidget);
    expect(find.text('Play Online 1v1'), findsOneWidget);
    expect(find.text('Play with a Friend'), findsOneWidget);
  });

  testWidgets('tapping the random-opponent card starts the queue', (tester) async {
    final api = _FakeMatchApi();
    final controller = buildController(api, StreamController<MatchEvent>.broadcast());

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlayWithFriendsScreen(controller: controller))));
    await tester.pump();

    await tester.tap(find.text('Play Online 1v1'));
    await tester.pump();
    await tester.pump();

    expect(controller.screen, AppScreen.matchWaiting);
    expect(controller.matchFlowKind, MatchFlowKind.random);
  });

  testWidgets('Match waiting screen renders the searching state without layout overflow', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;

    final controller = buildController(_FakeMatchApi(), StreamController<MatchEvent>.broadcast())
      ..matchFlowKind = MatchFlowKind.random
      ..isSearchingMatch = true;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MatchWaitingScreen(controller: controller))));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Searching for an opponent…'), findsOneWidget);
  });

  testWidgets('Match waiting screen renders the friend code-entry state without layout overflow', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;

    final controller = buildController(_FakeMatchApi(), StreamController<MatchEvent>.broadcast())
      ..matchFlowKind = MatchFlowKind.friend;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MatchWaitingScreen(controller: controller))));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Have a code?'), findsOneWidget);
    expect(find.text('Create an Invite'), findsOneWidget);
  });

  testWidgets(
    'Results screen with a match banner AND a full burst of first-Rush badges renders '
    'without layout overflow on a narrow phone width',
    (tester) async {
      // Regression test — this exact combination (many simultaneous first-Rush badges
      // plus the match head-to-head banner) overflowed a fixed, non-scrollable Column
      // when first found via a live end-to-end check, not by any narrower unit test.
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;

      final controller = buildController(_FakeMatchApi(), StreamController<MatchEvent>.broadcast())
        ..activeMatchId = 1
        ..opponent = _opponent
        ..matchResult = const MatchResultEvent(matchId: 1, winnerPlayerId: 99)
        ..score = 672
        ..correctCount = 5
        ..wrongCount = 5
        ..bestStreak = 2
        ..xpAwarded = 406
        ..isNewPersonalBest = true
        ..isNewBestStreak = true
        ..leveledUp = true
        ..profile = const PlayerProfile(
          displayName: 'Test',
          level: 3,
          lifetimeXp: 500,
          xpIntoLevel: 100,
          xpForNextLevel: 300,
          stats: ProfileStats(
            rushesCompleted: 1,
            questionsAnswered: 10,
            questionsCorrect: 5,
            accuracyPct: 50,
            avgResponseTimeMs: 1200,
          ),
          records: ProfileRecords(
            bestRushScore: 672,
            bestStreak: 2,
            bestAccuracyPct: 50,
            fastestAvgResponseTimeMs: 1200,
            perfectRushCount: 0,
          ),
          achievements: [],
        )
        ..newlyUnlockedAchievements = const [
          Achievement(key: 'first_rush', name: 'First Rush', description: 'Complete your first Rush.'),
          Achievement(key: 'speed_demon', name: 'Speed Demon', description: 'Answer fast.'),
          Achievement(key: 'warm_up', name: 'Warm Up', description: 'Complete a Rush.'),
        ]
        ..lastXpMultiplierApplied = 2.0;

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ResultsScreen(controller: controller))));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow at 360dp width');
      expect(find.text('YOU LOSE'), findsOneWidget);
      expect(find.text('vs Rival'), findsOneWidget);
    },
  );
}
