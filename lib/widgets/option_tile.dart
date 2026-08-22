import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class OptionTile extends StatefulWidget {
  final int index;
  final String text;
  final Color imgBg;
  final VoidCallback onTap;
  final bool answered;
  final bool isCorrectOption;
  final bool isSelected;
  final bool shake;

  const OptionTile({
    super.key,
    required this.index,
    required this.text,
    required this.imgBg,
    required this.onTap,
    required this.answered,
    required this.isCorrectOption,
    required this.isSelected,
    required this.shake,
  });

  @override
  State<OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<OptionTile> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  static const _letters = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.shake) _shakeController.forward();
  }

  @override
  void didUpdateWidget(covariant OptionTile old) {
    super.didUpdateWidget(old);
    if (widget.shake && !old.shake) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.cardWhite;
    Color border = Colors.transparent;
    Color color = AppColors.darkText;
    String icon = '';

    if (widget.answered) {
      if (widget.isCorrectOption) {
        bg = AppColors.correctBg;
        border = AppColors.correctBorder;
        icon = '✓';
      } else if (widget.isSelected) {
        bg = AppColors.wrongBg;
        border = AppColors.wrongBorder;
        icon = '✗';
      } else {
        bg = AppColors.disabledBg;
        color = AppColors.disabledText;
      }
    }

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final t = _shakeController.value;
        final dx = _shakeOffset(t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.answered ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border, width: 2),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.imgBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: const BoxDecoration(
                          color: Color(0xE6FFFFFF),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _letters[widget.index],
                          style: AppFonts.inter(
                            size: 9,
                            weight: FontWeight.w800,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.text,
                    style: AppFonts.inter(size: 15, weight: FontWeight.w700, color: color),
                  ),
                ),
                if (icon.isNotEmpty)
                  Text(icon, style: AppFonts.inter(size: 16, weight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _shakeOffset(double t) {
    if (t <= 0 || t >= 1) return 0;
    // Mirrors the source design's unused `shakeX` keyframe.
    const stops = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];
    const vals = [-2.0, 4.0, -8.0, 8.0, -8.0, 8.0, -8.0, 4.0, -2.0];
    for (int i = 0; i < stops.length - 1; i++) {
      if (t <= stops[i + 1]) {
        final localT = (t - stops[i]) / (stops[i + 1] - stops[i]);
        return vals[i] + (vals[i + 1] - vals[i]) * localT;
      }
    }
    return 0;
  }
}
