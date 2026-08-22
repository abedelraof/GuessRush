import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around the platform's native TTS engine
/// (Android TextToSpeech / iOS AVSpeechSynthesizer via flutter_tts).
class TtsService {
  TtsService._() {
    _tts.setSpeechRate(0.48);
    _tts.setPitch(1.0);
  }

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
