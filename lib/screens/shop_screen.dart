import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/text_styles.dart';

/// Coins are earned (per correct answer) but have nothing to spend on yet —
/// there was a "buy an energy refill" item, but it went away along with
/// energy itself (see quiz_controller.dart). This is an honest placeholder
/// rather than a dead purchase flow; a real catalog is a future feature.
class ShopScreen extends StatelessWidget {
  final QuizController controller;

  const ShopScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final coins = controller.profile?.coins;
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
                    child: const Icon(
                      Icons.arrow_back,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('SHOP', style: AppFonts.baloo(size: 22)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🛒', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 12),
                    Text(
                      'Nothing to spend coins on yet',
                      textAlign: TextAlign.center,
                      style: AppFonts.baloo(size: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      coins != null
                          ? 'You have 🪙 $coins — check back soon.'
                          : 'Check back soon.',
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        size: 13,
                        weight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
