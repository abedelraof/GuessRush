import 'package:flutter/material.dart';

import '../models/question.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/animated_counter.dart';
import '../widgets/audio_question.dart';
import '../widgets/double_down_overlay.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/image_question.dart';
import '../widgets/momentum_meter.dart';
import '../widgets/option_tile.dart';
import '../widgets/progressive_question.dart';
import '../widgets/timer_ring.dart';
import '../widgets/video_question.dart';

class GameScreen extends StatelessWidget {
  final QuizController controller;

  const GameScreen({super.key, required this.controller});

  // One background per round, in order — cycling through them as the Rush
  // progresses so each round reads as visually distinct. Split by quartile
  // of the Rush's length rather than a hardcoded question count, so this
  // keeps working if the server's rounds-per-Rush ever changes.
  static const List<String> _roundBackgrounds = [
    'assets/images/app_background.png',
    'assets/images/app_background2.png',
    'assets/images/app_background3.png',
    'assets/images/app_background4.png',
  ];

  String _backgroundForRound(int qIndex, int questionTotal) {
    if (questionTotal <= 0) return _roundBackgrounds.first;
    final segment = (qIndex * _roundBackgrounds.length ~/ questionTotal).clamp(
      0,
      _roundBackgrounds.length - 1,
    );
    return _roundBackgrounds[segment];
  }

  @override
  Widget build(BuildContext context) {
    final q = controller.currentQuestion;

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            _backgroundForRound(controller.qIndex, controller.questionTotal),
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Play With Friends only — a no-op Column child (nothing rendered)
                // for an ordinary solo/Daily Rush, since activeMatchId is null.
                if (controller.activeMatchId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: _OpponentStrip(
                      opponentName: controller.opponent?.displayName ?? 'Opponent',
                      opponentIndex: controller.opponentQuestionIndex,
                      total: controller.questionTotal,
                    ),
                  ),
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StreakChip(streak: controller.streak),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '⭐',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    AnimatedCounter(
                                      value: controller.score,
                                      style: AppFonts.inter(
                                        size: 13,
                                        weight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 8,
                                color: Colors.white.withValues(alpha: 0.25),
                                alignment: Alignment.centerLeft,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: controller.progressPct.clamp(0, 1),
                                  ),
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                  builder: (context, factor, child) =>
                                      FractionallySizedBox(
                                        widthFactor: factor,
                                        child: child,
                                      ),
                                  child: Container(color: AppColors.goldTimer),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          MomentumMeter(momentum: controller.momentum),
                        ],
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.questionLabel,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x26000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    q.label,
                                    style: AppFonts.inter(
                                      size: 12,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (controller.currentDoubleDownChoice ==
                                    'risky') ...[
                                  const SizedBox(width: 8),
                                  const _RiskyBadge(),
                                ],
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _RemoveOneButton(controller: controller),
                                if (q.hasTimer) ...[
                                  const SizedBox(width: 8),
                                  TimerRing(
                                    timeLeft: controller.timeLeft,
                                    totalSeconds: q.timerSeconds,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        if (controller.audioError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '🔇 ${controller.audioError}',
                            style: AppFonts.inter(
                              size: 11,
                              weight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                        if (controller.errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${controller.errorMessage!} Tap an option to try again.',
                              style: AppFonts.inter(
                                size: 13,
                                weight: FontWeight.w600,
                                color: AppColors.feedbackWrongTitle,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (q.showTopPrompt) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              q.prompt ?? '',
                              style: AppFonts.baloo(
                                size: 21,
                                weight: FontWeight.w700,
                                height: 1.25,
                              ),
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
                                imageUrl: i < q.optionImageUrls.length
                                    ? q.optionImageUrls[i]
                                    : null,
                                answered: controller.answered,
                                isGrading: controller.isGrading,
                                isCorrectOption:
                                    i == controller.gradedCorrectIndex,
                                isSelected: controller.selected == i,
                                shake: controller.shakeIndex == i,
                                isRemoved: controller.removedOptionIndex == i,
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
          if (controller.feedback != AnswerFeedback.none &&
              controller.gradedCorrectIndex != null)
            Positioned.fill(
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
          if (controller.awaitingDoubleDownChoice)
            Positioned.fill(
              child: DoubleDownOverlay(
                streak: controller.streak,
                isChoosing: controller.isChoosingDoubleDown,
                onChoose: controller.chooseDoubleDown,
              ),
            ),
        ],
      ),
    );
  }
}

/// Play With Friends' opponent HUD — presence only, deliberately never shows
/// correctness or score (see the plan's "presence-only reveal" decision);
/// just which question they're on, as a mini progress bar alongside their name.
class _OpponentStrip extends StatelessWidget {
  final String opponentName;
  final int opponentIndex;
  final int total;

  const _OpponentStrip({required this.opponentName, required this.opponentIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (opponentIndex / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🆚', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              opponentName,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.inter(size: 11, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 6,
                color: Colors.white.withValues(alpha: 0.2),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (context, factor, child) =>
                      FractionallySizedBox(widthFactor: factor, child: child),
                  child: Container(color: AppColors.tilePink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  final int streak;

  const _StreakChip({required this.streak});

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    final milestone = kStreakMilestones.contains(streak);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: active ? AppColors.streakBadge : null,
        color: active ? null : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        boxShadow: milestone
            ? [
                BoxShadow(
                  color: AppColors.streakGradA.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🔥',
            style: TextStyle(
              fontSize: 13,
              color: active ? null : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 4),
          // Re-keyed on every streak change so the pop-in restarts from scratch
          // instead of tweening from the old value — a quick "beat" per streak tick.
          TweenAnimationBuilder<double>(
            key: ValueKey(streak),
            tween: Tween(begin: milestone ? 1.6 : 1.25, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              '$streak',
              style: AppFonts.inter(
                size: 13,
                weight: FontWeight.w800,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reminds the player they're on a Double Down question while they're still
/// answering it — the outcome itself is communicated afterward by FeedbackOverlay.
class _RiskyBadge extends StatelessWidget {
  const _RiskyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.streakGradA.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            'RISKY',
            style: AppFonts.inter(
              size: 11,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Limited to REMOVE_ONE_USES_PER_RUSH charges for the whole Rush (currently
/// 1) — the count itself communicates "save it or spend it now" without
/// needing extra copy.
class _RemoveOneButton extends StatelessWidget {
  final QuizController controller;

  const _RemoveOneButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    final usable =
        !controller.answered &&
        !controller.isUsingRemoveOne &&
        controller.removeOneUsesRemaining > 0 &&
        controller.removedOptionIndex == null;
    final visible =
        controller.removeOneUsesRemaining > 0 ||
        controller.removedOptionIndex != null;
    if (!visible) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: usable ? controller.useRemoveOne : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: usable ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.isUsingRemoveOne)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Text(
                  '🚫',
                  style: TextStyle(
                    fontSize: 13,
                    color: usable ? null : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              const SizedBox(width: 5),
              Text(
                '${controller.removeOneUsesRemaining}',
                style: AppFonts.inter(
                  size: 12,
                  weight: FontWeight.w800,
                  color: usable
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
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
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            q.prompt ?? '',
            textAlign: TextAlign.center,
            style: AppFonts.baloo(
              size: 21,
              weight: FontWeight.w700,
              color: AppColors.darkText,
              height: 1.3,
            ),
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
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
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
          isRevealing: controller.isRevealingClue,
          nextClueMultiplier: clueMultiplierHintFor(controller.clueCount + 1),
          onRevealClue: controller.revealClue,
        );
    }
  }
}
