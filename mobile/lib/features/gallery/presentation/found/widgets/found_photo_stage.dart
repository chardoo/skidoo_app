import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_action_rail.dart';
import 'package:skidoo_app/core/widgets/image_aspect.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_meta_bar.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_visibility_badge.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

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
  });

  final Photo photo;

  /// Whether the photo is something to react to. False where the viewer is
  /// showing someone's work rather than a photo of you — a portfolio opened
  /// while booking has nothing to like, and the rail would be acting on a
  /// sample id the picture endpoints know nothing about.
  final bool showSocialActions;

  /// False for the off-screen neighbours in the viewer's PageView — keeps
  /// their videos paused.
  final bool isActive;

  final VoidCallback? onViewAlbum;

  /// Shape used for the first frame of a record the server sent no dimensions
  /// for. It is a starting point, not the answer: [ResolvedAspect] measures the
  /// image and rebuilds with its real shape, so a panorama is never boxed into
  /// a 4:3 slot.
  static const _defaultAspect = 4 / 3;

  /// Height of the video player's own bottom controls — 20 dp scrubber,
  /// timestamp row, 6 dp padding (`_BottomBar` in skidoo_video_player.dart).
  static const double _videoControlsBand = 40;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Center(
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
                SkidooVideoPlayer(
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
                SkidooImage(
                  imageUrl: photo.url,
                  // Identical to `cover` once the box is the photo's own
                  // shape, which is the steady state. It differs only in the
                  // moment before an unmeasured photo resolves, and there
                  // `contain` shows the whole frame rather than cropping into
                  // it and then jumping.
                  fit: BoxFit.contain,
                  semanticLabel: 'Found photo',
                  placeholder: (_, __) => const SkidooImagePlaceholder(),
                  errorWidget: (_, __, ___) => const SkidooImagePlaceholder(),
                ),

              Positioned(
                left: AppSpacing.md.w,
                top: AppSpacing.md.h,
                child: FoundVisibilityBadge(isPublic: photo.isPublic),
              ),

              if (showSocialActions)
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
                      child: FoundActionRail(
                        key: ValueKey('found_actions_${photo.id}'),
                        photo: photo,
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
                child:
                    FoundPhotoMetaBar(photo: photo, onViewAlbum: onViewAlbum),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
