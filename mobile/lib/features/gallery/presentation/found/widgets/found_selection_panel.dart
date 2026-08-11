import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/core/purchase/selected_photos_strip.dart';
import 'package:jperg_app/core/purchase/photo_price_badge.dart';

/// The viewer's running total: "3 photos selected", a Clear, the thumbnails,
/// and the button that buys them.
///
/// The thumbnail row is the part that earns its place. In the album the grid
/// is the evidence of what is selected; here a single photo fills the screen,
/// so without this the count is a number with nothing behind it and the only
/// way to check what is in it is to leave.
class FoundSelectionPanel extends StatelessWidget {
  const FoundSelectionPanel({
    super.key,
    required this.selection,
    required this.onCheckout,
    this.isBusy = false,
  });

  final PhotoSelection selection;
  final VoidCallback onCheckout;

  /// A payment is being opened. The button holds still rather than letting a
  /// second press start a second checkout.
  final bool isBusy;

  static const _thumb = 64.0;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final paid = selection.paid;
        if (paid.isEmpty) return SizedBox(height: 88.h);

        final photoWord = paid.length == 1 ? 'photo' : 'photos';

        return Container(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.sm.h,
              AppSpacing.lg.w, AppSpacing.md.h),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.lg.r)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grab handle. Decorative — the panel does not drag — but it
                // is what the design draws and it reads as "this is a layer
                // over the photo" rather than a fixed part of the chrome.
                Container(
                  width: 32.w,
                  height: 3.h,
                  decoration: BoxDecoration(
                    color: ext.searchHintColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.pill.r),
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                SelectedPhotosStrip(
                  photos: paid,
                  onClear: selection.clear,
                  thumbSize: _thumb,
                ),
                SizedBox(height: AppSpacing.md.h),
                AppButton(
                  label: 'Get ${paid.length} $photoWord – '
                      '${PhotoPriceBadge.formatTotal(selection.total)}',
                  onPressed: isBusy ? null : onCheckout,
                  isLoading: isBusy,
                  fullWidth: true,
                  borderRadius: AppRadius.pill,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
