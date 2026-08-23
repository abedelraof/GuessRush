import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/stat_tile.dart';

class ProfileScreen extends StatelessWidget {
  final QuizController controller;

  const ProfileScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: controller.goHome,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('PROFILE', style: AppFonts.baloo(size: 22)),
              ],
            ),
          ),
          Expanded(
            child: profile == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LevelCard(profile: profile),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Statistics',
                          child: GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 2.6,
                            children: [
                              StatTile(value: '${profile.stats.rushesCompleted}', label: 'Rushes Completed', color: AppColors.linkPurple),
                              StatTile(value: '${profile.stats.questionsAnswered}', label: 'Questions Answered', color: AppColors.darkText),
                              StatTile(value: '${profile.stats.accuracyPct}%', label: 'Lifetime Accuracy', color: AppColors.correctStat),
                              StatTile(
                                value: '${(profile.stats.avgResponseTimeMs / 1000).toStringAsFixed(1)}s',
                                label: 'Avg Response Time',
                                color: AppColors.darkText,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Personal Records',
                          child: GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 2.6,
                            children: [
                              StatTile(value: '${profile.records.bestRushScore}', label: 'Best Rush Score', color: AppColors.finalScoreGold),
                              StatTile(value: '🔥${profile.records.bestStreak}', label: 'Best Streak', color: AppColors.bestStreakStat),
                              StatTile(value: '${profile.records.bestAccuracyPct}%', label: 'Best Accuracy', color: AppColors.correctStat),
                              StatTile(
                                value: profile.records.fastestAvgResponseTimeMs != null
                                    ? '${(profile.records.fastestAvgResponseTimeMs! / 1000).toStringAsFixed(1)}s'
                                    : '—',
                                label: 'Fastest Avg Rush',
                                color: AppColors.darkText,
                              ),
                              StatTile(value: '${profile.records.perfectRushCount}', label: 'Perfect Rushes', color: AppColors.wrongStat),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title:
                              'Achievements (${profile.achievements.where((a) => a.unlocked).length}/${profile.achievements.length})',
                          child: Column(
                            children: profile.achievements.map((a) => _AchievementRow(achievement: a)).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final PlayerProfile profile;

  const _LevelCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(profile.displayName, style: AppFonts.baloo(size: 18, color: AppColors.darkText)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(gradient: AppColors.playNowButton, borderRadius: BorderRadius.circular(999)),
                child: Text('LEVEL ${profile.level}', style: AppFonts.inter(size: 12, weight: FontWeight.w800, color: AppColors.darkText)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 10,
              color: AppColors.disabledBg,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: profile.levelProgress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, factor, child) => FractionallySizedBox(widthFactor: factor, child: child),
                child: Container(color: AppColors.goldTimer),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${profile.xpIntoLevel} / ${profile.xpForNextLevel} XP to Level ${profile.level + 1} · ${profile.lifetimeXp} lifetime XP',
            style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.inter(size: 14, weight: FontWeight.w800, color: AppColors.darkText)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  final Achievement achievement;

  const _AchievementRow({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Opacity(
        opacity: achievement.unlocked ? 1 : 0.45,
        child: Row(
          children: [
            Text(achievement.unlocked ? '🏆' : '🔒', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(achievement.name, style: AppFonts.inter(size: 13, weight: FontWeight.w800, color: AppColors.darkText)),
                  Text(achievement.description, style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: AppColors.mutedText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
