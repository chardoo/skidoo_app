import 'package:flutter/material.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/pages/gallery_fullscreen_page.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';

class GalleryImageWidget extends StatelessWidget {
  final Photo photo;

  /// Full gallery list and this tile's position, so the fullscreen viewer can
  /// swipe left/right through every photo.
  final List<Photo> photos;
  final int index;

  const GalleryImageWidget({
    super.key,
    required this.photo,
    required this.photos,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      button: true,
      image: true,
      label: photo.eventName.isNotEmpty
          ? 'Photo from ${photo.eventName}, open full screen'
          : 'Photo, open full screen',
      child: GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          color: ext.cardSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // ── Image ─────────────────────────────────────────────────────
            SkidooImage(
              imageUrl: photo.url,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(
                height: 160.h,
                color: ext.searchFieldFill,
                child: Center(
                  child: SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ext.accentGold,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 160.h,
                color: ext.searchFieldFill,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: ext.searchHintColor,
                  size: 32.sp,
                ),
              ),
            ),

            // ── Bottom gradient ────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 48.h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Event name ─────────────────────────────────────────────────
            if (photo.eventName.isNotEmpty)
              Positioned(
                bottom: 8.h,
                left: 10.w,
                right: 10.w,
                child: Text(
                  photo.eventName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Colors.black87),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            GalleryFullscreenPage(photos: photos, initialIndex: index),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}
