import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/core/purchase/photo_price_badge.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// "GHS 20 | Buy" over the top-right of a photo in the viewer.
///
/// One pill carrying two things — what it costs and what to do about it —
/// split by a hairline, as the design draws it. The whole pill is the target;
/// the divider is there to say the word "Buy" is the action rather than part
/// of the price.
///
/// It is a toggle, not a one-way action. Everything in an album starts
/// selected, so a photo the person is already buying shows as included and
/// tapping takes it back out. "Buy" is the label for the state it is *not*
/// in — pressing it is what keeps the photo.
class FoundBuyPill extends StatelessWidget {
  const FoundBuyPill({
    super.key,
    required this.photo,
    required this.selection,
  });

  final Photo photo;
  final PhotoSelection selection;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final selected = selection.isSelected(photo.id);

        return Semantics(
          button: true,
          selected: selected,
          label: selected
              ? 'Buying this photo for ${PhotoPriceBadge.format(photo.price)}. '
                  'Tap to remove it'
              : 'Buy this photo for ${PhotoPriceBadge.format(photo.price)}',
          child: GestureDetector(
            onTap: () => selection.toggle(photo.id),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.xs.h,
              ),
              decoration: BoxDecoration(
                // Amber when it is being bought, dark scrim when it is not, so
                // the state is legible from the colour before the words are
                // read.
                color: selected
                    ? ext.publicAmber
                    : Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadius.pill.r),
                border: selected
                    ? null
                    : Border.all(color: ext.publicAmber.withValues(alpha: 0.7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    PhotoPriceBadge.format(photo.price),
                    style: TextStyle(
                      color:
                          selected ? const Color(0xFF1A1A1A) : ext.publicAmber,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 12.h,
                    margin: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
                    color: (selected ? Colors.black : ext.publicAmber)
                        .withValues(alpha: 0.35),
                  ),
                  Text(
                    selected ? 'Added' : 'Buy',
                    style: TextStyle(
                      color:
                          selected ? const Color(0xFF1A1A1A) : ext.publicAmber,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
