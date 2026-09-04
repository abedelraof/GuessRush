import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/decorative_card_circles.dart';
import '../widgets/pressable_scale.dart';

/// Shown after tapping "Play With Friends" on Home — the mode-select screen
/// for 1v1: a random opponent, or a friend via invite code. Mirrors Pick
/// Your Rush's card visual language (lib/screens/pick_rush_screen.dart).
class PlayWithFriendsScreen extends StatelessWidget {
  final QuizController controller;

  const PlayWithFriendsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: controller.backFromPlayWithFriends,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '←',
                        style: AppFonts.inter(
                          size: 16,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Play With Friends',
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.baloo(size: 24),
                  ),
                ),
              ],
            ),
            if (controller.matchError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.matchError!,
                  style: AppFonts.inter(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.feedbackWrongTitle,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: PressableScale(
                      onTap: () => controller.startRandomQueue(),
                      child: const _ModeCard(
                        seed: 0,
                        assetPath: 'assets/images/play_online.png',
                        title: 'Play Online 1v1',
                        tagline: 'Get matched with a random opponent',
                        description: 'Same questions, same clock — see who scores higher.',
                        gradient: AppColors.playNowButton,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: PressableScale(
                      onTap: controller.goToFriendMatch,
                      child: const _ModeCard(
                        seed: 1,
                        assetPath: 'assets/images/play_with_friends.png',
                        title: 'Play with a Friend',
                        tagline: 'Invite someone with a code',
                        description:
                            'Share a code, or enter one a friend sent you.',
                        gradient: AppColors.questionLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final int seed;
  final String assetPath;
  final String title;
  final String tagline;
  final String description;
  final Gradient gradient;

  const _ModeCard({
    required this.seed,
    required this.assetPath,
    required this.title,
    required this.tagline,
    required this.description,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.9,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            DecorativeCardCircles(seed: seed),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(assetPath, height: 104),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: AppFonts.baloo(size: 22, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  tagline.toUpperCase(),
                  style: AppFonts.inter(
                    size: 11,
                    weight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppFonts.inter(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
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
