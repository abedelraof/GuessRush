import 'package:flutter/material.dart';

import '../models/question.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/audio_question.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/image_question.dart';
import '../widgets/option_tile.dart';
import '../widgets/progressive_question.dart';
import '../widgets/timer_ring.dart';
import '../widgets/video_question.dart';

class GameScreen extends StatelessWidget {
  final QuizController controller;

  const GameScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final q = controller.currentQuestion;

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'QUESTION ${controller.qIndex + 1} / ${controller.questionTotal}',
                          style: AppFonts.inter(
                            size: 12,
                            weight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text('${controller.score}', style: AppFonts.inter(size: 13, weight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 8,
                        color: Colors.white.withValues(alpha: 0.25),
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: controller.progressPct.clamp(0, 1)),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          builder: (context, factor, child) => FractionallySizedBox(
                            widthFactor: factor,
                            child: child,
                          ),
                          child: Container(color: AppColors.goldTimer),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.questionLabel,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Text(q.label, style: AppFonts.inter(size: 12, weight: FontWeight.w800)),
                          ),
                          if (q.hasTimer)
                            TimerRing(timeLeft: controller.timeLeft, totalSeconds: q.timerSeconds),
                        ],
                      ),
                      if (controller.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${controller.errorMessage!} Tap an option to try again.',
                            style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.feedbackWrongTitle),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (q.showTopPrompt) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            q.prompt ?? '',
                            style: AppFonts.baloo(size: 21, weight: FontWeight.w700, height: 1.25),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _QuestionBody(controller: controller, q: q),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.4,
                        children: [
                          for (var i = 0; i < q.options.length; i++)
                            OptionTile(
                              index: i,
                              text: q.options[i],
                              imgBg: AppColors.optionHues[i % 4],
                              answered: controller.answered,
                              isGrading: controller.isGrading,
                              isCorrectOption: i == controller.gradedCorrectIndex,
                              isSelected: controller.selected == i,
                              shake: controller.shakeIndex == i,
                              onTap: () => controller.selectAnswer(i),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (controller.feedback != AnswerFeedback.none && controller.gradedCorrectIndex != null)
          Positioned.fill(
            child: FeedbackOverlay(
              feedback: controller.feedback,
              xpGained: controller.xpGained,
              streak: controller.streak,
              correctAnswerText: q.options[controller.gradedCorrectIndex!],
            ),
          ),
      ],
    );
  }
}

class _QuestionBody extends StatelessWidget {
  final QuizController controller;
  final Question q;

  const _QuestionBody({required this.controller, required this.q});

  @override
  Widget build(BuildContext context) {
    switch (q.type) {
      case QuestionType.image:
        return ImageQuestion(placeholder: q.placeholder ?? '');
      case QuestionType.audio:
        return AudioQuestion(
          duration: q.duration ?? '',
          isPlaying: controller.isPlaying,
          onTogglePlay: controller.togglePlay,
        );
      case QuestionType.video:
        return VideoQuestion(
          duration: q.duration ?? '',
          isPlaying: controller.isPlaying,
          onTogglePlay: controller.togglePlay,
        );
      case QuestionType.text:
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            q.prompt ?? '',
            textAlign: TextAlign.center,
            style: AppFonts.baloo(size: 21, weight: FontWeight.w700, color: AppColors.darkText, height: 1.3),
          ),
        );
      case QuestionType.emoji:
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            q.emojis ?? '',
            style: const TextStyle(fontSize: 52, letterSpacing: 6),
          ),
        );
      case QuestionType.progressive:
        final clues = q.clues ?? const [];
        return ProgressiveQuestion(
          clues: clues,
          clueCount: controller.clueCount,
          hasMore: controller.clueCount < clues.length,
          onRevealClue: controller.revealClue,
        );
    }
  }
}
