import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class ImageQuestion extends StatelessWidget {
  final String placeholder;

  const ImageQuestion({super.key, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: AppColors.imagePlaceholder,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x2E000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x59000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '[ $placeholder ]',
          style: AppFonts.inter(size: 12, weight: FontWeight.w500, color: Colors.white).copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
