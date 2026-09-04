import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/round_background.dart';
import '../widgets/feedback_overlay.dart';

/// Shown for ~1.6s right after a question is graded — a real screen (not an
/// overlay on top of GameScreen) so GameScreen can fully unmount here, giving
/// QuizController a clean window to prefetch the next question's assets
/// (see QuizController._prefetchNextQuestionAssets) while this is on screen.
class FeedbackScreen extends StatelessWidget {
  final QuizController controller;

  const FeedbackScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final q = controller.currentQuestion;
    return Container(
      // Same per-round background the just-answered question was showing
      // (qIndex hasn't advanced yet here) — keeps this from visually jumping
      // to the shell's plain background between question and feedback.
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            roundBackgroundFor(controller.qIndex, controller.questionTotal),
          ),
          fit: BoxFit.cover,
        ),
      ),
      // FeedbackOverlay's root has no explicit size — it filled the screen
      // previously only because its old call site wrapped it in Positioned.fill
      // inside a Stack. AnimatedSwitcher's own Stack is loose, so force it back
      // to full-size here.
      child: SizedBox.expand(
        child: FeedbackOverlay(
          feedback: controller.feedback,
          answerScore: controller.xpGained,
          streak: controller.streak,
          streakBeforeAnswer: controller.lastStreakBeforeAnswer,
          isMilestone: controller.lastIsMilestone,
          speedLabel: controller.lastSpeedLabel,
          streakMultiplier: controller.lastStreakMultiplier,
          difficulty: controller.lastDifficulty,
          correctAnswerText: q.options[controller.gradedCorrectIndex!],
          momentumTier: controller.momentumTier,
          cluesRevealed: controller.lastCluesRevealed,
          clueMultiplier: controller.lastClueMultiplier,
          removeOneUsed: controller.lastRemoveOneUsed,
          doubleDownChoice: controller.lastDoubleDownChoice,
          doubleDownMultiplier: controller.lastDoubleDownMultiplier,
        ),
      ),
    );
  }
}
