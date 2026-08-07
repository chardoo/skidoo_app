import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_grid.dart';

/// One album block in the Found feed.
///
/// Two shapes, both from the design:
///   • browsing (default) — the event name, then a six-tile preview whose
///     last slot is a "+N" tile into the full album.
///   • [expanded] — used once a filter is applied: no title, and the matches
///     laid out in one grid. The section gap is kept so the result still reads
///     as grouped by event, but the album framing gives way to "here is what
///     matched".
///
/// Both shapes keep the "+N" tile. Expanded mode used to drop it on the
/// premise that it showed *every* match, which it never did: the feed only
/// ever holds the server's preview slice, so an event with 17 matches rendered
/// 6 tiles with no way through to the other 11 while the header counted all
/// 17. The slice is larger when filtered (see [FoundBloc.filteredPreviewLimit])
/// but it is still a slice, so what's beyond it has to stay reachable.
class FoundAlbumSection extends StatelessWidget {
  const FoundAlbumSection({
    super.key,
    required this.album,
    required this.onPhotoTap,
    required this.onOpenAlbum,
    this.expanded = false,
  });

  final FoundAlbum album;

  /// Index is into [FoundAlbum.photos], not just the preview slice.
  final void Function(int index) onPhotoTap;
  final VoidCallback onOpenAlbum;

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    if (expanded) {
      return FoundPhotoGrid(
        photos: album.photos,
        overflowCount: album.moreCount,
        onOverflowTap: onOpenAlbum,
        onPhotoTap: onPhotoTap,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          header: true,
          label: '${album.title}, ${album.photoCount} photos, open album',
          child: GestureDetector(
            onTap: onOpenAlbum,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md.h),
              child: Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        FoundPhotoGrid(
          // The server's preview slice: the last tile carries the "+N" wash
          // and `moreCount` counts the matches beyond it.
          photos: album.photos,
          overflowCount: album.moreCount,
          onOverflowTap: onOpenAlbum,
          onPhotoTap: onPhotoTap,
        ),
      ],
    );
  }
}
