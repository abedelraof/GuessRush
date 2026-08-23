enum LeaderboardPeriod { global, daily }

class LeaderboardEntry {
  final int rank;
  final int playerId;
  final String displayName;
  final int score;
  final int bestStreak;

  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.displayName,
    required this.score,
    required this.bestStreak,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        rank: json['rank'] as int,
        playerId: json['player_id'] as int,
        displayName: json['display_name'] as String,
        score: json['score'] as int,
        bestStreak: json['best_streak'] as int,
      );
}

class LeaderboardPage {
  final LeaderboardPeriod period;
  final String? date;
  final int total;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? me;

  const LeaderboardPage({
    required this.period,
    required this.date,
    required this.total,
    required this.entries,
    required this.me,
  });

  factory LeaderboardPage.fromJson(Map<String, dynamic> json) => LeaderboardPage(
        period: json['period'] == 'daily' ? LeaderboardPeriod.daily : LeaderboardPeriod.global,
        date: json['date'] as String?,
        total: json['total'] as int? ?? 0,
        entries: (json['entries'] as List).map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList(),
        me: json['me'] != null ? LeaderboardEntry.fromJson(json['me'] as Map<String, dynamic>) : null,
      );
}
