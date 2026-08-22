import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class ProgressiveQuestion extends StatelessWidget {
  final List<String> clues;
  final int clueCount;
  final bool hasMore;
  final VoidCallback onRevealClue;

  const ProgressiveQuestion({
    super.key,
    required this.clues,
    required this.clueCount,
    required this.hasMore,
    required this.onRevealClue,
  });

  @override
  Widget build(BuildContext context) {
    final revealed = clues.take(clueCount).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < revealed.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: const BoxDecoration(
                    gradient: AppColors.audioPlayButton,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: AppFonts.inter(size: 11, weight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    revealed[i],
                    style: AppFonts.inter(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.darkText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasMore) ...[
            const SizedBox(height: 4),
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onRevealClue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.revealBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'REVEAL NEXT CLUE',
                      style: AppFonts.inter(
                        size: 12,
                        weight: FontWeight.w800,
                        color: AppColors.revealText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
