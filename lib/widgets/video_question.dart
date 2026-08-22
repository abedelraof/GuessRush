import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class VideoQuestion extends StatefulWidget {
  final String duration;
  final bool isPlaying;
  final VoidCallback onTogglePlay;

  const VideoQuestion({
    super.key,
    required this.duration,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  @override
  State<VideoQuestion> createState() => _VideoQuestionState();
}

class _VideoQuestionState extends State<VideoQuestion> with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isPlaying) _scanController.repeat();
  }

  @override
  void didUpdateWidget(covariant VideoQuestion old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      widget.isPlaying ? _scanController.repeat() : _scanController.stop();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          gradient: AppColors.videoPlaceholder,
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            if (widget.isPlaying)
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final x = -w * 0.4 + (_scanController.value * w * 1.4);
                      return Positioned(
                        top: 0,
                        bottom: 0,
                        left: x,
                        width: w * 0.4,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            Center(
              child: GestureDetector(
                onTap: widget.onTogglePlay,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xE6FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.isPlaying ? '❙❙' : '▶',
                    style: const TextStyle(color: AppColors.videoGradB, fontSize: 20),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 4,
                        color: Colors.white.withValues(alpha: 0.3),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.35,
                          child: Container(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.duration, style: AppFonts.inter(size: 11, weight: FontWeight.w600)),
                        Text('⟲ ⛶', style: AppFonts.inter(size: 11, weight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
