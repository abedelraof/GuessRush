import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Shown once per Rush, the first time streak crosses the threshold, before
/// the very next question starts (no timer/narration runs until a choice is
/// made) — the "should I use this now or save it" decision made concrete:
/// bank a normal score, or risk it for double.
class DoubleDownOverlay extends StatelessWidget {
  final int streak;
  final bool isChoosing;
  final void Function(String choice) onChoose;

  const DoubleDownOverlay({super.key, required this.streak, required this.isChoosing, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC141423),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              const BoxShadow(color: Color(0x4D000000), blurRadius: 40, offset: Offset(0, 20)),
              BoxShadow(color: AppColors.streakGradA.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text('$streak STREAK!', style: AppFonts.baloo(size: 22, color: AppColors.darkText)),
              const SizedBox(height: 6),
              Text(
                'DOUBLE DOWN on the next question?',
                textAlign: TextAlign.center,
                style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.mutedText),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _Choice(
                      label: 'SAFE',
                      sublabel: 'Normal score',
                      color: AppColors.linkPurple,
                      onTap: () => onChoose('safe'),
                      disabled: isChoosing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Choice(
                      label: 'RISKY',
                      sublabel: '2x or nothing',
                      color: AppColors.streakGradA,
                      onTap: () => onChoose('risky'),
                      disabled: isChoosing,
                    ),
                  ),
                ],
              ),
              if (isChoosing) ...[
                const SizedBox(height: 16),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  final bool disabled;

  const _Choice({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppFonts.baloo(size: 16, color: color)),
              const SizedBox(height: 2),
              Text(sublabel, style: AppFonts.inter(size: 10, weight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
