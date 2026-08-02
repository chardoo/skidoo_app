import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/user_profile/data/repositories/profile_overview_repository.dart';

/// One square in the liked or bookmarked grid.
///
/// Two gestures live here and they must not fight: the whole tile opens the
/// photo, and the icon in its corner takes it out of the list.
class ProfilePhotoTile extends StatelessWidget {
  const ProfilePhotoTile({
    super.key,
    required this.photo,
    required this.ext,
    required this.removeIcon,
    required this.removeTooltip,
    required this.onRemove,
    required this.onOpen,
  });

  final ProfilePhoto photo;
  final AppThemeExtension ext;
  final IconData removeIcon;
  final String removeTooltip;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque, not the default deferToChild: an Image does not absorb a hit,
      // so with deferToChild a tap anywhere on the photo found no child willing
      // to take it and the tile did nothing at all.
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: ColoredBox(
        color: ext.avatarBackground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image_outlined,
                color: ext.searchHintColor,
                size: 20.r,
              ),
            ),
            if (photo.isVideo)
              Positioned(
                left: 6.w,
                top: 6.h,
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18.r,
                ),
              ),
            if (photo.isEvent)
              Positioned(
                left: 6.w,
                bottom: 6.h,
                child: Icon(
                  Icons.event_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 16.r,
                ),
              ),
            Positioned(
              right: 0,
              top: 0,
              child: Semantics(
                button: true,
                label: removeTooltip,
                child: GestureDetector(
                  // Opaque so the corner takes its own taps rather than
                  // letting them through to the tile underneath and opening
                  // the photo the user was trying to remove.
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Padding(
                    // Padded rather than sized: the icon is small, and the tap
                    // target around it needs to be a finger wide.
                    padding: EdgeInsets.all(6.r),
                    child: Icon(
                      removeIcon,
                      size: 18.r,
                      color: Colors.white.withValues(alpha: 0.95),
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
