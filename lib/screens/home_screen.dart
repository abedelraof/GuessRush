import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/streak_badge.dart';

class HomeScreen extends StatelessWidget {
  final QuizController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final name = controller.player?.displayName ?? 'Player';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                  ],
                ),
                Row(
                  children: [
                    StreakBadge(streak: controller.bestStreak),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'GUESS IT!',
                    textAlign: TextAlign.center,
                    style: AppFonts.baloo(size: 56, height: 1).copyWith(
                      shadows: const [Shadow(color: Color(0x1F000000), offset: Offset(0, 4))],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Can you figure it out?',
                    style: AppFonts.inter(
                      size: 17,
                      weight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _PlayNowButton(onTap: controller.playNow),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: const [
                    _QuickTile(label: '⚡ Daily Challenge'),
                    _QuickTile(label: '🏆 Leaderboard'),
                    _QuickTile(label: '📚 Categories'),
                    _QuickTile(label: '❔ How to Play'),
                  ],
                ),
              ],
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

  const _QuickTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppFonts.inter(size: 13, weight: FontWeight.w700),
      ),
    );
  }
}
