import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/text_styles.dart';

class CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const CategoryTile({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            color: category.bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x24000000), blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                category.name,
                style: AppFonts.baloo(size: 14, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
