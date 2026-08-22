import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const StatTile({super.key, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppFonts.inter(size: 22, weight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppFonts.inter(size: 12, weight: FontWeight.w600, color: AppColors.statLabel)),
      ],
    );
  }
}
