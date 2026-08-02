import 'package:flutter/material.dart';
import 'package:skidoo_app/core/widgets/media_grid.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_tile.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// The three-column square grid shared by the Found tab's album previews and
/// the full album page — one place that owns column count, gutter and tile
/// shape so the two screens can never drift apart.
class FoundPhotoGrid extends StatelessWidget {
  const FoundPhotoGrid({
    super.key,
    required this.photos,
    required this.onPhotoTap,
    this.overflowCount = 0,
    this.onOverflowTap,
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
  });

  static const columns = 3;

  final List<Photo> photos;
  final void Function(int index) onPhotoTap;

  /// When > 0, the **last** tile of [photos] is washed over with a "+N" label
  /// standing for the matches the preview didn't have room for. It stays a
  /// real photo underneath — the server sends `previewLimit` photos and a
  /// separate `moreCount` for what lies beyond them, so the count is not
  /// derived from the tiles on screen.
  final int overflowCount;

  final VoidCallback? onOverflowTap;

  /// False (default) lets the grid size itself inside an outer scroll view.
  final bool scrollable;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const gutter = 6.0;
    final lastIndex = photos.length - 1;

    return MediaGrid(
      padding: padding,
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      // An album preview shows a fixed number across regardless of width, so
      // the caller's count wins over the responsive one.
      columns: columns,
      gutter: gutter,
      itemCount: photos.length,
      itemBuilder: (_, index) {
        final isOverflowTile = overflowCount > 0 && index == lastIndex;
        return FoundPhotoTile(
          key: ValueKey(photos[index].id),
          photo: photos[index],
          overflowCount: isOverflowTile ? overflowCount : 0,
          onTap: isOverflowTile
              ? (onOverflowTap ?? () => onPhotoTap(index))
              : () => onPhotoTap(index),
        );
      },
    );
  }
}
