import 'package:flutter/material.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_photo_actions.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_action_rail.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/widgets/zoomable_photo.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_meta_bar.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_visibility_badge.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_buy_pill.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_counter_pill.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// One page of the Found viewer: the media itself with the three overlays
/// that hang off its edges — visibility badge (top-left), action rail
/// (right), photographer + "View album" bar (bottom).
///
/// The media is boxed to the photo's own aspect ratio so the overlays hug the
/// image rather than the screen, which is what makes the letterboxed look in
/// the design work for both portrait and landscape shots.
class FoundPhotoStage extends StatelessWidget {
  const FoundPhotoStage({
    super.key,
    required this.photo,
    required this.isActive,
    this.onViewAlbum,
    this.showSocialActions = true,
    this.purchaseGated = false,
    this.selection,
    this.counter,
    this.onZoomChanged,
  });

  final Photo photo;

  /// Whether the rail's contents follow the photo's price and visibility —
  /// true only in Found you. See [FoundPhotoActions].
  final bool purchaseGated;

  /// Non-null shows the "GHS 20 | Buy" pill for a priced, unowned photo, and
  /// toggles this photo in the album's selection when it is tapped.
  final PhotoSelection? selection;

  /// "3 of 16", when the app bar has given its centre over to the album name.
  /// It takes the top-left corner, which is why the visibility badge steps
  /// aside below — two pills stacked there would collide over an arbitrary
  /// photo.
  final String? counter;

  /// Whether the photo is something to react to. False where the viewer is
  /// showing someone's work rather than a photo of you — a portfolio opened
  /// while booking has nothing to like, and the rail would be acting on a
  /// sample id the picture endpoints know nothing about.
  final bool showSocialActions;

  /// False for the off-screen neighbours in the viewer's PageView — keeps
  /// their videos paused.
  final bool isActive;

  final VoidCallback? onViewAlbum;

  /// Fires as the photo leaves 1× and as it returns. The viewer freezes its
  /// pager in between — see [ZoomableArea].
  final ValueChanged<bool>? onZoomChanged;

  /// Shape used for the first frame of a record the server sent no dimensions
  /// for. It is a starting point, not the answer: [ResolvedAspect] measures the
  /// image and rebuilds with its real shape, so a panorama is never boxed into
  /// a 4:3 slot.
  static const _defaultAspect = 4 / 3;

  /// Height of the video player's own bottom controls — 20 dp scrubber,
  /// timestamp row, 6 dp padding (`_BottomBar` in jperg_video_player.dart).
  static const double _videoControlsBand = 40;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // Scales up out of the way when a comment sheet opens, so the photo being
    // discussed stays whole and lit above it.
    return CommentPushArea(
      child: Center(
        child: ResolvedAspect(
          imageUrl: photo.url,
          // Videos measure too — [ResolvedAspect] reads their poster frame, so a
          // clip the server sent no dimensions for still gets its real shape
          // instead of the stand-in.
          knownAspect: photo.aspectRatio,
          fallback: _defaultAspect,
          builder: (context, aspect) => AspectRatio(
            aspectRatio: aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo.isVideo)
                  JpergVideoPlayer(
                    url: photo.url,
                    isActive: isActive,
                    autoPlay: true,
                    loop: true,
                    fit: BoxFit.cover,
                    showControls: true,
                    backgroundColor: ext.mediaLetterbox,
                    listenToPauseNotifier: true,
                  )
                else
                  // Pinch or double-tap to look closer: this is where someone
                  // decides whether the face in a crowd shot is theirs, and at
                  // screen size it often isn't decidable. The zoom is bounded
                  // by the photo's own box, so the magnified image stays under
                  // the overlays that hang off its edges rather than sliding
                  // out over the letterbox.
                  ZoomableArea(
                    isActive: isActive,
                    resetToken: photo.id,
                    onZoomChanged: onZoomChanged,
                    child: JpergImage(
                      imageUrl: photo.url,
                      // Identical to `cover` once the box is the photo's own
                      // shape, which is the steady state. It differs only in
                      // the moment before an unmeasured photo resolves, and
                      // there `contain` shows the whole frame rather than
                      // cropping into it and then jumping.
                      fit: BoxFit.contain,
                      semanticLabel: 'Found photo',
                      placeholder: (_, __) => const JpergImagePlaceholder(),
                      errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
                    ),
                  ),

                // Everything below is chrome over the photo, and all of it
                // goes while a comment sheet is open — see [CommentSheetHide].
                // The band above the sheet is media and nothing else, the same
                // as it is on the feeds.
                Positioned(
                  left: AppSpacing.md.w,
                  top: AppSpacing.md.h,
                  child: CommentSheetHide(
                    child: counter == null
                        ? FoundVisibilityBadge(isPublic: photo.isPublic)
                        : FoundCounterPill(label: counter!),
                  ),
                ),

                // "GHS 20 | Buy". Sits above the action rail, which is centred
                // down the right edge rather than pinned to the top, so the two
                // do not meet.
                if (selection != null && photo.price > 0 && !photo.isPurchased)
                  Positioned(
                    right: AppSpacing.md.w,
                    top: AppSpacing.md.h,
                    child: CommentSheetHide(
                      child: FoundBuyPill(
                        photo: photo,
                        selection: selection!,
                      ),
                    ),
                  ),

                // Nothing on offer means no rail, not an empty column: an
                // unbought photo in Found you has no reactions of any kind, and
                // the space belongs to the photo.
                if (showSocialActions &&
                    FoundActionRail.actionsFor(photo, gated: purchaseGated).any)
                  Positioned(
                    right: AppSpacing.md.w,
                    top: AppSpacing.sm.h,
                    bottom: AppSpacing.huge.h,
                    child: Align(
                      alignment: const Alignment(0, -0.1),
                      // The rail is sized to the *photo*, and a wide landscape
                      // shot leaves it very little height — scaleDown keeps every
                      // action reachable instead of clipping the bottom one off.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: CommentSheetHide(
                          child: FoundActionRail(
                            key: ValueKey('found_actions_${photo.id}'),
                            photo: photo,
                            purchaseGated: purchaseGated,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Cleared of the player's own controls on video: the scrubber and
                // timestamps are anchored to the same bottom edge, so a meta bar
                // at 0 covers the progress bar and swallows the drags that seek.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: photo.isVideo ? _videoControlsBand.h : 0,
                  child: CommentSheetHide(
                    child: FoundPhotoMetaBar(
                        photo: photo, onViewAlbum: onViewAlbum),
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
