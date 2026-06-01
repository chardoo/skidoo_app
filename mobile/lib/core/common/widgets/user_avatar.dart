import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

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
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Initials(initial: initial, radius: radius, bg: bg, fg: fg),
          errorWidget: (_, __, ___) => _Initials(initial: initial, radius: radius, bg: bg, fg: fg),
        ),
      );
    } else {
      avatar = _Initials(initial: initial, radius: radius, bg: bg, fg: fg);
    }

    if (onTap == null) return avatar;
    return Semantics(button: true, child: GestureDetector(onTap: onTap, child: avatar));
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
