import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/purchase/photo_price_badge.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// One square thumbnail in a Found grid.
///
/// When [overflowCount] is greater than zero the tile is the album's last
/// slot: the thumbnail is dimmed under an accent wash and labelled "+N",
/// which is the affordance for opening the full album.
///
/// The tile has two modes. On the Found tab it is a plain thumbnail with a
/// price badge in the top-right. Inside an album it is also a checkbox — pass
/// [selectable] — and the badge moves to the bottom-left, because the tick
/// takes the top-right corner and the two would otherwise sit on top of each
/// other.
///
/// Watermarking is not this widget's job. Anything the photographer marked is
/// already watermarked in the stored URL (see main/app/routers/common/
/// preview.py), so the locked look in the design arrives with the image.
class FoundPhotoTile extends StatelessWidget {
  const FoundPhotoTile({
    super.key,
    required this.photo,
    required this.onTap,
    this.overflowCount = 0,
    this.selectable = false,
    this.selected = true,
    this.onToggle,
    this.reviewing = false,
  });

  final Photo photo;
  final VoidCallback onTap;
  final int overflowCount;

  /// Whether this tile takes part in the album's keep/discard pass.
  final bool selectable;

  final bool selected;

  /// Toggles the tick. Also fires on a tap anywhere on the tile while
  /// [selectable] — see the GestureDetector below.
  final VoidCallback? onToggle;

  /// Whether an unticked tile means "not me" rather than "not buying it".
  ///
  /// Only true while reviewing a photo that is still pending an answer. On the
  /// browsing grid an unticked photo is simply one nobody has chosen to buy —
  /// labelling every tile "Not me" the moment the album opens, which is what
  /// this flag was missing before, made the whole grid read as rejected.
  ///
  /// It is also false for a photo already confirmed: that question has been
  /// answered, and the tick there governs the purchase alone.
  final bool reviewing;

  bool get _isOverflow => overflowCount > 0;

  /// Priced, and not already bought. An owned photo shows no price: it is
  /// paid for, and repeating the amount reads as a second charge.
  bool get _showsPrice => photo.price > 0 && !photo.isPurchased && !_isOverflow;

  /// Deselected *and* being reviewed — the "Not me" treatment.
  bool get _isDiscarded => reviewing && selectable && !selected && !_isOverflow;

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
        // Inside an album the whole tile is the checkbox. The design's caption
        // — "Tap to deselect photos that aren't you" — promises exactly that,
        // and a 22px tick as the only target would make the promise false on
        // a three-column grid.
        onTap: selectable ? (onToggle ?? onTap) : onTap,
        // The photo is still reachable while selecting; it just needs the
        // longer press now that tap means "not me".
        onLongPress: selectable ? onTap : null,
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
                // "Not me": the photo greys back so the kept ones read as the
                // subject of the screen, and the label says which state this
                // is — a dim alone is ambiguous at thumbnail size.
                if (_isDiscarded) ...[
                  ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
                  Center(
                    child: Text(
                      'Not me',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                if (photo.isVideo && !_isOverflow)
                  Positioned(
                    // Moves aside for the tick, which owns the top-right the
                    // moment this grid becomes selectable.
                    right: selectable ? null : 6.w,
                    left: selectable ? 6.w : null,
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

                // Price sits top-right on the Found tab and bottom-left inside
                // an album, where the tick has taken the top-right corner.
                if (_showsPrice)
                  Positioned(
                    left: selectable ? 6.w : null,
                    right: selectable ? null : 6.w,
                    top: selectable ? null : 6.h,
                    bottom: selectable ? 6.h : null,
                    child: PhotoPriceBadge(
                      price: photo.price,
                      muted: _isDiscarded,
                      // A label on a photo, not a banner across it: at the
                      // full size "GHS 20" covered 70% of a three-across tile
                      // and a fifth of its height.
                      compact: true,
                    ),
                  ),

                if (selectable && !_isOverflow && !photo.isPurchased)
                  Positioned(
                    right: 6.w,
                    top: 6.h,
                    child: PhotoSelectionTick(selected: selected),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
