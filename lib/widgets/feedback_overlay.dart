import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'animated_counter.dart';

class FeedbackOverlay extends StatefulWidget {
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

  @override
  State<FeedbackOverlay> createState() => _FeedbackOverlayState();
}

/// One confetti bit flying outward from center — deterministic per particle
/// (angle/distance/color/spin rolled once in initState), animated purely off
/// the shared controller's `t` in build.
class _Confetti {
  final double angle;
  final double distance;
  final Color color;
  final double size;
  final double delay;
  final double spin;

  const _Confetti({
    required this.angle,
    required this.distance,
    required this.color,
    required this.size,
    required this.delay,
    required this.spin,
  });
}

const _kConfettiColors = [
  AppColors.streakGradA,
  AppColors.streakGradB,
  AppColors.tileBlue,
  AppColors.tileGreen,
  AppColors.tilePink,
  AppColors.coinGold,
  AppColors.tilePurple,
];

class _FeedbackOverlayState extends State<FeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Confetti> _confetti;

  bool get _correct => widget.feedback == AnswerFeedback.correct;
  bool get _timeout => widget.feedback == AnswerFeedback.timeout;

  @override
  void initState() {
    super.initState();
    // Correct gets the full bounce+confetti sequence room to play out; a
    // miss/timeout is just a quick shake, so it can resolve faster.
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _correct ? 900 : 550),
    )..forward();
    _confetti = _correct
        ? _rollConfetti(widget.isMilestone ? 20 : 13)
        : const [];
  }

  List<_Confetti> _rollConfetti(int count) {
    final rng = math.Random();
    return List.generate(count, (i) {
      final angle = (i / count) * 2 * math.pi + rng.nextDouble() * 0.5;
      return _Confetti(
        angle: angle,
        distance: 60 + rng.nextDouble() * 70,
        color: _kConfettiColors[rng.nextInt(_kConfettiColors.length)],
        size: 6 + rng.nextDouble() * 7,
        delay: rng.nextDouble() * 0.15,
        spin: (rng.nextBool() ? 1 : -1) * (2 + rng.nextDouble() * 4),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // progress of the [start, end] window of the timeline, curved.
  double _p(double t, double start, double end, Curve curve) {
    final raw = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  double _lerp(double a, double b, double p) => a + (b - a) * p;

  String get _icon => _correct
      ? '🎉'
      : _timeout
      ? '⏰'
      : '😬';
  String get _title => _correct
      ? 'CORRECT!'
      : _timeout
      ? "TIME'S UP!"
      : 'NOT THIS TIME!';

  @override
  Widget build(BuildContext context) {
    final accent = _correct
        ? AppColors.feedbackCorrectTitle
        : _timeout
        ? AppColors.feedbackTimeoutTitle
        : AppColors.feedbackWrongTitle;
    final hot = _correct && widget.momentumTier == MomentumTier.max;

    return Container(
      color: const Color(0x8C141423),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(30),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          // A punchy left-right wobble for a miss/timeout — the "no" shake,
          // decaying out over the animation instead of a flat scale-in.
          final shakeDx = _correct
              ? 0.0
              : math.sin(t * math.pi * 5) * (1 - t) * 14;

          final ringP = _p(t, 0.0, 0.6, Curves.easeOut);
          final ringScale = _lerp(0.2, _correct ? 1.9 : 1.3, ringP);
          final ringOpacity = _lerp(0.55, 0.0, ringP);

          final cardP = _p(
            t,
            0.0,
            0.5,
            widget.isMilestone ? Curves.elasticOut : Curves.easeOutBack,
          );
          final cardScale = _lerp(widget.isMilestone ? 0.7 : 0.85, 1.0, cardP);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (final c in _confetti) _buildConfetti(c, t),
              // Radiating ring behind the card — a quick color pulse instead
              // of a static backdrop, correct or not.
              Opacity(
                opacity: ringOpacity,
                child: Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 4),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(shakeDx, 0),
                child: Transform.scale(
                  scale: cardScale,
                  child: _buildCard(accent, hot, t),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConfetti(_Confetti c, double t) {
    final p = _p(t, c.delay, (c.delay + 0.7).clamp(0.0, 1.0), Curves.easeOut);
    final dx = math.cos(c.angle) * c.distance * p;
    final dy = math.sin(c.angle) * c.distance * p - (18 * p * (1 - p) * 4);
    final opacity = 1.0 - _p(t, c.delay + 0.35, 1.0, Curves.easeIn);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: c.spin * p * math.pi,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            width: c.size,
            height: c.size,
            decoration: BoxDecoration(
              color: c.color,
              borderRadius: BorderRadius.circular(c.size * 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Color accent, bool hot, double t) {
    final iconScale = _lerp(0.0, 1.0, _p(t, 0.05, 0.65, Curves.elasticOut));
    final iconRotate = _lerp(-0.5, 0.0, _p(t, 0.05, 0.45, Curves.easeOutCubic));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border(top: BorderSide(color: accent, width: 5)),
        boxShadow: [
          const BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
          if (hot)
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 30,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: iconRotate,
            child: Transform.scale(
              scale: iconScale,
              child: Text(_icon, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 6),
          Text(_title, style: AppFonts.baloo(size: 22, color: accent)),
          const SizedBox(height: 10),
          if (_correct) ..._correctBody(t) else ..._missBody(t),
        ],
      ),
    );
  }

  List<Widget> _correctBody(double t) {
    var delay = 0.45;
    Widget nextChip(String text, {bool emphasize = false, bool muted = false}) {
      final w = _chip(text, t, delay, emphasize: emphasize, muted: muted);
      delay += 0.06;
      return w;
    }

    return [
      if (widget.doubleDownChoice == 'risky') ...[
        nextChip('🔥 DOUBLE DOWN HIT!', emphasize: true),
        const SizedBox(height: 6),
      ],
      Transform.scale(
        scale: _lerp(0.5, 1.0, _p(t, 0.3, 0.55, Curves.elasticOut)),
        child: AnimatedCounter(
          value: widget.answerScore,
          prefix: '+',
          style: AppFonts.inter(
            size: 30,
            weight: FontWeight.w800,
            color: AppColors.xpGoldText,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          nextChip('🔥 ${widget.streak} STREAK', emphasize: widget.isMilestone),
          if (widget.doubleDownMultiplier > 1.0)
            nextChip(
              '×${widget.doubleDownMultiplier.toStringAsFixed(0)} DOUBLE DOWN',
            ),
          if (widget.streakMultiplier > 1.0)
            nextChip('×${widget.streakMultiplier.toStringAsFixed(1)}'),
          if (widget.speedLabel.isNotEmpty) nextChip(widget.speedLabel),
          if (widget.clueMultiplier < 1.0)
            nextChip(
              '${(widget.clueMultiplier * 100).round()}% · ${widget.cluesRevealed} CLUES',
            ),
          if (widget.removeOneUsed) nextChip('🚫 REMOVE ONE'),
          // Easy is the baseline difficulty — surfacing it here would just be noise.
          if (widget.difficulty != 'easy')
            nextChip(widget.difficulty.toUpperCase()),
        ],
      ),
    ];
  }

  List<Widget> _missBody(double t) {
    return [
      if (widget.doubleDownChoice == 'risky') ...[
        _chip('💔 DOUBLE DOWN FAILED', t, 0.1, muted: true),
        const SizedBox(height: 8),
      ],
      Opacity(
        opacity: _p(t, 0.15, 0.4, Curves.easeOut),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppFonts.inter(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.mutedText,
            ),
            children: [
              const TextSpan(text: 'The answer was: '),
              TextSpan(
                text: widget.correctAnswerText,
                style: AppFonts.inter(
                  size: 14,
                  weight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
      if (widget.streakBeforeAnswer > 0) ...[
        const SizedBox(height: 8),
        _chip(
          'STREAK LOST · WAS ${widget.streakBeforeAnswer}',
          t,
          0.25,
          muted: true,
        ),
      ],
    ];
  }

  Widget _chip(
    String text,
    double t,
    double delay, {
    bool emphasize = false,
    bool muted = false,
  }) {
    final popP = _p(t, delay, delay + 0.35, Curves.easeOutBack);
    final fadeP = _p(t, delay, delay + 0.25, Curves.easeOut);
    return Opacity(
      opacity: fadeP,
      child: Transform.scale(
        scale: _lerp(0.4, 1.0, popP),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: emphasize
                ? AppColors.streakGradA.withValues(alpha: 0.16)
                : AppColors.chipBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: AppFonts.inter(
              size: emphasize ? 13 : 12,
              weight: FontWeight.w800,
              color: muted
                  ? AppColors.streakLostText
                  : (emphasize ? AppColors.streakGradA : AppColors.chipText),
            ),
          ),
        ),
      ),
    );
  }
}
