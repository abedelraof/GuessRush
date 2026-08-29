import 'package:flutter/material.dart';

import '../models/home_summary.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/daily_streak_card.dart';
import '../widgets/missions_card.dart';

/// Everything that isn't the core "play now" loop — Daily Rush, active
/// events, the daily streak, missions, and the personal-best/leaderboard
/// stat strip. Split out of HomeScreen (which was getting long) and reachable
/// from the bottom nav's EVENTS tab; same dark background as Home so moving
/// between the two doesn't feel like leaving the redesign.
class EventsScreen extends StatelessWidget {
  final QuizController controller;

  const EventsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final home = controller.homeSummary;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
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
                      child: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('EVENTS', style: AppFonts.baloo(size: 20)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  children: [
                    _DailyRushCard(controller: controller),
                    const SizedBox(height: 12),
                    if (home != null && home.activeEvents.isNotEmpty) ...[
                      _EventsBanner(events: home.activeEvents),
                      const SizedBox(height: 12),
                    ],
                    DailyStreakCard(
                      current: home?.dailyStreakCurrent ?? 0,
                      longest: home?.dailyStreakLongest ?? 0,
                      dailyRushCompletedToday:
                          controller.dailyRushStatus?.completed ?? false,
                    ),
                    const SizedBox(height: 12),
                    MissionsCard(missions: home?.missions),
                    const SizedBox(height: 12),
                    _StatsStrip(
                      personalBest: controller.profile?.records.bestRushScore,
                      leaderboardPosition: home?.leaderboardPosition,
                      onTapLeaderboard: controller.goToLeaderboard,
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
                Text(
                  event.name,
                  style: AppFonts.inter(
                    size: 13,
                    weight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                Text(
                  event.description,
                  style: AppFonts.inter(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.darkText.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Personal best score and current global leaderboard position.
class _StatsStrip extends StatelessWidget {
  final int? personalBest;
  final LeaderboardPosition? leaderboardPosition;
  final VoidCallback onTapLeaderboard;

  const _StatsStrip({
    required this.personalBest,
    required this.leaderboardPosition,
    required this.onTapLeaderboard,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppFonts.inter(
              size: 15,
              weight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          Text(
            label,
            style: AppFonts.inter(
              size: 9,
              weight: FontWeight.w700,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// The real server-reported Daily Rush state — availability, completion, time
/// until the next UTC rollover, personal best, and today's rank once played.
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
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        alignment: Alignment.center,
        child: Text(
          'Loading Daily Rush…',
          style: AppFonts.inter(
            size: 13,
            weight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
          ),
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
        onTap: status.available
            ? controller.startDailyRush
            : controller.goToLeaderboard,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.streakBadge,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
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
                      style: AppFonts.inter(
                        size: 11,
                        weight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (status.bestScore != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${status.bestScore}',
                      style: AppFonts.inter(size: 15, weight: FontWeight.w800),
                    ),
                    Text(
                      'BEST',
                      style: AppFonts.inter(
                        size: 9,
                        weight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                )
              else if (status.available)
                Text(
                  'PLAY',
                  style: AppFonts.inter(size: 13, weight: FontWeight.w800),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
