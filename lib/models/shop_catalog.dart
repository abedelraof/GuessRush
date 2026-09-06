/// Static shop pricing — currently just the one purchasable item (an
/// instant energy refill). Kept as its own tiny model (rather than inlining
/// the price into PlayerProfile) so a future second item just adds a field
/// here instead of overloading the player-state model.
class ShopCatalog {
  final int energyRefillCostCoins;

  const ShopCatalog({required this.energyRefillCostCoins});

  factory ShopCatalog.fromJson(Map<String, dynamic> json) => ShopCatalog(
    energyRefillCostCoins: json['energy_refill_cost_coins'] as int,
  );
}
