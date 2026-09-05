import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/leaderboard.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/round_background.dart';
import '../theme/text_styles.dart';
import '../widgets/animated_counter.dart';

class ResultsScreen extends StatelessWidget {
  final QuizController controller;

  const ResultsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      if (controller.isDailyRush && controller.dailyRank != null)
        '📊 DAILY RANK #${controller.dailyRank}',
      if (controller.isDailyRush && controller.isNewDailyBest)
        '⚡ NEW DAILY BEST',
      if (controller.isNewPersonalBest) '🏆 NEW PERSONAL BEST',
      if (controller.isNewBestStreak) '🔥 NEW BEST STREAK',
      if (controller.isPerfectRush) '💯 PERFECT RUSH',
      if (controller.leveledUp)
        '⭐ LEVEL UP! → Lv ${controller.profile?.level ?? ''}',
      for (final a in controller.newlyUnlockedAchievements) '🏅 ${a.name}',
      if (controller.dailyStreakJustExtended)
        '🔥 ${controller.dailyStreakCurrent} DAY STREAK',
      for (final m in controller.newlyCompletedMissions) '🎯 ${m.name}',
      if (controller.lastXpMultiplierApplied > 1)
        '✨ ×${controller.lastXpMultiplierApplied.toStringAsFixed(0)} XP EVENT',
    ];

    // Same round background the last question was showing — this is a
    // bigger, rarer moment than per-question feedback, so it gets its own
    // celebratory gold glow over that background rather than reusing
    // feedback's green/red one.
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                roundBackgroundFor(controller.qIndex, controller.questionTotal),
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(color: Colors.black.withValues(alpha: 0.22)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.6),
              radius: 0.9,
              colors: [Color(0x6BFFC94A), Color(0x00FFC94A)],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              children: [
                // Scrollable: a Rush with several simultaneous badges (first-ever Rush
                // commonly triggers many at once — new personal best, level up, first-rush
                // achievements, ...) plus the match banner can genuinely exceed a compact
                // screen's height. A fixed Column here would just overflow instead.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const _TrophyBadge(),
                        const SizedBox(height: 12),
                        Text(
                          controller.isDailyRush
                              ? 'DAILY RUSH COMPLETE!'
                              : 'GAME COMPLETE!',
                          style: AppFonts.baloo(size: 26).copyWith(
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        if (controller.activeMatchId != null) ...[
                          const SizedBox(height: 14),
                          _MatchResultBanner(controller: controller),
                        ],
                        const SizedBox(height: 14),
                        AnimatedCounter(
                          value: controller.score,
                          duration: const Duration(milliseconds: 900),
                          style: AppFonts.baloo(
                            size: 56,
                            color: AppColors.finalScoreGold,
                          ),
                        ),
                        if (controller.xpAwarded > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+${controller.xpAwarded} XP',
                            style: AppFonts.inter(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppColors.finalScoreGold,
                            ),
                          ),
                        ],
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: badges
                                .map((a) => _AchievementBadge(text: a))
                                .toList(),
                          ),
                        ] else if (controller.isDailyRush &&
                            controller.dailyPreviousBestScore != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Your best Daily Rush: ${controller.dailyPreviousBestScore}',
                            style: AppFonts.inter(
                              size: 13,
                              weight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ] else if (controller.personalBestScore != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Personal best: ${controller.personalBestScore}',
                            style: AppFonts.inter(
                              size: 13,
                              weight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.92,
                          children: [
                            _MiniStat(
                              value: '${controller.correctCount}',
                              label: 'CORRECT',
                            ),
                            _MiniStat(
                              value: '${controller.wrongCount}',
                              label: 'WRONG',
                            ),
                            _MiniStat(
                              value: '${controller.accuracyPct.round()}%',
                              label: 'ACCURACY',
                            ),
                            _MiniStat(
                              value: '🔥${controller.bestStreak}',
                              label: 'BEST STREAK',
                            ),
                            _MiniStat(
                              value:
                                  '${controller.avgResponseTime.toStringAsFixed(1)}s',
                              label: 'AVG TIME',
                            ),
                            _MiniStat(
                              value: '${controller.momentum.round()}%',
                              label: 'MOMENTUM',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        // Daily Rush only ever gets the one official attempt — replaying isn't
                        // offered; the natural next step is seeing where that score landed.
                        // A match has no "replay the same opponent" — Play Again sends you back
                        // to mode-select instead (playAgain() has nothing to replay here: a
                        // match session was never started via selectCategory/startRush).
                        onTap: controller.isDailyRush
                            ? () => controller.goToLeaderboard(
                                period: LeaderboardPeriod.daily,
                              )
                            : controller.activeMatchId != null
                            ? controller.goToPlayWithFriends
                            : controller.playAgain,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.goldTimer,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.playAgainShadow,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            controller.isDailyRush
                                ? 'VIEW LEADERBOARD'
                                : 'PLAY AGAIN',
                            style: AppFonts.baloo(
                              size: 17,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: controller.goHome,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'HOME',
                            style: AppFonts.inter(
                              size: 14,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Head-to-head comparison for a Play With Friends match — shown on the
/// results screen alongside the ordinary solo-Rush stats. `controller.score`
/// is always *this* player's own final score (the underlying session is an
/// ordinary Rush session); `matchResult` only arrives once the opponent has
/// also finished, so this shows a "waiting" state until then.
class _MatchResultBanner extends StatelessWidget {
  final QuizController controller;

  const _MatchResultBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    final result = controller.matchResult;
    final opponentName = controller.opponent?.displayName ?? 'Opponent';

    if (result == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Waiting for $opponentName to finish…',
              style: AppFonts.inter(size: 13, weight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    final isDraw = result.winnerPlayerId == null;
    final youWon = !isDraw && controller.player?.id == result.winnerPlayerId;
    final label = isDraw
        ? "IT'S A DRAW"
        : (youWon ? 'YOU WIN! 🏆' : 'YOU LOSE');
    final color = isDraw
        ? Colors.white
        : (youWon ? AppColors.correctStat : AppColors.wrongStat);

    return Column(
      children: [
        Text(label, style: AppFonts.baloo(size: 20, color: color)),
        if (result.forfeit) ...[
          const SizedBox(height: 2),
          Text(
            '$opponentName disconnected',
            style: AppFonts.inter(
              size: 12,
              weight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'vs $opponentName',
          style: AppFonts.inter(
            size: 13,
            weight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// The hero moment at the top of Results — a 3D coin-style flip-in, same
/// technique as the per-question feedback screen's reveal (Matrix4 rotateY
/// with perspective), just a bigger one-shot occasion since this only shows
/// once per whole Rush rather than once per question.
class _TrophyBadge extends StatelessWidget {
  const _TrophyBadge();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final spinAngle = t.clamp(0.0, 1.4) * 2 * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0022)
            ..rotateY(spinAngle)
            ..scaleByDouble(t, t, t, 1.0),
          child: child,
        );
      },
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text('🏆', style: TextStyle(fontSize: 42)),
      ),
    );
  }
}

/// A single Rush stat as a compact chip directly on the colorful background —
/// replaces the old white-card GridView of StatTiles, which forced a tall
/// fixed aspect ratio per cell (empty space around short value/label text)
/// and assumed a white backdrop these chips no longer sit on.
class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppFonts.baloo(size: 22, color: Colors.white)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.inter(
              size: 9,
              weight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final String text;

  const _AchievementBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.streakBadge,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.streakGradA.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Text(
          text,
          style: AppFonts.inter(size: 12, weight: FontWeight.w800),
        ),
      ),
    );
  }
}
