import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/category_tile.dart';

class CategoriesScreen extends StatelessWidget {
  final QuizController controller;

  const CategoriesScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: controller.goHome,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('←', style: AppFonts.inter(size: 16, weight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text('Pick a category', style: AppFonts.baloo(size: 24)),
              ],
            ),
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.errorMessage!,
                  style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.feedbackWrongTitle),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Expanded(
              child: Stack(
                children: [
                  GridView.builder(
                    itemCount: controller.categories.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                    ),
                    itemBuilder: (context, i) {
                      final cat = controller.categories[i];
                      return CategoryTile(
                        category: cat,
                        onTap: controller.isCreatingSession ? () {} : () => controller.selectCategory(cat),
                      );
                    },
                  ),
                  if (controller.isCreatingSession)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
