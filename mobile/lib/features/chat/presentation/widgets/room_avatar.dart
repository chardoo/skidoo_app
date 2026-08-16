import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// The circular image at the head of a room — in the inbox, the conversation
/// header, and the info screens.
///
/// Resolves what to show in one place, because "the room's picture" means three
/// different things: a group's own photo, the other person's avatar in a DM, and
/// an icon for the room types that have no face behind them at all.
class RoomAvatar extends StatelessWidget {
  const RoomAvatar({
    super.key,
    required this.room,
    required this.currentUserId,
    this.radius = 26,
    this.onTap,
  });

  final ChatRoom room;
  final String currentUserId;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // An official room is badged rather than shown with a face — knowing it is
    // Jperg matters more than which admin happens to be in it.
    if (room.hasAdminParticipant) {
      return _IconAvatar(
        icon: Icons.shield_rounded,
        color: ext.infoBlue,
        radius: radius,
        onTap: onTap,
      );
    }

    final image = room.avatarFor(currentUserId);
    if (image != null && image.isNotEmpty) {
      return UserAvatar(
        imageUrl: image,
        initial: room.displayNameFor(currentUserId),
        radius: radius,
        onTap: onTap,
      );
    }

    // A named room falls back to its initial; the rest to an icon, since
    // "Photo comments" has no meaningful letter.
    final name = room.displayNameFor(currentUserId);
    final usesInitial =
        room.type == RoomType.direct || room.type == RoomType.group;
    if (usesInitial && name.isNotEmpty) {
      return UserAvatar(initial: name, radius: radius, onTap: onTap);
    }

    final (icon, color) = _iconFor(room.type, ext);
    return _IconAvatar(
      icon: icon,
      color: color,
      radius: radius,
      onTap: onTap,
    );
  }

  (IconData, Color) _iconFor(RoomType type, AppThemeExtension ext) {
    switch (type) {
      case RoomType.event:
      case RoomType.eventPrivate:
        return (Icons.event_rounded, ext.accentGold);
      case RoomType.photo:
      case RoomType.sample:
        return (Icons.photo_rounded, ext.accentGold);
      case RoomType.group:
        return (Icons.group_rounded, ext.accentGold);
      case RoomType.direct:
        return (Icons.person_rounded, ext.accentGold);
      case RoomType.global:
      case RoomType.unknown:
        return (Icons.chat_bubble_rounded, ext.searchHintColor);
    }
  }
}

class _IconAvatar extends StatelessWidget {
  const _IconAvatar({
    required this.icon,
    required this.color,
    required this.radius,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius.r,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: (radius * 0.85).sp),
    );
    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
