/// One mission's definition plus this player's current-period progress
/// (Phase 6 — Retention Systems). Server-authoritative: progress, completion,
/// and the reward are all computed and persisted server-side; the client just
/// displays them.
class Mission {
  final String key;
  final String name;
  final String description;
  final String resetPeriod;
  final int target;
  final int progress;
  final bool completed;
  final int rewardXp;

  const Mission({
    required this.key,
    required this.name,
    required this.description,
    required this.resetPeriod,
    required this.target,
    required this.progress,
    required this.completed,
    required this.rewardXp,
  });

  double get progressFraction => target > 0 ? (progress / target).clamp(0, 1) : 0;

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
        key: json['key'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        resetPeriod: json['reset_period'] as String? ?? 'daily',
        target: json['target'] as int,
        progress: json['progress'] as int,
        completed: json['completed'] as bool,
        rewardXp: json['reward_xp'] as int,
      );
}

/// A mission that was JUST completed by finishing a Rush — surfaced once, in
/// the /finish response, as a lightweight "what happened" record (not the
/// full Mission shape, since target/progress are moot once it's done).
class CompletedMission {
  final String key;
  final String name;
  final int rewardXp;

  const CompletedMission({required this.key, required this.name, required this.rewardXp});

  factory CompletedMission.fromJson(Map<String, dynamic> json) => CompletedMission(
        key: json['key'] as String,
        name: json['name'] as String,
        rewardXp: json['reward_xp'] as int,
      );
}
