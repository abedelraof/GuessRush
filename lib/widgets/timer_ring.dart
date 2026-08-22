import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class TimerRing extends StatelessWidget {
  final int timeLeft;
  final int totalSeconds;

  const TimerRing({super.key, required this.timeLeft, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final urgent = timeLeft <= 5;
    final pct = totalSeconds > 0 ? (timeLeft.clamp(0, totalSeconds)) / totalSeconds : 0.0;
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(50, 50),
            painter: _RingPainter(
              progress: pct,
              color: urgent ? AppColors.timerUrgent : AppColors.timerDefault,
            ),
          ),
          Text('$timeLeft', style: AppFonts.inter(size: 15, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2.5;
    final bgPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
