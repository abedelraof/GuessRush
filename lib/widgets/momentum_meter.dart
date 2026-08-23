import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/text_styles.dart';

/// Compact horizontal meter for Rush Momentum (0-100), separate from streak —
/// momentum reflects overall performance across the Rush so far, streak only
/// consecutive correct answers. Color grades smoothly from cool (low) to hot
/// (max) across the tier bounds in [momentumTierFor], with a subtle glow at
/// the max tier so a hot run is felt without a second overlay grabbing focus.
class MomentumMeter extends StatelessWidget {
  final double momentum;

  const MomentumMeter({super.key, required this.momentum});

  static const _low = Color(0xFF7DD3FC); // cool sky blue
  static const _medium = Color(0xFF34D9C4); // teal
  static const _high = Color(0xFFF7A224); // matches AppColors.goldTimer
  static const _max = Color(0xFFFF3D6E); // hot pink-red

  Color _colorFor(double v) {
    if (v >= 75) return Color.lerp(_high, _max, (v - 75) / 25)!;
    if (v >= 50) return Color.lerp(_medium, _high, (v - 50) / 25)!;
    if (v >= 25) return Color.lerp(_low, _medium, (v - 25) / 25)!;
    return Color.lerp(_low.withValues(alpha: 0.55), _low, v / 25)!;
  }

  @override
  Widget build(BuildContext context) {
    final tier = momentumTierFor(momentum);
    final color = _colorFor(momentum.clamp(0, 100));
    final isMax = tier == MomentumTier.max;

    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MOMENTUM',
                style: AppFonts.inter(
                  size: 8,
                  weight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: Colors.white.withValues(alpha: 0.25),
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: momentum.clamp(0, 100) / 100),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                builder: (context, factor, child) => FractionallySizedBox(
                  widthFactor: factor,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      boxShadow: isMax
                          ? [BoxShadow(color: color.withValues(alpha: 0.75), blurRadius: 8, spreadRadius: 0.5)]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
