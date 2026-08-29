/// The four Pick Your Rush game modes — what replaces the old "pick a category"
/// step. Category stays purely internal (see questionSelection.service.js on the
/// server); this is the only thing the player actually chooses before playing.
enum GameMode { quickRush, chaosRush, streakRush, chillRush }

extension GameModeApiValue on GameMode {
  /// The value sent to POST /api/rush/start's `mode` field.
  String get apiValue {
    switch (this) {
      case GameMode.quickRush:
        return 'quick_rush';
      case GameMode.chaosRush:
        return 'chaos_rush';
      case GameMode.streakRush:
        return 'streak_rush';
      case GameMode.chillRush:
        return 'chill_rush';
    }
  }
}
