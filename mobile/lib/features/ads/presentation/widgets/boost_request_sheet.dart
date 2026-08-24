import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/models/boost_tier.dart';

/// "Boost Your Request" — pick how many days of reach to buy.
///
/// Pops with the chosen [BoostTier], or null when dismissed. It does not pay
/// for anything itself: the caller starts the payment, so the sheet stays a
/// menu and the money lives in one place.
class BoostRequestSheet extends StatefulWidget {
  const BoostRequestSheet({super.key, required this.catalogue});

  final BoostCatalogue catalogue;

  @override
  State<BoostRequestSheet> createState() => _BoostRequestSheetState();
}

class _BoostRequestSheetState extends State<BoostRequestSheet> {
  BoostTier? _selected;

  @override
  void initState() {
    super.initState();
    // Opens on the best-value tier, so the Pay button always carries a price
    // and the recommended option is the one you get by not choosing.
    _selected = widget.catalogue.defaultTier;
  }

  String _price(BoostTier tier) {
    final amount = tier.priceGhs;
    // Whole cedis in the designs. A tier priced in pesewas keeps its decimals
    // rather than being rounded into a different number.
    final text = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '${widget.catalogue.currency} $text';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final selected = _selected;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: AppSpacing.sm.h, bottom: 28.h),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boost Your Request',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  Text(
                    'Get your request seen by more photographers instantly.',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),

            for (final tier in widget.catalogue.tiers)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl.w, 0, AppSpacing.xl.w, AppSpacing.md.h),
                child: _TierRow(
                  tier: tier,
                  price: _price(tier),
                  isSelected: selected?.days == tier.days,
                  onTap: () => setState(() => _selected = tier),
                ),
              ),

            if (widget.catalogue.benefits.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xs.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
                child: Container(
                  padding: EdgeInsets.all(AppSpacing.lg.w),
                  decoration: BoxDecoration(
                    color: ext.accentGold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final benefit in widget.catalogue.benefits)
                        Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_rounded,
                                  size: 16.sp, color: ext.accentGold),
                              SizedBox(width: AppSpacing.sm.w),
                              Expanded(
                                child: Text(
                                  benefit,
                                  style: TextStyle(
                                    color: ext.accentGold,
                                    fontSize: 12.5.sp,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: AppSpacing.xl.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 44.w),
              child: Semantics(
                button: true,
                label: selected == null
                    ? 'Pay'
                    : 'Pay ${_price(selected)} to boost for ${selected.days} days',
                child: ElevatedButton(
                  // Nothing to buy means nothing to press. The menu is served,
                  // so an empty one is a failed fetch rather than an empty
                  // catalogue — the caller reports that; this just does not
                  // offer a purchase it cannot price.
                  onPressed: selected == null
                      ? null
                      : () => Navigator.of(context).pop(selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.accentGold,
                    disabledBackgroundColor:
                        ext.accentGold.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(52.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                  ),
                  child: Text(
                    selected == null ? 'Pay' : 'Pay - ${_price(selected)}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One duration on the menu.
class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  final BoostTier tier;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${tier.label}, $price. ${tier.blurb}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.lg.h),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            // The selected row is outlined in the accent rather than filled:
            // it has to read as chosen without competing with the Pay button,
            // which is the only filled thing on the sheet.
            border: Border.all(
              color: isSelected
                  ? ext.accentGold
                  : ext.searchHintColor.withValues(alpha: 0.18),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flexible on the label: at a large text scale the
                    // heading and the BEST VALUE pill together are wider than
                    // the row leaves them, and the pill is the part that must
                    // not be cut — it is the whole reason the row is marked.
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tier.label,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tier.bestValue) ...[
                          SizedBox(width: AppSpacing.sm.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: ext.accentGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              'BEST VALUE',
                              style: TextStyle(
                                color: ext.accentGold,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      tier.blurb,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Text(
                price,
                style: TextStyle(
                  color: isSelected ? ext.accentGold : ext.greetingColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
