import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// One square thumbnail in a Found grid.
///
/// When [overflowCount] is greater than zero the tile is the album's last
/// slot: the thumbnail is dimmed under an accent wash and labelled "+N",
/// which is the affordance for opening the full album.
class FoundPhotoTile extends StatelessWidget {
  const FoundPhotoTile({
    super.key,
    required this.photo,
    required this.onTap,
    this.overflowCount = 0,
  });

  final Photo photo;
  final VoidCallback onTap;
  final int overflowCount;

  bool get _isOverflow => overflowCount > 0;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final radius = BorderRadius.circular(AppRadius.sm.r);

    return Semantics(
      button: true,
      image: !_isOverflow,
      label: _isOverflow
          ? '$overflowCount more photos'
          : (photo.eventName.isNotEmpty
              ? 'Photo from ${photo.eventName}'
              : 'Found photo'),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: ext.cardSurface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                JpergImage(
                  imageUrl: photo.url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const JpergImagePlaceholder(),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: ext.cardSurface,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: ext.searchHintColor,
                      size: 20.sp,
                    ),
                  ),
                ),
                if (photo.isVideo && !_isOverflow)
                  Positioned(
                    right: 6.w,
                    top: 6.h,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 18.sp,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                if (_isOverflow)
                  ColoredBox(
                    // Sampled off the design's "+16" tile — a deep teal wash
                    // that keeps a hint of the photo showing through.
                    color: const Color(0xE60A4037),
                    child: Center(
                      child: Text(
                        '+$overflowCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
