import 'package:flutter/material.dart';

import '../models/leaderboard.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/animated_counter.dart';
import '../widgets/stat_tile.dart';

class ResultsScreen extends StatelessWidget {
  final QuizController controller;

  const ResultsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      if (controller.isDailyRush && controller.dailyRank != null) '📊 DAILY RANK #${controller.dailyRank}',
      if (controller.isDailyRush && controller.isNewDailyBest) '⚡ NEW DAILY BEST',
      if (controller.isNewPersonalBest) '🏆 NEW PERSONAL BEST',
      if (controller.isNewBestStreak) '🔥 NEW BEST STREAK',
      if (controller.isPerfectRush) '💯 PERFECT RUSH',
      if (controller.leveledUp) '⭐ LEVEL UP! → Lv ${controller.profile?.level ?? ''}',
      for (final a in controller.newlyUnlockedAchievements) '🏅 ${a.name}',
      if (controller.dailyStreakJustExtended) '🔥 ${controller.dailyStreakCurrent} DAY STREAK',
      for (final m in controller.newlyCompletedMissions) '🎯 ${m.name}',
      if (controller.lastXpMultiplierApplied > 1) '✨ ×${controller.lastXpMultiplierApplied.toStringAsFixed(0)} XP EVENT',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          children: [
            Text(
              controller.isDailyRush ? 'DAILY RUSH COMPLETE! ⚡' : 'GAME COMPLETE! 🎉',
              style: AppFonts.baloo(size: 26),
            ),
            const SizedBox(height: 14),
            AnimatedCounter(
              value: controller.score,
              duration: const Duration(milliseconds: 900),
              style: AppFonts.baloo(size: 56, color: AppColors.finalScoreGold),
            ),
            if (controller.xpAwarded > 0) ...[
              const SizedBox(height: 4),
              Text(
                '+${controller.xpAwarded} XP',
                style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.finalScoreGold),
              ),
            ],
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: badges.map((a) => _AchievementBadge(text: a)).toList(),
              ),
            ] else if (controller.isDailyRush && controller.dailyPreviousBestScore != null) ...[
              const SizedBox(height: 6),
              Text(
                'Your best Daily Rush: ${controller.dailyPreviousBestScore}',
                style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)),
              ),
            ] else if (controller.personalBestScore != null) ...[
              const SizedBox(height: 6),
              Text(
                'Personal best: ${controller.personalBestScore}',
                style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)),
              ),
            ],
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.6,
                children: [
                  StatTile(value: '${controller.correctCount}', label: 'Correct', color: AppColors.correctStat),
                  StatTile(value: '${controller.wrongCount}', label: 'Wrong', color: AppColors.wrongStat),
                  StatTile(
                    value: '${controller.accuracyPct.round()}%',
                    label: 'Accuracy',
                    color: AppColors.linkPurple,
                  ),
                  StatTile(
                    value: '🔥${controller.bestStreak}',
                    label: 'Best Streak',
                    color: AppColors.bestStreakStat,
                  ),
                  StatTile(
                    value: '${controller.avgResponseTime.toStringAsFixed(1)}s',
                    label: 'Avg Response Time',
                    color: AppColors.darkText,
                  ),
                  StatTile(
                    value: '${controller.momentum.round()}%',
                    label: 'Final Momentum',
                    color: AppColors.streakGradA,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    // Daily Rush only ever gets the one official attempt — replaying isn't
                    // offered; the natural next step is seeing where that score landed.
                    onTap: controller.isDailyRush
                        ? () => controller.goToLeaderboard(period: LeaderboardPeriod.daily)
                        : controller.playAgain,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.goldTimer,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(color: AppColors.playAgainShadow, offset: Offset(0, 6)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        controller.isDailyRush ? 'VIEW LEADERBOARD' : 'PLAY AGAIN',
                        style: AppFonts.baloo(size: 17, color: AppColors.darkText),
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
                        style: AppFonts.inter(size: 14, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.streakBadge,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: AppColors.streakGradA.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 0.5),
          ],
        ),
        child: Text(text, style: AppFonts.inter(size: 12, weight: FontWeight.w800)),
      ),
    );
  }
}
