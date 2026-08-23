import 'package:flutter/material.dart';

import '../models/home_summary.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/daily_streak_card.dart';
import '../widgets/missions_card.dart';
import '../widgets/streak_badge.dart';

class HomeScreen extends StatelessWidget {
  final QuizController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final name = controller.player?.displayName ?? 'Player';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final level = controller.profile?.level;
    // Lifetime best streak once the profile has loaded; falls back to the
    // last-known Rush's streak so the badge doesn't flash to 0 in the meantime.
    final bestStreak = controller.profile?.records.bestStreak ?? controller.bestStreak;
    final home = controller.homeSummary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: controller.goToProfile,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: AppFonts.baloo(size: 18, color: AppColors.linkPurple),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(name, style: AppFonts.inter(size: 14, weight: FontWeight.w700)),
                      if (level != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Lv $level', style: AppFonts.inter(size: 11, weight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    StreakBadge(streak: bestStreak),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: controller.logout,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.logout, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'GUESS IT!',
                      textAlign: TextAlign.center,
                      style: AppFonts.baloo(size: 44, height: 1).copyWith(
                        shadows: const [Shadow(color: Color(0x1F000000), offset: Offset(0, 4))],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Can you figure it out?',
                      style: AppFonts.inter(
                        size: 15,
                        weight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _PlayNowButton(onTap: controller.playNow),
                    const SizedBox(height: 12),
                    _DailyRushCard(controller: controller),
                    const SizedBox(height: 12),
                    if (home != null && home.activeEvents.isNotEmpty) ...[
                      _EventsBanner(events: home.activeEvents),
                      const SizedBox(height: 12),
                    ],
                    DailyStreakCard(
                      current: home?.dailyStreakCurrent ?? 0,
                      longest: home?.dailyStreakLongest ?? 0,
                      dailyRushCompletedToday: controller.dailyRushStatus?.completed ?? false,
                    ),
                    const SizedBox(height: 12),
                    MissionsCard(missions: home?.missions),
                    const SizedBox(height: 12),
                    _StatsStrip(
                      personalBest: controller.profile?.records.bestRushScore,
                      leaderboardPosition: home?.leaderboardPosition,
                      onTapLeaderboard: controller.goToLeaderboard,
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.4,
                      children: [
                        _QuickTile(label: '🏆 Leaderboard', onTap: controller.goToLeaderboard),
                        const _QuickTile(label: '📚 Categories'),
                        const _QuickTile(label: '❔ How to Play'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayNowButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayNowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: AppColors.playNowButton,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: AppColors.playNowShadow, offset: Offset(0, 8)),
                BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 16)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'PLAY NOW',
              style: AppFonts.baloo(size: 22, color: AppColors.darkText),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickTile({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.inter(size: 12, weight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// A currently-active temporary event (Phase 6), e.g. Double XP — purely
/// informational; the actual effect (an XP multiplier) is applied
/// server-side, this just tells the player it's happening right now.
class _EventsBanner extends StatelessWidget {
  final List<GameEvent> events;

  const _EventsBanner({required this.events});

  @override
  Widget build(BuildContext context) {
    final event = events.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.playNowButton,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name, style: AppFonts.inter(size: 13, weight: FontWeight.w800, color: AppColors.darkText)),
                Text(
                  event.description,
                  style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: AppColors.darkText.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Personal best score and current global leaderboard position — the two
/// pieces of "why should I play now" the Home screen didn't already surface
/// elsewhere (level is in the header, Daily Rush/streak/missions have their
/// own cards).
class _StatsStrip extends StatelessWidget {
  final int? personalBest;
  final LeaderboardPosition? leaderboardPosition;
  final VoidCallback onTapLeaderboard;

  const _StatsStrip({required this.personalBest, required this.leaderboardPosition, required this.onTapLeaderboard});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'PERSONAL BEST',
            value: personalBest != null ? '$personalBest' : '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onTapLeaderboard,
            child: _StatChip(
              label: 'LEADERBOARD',
              value: leaderboardPosition != null
                  ? '#${leaderboardPosition!.rank} / ${leaderboardPosition!.total}'
                  : 'Unranked',
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppFonts.inter(size: 15, weight: FontWeight.w800)),
          Text(label, style: AppFonts.inter(size: 9, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}

/// Replaces the old static "⚡ Daily Challenge" placeholder tile with the real
/// server-reported state — availability, completion, time until the next UTC
/// rollover, personal best, and today's rank once played. No field here is
/// guessed client-side.
class _DailyRushCard extends StatelessWidget {
  final QuizController controller;

  const _DailyRushCard({required this.controller});

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final status = controller.dailyRushStatus;

    if (status == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          'Loading Daily Rush…',
          style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85)),
        ),
      );
    }

    final subtitle = status.completed
        ? 'Score ${status.todayScore}${status.todayRank != null ? " · Rank #${status.todayRank}" : ''}'
        : 'Resets in ${_formatDuration(status.secondsUntilReset)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: status.available ? controller.startDailyRush : controller.goToLeaderboard,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.streakBadge,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.completed ? 'DAILY RUSH — DONE' : 'DAILY RUSH',
                      style: AppFonts.inter(size: 13, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              if (status.bestScore != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${status.bestScore}', style: AppFonts.inter(size: 15, weight: FontWeight.w800)),
                    Text('BEST', style: AppFonts.inter(size: 9, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75))),
                  ],
                )
              else if (status.available)
                Text('PLAY', style: AppFonts.inter(size: 13, weight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
