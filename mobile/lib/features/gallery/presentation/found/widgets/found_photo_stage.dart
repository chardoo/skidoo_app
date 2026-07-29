import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_action_rail.dart';
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
  });

  final Photo photo;

  /// False for the off-screen neighbours in the viewer's PageView — keeps
  /// their videos paused.
  final bool isActive;

  final VoidCallback? onViewAlbum;

  /// Fallback shape for records the server never sent dimensions for.
  static const _defaultAspect = 4 / 3;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: photo.aspectRatio ?? _defaultAspect,
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
                backgroundColor: Colors.black,
                listenToPauseNotifier: true,
              )
            else
              SkidooImage(
                imageUrl: photo.url,
                fit: BoxFit.cover,
                semanticLabel: 'Found photo',
                placeholder: (_, __) => const SkidooImagePlaceholder(alwaysDark: true),
                errorWidget: (_, __, ___) =>
                    const SkidooImagePlaceholder(alwaysDark: true),
              ),

            Positioned(
              left: AppSpacing.md.w,
              top: AppSpacing.md.h,
              child: FoundVisibilityBadge(isPublic: photo.isPublic),
            ),

            Positioned(
              right: AppSpacing.md.w,
              top: AppSpacing.sm.h,
              bottom: AppSpacing.huge.h,
              child: Align(
                alignment: const Alignment(0, -0.1),
                // The rail is sized to the *photo*, and a wide landscape shot
                // leaves it very little height — scaleDown keeps every action
                // reachable instead of clipping the bottom one off.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: FoundActionRail(
                    key: ValueKey('found_actions_${photo.id}'),
                    photo: photo,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FoundPhotoMetaBar(photo: photo, onViewAlbum: onViewAlbum),
            ),
          ],
        ),
      ),
    );
  }
}
