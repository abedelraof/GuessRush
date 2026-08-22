enum QuestionType { image, audio, video, text, emoji, progressive }

class Question {
  final QuestionType type;
  final String label;
  final String? prompt;
  final String? placeholder;
  final String? duration;
  final String? emojis;
  final List<String>? clues;
  final List<String> options;
  final int correct;
  final int timerSeconds;

  const Question({
    required this.type,
    required this.label,
    this.prompt,
    this.placeholder,
    this.duration,
    this.emojis,
    this.clues,
    required this.options,
    required this.correct,
    this.timerSeconds = 0,
  });

  bool get hasTimer => timerSeconds > 0;

  bool get showTopPrompt =>
      type == QuestionType.image ||
      type == QuestionType.audio ||
      type == QuestionType.video ||
      type == QuestionType.emoji ||
      type == QuestionType.progressive;
}
