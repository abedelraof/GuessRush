enum RewardKind { level, streak, achievement }

RewardKind _rewardKindFromJson(String value) {
  switch (value) {
    case 'level':
      return RewardKind.level;
    case 'streak':
      return RewardKind.streak;
    case 'achievement':
      return RewardKind.achievement;
  }
  throw ArgumentError('Unknown reward kind: $value');
}

/// One claimable, one-time coin bonus — a level reached, a daily-streak
/// milestone, or an achievement unlock. `unlocked`/`claimed` are both
/// server-computed fresh from the player's current state on every fetch.
class Reward {
  final String key;
  final RewardKind kind;
  final String title;
  final String description;
  final int coins;
  final bool unlocked;
  final bool claimed;

  const Reward({
    required this.key,
    required this.kind,
    required this.title,
    required this.description,
    required this.coins,
    required this.unlocked,
    required this.claimed,
  });

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
    key: json['key'] as String,
    kind: _rewardKindFromJson(json['kind'] as String),
    title: json['title'] as String,
    description: json['description'] as String,
    coins: json['coins'] as int,
    unlocked: json['unlocked'] as bool,
    claimed: json['claimed'] as bool,
  );
}
