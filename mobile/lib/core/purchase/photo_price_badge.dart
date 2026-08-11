import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The amount on a photo that has to be bought — "GHS 20".
///
/// A solid amber pill with dark text, not the dark scrim of
/// [FoundVisibilityBadge]: the design gives price its own weight, and a price
/// is the one label on a photo that has to survive being glanced past. The
/// colour is the existing `publicAmber` token, which is what the design uses.
///
/// [muted] is the deselected state — the photo is still priced, but it is not
/// being bought, so the badge recedes rather than disappearing. Removing it
/// would make a deselected paid photo look free.
class PhotoPriceBadge extends StatelessWidget {
  const PhotoPriceBadge({
    super.key,
    required this.price,
    this.muted = false,
    this.compact = false,
  });

  final double price;

  final bool muted;

  /// Filmstrip sizing — same pill, smaller.
  final bool compact;

  /// The badge form: "GHS 20", not "GHS 20.00".
  ///
  /// A tag on a thumbnail is a glance, and two decimal places of nothing is
  /// noise at 11sp. Real pesewas still show.
  static String format(double price) {
    final whole = price.truncateToDouble() == price;
    return 'GHS ${whole ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';
  }

  /// The checkout form: "GHS 120.00", always two decimals.
  ///
  /// Deliberately different from [format], because the design draws them
  /// differently and it is right to: this is the amount about to be charged,
  /// and an amount someone is being asked to approve should look like money
  /// rather than like a label.
  static String formatTotal(double amount) =>
      'GHS ${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      label: 'Costs ${format(price)}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: (compact ? AppSpacing.xs : AppSpacing.sm).w,
          vertical: (compact ? 1 : AppSpacing.xs).h,
        ),
        decoration: BoxDecoration(
          color:
              muted ? ext.publicAmber.withValues(alpha: 0.35) : ext.publicAmber,
          borderRadius: BorderRadius.circular(AppRadius.pill.r),
        ),
        child: Text(
          format(price),
          style: TextStyle(
            // Dark text on amber. The pill is light enough that white would
            // fail contrast at this size.
            color: muted
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFF1A1A1A),
            fontSize: (compact ? 8 : 11).sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The tick on a photo the viewer is keeping, and the empty ring on one they
/// have marked "Not me".
class PhotoSelectionTick extends StatelessWidget {
  const PhotoSelectionTick({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      label: selected ? 'Selected' : 'Not selected',
      child: Container(
        width: 22.r,
        height: 22.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              selected ? ext.accentGold : Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: selected
                ? ext.accentGold
                : Colors.white.withValues(alpha: 0.75),
            width: 1.5,
          ),
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 14.sp, color: Colors.white)
            : null,
      ),
    );
  }
}
