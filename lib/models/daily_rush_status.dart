/// Server-computed Daily Rush status for the Home screen — every field here
/// comes straight from the server (date, availability, time remaining,
/// score, rank); nothing is guessed or derived from the device clock.
class DailyRushStatus {
  final String date;
  final int secondsUntilReset;
  final bool available;
  final bool completed;
  final int? sessionId;
  final int? todayScore;
  final int? todayRank;
  final int? bestScore;

  const DailyRushStatus({
    required this.date,
    required this.secondsUntilReset,
    required this.available,
    required this.completed,
    required this.sessionId,
    required this.todayScore,
    required this.todayRank,
    required this.bestScore,
  });

  factory DailyRushStatus.fromJson(Map<String, dynamic> json) => DailyRushStatus(
        date: json['date'] as String,
        secondsUntilReset: json['seconds_until_reset'] as int,
        available: json['available'] as bool,
        completed: json['completed'] as bool,
        sessionId: json['session_id'] as int?,
        todayScore: json['today_score'] as int?,
        todayRank: json['today_rank'] as int?,
        bestScore: json['best_score'] as int?,
      );
}
