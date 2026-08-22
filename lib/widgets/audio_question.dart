import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class AudioQuestion extends StatefulWidget {
  final String duration;
  final bool isPlaying;
  final VoidCallback onTogglePlay;

  const AudioQuestion({
    super.key,
    required this.duration,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  @override
  State<AudioQuestion> createState() => _AudioQuestionState();
}

class _Bar {
  final double heightFactor;
  final Color color;
  final Duration duration;
  final Duration delay;

  const _Bar(this.heightFactor, this.color, this.duration, this.delay);
}

class _AudioQuestionState extends State<AudioQuestion> with TickerProviderStateMixin {
  static const _bars = [
    _Bar(0.6, AppColors.wavePurple, Duration(milliseconds: 600), Duration.zero),
    _Bar(0.9, AppColors.wavePurple, Duration(milliseconds: 600), Duration(milliseconds: 100)),
    _Bar(0.4, AppColors.wavePink, Duration(milliseconds: 500), Duration(milliseconds: 150)),
    _Bar(1.0, AppColors.wavePurple, Duration(milliseconds: 700), Duration(milliseconds: 50)),
    _Bar(0.55, AppColors.wavePink, Duration(milliseconds: 550), Duration(milliseconds: 200)),
    _Bar(0.85, AppColors.wavePurple, Duration(milliseconds: 650), Duration(milliseconds: 120)),
    _Bar(0.35, AppColors.wavePink, Duration(milliseconds: 500), Duration(milliseconds: 250)),
    _Bar(0.75, AppColors.wavePurple, Duration(milliseconds: 600), Duration(milliseconds: 80)),
  ];

  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _bars
        .map((b) => AnimationController(vsync: this, duration: b.duration))
        .toList();
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(_bars[i].delay, () {
        if (mounted && widget.isPlaying) _controllers[i].repeat(reverse: true, min: 0.3, max: 1.0);
      });
    }
    if (widget.isPlaying) _startAll();
  }

  void _startAll() {
    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].repeat(reverse: true, min: 0.3, max: 1.0);
    }
  }

  void _stopAll() {
    for (final c in _controllers) {
      c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AudioQuestion old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      widget.isPlaying ? _startAll() : _stopAll();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _bars.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  AnimatedBuilder(
                    animation: _controllers[i],
                    builder: (context, _) {
                      final scale = widget.isPlaying ? _controllers[i].value : 0.3;
                      return Container(
                        width: 5,
                        height: 48 * _bars[i].heightFactor * scale,
                        decoration: BoxDecoration(
                          color: _bars[i].color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: widget.onTogglePlay,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.audioPlayButton,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.isPlaying ? '❙❙' : '▶',
                style: const TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.duration,
            style: AppFonts.inter(size: 12, weight: FontWeight.w600, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}
