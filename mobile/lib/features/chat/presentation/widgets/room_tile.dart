import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class RoomTile extends StatelessWidget {
  const RoomTile({
    super.key,
    required this.room,
    required this.onTap,
    this.unreadCount = 0,
    this.lastMessageAt,
    this.currentUserId = '',
  });

  final ChatRoom room;
  final VoidCallback onTap;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final hasUnread = unreadCount > 0;

    return Semantics(
      button: true,
      label: hasUnread
          ? 'Chat with ${room.displayNameFor(currentUserId)}, $unreadCount unread'
          : 'Chat with ${room.displayNameFor(currentUserId)}',
      child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: 10.h),
        child: Row(
          children: [
            _RoomAvatar(type: room.type, ext: ext, isAdmin: room.hasAdminParticipant),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (room.hasAdminParticipant) ...[
                              Icon(Icons.verified_rounded,
                                  size: 14.sp, color: ext.infoBlue),
                              SizedBox(width: AppSpacing.xs.w),
                            ],
                            Flexible(
                              child: Text(
                                room.displayNameFor(currentUserId),
                                style: TextStyle(
                                  color: ext.greetingColor,
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 15.sp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (lastMessageAt != null)
                        Text(
                          _formatTime(lastMessageAt!),
                          style: TextStyle(
                            color: hasUnread
                                ? ext.greetingColor
                                : ext.searchHintColor,
                            fontSize: 11.sp,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _subtitle(room, currentUserId),
                          style: TextStyle(
                            color: ext.searchHintColor,
                            fontSize: 13.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: ext.accentGold,
                            borderRadius: BorderRadius.circular(AppRadius.xl.r),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _subtitle(ChatRoom room, String myId) {
    switch (room.type) {
      case RoomType.global:
        return 'Everyone';
      case RoomType.direct:
        return room.peerName(myId) ?? 'Direct message';
      case RoomType.event:
        return 'Event discussion';
      case RoomType.eventPrivate:
        return 'Private event room';
      case RoomType.photo:
        return 'Photo comments';
      case RoomType.sample:
        return 'Sample image chat';
      case RoomType.group:
        final count = room.participants.where((p) => !p.isPending).length;
        return count > 1 ? '$count members' : 'Group chat';
      case RoomType.unknown:
        return 'Chat room';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour:$m $period';
    } else if (diff == 1) {
      return 'Yesterday';
    } else if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    }
  }
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({required this.type, required this.ext, this.isAdmin = false});
  final RoomType type;
  final AppThemeExtension ext;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    if (isAdmin) {
      return Container(
        width: 52.w,
        height: 52.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ext.infoBlue.withValues(alpha: 0.18),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.shield_rounded, color: ext.infoBlue, size: 22.sp),
      );
    }
    final (icon, color) = _iconAndColor(ext);
    return CircleAvatar(
      radius: 26.r,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Icon(icon, color: color, size: 22.sp),
    );
  }

  (IconData, Color) _iconAndColor(AppThemeExtension ext) {
    switch (type) {
      case RoomType.global:
        return (Icons.public_rounded, Colors.cyan);
      case RoomType.direct:
        return (Icons.person_rounded, Colors.blueAccent);
      case RoomType.event:
        return (Icons.event_rounded, Colors.green);
      case RoomType.eventPrivate:
        return (Icons.lock_rounded, Colors.deepPurple);
      case RoomType.photo:
        return (Icons.camera_alt_rounded, Colors.pinkAccent);
      case RoomType.sample:
        return (Icons.photo_rounded, Colors.teal);
      case RoomType.group:
        return (Icons.group_rounded, Colors.orange);
      case RoomType.unknown:
        return (Icons.chat_bubble_rounded, ext.searchHintColor);
    }
  }
}
