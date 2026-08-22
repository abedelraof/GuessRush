import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/stat_tile.dart';

class ResultsScreen extends StatelessWidget {
  final QuizController controller;

  const ResultsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          children: [
            Text('GAME COMPLETE! 🎉', style: AppFonts.baloo(size: 26)),
            const SizedBox(height: 14),
            Text(
              '${controller.score}',
              style: AppFonts.baloo(size: 56, color: AppColors.finalScoreGold),
            ),
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
                    onTap: controller.playAgain,
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
                      child: Text('PLAY AGAIN', style: AppFonts.baloo(size: 17, color: AppColors.darkText)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text('SHARE RESULT', style: AppFonts.inter(size: 14, weight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: controller.goHome,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: Text(
                        'HOME',
                        style: AppFonts.inter(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.8),
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
    );
  }
}
