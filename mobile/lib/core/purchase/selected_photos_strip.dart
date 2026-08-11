import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// "3 photos selected", a Clear, and the photos themselves in a row.
///
/// What someone is about to be charged for, shown rather than counted. It
/// belongs to any screen that can take money: in the viewer one photo fills
/// the screen and the count would otherwise be a number with nothing behind
/// it, and in a long results grid the chosen photos have usually been scrolled
/// past by the time the button is reached.
///
/// Takes a plain list rather than a [PhotoSelection] because the screens that
/// need it do not agree on how they hold a selection — the album pages use the
/// selection object, the search results page has its own id set — and the row
/// is the same row either way.
class SelectedPhotosStrip extends StatelessWidget {
  const SelectedPhotosStrip({
    super.key,
    required this.photos,
    required this.onClear,
    this.thumbSize = 64,
  });

  final List<Photo> photos;
  final VoidCallback onClear;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final photoWord = photos.length == 1 ? 'photo' : 'photos';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${photos.length} $photoWord selected',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onClear,
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md.h),
        SizedBox(
          height: thumbSize.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm.w),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
              child: SizedBox(
                width: thumbSize.w,
                height: thumbSize.h,
                child: JpergImage(
                  imageUrl: photos[i].url,
                  fit: BoxFit.cover,
                  semanticLabel: 'Selected photo',
                  placeholder: (_, __) => const JpergImagePlaceholder(),
                  errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
