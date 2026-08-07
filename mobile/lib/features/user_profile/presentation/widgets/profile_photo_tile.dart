import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/animations/app_animations.dart';
import 'package:jperg_app/features/user_profile/data/repositories/profile_overview_repository.dart';

/// One square in the liked or bookmarked grid.
///
/// Two gestures live here and they must not fight: the whole tile opens the
/// photo, and the icon in its corner takes it out of the list.
///
/// Both press: a photo is a flat rectangle with no button around it, so
/// without the tile giving under the finger there is nothing to tell you the
/// tap landed until the next screen arrives.
class ProfilePhotoTile extends StatefulWidget {
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
  State<ProfilePhotoTile> createState() => _ProfilePhotoTileState();
}

class _ProfilePhotoTileState extends State<ProfilePhotoTile> {
  /// Small on purpose. A tile is one of nine on screen; anything deeper reads
  /// as the grid flinching rather than this square acknowledging a finger.
  static const _pressedScale = 0.96;
  static const _iconPressedScale = 0.82;
  static const _press = Duration(milliseconds: 90);

  bool _pressed = false;
  bool _iconPressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  void _setIconPressed(bool value) {
    if (_iconPressed != value && mounted) setState(() => _iconPressed = value);
  }

  void _open() {
    HapticFeedback.selectionClick();
    widget.onOpen();
  }

  void _remove() {
    // Heavier than opening: this one takes something away, and the tile it was
    // on is about to disappear from under the finger.
    HapticFeedback.lightImpact();
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final ext = widget.ext;

    return GestureDetector(
      // Opaque, not the default deferToChild: an Image does not absorb a hit,
      // so with deferToChild a tap anywhere on the photo found no child willing
      // to take it and the tile did nothing at all.
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      // Also on cancel: dragging off, or the corner icon winning the gesture,
      // has to release the tile rather than leave it stuck down.
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? _pressedScale : 1,
        duration: _press,
        curve: AppMotion.ease,
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
                label: widget.removeTooltip,
                child: GestureDetector(
                  // Opaque so the corner takes its own taps rather than
                  // letting them through to the tile underneath and opening
                  // the photo the user was trying to remove.
                  behavior: HitTestBehavior.opaque,
                  onTap: _remove,
                  onTapDown: (_) => _setIconPressed(true),
                  onTapUp: (_) => _setIconPressed(false),
                  onTapCancel: () => _setIconPressed(false),
                  child: Padding(
                    // Padded rather than sized: the icon is small, and the tap
                    // target around it needs to be a finger wide.
                    padding: EdgeInsets.all(6.r),
                    child: AnimatedScale(
                      scale: _iconPressed ? _iconPressedScale : 1,
                      duration: _press,
                      curve: AppMotion.ease,
                      child: Icon(
                        widget.removeIcon,
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
            ),
          ],
        ),
        ),
      ),
    );
  }
}
