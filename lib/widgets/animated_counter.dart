import 'package:flutter/material.dart';

/// Tweens its displayed integer from whatever it last showed to [value]
/// whenever [value] changes, instead of snapping straight to the new number.
/// Used anywhere a score needs to feel like it's landing rather than just
/// appearing (HUD chip, feedback overlay, results screen).
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle style;
  final String prefix;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) => Text('$prefix$animatedValue', style: style),
    );
  }
}
