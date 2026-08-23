import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'animated_counter.dart';

class FeedbackOverlay extends StatelessWidget {
  final AnswerFeedback feedback;
  final int answerScore;
  final int streak;
  final int streakBeforeAnswer;
  final bool isMilestone;
  final String speedLabel;
  final double streakMultiplier;
  final String difficulty;
  final String correctAnswerText;
  final MomentumTier momentumTier;

  // Strategic mechanics (Phase 5) breakdown for this specific answer.
  final int cluesRevealed;
  final double clueMultiplier;
  final bool removeOneUsed;
  final String doubleDownChoice; // 'none' | 'safe' | 'risky'
  final double doubleDownMultiplier;

  const FeedbackOverlay({
    super.key,
    required this.feedback,
    required this.answerScore,
    required this.streak,
    required this.streakBeforeAnswer,
    required this.isMilestone,
    required this.speedLabel,
    required this.streakMultiplier,
    required this.difficulty,
    required this.correctAnswerText,
    required this.momentumTier,
    required this.cluesRevealed,
    required this.clueMultiplier,
    required this.removeOneUsed,
    required this.doubleDownChoice,
    required this.doubleDownMultiplier,
  });

  bool get _correct => feedback == AnswerFeedback.correct;
  bool get _timeout => feedback == AnswerFeedback.timeout;

  @override
  Widget build(BuildContext context) {
    final accent = _correct
        ? AppColors.feedbackCorrectTitle
        : _timeout
            ? AppColors.feedbackTimeoutTitle
            : AppColors.feedbackWrongTitle;
    final hot = _correct && momentumTier == MomentumTier.max;

    return Container(
      color: const Color(0x8C141423),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(30),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: isMilestone ? 0.7 : 0.85, end: 1),
        duration: Duration(milliseconds: isMilestone ? 380 : 250),
        curve: isMilestone ? Curves.elasticOut : Curves.easeOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border(top: BorderSide(color: accent, width: 5)),
            boxShadow: [
              const BoxShadow(color: Color(0x4D000000), blurRadius: 40, offset: Offset(0, 20)),
              if (hot) BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 6),
              Text(_title, style: AppFonts.baloo(size: 22, color: accent)),
              const SizedBox(height: 10),
              if (_correct) ..._correctBody() else ..._missBody(),
            ],
          ),
        ),
      ),
    );
  }

  String get _icon => _correct ? '🎉' : _timeout ? '⏰' : '😬';
  String get _title => _correct ? 'CORRECT!' : _timeout ? "TIME'S UP!" : 'NOT THIS TIME!';

  List<Widget> _correctBody() {
    return [
      if (doubleDownChoice == 'risky') ...[
        _chip('🔥 DOUBLE DOWN HIT!', emphasize: true),
        const SizedBox(height: 6),
      ],
      AnimatedCounter(
        value: answerScore,
        prefix: '+',
        style: AppFonts.inter(size: 30, weight: FontWeight.w800, color: AppColors.xpGoldText),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          _chip('🔥 $streak STREAK', emphasize: isMilestone),
          if (doubleDownMultiplier > 1.0) _chip('×${doubleDownMultiplier.toStringAsFixed(0)} DOUBLE DOWN'),
          if (streakMultiplier > 1.0) _chip('×${streakMultiplier.toStringAsFixed(1)}'),
          if (speedLabel.isNotEmpty) _chip(speedLabel),
          if (clueMultiplier < 1.0) _chip('${(clueMultiplier * 100).round()}% · $cluesRevealed CLUES'),
          if (removeOneUsed) _chip('🚫 REMOVE ONE'),
          // Easy is the baseline difficulty — surfacing it here would just be noise.
          if (difficulty != 'easy') _chip(difficulty.toUpperCase()),
        ],
      ),
    ];
  }

  List<Widget> _missBody() {
    return [
      if (doubleDownChoice == 'risky') ...[
        _chip('💔 DOUBLE DOWN FAILED', muted: true),
        const SizedBox(height: 8),
      ],
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
      if (streakBeforeAnswer > 0) ...[
        const SizedBox(height: 8),
        _chip('STREAK LOST · WAS $streakBeforeAnswer', muted: true),
      ],
    ];
  }

  Widget _chip(String text, {bool emphasize = false, bool muted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: emphasize ? AppColors.streakGradA.withValues(alpha: 0.16) : AppColors.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppFonts.inter(
          size: emphasize ? 13 : 12,
          weight: FontWeight.w800,
          color: muted ? AppColors.streakLostText : (emphasize ? AppColors.streakGradA : AppColors.chipText),
        ),
      ),
    );
  }
}
