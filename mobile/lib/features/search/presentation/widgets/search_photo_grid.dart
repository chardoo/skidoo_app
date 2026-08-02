import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/widgets/media_grid.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// The photo grid behind both "You may like" and an event's photos, as a
/// sliver so either can sit in a page that scrolls other things above it.
///
/// Thin wrapper over [MediaGridSliver] that knows how to draw a [Photo]. An
/// event's photos used to fall into a ragged masonry wall at their real aspect
/// ratios; see [MediaGrid] for why every tiled collection is uniform now.
class SearchPhotoGridSliver extends StatelessWidget {
  const SearchPhotoGridSliver({
    super.key,
    required this.photos,
    required this.onPhotoTap,
    this.padding = EdgeInsets.zero,
  });

  final List<Photo> photos;
  final void Function(int index) onPhotoTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return MediaGridSliver(
      padding: padding,
      itemCount: photos.length,
      itemBuilder: (context, index) => SearchPhotoTile(
        key: ValueKey(photos[index].id),
        photo: photos[index],
        onTap: () => onPhotoTap(index),
      ),
    );
  }
}

/// One tile: the photo cropped to a square cell.
class SearchPhotoTile extends StatelessWidget {
  const SearchPhotoTile({
    super.key,
    required this.photo,
    required this.onTap,
  });

  final Photo photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final media = ColoredBox(
      color: ext.searchFieldFill,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          SkidooImage(
            imageUrl: photo.url,
            fit: BoxFit.cover,
            width: double.infinity,
            semanticLabel: photo.eventName.isEmpty
                ? 'Photo'
                : 'Photo from ${photo.eventName}',
            placeholder: (_, __) => const SkidooImagePlaceholder(),
            errorWidget: (_, __, ___) => ColoredBox(
              color: ext.searchFieldFill,
              child: Icon(Icons.broken_image_outlined,
                  color: ext.searchHintColor, size: 20.sp),
            ),
          ),
          if (photo.isVideo)
            Positioned(
              right: 6.w,
              top: 6.h,
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white.withValues(alpha: 0.9), size: 18.sp),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      image: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs.r),
          // The cell is already square, so this only matters where a tile is
          // built outside the grid.
          child: AspectRatio(aspectRatio: 1, child: media),
        ),
      ),
    );
  }
}
