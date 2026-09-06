import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class ShopScreen extends StatelessWidget {
  final QuizController controller;

  const ShopScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final catalog = controller.shopCatalog;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: controller.goHome,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('SHOP', style: AppFonts.baloo(size: 22)),
                  ],
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      controller.errorMessage!,
                      style: AppFonts.inter(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.feedbackWrongTitle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: (profile == null || catalog == null)
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: _EnergyRefillCard(
                      controller: controller,
                      energy: profile.energy,
                      energyMax: profile.energyMax,
                      coins: profile.coins,
                      cost: catalog.energyRefillCostCoins,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EnergyRefillCard extends StatelessWidget {
  final QuizController controller;
  final int energy;
  final int energyMax;
  final int coins;
  final int cost;

  const _EnergyRefillCard({
    required this.controller,
    required this.energy,
    required this.energyMax,
    required this.coins,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = energy >= energyMax;
    final canAfford = coins >= cost;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energy Refill',
                      style: AppFonts.inter(
                        size: 15,
                        weight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                    Text(
                      'Instantly restore 1 energy.',
                      style: AppFonts.inter(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$energy / $energyMax energy',
                style: AppFonts.inter(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.mutedText,
                ),
              ),
              Text(
                '🪙 $coins',
                style: AppFonts.inter(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.coinGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BuyButton(
            loading: controller.isBuyingEnergy,
            label: isFull
                ? 'ENERGY FULL'
                : (!canAfford ? 'NOT ENOUGH COINS' : 'BUY FOR 🪙 $cost'),
            enabled: !isFull && canAfford,
            onTap: controller.buyEnergyRefill,
          ),
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  const _BuyButton({
    required this.loading,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: (enabled && !loading) ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.playNowButton : null,
            color: enabled ? null : AppColors.disabledBg,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.darkText,
                  ),
                )
              : Text(
                  label,
                  style: AppFonts.baloo(
                    size: 15,
                    color: enabled
                        ? AppColors.darkText
                        : AppColors.disabledText,
                  ),
                ),
        ),
      ),
    );
  }
}
