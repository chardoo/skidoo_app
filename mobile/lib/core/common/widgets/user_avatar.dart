import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// Circular avatar that shows a network image when [imageUrl] is set,
/// or a themed initial/letter when no image is available.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initial,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
  });

  final String initial;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final bg = backgroundColor ?? ext.avatarBackground;
    final fg = foregroundColor ?? ext.avatarForeground;

    Widget avatar;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(radius.r),
        child: Semantics(
          image: true,
          label: 'Profile picture',
          // A profile photo is the one image in the app that changes under a
          // widget that stays put — swapped the moment an upload finishes, on
          // every screen showing it at once. JpergImage cross-fades that
          // instead of blinking through the initials placeholder, and sizes the
          // decode to the avatar rather than downloading a full-resolution
          // portrait for a 40 px circle.
          child: JpergImage(
            imageUrl: imageUrl!,
            width: radius * 2,
            height: radius * 2,
            logicalWidth: radius * 2,
            fit: BoxFit.cover,
            placeholder: (_, __) => _Initials(initial: initial, radius: radius, bg: bg, fg: fg),
            errorWidget: (_, __, ___) => _Initials(initial: initial, radius: radius, bg: bg, fg: fg),
          ),
        ),
      );
    } else {
      avatar = _Initials(initial: initial, radius: radius, bg: bg, fg: fg);
    }

    if (onTap == null) return avatar;
    return Semantics(button: true, label: 'User avatar', child: GestureDetector(onTap: onTap, child: avatar));
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.initial,
    required this.radius,
    required this.bg,
    required this.fg,
  });

  final String initial;
  final double radius;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius.r,
      backgroundColor: bg,
      child: Text(
        initial.isNotEmpty ? initial[0].toUpperCase() : '?',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: (radius * 0.7).sp,
        ),
      ),
    );
  }
}
