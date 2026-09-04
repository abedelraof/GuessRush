import 'package:shared_preferences/shared_preferences.dart';

/// Persisted player preferences (sound/narration/haptics toggles, the Daily
/// Rush reminder). Plain wrapper around SharedPreferences, not a
/// ChangeNotifier — QuizController owns the single instance and is the one
/// thing every screen already listens to, same as `profile`/`dailyRushStatus`.
class SettingsService {
  static const _kSoundEffects = 'settings_sound_effects_enabled';
  static const _kNarration = 'settings_narration_enabled';
  static const _kHaptics = 'settings_haptics_enabled';
  static const _kReminderEnabled = 'settings_daily_rush_reminder_enabled';
  static const _kReminderHour = 'settings_daily_rush_reminder_hour';
  static const _kReminderMinute = 'settings_daily_rush_reminder_minute';

  bool soundEffectsEnabled = true;
  bool narrationEnabled = true;
  bool hapticsEnabled = true;
  bool dailyRushReminderEnabled = false;
  int reminderHour = 18;
  int reminderMinute = 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    soundEffectsEnabled = prefs.getBool(_kSoundEffects) ?? true;
    narrationEnabled = prefs.getBool(_kNarration) ?? true;
    hapticsEnabled = prefs.getBool(_kHaptics) ?? true;
    dailyRushReminderEnabled = prefs.getBool(_kReminderEnabled) ?? false;
    reminderHour = prefs.getInt(_kReminderHour) ?? 18;
    reminderMinute = prefs.getInt(_kReminderMinute) ?? 0;
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    soundEffectsEnabled = value;
    await _putBool(_kSoundEffects, value);
  }

  Future<void> setNarrationEnabled(bool value) async {
    narrationEnabled = value;
    await _putBool(_kNarration, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    hapticsEnabled = value;
    await _putBool(_kHaptics, value);
  }

  Future<void> setDailyRushReminderEnabled(bool value) async {
    dailyRushReminderEnabled = value;
    await _putBool(_kReminderEnabled, value);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    reminderHour = hour;
    reminderMinute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReminderHour, hour);
    await prefs.setInt(_kReminderMinute, minute);
  }

  Future<void> _putBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
