import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/core/purchase/photo_price_badge.dart';

/// What the album's keep/discard pass adds up to, and the button that acts on
/// it: "Get 6 photos – GHS 120.00" over "12 free photos saved automatically".
///
/// The caption is not decoration. Everything arrives selected, so the default
/// action of this screen is to buy every priced photo in the album — the count
/// and the total are the only warning of that, which is why they are in the
/// button itself rather than on a confirmation the person can skip past.
///
/// Free photos ride along with the same press. They cost nothing, so they are
/// stated rather than offered: there is no version of this where someone wants
/// the photos of themselves they don't have to pay for.
class PhotoPurchaseBar extends StatelessWidget {
  const PhotoPurchaseBar({
    super.key,
    required this.selection,
    required this.onCheckout,
    this.isBusy = false,
  });

  final PhotoSelection selection;
  final VoidCallback onCheckout;
  final bool isBusy;

  /// The free-photos line belongs to the review screen only. Browsing an album
  /// saves nothing automatically — the person picked what they wanted — so
  /// claiming otherwise there would be a promise the button does not keep.
  bool get _announcesFreeSaves => selection.reviewMode;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        // Nothing selected at all — every match was marked "not me". There is
        // no action left, so the bar gets out of the way rather than offering
        // a button that would do nothing.
        if (!selection.hasAnything) return const SizedBox.shrink();

        final paid = selection.paidCount;
        final free = selection.freeCount;
        final photoWord = paid == 1 ? 'photo' : 'photos';

        return Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w,
            AppSpacing.md.h,
            AppSpacing.lg.w,
            AppSpacing.lg.h,
          ),
          decoration: BoxDecoration(
            color: ext.homeBackground,
            // Lifts the bar off a grid that scrolls underneath it.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  label: paid > 0
                      ? 'Get $paid $photoWord – ${PhotoPriceBadge.formatTotal(selection.total)}'
                      // Only free photos left to save, so the button says so
                      // rather than quoting GHS 0.00.
                      : 'Save ${free == 1 ? 'photo' : '$free photos'}',
                  onPressed: isBusy ? null : onCheckout,
                  isLoading: isBusy,
                  fullWidth: true,
                  borderRadius: AppRadius.pill,
                ),
                if (_announcesFreeSaves && free > 0 && paid > 0) ...[
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    '$free free ${free == 1 ? 'photo' : 'photos'} saved automatically',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
