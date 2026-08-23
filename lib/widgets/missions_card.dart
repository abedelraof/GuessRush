import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Today's mission list (Phase 6) — server-authoritative progress/completion,
/// this just renders whatever GET /api/home last reported.
class MissionsCard extends StatelessWidget {
  final List<Mission>? missions;

  const MissionsCard({super.key, required this.missions});

  @override
  Widget build(BuildContext context) {
    final list = missions;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎯 TODAY\'S MISSIONS', style: AppFonts.inter(size: 12, weight: FontWeight.w800, letterSpacing: 0.4)),
          const SizedBox(height: 10),
          if (list == null)
            Text(
              'Loading missions…',
              style: AppFonts.inter(size: 12, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75)),
            )
          else
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _MissionRow(mission: list[i]),
            ],
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final Mission mission;

  const _MissionRow({required this.mission});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(mission.completed ? '✅' : '🎯', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.name,
                style: AppFonts.inter(
                  size: 12,
                  weight: FontWeight.w700,
                  color: mission.completed ? Colors.white.withValues(alpha: 0.65) : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 6,
                  color: Colors.white.withValues(alpha: 0.2),
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: mission.progressFraction),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (context, factor, child) => FractionallySizedBox(widthFactor: factor, child: child),
                    child: Container(color: mission.completed ? AppColors.correctBorder : AppColors.goldTimer),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '+${mission.rewardXp} XP',
          style: AppFonts.inter(size: 11, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}
