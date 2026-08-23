/// One achievement definition plus this player's unlock state for it.
/// Also reused for the "newly unlocked this Rush" list in a finish-session
/// response, where `unlocked` is always true and `unlockedAt` isn't sent
/// (the moment is "now", the results screen doesn't need a timestamp for it).
class Achievement {
  final String key;
  final String name;
  final String description;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.key,
    required this.name,
    required this.description,
    this.unlocked = true,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        key: json['key'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        unlocked: json['unlocked'] as bool? ?? true,
        unlockedAt: json['unlocked_at'] != null ? DateTime.tryParse(json['unlocked_at'] as String) : null,
      );
}

class ProfileStats {
  final int rushesCompleted;
  final int questionsAnswered;
  final int questionsCorrect;
  final int accuracyPct;
  final int avgResponseTimeMs;

  const ProfileStats({
    required this.rushesCompleted,
    required this.questionsAnswered,
    required this.questionsCorrect,
    required this.accuracyPct,
    required this.avgResponseTimeMs,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
        rushesCompleted: json['rushes_completed'] as int,
        questionsAnswered: json['questions_answered'] as int,
        questionsCorrect: json['questions_correct'] as int,
        accuracyPct: json['accuracy_pct'] as int,
        avgResponseTimeMs: json['avg_response_time_ms'] as int,
      );
}

class ProfileRecords {
  final int bestRushScore;
  final int bestStreak;
  final int bestAccuracyPct;
  final int? fastestAvgResponseTimeMs;
  final int perfectRushCount;

  const ProfileRecords({
    required this.bestRushScore,
    required this.bestStreak,
    required this.bestAccuracyPct,
    required this.fastestAvgResponseTimeMs,
    required this.perfectRushCount,
  });

  factory ProfileRecords.fromJson(Map<String, dynamic> json) => ProfileRecords(
        bestRushScore: json['best_rush_score'] as int,
        bestStreak: json['best_streak'] as int,
        bestAccuracyPct: json['best_accuracy_pct'] as int,
        fastestAvgResponseTimeMs: json['fastest_avg_response_time_ms'] as int?,
        perfectRushCount: json['perfect_rush_count'] as int,
      );
}

class PlayerProfile {
  final String displayName;
  final int level;
  final int lifetimeXp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final ProfileStats stats;
  final ProfileRecords records;
  final List<Achievement> achievements;

  const PlayerProfile({
    required this.displayName,
    required this.level,
    required this.lifetimeXp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.stats,
    required this.records,
    required this.achievements,
  });

  double get levelProgress => xpForNextLevel > 0 ? (xpIntoLevel / xpForNextLevel).clamp(0, 1) : 0;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        displayName: json['display_name'] as String,
        level: json['level'] as int,
        lifetimeXp: json['lifetime_xp'] as int,
        xpIntoLevel: json['xp_into_level'] as int,
        xpForNextLevel: json['xp_for_next_level'] as int,
        stats: ProfileStats.fromJson(json['stats'] as Map<String, dynamic>),
        records: ProfileRecords.fromJson(json['records'] as Map<String, dynamic>),
        achievements: (json['achievements'] as List)
            .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}
