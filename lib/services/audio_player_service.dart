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

  AudioPlayer _player = AudioPlayer();
  final AudioPlayer _tickPlayer = AudioPlayer();

  // A second player kept pre-buffered with the NEXT question's narration
  // (via preload, called during the feedback screen's display window) so
  // playUrl can start it near-instantly instead of fetching from scratch.
  AudioPlayer _preloadPlayer = AudioPlayer();
  String? _preloadedUrl;

  /// Buffers [url] on a spare player without playing it, so a later playUrl
  /// call for the same url can start instantly. Best-effort — a failure here
  /// just means playUrl falls back to its normal fetch-and-play path.
  Future<void> preload(String? url) async {
    if (url == null || url.isEmpty || url == _preloadedUrl) return;
    try {
      await _preloadPlayer.setSourceUrl(url);
      _preloadedUrl = url;
    } catch (_) {
      _preloadedUrl = null;
    }
  }

  /// Plays [url] and waits for it to actually finish (not just start), so
  /// callers can reliably chain behavior — e.g. starting the timer tick —
  /// on narration completion. Falls back to a 30s cap in case the platform
  /// player never fires a completion event for some clip.
  Future<void> playUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    if (url == _preloadedUrl) {
      // Already buffered on _preloadPlayer — swap it in as the active player
      // and resume from the existing source instead of re-fetching. The old
      // _player is recycled into the preload slot for the next question.
      final recycled = _player;
      _player = _preloadPlayer;
      _preloadPlayer = recycled;
      _preloadedUrl = null;
      await recycled.stop();

      final completer = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      final fallback = Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) completer.complete();
      });
      try {
        await _player.resume();
        await completer.future;
      } finally {
        fallback.cancel();
        await sub.cancel();
      }
      return;
    }

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

  Future<void> stop() {
    _preloadedUrl = null;
    return Future.wait([
      _player.stop(),
      _tickPlayer.stop(),
      _preloadPlayer.stop(),
    ]);
  }
}
