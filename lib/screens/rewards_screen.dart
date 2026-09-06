import 'package:flutter/material.dart';

import '../models/reward.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class RewardsScreen extends StatelessWidget {
  final QuizController controller;

  const RewardsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final rewards = controller.rewards;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    Text('REWARDS', style: AppFonts.baloo(size: 22)),
                  ],
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      controller.errorMessage!,
                      style: AppFonts.inter(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.feedbackWrongTitle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: rewards == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RewardSection(
                          title: 'Level Up',
                          rewards: rewards
                              .where((r) => r.kind == RewardKind.level)
                              .toList(),
                          controller: controller,
                        ),
                        const SizedBox(height: 16),
                        _RewardSection(
                          title: 'Daily Streak',
                          rewards: rewards
                              .where((r) => r.kind == RewardKind.streak)
                              .toList(),
                          controller: controller,
                        ),
                        const SizedBox(height: 16),
                        _RewardSection(
                          title: 'Achievements',
                          rewards: rewards
                              .where((r) => r.kind == RewardKind.achievement)
                              .toList(),
                          controller: controller,
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

class _RewardSection extends StatelessWidget {
  final String title;
  final List<Reward> rewards;
  final QuizController controller;

  const _RewardSection({
    required this.title,
    required this.rewards,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            title,
            style: AppFonts.inter(
              size: 14,
              weight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 14),
          if (rewards.isEmpty)
            Text(
              'Nothing yet — keep playing to unlock rewards here.',
              style: AppFonts.inter(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.mutedText,
              ),
            )
          else
            Column(
              children: rewards
                  .map((r) => _RewardRow(reward: r, controller: controller))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final Reward reward;
  final QuizController controller;

  const _RewardRow({required this.reward, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isClaiming = controller.claimingRewardKey == reward.key;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Opacity(
        opacity: reward.unlocked ? 1 : 0.45,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              reward.claimed ? '✅' : (reward.unlocked ? '🎁' : '🔒'),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    style: AppFonts.inter(
                      size: 13,
                      weight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                  Text(
                    reward.description,
                    style: AppFonts.inter(
                      size: 11,
                      weight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🪙 ${reward.coins}',
                    style: AppFonts.inter(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.coinGold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (reward.claimed)
              Text(
                'CLAIMED',
                style: AppFonts.inter(
                  size: 11,
                  weight: FontWeight.w800,
                  color: AppColors.mutedText,
                ),
              )
            else if (reward.unlocked)
              _ClaimButton(
                loading: isClaiming,
                onTap: () => controller.claimReward(reward.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _ClaimButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.playNowButton,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.darkText,
                  ),
                )
              : Text(
                  'CLAIM',
                  style: AppFonts.inter(
                    size: 11,
                    weight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
        ),
      ),
    );
  }
}
