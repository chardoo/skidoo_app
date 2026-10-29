/// The boost menu, exactly as the server sells it.
///
/// None of this is hardcoded in the sheet. The price on the button has to be
/// the price that gets charged, and a client carrying its own copy of the menu
/// can be a version behind — the gap between the two is somebody paying an
/// amount they were never shown.
class BoostTier {
  const BoostTier({
    required this.days,
    required this.priceGhs,
    required this.label,
    required this.blurb,
    this.bestValue = false,
    this.ios,
  });

  final int days;

  /// What the boost is configured at, in the admin console's currency.
  final double priceGhs;

  /// Which App Store product pays for this tier, when the sheet asked for iOS.
  ///
  /// Null everywhere else. Carries no price: what a boost costs on an iPhone
  /// is set in App Store Connect, and Apple localises it per storefront — so
  /// the figure comes from StoreKit at display time rather than from a server
  /// that would have to be kept in step with Apple's own catalogue.
  final IosBoostPrice? ios;

  /// "7 Days" — the heading on the row.
  final String label;

  /// "Perfect duration for maximum response" — the line under it.
  final String blurb;

  /// Drawn with the BEST VALUE pill. Exactly one tier carries it.
  final bool bestValue;

  factory BoostTier.fromJson(Map<String, dynamic> json) => BoostTier(
        days: (json['days'] as num?)?.toInt() ?? 0,
        priceGhs: (json['price_ghs'] as num?)?.toDouble() ?? 0,
        label: json['label'] as String? ?? '',
        blurb: json['blurb'] as String? ?? '',
        bestValue: json['best_value'] == true,
        ios: json['ios'] is Map<String, dynamic>
            ? IosBoostPrice.fromJson(json['ios'] as Map<String, dynamic>)
            : null,
      );
}

/// Which App Store product pays for one tier.
class IosBoostPrice {
  const IosBoostPrice({required this.productId});

  final String productId;

  factory IosBoostPrice.fromJson(Map<String, dynamic> json) =>
      IosBoostPrice(productId: json['productId'] as String? ?? '');
}


class BoostCatalogue {
  const BoostCatalogue({
    required this.tiers,
    required this.benefits,
    required this.currency,
  });

  final List<BoostTier> tiers;

  /// The ticked list under the tiers. Server-side so the promise and the
  /// behaviour that honours it change together.
  final List<String> benefits;

  /// ISO code, for the price labels. "GHS" today.
  final String currency;

  /// The tier to open on: the one marked best value, else the first.
  ///
  /// Never null for a non-empty menu — the sheet always has something
  /// selected, so the Pay button always has a price on it.
  BoostTier? get defaultTier {
    if (tiers.isEmpty) return null;
    for (final tier in tiers) {
      if (tier.bestValue) return tier;
    }
    return tiers.first;
  }

  factory BoostCatalogue.fromJson(Map<String, dynamic> json) => BoostCatalogue(
        tiers: (json['tiers'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BoostTier.fromJson)
            .toList(),
        benefits: (json['benefits'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
        currency: json['currency'] as String? ?? 'GHS',
      );

  static const empty =
      BoostCatalogue(tiers: [], benefits: [], currency: 'GHS');
}
