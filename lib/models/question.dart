enum QuestionType { image, audio, video, text, emoji, progressive }

QuestionType _typeFromString(String s) => QuestionType.values.firstWhere((t) => t.name == s);

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
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
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
      );

  bool get hasTimer => timerSeconds > 0;

  bool get showTopPrompt =>
      type == QuestionType.image ||
      type == QuestionType.audio ||
      type == QuestionType.video ||
      type == QuestionType.emoji ||
      type == QuestionType.progressive;
}
