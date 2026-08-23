import 'package:flutter/material.dart';

import '../models/leaderboard.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class LeaderboardScreen extends StatelessWidget {
  final QuizController controller;

  const LeaderboardScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
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
                Text('LEADERBOARD', style: AppFonts.baloo(size: 20)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(child: _PeriodTab(label: 'GLOBAL', period: LeaderboardPeriod.global, controller: controller)),
                const SizedBox(width: 10),
                Expanded(child: _PeriodTab(label: 'DAILY', period: LeaderboardPeriod.daily, controller: controller)),
              ],
            ),
          ),
          Expanded(child: _Body(controller: controller)),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final LeaderboardPeriod period;
  final QuizController controller;

  const _PeriodTab({required this.label, required this.period, required this.controller});

  @override
  Widget build(BuildContext context) {
    final active = controller.leaderboardPeriod == period;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: active ? null : () => controller.loadLeaderboard(period: period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppFonts.inter(
              size: 13,
              weight: FontWeight.w800,
              color: active ? AppColors.linkPurple : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final QuizController controller;

  const _Body({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingLeaderboard && controller.leaderboardPage == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (controller.leaderboardError != null && controller.leaderboardPage == null) {
      return _MessageState(
        icon: '🔌',
        title: 'Couldn\'t load the leaderboard',
        subtitle: controller.leaderboardError!,
        actionLabel: 'RETRY',
        onAction: () => controller.loadLeaderboard(),
      );
    }

    final page = controller.leaderboardPage;
    if (page == null) return const SizedBox.shrink();

    if (page.entries.isEmpty) {
      return _MessageState(
        icon: '🏆',
        title: page.period == LeaderboardPeriod.daily ? 'No Daily Rush scores yet' : 'No scores yet',
        subtitle: 'Be the first to set the pace!',
      );
    }

    final myPlayerId = controller.player?.id;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            itemCount: page.entries.length,
            itemBuilder: (context, i) {
              final entry = page.entries[i];
              return _LeaderboardRow(entry: entry, isMe: entry.playerId == myPlayerId);
            },
          ),
        ),
        if (page.me != null) _MyPositionCard(entry: page.me!, inVisiblePage: page.entries.any((e) => e.playerId == page.me!.playerId)),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;

  const _LeaderboardRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final medal = entry.rank == 1 ? '🥇' : entry.rank == 2 ? '🥈' : entry.rank == 3 ? '🥉' : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.goldTimer.withValues(alpha: 0.25) : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? Border.all(color: AppColors.goldTimer, width: 2) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 20))
                : Text('${entry.rank}', style: AppFonts.inter(size: 14, weight: FontWeight.w800, color: AppColors.mutedText)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? '${entry.displayName} (you)' : entry.displayName,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.darkText),
            ),
          ),
          Text('🔥${entry.bestStreak}', style: AppFonts.inter(size: 12, weight: FontWeight.w600, color: AppColors.mutedText)),
          const SizedBox(width: 10),
          Text('${entry.score}', style: AppFonts.inter(size: 15, weight: FontWeight.w800, color: AppColors.darkText)),
        ],
      ),
    );
  }
}

class _MyPositionCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool inVisiblePage;

  const _MyPositionCard({required this.entry, required this.inVisiblePage});

  @override
  Widget build(BuildContext context) {
    // Already visible in the list above with its own highlight — no need to repeat it.
    if (inVisiblePage) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text('YOUR RANK', style: AppFonts.inter(size: 11, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(width: 10),
          Text('#${entry.rank}', style: AppFonts.baloo(size: 18)),
          const Spacer(),
          Text('${entry.score}', style: AppFonts.inter(size: 15, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: AppFonts.baloo(size: 18)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.goldTimer, borderRadius: BorderRadius.circular(14)),
                    child: Text(actionLabel!, style: AppFonts.inter(size: 13, weight: FontWeight.w800, color: AppColors.darkText)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
