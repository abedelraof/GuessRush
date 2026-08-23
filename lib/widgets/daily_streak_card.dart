import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// The DAILY play streak (Phase 6) — distinct from the in-game answer streak
/// shown by StreakBadge/timer-ring UI elsewhere. Deliberately styled
/// differently from both that badge and the Daily Rush tile (glass card, not
/// the shared streakBadge gradient) so the two "streak" concepts never read
/// as the same thing at a glance.
class DailyStreakCard extends StatelessWidget {
  final int current;
  final int longest;
  final bool dailyRushCompletedToday;

  const DailyStreakCard({
    super.key,
    required this.current,
    required this.longest,
    required this.dailyRushCompletedToday,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = current == 0
        ? 'Complete today\'s Daily Rush to start a streak'
        : dailyRushCompletedToday
            ? 'Come back tomorrow to keep it going'
            : 'Play today\'s Daily Rush to keep it going';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text('🔥', style: TextStyle(fontSize: 28, shadows: [Shadow(color: AppColors.streakGradA.withValues(alpha: 0.6), blurRadius: 12)])),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$current DAY STREAK', style: AppFonts.inter(size: 14, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          if (longest > current) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$longest', style: AppFonts.inter(size: 15, weight: FontWeight.w800)),
                Text('BEST', style: AppFonts.inter(size: 9, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
