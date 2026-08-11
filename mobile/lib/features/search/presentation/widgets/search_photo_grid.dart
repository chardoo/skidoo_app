import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/media_grid.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/purchase/photo_price_badge.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/models/photos/Photo.dart';

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
    this.selection,
  });

  final List<Photo> photos;
  final void Function(int index) onPhotoTap;
  final EdgeInsets padding;

  /// Non-null lets the grid be bought from: a tick on each priced photo, and
  /// tap to add. Null — "You may like", where there is no one album to check
  /// out — leaves plain thumbnails.
  final PhotoSelection? selection;

  @override
  Widget build(BuildContext context) {
    final selection = this.selection;

    return MediaGridSliver(
      padding: padding,
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        if (selection == null) {
          return SearchPhotoTile(
            key: ValueKey(photo.id),
            photo: photo,
            onTap: () => onPhotoTap(index),
          );
        }
        // Listened to per tile so choosing one photo repaints one tile.
        return ListenableBuilder(
          listenable: selection,
          builder: (_, __) => SearchPhotoTile(
            key: ValueKey(photo.id),
            photo: photo,
            onTap: () => onPhotoTap(index),
            selectable: photo.price > 0 && !photo.isPurchased,
            selected: selection.isSelected(photo.id),
            onToggle: () => selection.toggle(photo.id),
          ),
        );
      },
    );
  }
}

/// One tile: the photo cropped to a square cell.
class SearchPhotoTile extends StatelessWidget {
  const SearchPhotoTile({
    super.key,
    required this.photo,
    required this.onTap,
    this.selectable = false,
    this.selected = false,
    this.onToggle,
  });

  final Photo photo;
  final VoidCallback onTap;

  /// Whether this photo can be added to a purchase from the grid. Only priced,
  /// unowned photos qualify — there is nothing to buy otherwise.
  final bool selectable;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final media = ColoredBox(
      color: ext.searchFieldFill,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          JpergImage(
            imageUrl: photo.url,
            fit: BoxFit.cover,
            width: double.infinity,
            semanticLabel: photo.eventName.isEmpty
                ? 'Photo'
                : 'Photo from ${photo.eventName}',
            placeholder: (_, __) => const JpergImagePlaceholder(),
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
          // Any grid where a photo costs money says so. Bottom-left, the same
          // corner every other grid uses, so the amount is always in the same
          // place whichever screen someone came in through.
          if (photo.price > 0 && !photo.isPurchased)
            Positioned(
              left: 6.w,
              bottom: 6.h,
              child: PhotoPriceBadge(
                price: photo.price,
                muted: selectable && !selected,
                compact: true,
              ),
            ),
          if (selectable)
            Positioned(
              right: 6.w,
              top: 6.h,
              child: PhotoSelectionTick(selected: selected),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      image: true,
      child: GestureDetector(
        // Tap adds a priced photo to the purchase; the photo itself is a long
        // press away. Unpriced tiles open as they always did.
        onTap: selectable ? (onToggle ?? onTap) : onTap,
        onLongPress: selectable ? onTap : null,
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
