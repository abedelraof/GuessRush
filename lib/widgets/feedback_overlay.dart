import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class FeedbackOverlay extends StatelessWidget {
  final AnswerFeedback feedback;
  final int xpGained;
  final int streak;
  final String correctAnswerText;

  const FeedbackOverlay({
    super.key,
    required this.feedback,
    required this.xpGained,
    required this.streak,
    required this.correctAnswerText,
  });

  @override
  Widget build(BuildContext context) {
    final correct = feedback == AnswerFeedback.correct;
    return Container(
      color: const Color(0x8C141423),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(30),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x4D000000), blurRadius: 40, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(correct ? '🎉' : '😬', style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text(
                correct ? 'CORRECT! 🔥' : 'NOT THIS TIME!',
                style: AppFonts.baloo(
                  size: 24,
                  color: correct ? AppColors.feedbackCorrectTitle : AppColors.feedbackWrongTitle,
                ),
              ),
              const SizedBox(height: 6),
              if (correct) ...[
                Text(
                  '+$xpGained XP',
                  style: AppFonts.inter(size: 16, weight: FontWeight.w800, color: AppColors.xpGoldText),
                ),
                const SizedBox(height: 4),
                Text(
                  '🔥 $streak ANSWER STREAK',
                  style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.mutedText),
                ),
              ] else ...[
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppFonts.inter(size: 14, weight: FontWeight.w600, color: AppColors.mutedText),
                    children: [
                      const TextSpan(text: 'The answer was: '),
                      TextSpan(
                        text: correctAnswerText,
                        style: AppFonts.inter(size: 14, weight: FontWeight.w800, color: AppColors.darkText),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
