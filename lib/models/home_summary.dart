import 'mission.dart';

/// A currently-active temporary event (Phase 6) — e.g. Double XP. `type` is
/// what a future effect (speed bonus, category lock) would key off; today the
/// client only has copy to show for any type, since the one concrete effect
/// (XP multiplier) is applied entirely server-side.
class GameEvent {
  final String key;
  final String name;
  final String description;
  final String type;
  final num multiplier;
  final DateTime? endsAt;

  const GameEvent({
    required this.key,
    required this.name,
    required this.description,
    required this.type,
    required this.multiplier,
    required this.endsAt,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
        key: json['key'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        type: json['type'] as String,
        multiplier: json['multiplier'] as num? ?? 1,
        endsAt: json['ends_at'] != null ? DateTime.tryParse(json['ends_at'] as String) : null,
      );
}

class LeaderboardPosition {
  final int rank;
  final int total;

  const LeaderboardPosition({required this.rank, required this.total});

  factory LeaderboardPosition.fromJson(Map<String, dynamic> json) =>
      LeaderboardPosition(rank: json['rank'] as int, total: json['total'] as int);
}

/// Aggregates the retention-system data the Home screen needs beyond what
/// profile/daily-rush status already provide — see GET /api/home.
class HomeSummary {
  final int dailyStreakCurrent;
  final int dailyStreakLongest;
  final List<Mission> missions;
  final List<GameEvent> activeEvents;
  final LeaderboardPosition? leaderboardPosition;

  const HomeSummary({
    required this.dailyStreakCurrent,
    required this.dailyStreakLongest,
    required this.missions,
    required this.activeEvents,
    required this.leaderboardPosition,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
        dailyStreakCurrent: (json['daily_streak'] as Map<String, dynamic>)['current'] as int,
        dailyStreakLongest: (json['daily_streak'] as Map<String, dynamic>)['longest'] as int,
        missions: (json['missions'] as List).map((m) => Mission.fromJson(m as Map<String, dynamic>)).toList(),
        activeEvents:
            (json['active_events'] as List).map((e) => GameEvent.fromJson(e as Map<String, dynamic>)).toList(),
        leaderboardPosition: json['leaderboard_position'] != null
            ? LeaderboardPosition.fromJson(json['leaderboard_position'] as Map<String, dynamic>)
            : null,
      );
}
