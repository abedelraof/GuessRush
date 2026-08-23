import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Plays the server-generated narration clip for the current question
/// (question.audioUrl), replacing the earlier native-TTS read-aloud.
/// Also plays the local per-second countdown tick, on a separate player so
/// it never interrupts narration that's still playing.
class AudioPlayerService {
  AudioPlayerService._() {
    _tickPlayer.setPlayerMode(PlayerMode.lowLatency);
    _tickPlayer.setReleaseMode(ReleaseMode.stop);
    _tickPlayer.setVolume(0.5);
  }

  static final AudioPlayerService instance = AudioPlayerService._();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _tickPlayer = AudioPlayer();

  /// Plays [url] and waits for it to actually finish (not just start), so
  /// callers can reliably chain behavior — e.g. starting the timer tick —
  /// on narration completion. Falls back to a 30s cap in case the platform
  /// player never fires a completion event for some clip.
  Future<void> playUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    await _player.stop();

    final completer = Completer<void>();
    final sub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    final fallback = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await _player.play(UrlSource(url));
      await completer.future;
    } finally {
      fallback.cancel();
      await sub.cancel();
    }
  }

  Future<void> playTick() async {
    await _tickPlayer.stop();
    await _tickPlayer.play(AssetSource('audio/tick.wav'));
  }

  Future<void> stop() => Future.wait([_player.stop(), _tickPlayer.stop()]);
}
