import 'package:flutter/services.dart';

/// Central gate for haptic feedback, mirroring AudioPlayerService's singleton
/// style. QuizController flips [enabled] to match the player's Settings
/// toggle; every haptic call site in the app should go through here instead
/// of calling HapticFeedback directly, so the toggle actually has an effect.
class HapticsService {
  HapticsService._();

  static final HapticsService instance = HapticsService._();

  bool enabled = true;

  void selectionClick() {
    if (enabled) HapticFeedback.selectionClick();
  }

  void lightImpact() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void mediumImpact() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void heavyImpact() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
