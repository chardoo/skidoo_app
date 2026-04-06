import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';

class RoomTile extends StatelessWidget {
  const RoomTile({
    super.key,
    required this.room,
    required this.onTap,
    this.unreadCount = 0,
  });

  final ChatRoom room;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        constraints: BoxConstraints(minHeight: 88.h),
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: ext.accentGold.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            _RoomIcon(type: room.type, ext: ext),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.displayName,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _subtitle(room),
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 11.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: EdgeInsets.only(right: 6.w),
                padding:
                    EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: ext.accentGold,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: ext.accentGold, size: 18.sp),
          ],
        ),
      ),
    );
  }

  String _subtitle(ChatRoom room) {
    switch (room.type) {
      case RoomType.global:
        return 'Everyone';
      case RoomType.direct:
        final count = room.participants.length;
        return count > 0 ? '$count participants' : '1-on-1 chat';
      case RoomType.event:
        return 'Event discussion';
      case RoomType.eventPrivate:
        return 'Private event room';
      case RoomType.sample:
        return 'Sample image chat';
      case RoomType.unknown:
        return 'Chat room';
    }
  }
}

class _RoomIcon extends StatelessWidget {
  const _RoomIcon({required this.type, required this.ext});
  final RoomType type;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color bg;

    switch (type) {
      case RoomType.global:
        icon = Icons.public_rounded;
        bg = ext.accentGold;
        break;
      case RoomType.direct:
        icon = Icons.person_rounded;
        bg = Colors.blueAccent;
        break;
      case RoomType.event:
        icon = Icons.event_rounded;
        bg = Colors.green;
        break;
      case RoomType.eventPrivate:
        icon = Icons.lock_rounded;
        bg = Colors.deepPurple;
        break;
      case RoomType.sample:
        icon = Icons.photo_rounded;
        bg = Colors.teal;
        break;
      case RoomType.unknown:
        icon = Icons.chat_bubble_rounded;
        bg = ext.searchHintColor;
        break;
    }

    return Container(
      width: 42.w,
      height: 42.h,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12.r),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: bg, size: 20.sp),
    );
  }
}
