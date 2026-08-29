import 'question.dart';

class MatchOpponent {
  final int id;
  final String displayName;

  const MatchOpponent({required this.id, required this.displayName});

  factory MatchOpponent.fromJson(Map<String, dynamic> json) => MatchOpponent(
    id: json['id'] as int,
    displayName: json['display_name'] as String,
  );
}

/// One event received over MatchSocketService's stream. The `type` string
/// matches the server's own event `type` field verbatim (see
/// server/src/services/realtime.service.js and matchProgress.service.js) —
/// QuizController reacts to the concrete subtype via a switch, not this string.
sealed class MatchEvent {
  final String type;

  const MatchEvent(this.type);

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String?) {
      case 'match:paired':
        return MatchPairedEvent.fromJson(json);
      case 'match:opponent_progress':
        return MatchOpponentProgressEvent.fromJson(json);
      case 'match:result':
        return MatchResultEvent.fromJson(json);
      case 'match:cancelled':
        return MatchCancelledEvent.fromJson(json);
      case 'queue:timeout':
        return const QueueTimeoutEvent();
      default:
        return UnknownMatchEvent(json['type'] as String? ?? 'unknown');
    }
  }
}

/// Both players just got matched (random queue or friend invite) — carries
/// everything needed to jump straight into gameplay via the same
/// _beginRush flow a normal solo Rush uses; a match session is an ordinary
/// Rush session under the hood (see matches.controller.js).
class MatchPairedEvent extends MatchEvent {
  final int matchId;
  final int sessionId;
  final List<Question> questions;
  final int removeOneUsesRemaining;
  final MatchOpponent opponent;

  const MatchPairedEvent({
    required this.matchId,
    required this.sessionId,
    required this.questions,
    required this.removeOneUsesRemaining,
    required this.opponent,
  }) : super('match:paired');

  factory MatchPairedEvent.fromJson(Map<String, dynamic> json) => MatchPairedEvent(
    matchId: json['match_id'] as int,
    sessionId: json['session_id'] as int,
    questions: (json['questions'] as List)
        .map((q) => Question.fromJson(q as Map<String, dynamic>))
        .toList(),
    removeOneUsesRemaining: json['remove_one_uses_remaining'] as int? ?? 1,
    opponent: MatchOpponent.fromJson(json['opponent'] as Map<String, dynamic>),
  );
}

/// Presence-only — deliberately never carries correctness or score (see the
/// plan's "presence-only reveal" decision).
class MatchOpponentProgressEvent extends MatchEvent {
  final int matchId;
  final int currentIndex;

  const MatchOpponentProgressEvent({required this.matchId, required this.currentIndex})
    : super('match:opponent_progress');

  factory MatchOpponentProgressEvent.fromJson(Map<String, dynamic> json) => MatchOpponentProgressEvent(
    matchId: json['match_id'] as int,
    currentIndex: json['current_index'] as int,
  );
}

class MatchResultEvent extends MatchEvent {
  final int matchId;
  final int? winnerPlayerId;
  final bool forfeit;

  const MatchResultEvent({required this.matchId, required this.winnerPlayerId, this.forfeit = false})
    : super('match:result');

  factory MatchResultEvent.fromJson(Map<String, dynamic> json) => MatchResultEvent(
    matchId: json['match_id'] as int,
    winnerPlayerId: json['winner_player_id'] as int?,
    forfeit: json['forfeit'] as bool? ?? false,
  );
}

/// Sent when a match is voided (a mid-match disconnect before either side
/// answered anything) — distinct from a result, since there's no winner.
class MatchCancelledEvent extends MatchEvent {
  final int matchId;

  const MatchCancelledEvent({required this.matchId}) : super('match:cancelled');

  factory MatchCancelledEvent.fromJson(Map<String, dynamic> json) =>
      MatchCancelledEvent(matchId: json['match_id'] as int);
}

/// Waited too long in the random queue without finding an opponent.
class QueueTimeoutEvent extends MatchEvent {
  const QueueTimeoutEvent() : super('queue:timeout');
}

class UnknownMatchEvent extends MatchEvent {
  const UnknownMatchEvent(super.type);
}

/// GET /api/matches/:id poll-fallback response — used when the socket
/// connection was missed/dropped, e.g. after the app was backgrounded.
class MatchStatusResult {
  final String status;
  final int? winnerPlayerId;

  const MatchStatusResult({required this.status, this.winnerPlayerId});

  factory MatchStatusResult.fromJson(Map<String, dynamic> json) => MatchStatusResult(
    status: json['status'] as String,
    winnerPlayerId: json['winner_player_id'] as int?,
  );
}
