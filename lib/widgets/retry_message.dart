import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// A centered icon/title/subtitle message, with an optional "RETRY" (or any
/// other label) action — for a screen's empty state or a failed initial
/// load. Shared across every screen that needs one instead of each
/// reimplementing the same look.
class RetryMessage extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RetryMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.baloo(size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                size: 13,
                weight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldTimer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      actionLabel!,
                      style: AppFonts.inter(
                        size: 13,
                        weight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
