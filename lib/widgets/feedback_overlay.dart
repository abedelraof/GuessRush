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
    // Correct gets the full coin-spin+confetti sequence room to play out; a
    // miss/timeout is just a quick shake, so it can resolve faster.
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _correct ? 1000 : 600),
    )..forward();
    _confetti = _correct
        ? _rollConfetti(widget.isMilestone ? 22 : 15)
        : const [];
  }

  List<_Confetti> _rollConfetti(int count) {
    final rng = math.Random();
    return List.generate(count, (i) {
      final angle = (i / count) * 2 * math.pi + rng.nextDouble() * 0.5;
      return _Confetti(
        angle: angle,
        distance: 70 + rng.nextDouble() * 90,
        color: _kConfettiColors[rng.nextInt(_kConfettiColors.length)],
        size: 6 + rng.nextDouble() * 7,
        // Timed to burst once the coin lands, not simultaneously with its spin-in.
        delay: 0.42 + rng.nextDouble() * 0.15,
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
    final accent = _correct ? AppColors.tileGreen : AppColors.wrongBorder;
    final hot = _correct && widget.momentumTier == MomentumTier.max;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // A punchy left-right wobble for a miss/timeout — the "no" shake,
        // decaying out over the animation instead of a flat scale-in.
        final shakeDx = _correct
            ? 0.0
            : math.sin(t * math.pi * 5) * (1 - t) * 14;

        // Colored glow behind everything — fades in and holds, standing in
        // for a flat color wash without hiding the round's own background.
        final glowOpacity = _p(t, 0.05, 0.5, Curves.easeOut);

        // A quick white impact flash timed to the coin landing — brighter
        // for a correct answer, barely-there for a miss.
        final flashPeak = _correct ? 0.5 : 0.22;
        final flashRise = _p(t, 0.36, 0.44, Curves.easeOut);
        final flashFall = _p(t, 0.44, 0.58, Curves.easeIn);
        final flashOpacity = t < 0.44
            ? flashRise * flashPeak
            : (1 - flashFall) * flashPeak;

        // Impact rings: a one-shot burst timed to the same landing moment
        // (not a looping pulse — it fires once and is done).
        final ring1Show = t >= 0.4;
        final ring2Show = t >= 0.46;
        final ring1P = _p(t, 0.4, 0.64, Curves.easeOut);
        final ring2P = _p(t, 0.46, 0.68, Curves.easeOut);

        // The coin: spins in with real perspective, settling with a slight
        // overshoot bounce rather than just fading/scaling flat.
        final spinP = _p(t, 0.0, 0.48, Curves.easeOut);
        final spinTurns = _correct ? 2.5 : 2.0;
        final spinAngle = spinP * spinTurns * 2 * math.pi;
        final scaleP = _p(
          t,
          0.0,
          0.6,
          widget.isMilestone ? Curves.elasticOut : Curves.easeOutBack,
        );
        final coinScale = _lerp(0.3, 1.0, scaleP);
        final coinTranslateY = _lerp(-36.0, 0.0, _p(t, 0.0, 0.55, Curves.easeOut));

        return Stack(
          fit: StackFit.expand,
          children: [
            // Base scrim — just enough to keep white text legible over the
            // round's own busy background art, not a full opaque cover.
            Container(color: Colors.black.withValues(alpha: 0.22)),
            Opacity(
              opacity: glowOpacity.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.15),
                    radius: 0.7,
                    colors: [
                      accent.withValues(alpha: hot ? 0.55 : 0.4),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    for (final c in _confetti) _buildConfetti(c, t),
                    if (ring1Show) _buildRing(ring1P, 6),
                    if (ring2Show) _buildRing(ring2P, 3),
                    Transform.translate(
                      offset: Offset(shakeDx, coinTranslateY),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0022)
                              ..rotateY(spinAngle)
                              ..scaleByDouble(coinScale, coinScale, coinScale, 1.0),
                            child: _buildCoin(),
                          ),
                          const SizedBox(height: 14),
                          _buildTitle(t),
                          const SizedBox(height: 8),
                          if (_correct) ..._correctBody(t) else ..._missBody(t),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: Opacity(
                opacity: flashOpacity.clamp(0.0, 1.0),
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRing(double p, double borderWidth) {
    final scale = _lerp(0.25, 3.4, p);
    final opacity = _lerp(0.85, 0.0, p);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: borderWidth),
          ),
        ),
      ),
    );
  }

  Widget _buildCoin() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(_icon, style: const TextStyle(fontSize: 42)),
    );
  }

  Widget _buildTitle(double t) {
    final p = _p(t, 0.5, 0.66, Curves.easeOut);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, _lerp(10, 0, p)),
        child: Text(
          _title,
          style: AppFonts.baloo(size: 30, color: Colors.white).copyWith(
            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
        ),
      ),
    );
  }

  List<Widget> _correctBody(double t) {
    var delay = 0.58;
    Widget nextChip(String text, {bool emphasize = false, bool muted = false}) {
      final w = _chip(text, t, delay, emphasize: emphasize, muted: muted);
      delay += 0.05;
      return w;
    }

    return [
      if (widget.doubleDownChoice == 'risky') ...[
        nextChip('🔥 DOUBLE DOWN HIT!', emphasize: true),
        const SizedBox(height: 6),
      ],
      Opacity(
        opacity: _p(t, 0.56, 0.72, Curves.easeOut),
        child: AnimatedCounter(
          value: widget.answerScore,
          prefix: '+',
          style: AppFonts.inter(size: 32, weight: FontWeight.w800, color: AppColors.energyGold).copyWith(
            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
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
        _chip('💔 DOUBLE DOWN FAILED', t, 0.3, muted: true),
        const SizedBox(height: 8),
      ],
      Opacity(
        opacity: _p(t, 0.35, 0.55, Curves.easeOut),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppFonts.inter(size: 14, weight: FontWeight.w600, color: Colors.white70),
            children: [
              const TextSpan(text: 'The answer was '),
              TextSpan(
                text: widget.correctAnswerText,
                style: AppFonts.inter(size: 14, weight: FontWeight.w800, color: Colors.white),
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
          0.45,
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
    final popP = _p(t, delay, delay + 0.3, Curves.easeOutBack);
    final fadeP = _p(t, delay, delay + 0.22, Curves.easeOut);
    return Opacity(
      opacity: fadeP,
      child: Transform.scale(
        scale: _lerp(0.4, 1.0, popP),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: emphasize
                ? AppColors.energyGold.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: AppFonts.inter(
              size: emphasize ? 13 : 12,
              weight: FontWeight.w800,
              color: muted
                  ? Colors.white60
                  : (emphasize ? AppColors.energyGold : Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfetti(_Confetti c, double t) {
    final p = _p(t, c.delay, (c.delay + 0.55).clamp(0.0, 1.0), Curves.easeOut);
    final dx = math.cos(c.angle) * c.distance * p;
    final dy = math.sin(c.angle) * c.distance * p - (18 * p * (1 - p) * 4);
    final opacity = 1.0 - _p(t, c.delay + 0.3, 1.0, Curves.easeIn);
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
}
