import '../services/api_client.dart';

enum QuestionType { image, audio, video, text, emoji, progressive }

QuestionType _typeFromString(String s) => QuestionType.values.firstWhere((t) => t.name == s);

/// Resolves a root-relative media path from the API (e.g. "/public/audio/5.flac")
/// into a fully-qualified URL against the configured server origin.
String? _resolveMediaUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  return '${ApiClient.baseUrl}$path';
}

class Question {
  final int id;
  final QuestionType type;
  final String label;
  final String? prompt;
  final String? placeholder;
  final String? duration;
  final String? emojis;
  final List<String>? clues;
  final List<String> options;
  final int timerSeconds;
  final String? audioUrl;
  final List<String?> optionImageUrls;

  const Question({
    required this.id,
    required this.type,
    required this.label,
    this.prompt,
    this.placeholder,
    this.duration,
    this.emojis,
    this.clues,
    required this.options,
    this.timerSeconds = 0,
    this.audioUrl,
    this.optionImageUrls = const [null, null, null, null],
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawImagePaths = json['option_image_paths'] as List?;
    return Question(
      id: json['id'] as int,
      type: _typeFromString(json['type'] as String),
      label: json['label'] as String,
      prompt: json['prompt'] as String?,
      placeholder: json['media_placeholder'] as String?,
      duration: json['media_duration'] as String?,
      emojis: json['emojis'] as String?,
      clues: (json['clues'] as List?)?.map((e) => e as String).toList(),
      options: (json['options'] as List).map((e) => e as String).toList(),
      timerSeconds: json['timer_seconds'] as int? ?? 0,
      audioUrl: _resolveMediaUrl(json['audio_path'] as String?),
      optionImageUrls: rawImagePaths != null
          ? rawImagePaths.map((p) => _resolveMediaUrl(p as String?)).toList()
          : const [null, null, null, null],
    );
  }

  bool get hasTimer => timerSeconds > 0;

  bool get showTopPrompt =>
      type == QuestionType.image ||
      type == QuestionType.audio ||
      type == QuestionType.video ||
      type == QuestionType.emoji ||
      type == QuestionType.progressive;
}
