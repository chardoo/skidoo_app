import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/chat_time.dart';
import 'package:jperg_app/features/chat/presentation/widgets/room_avatar.dart';
import 'package:jperg_app/features/chat/presentation/widgets/system_notice_text.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// One row of the inbox: avatar, name, the last thing said, and when.
class RoomTile extends StatelessWidget {
  const RoomTile({
    super.key,
    required this.room,
    required this.onTap,
    this.unreadCount = 0,
    this.lastMessageAt,
    this.currentUserId = '',
    this.liveMessage,
  });

  final ChatRoom room;
  final VoidCallback onTap;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String currentUserId;

  /// A message that arrived after the room list was fetched, so newer than
  /// [ChatRoom.lastMessage] and shown in its place.
  final LastMessage? liveMessage;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final hasUnread = unreadCount > 0;
    final name = room.displayNameFor(currentUserId);
    final timestamp =
        lastMessageAt ?? liveMessage?.createdAt ?? room.lastMessage?.createdAt;

    return Semantics(
      button: true,
      label: hasUnread
          ? 'Chat with $name, $unreadCount unread'
          : 'Chat with $name',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RoomAvatar(
                room: room,
                currentUserId: currentUserId,
                radius: 26,
              ),
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
                                  name,
                                  style: TextStyle(
                                    color: ext.greetingColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (room.isMutedFor(currentUserId)) ...[
                                SizedBox(width: AppSpacing.xs.w),
                                Icon(Icons.notifications_off_rounded,
                                    size: 13.sp, color: ext.searchHintColor),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm.w),
                        if (timestamp != null)
                          Text(
                            _formatTime(timestamp),
                            style: TextStyle(
                              // Unread pulls the timestamp into the accent
                              // colour, so the eye finds the new rows first.
                              color: hasUnread
                                  ? ext.accentGold
                                  : ext.searchHintColor,
                              fontSize: 12.sp,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _preview(context),
                            style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 13.sp,
                              fontWeight:
                                  hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          SizedBox(width: AppSpacing.sm.w),
                          Container(
                            constraints: BoxConstraints(minWidth: 20.w),
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: ext.accentGold,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xl.r),
                            ),
                            alignment: Alignment.center,
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

  /// The line under the name: what was actually last said, falling back to a
  /// description of the room when nothing has been.
  String _preview(BuildContext context) {
    // The live one wins when present: the bloc clears these on every fetch, so
    // anything still here arrived after the server built its copy.
    final last = liveMessage ?? room.lastMessage;

    if (last != null) {
      final systemType = last.systemType;
      if (systemType != null) {
        final notice = systemNoticeText(
          systemType: systemType,
          actorName: last.senderName,
          isMe: last.senderId == currentUserId,
        );
        if (notice != null) return notice;
      }

      final text = last.content?.trim();
      if (text != null && text.isNotEmpty) {
        // Groups need to say who spoke; a DM has only one other person in it.
        final mine = last.senderId == currentUserId;
        if (room.type == RoomType.group) {
          final who = mine ? 'You' : _firstName(last.senderName);
          return who.isEmpty ? text : '$who: $text';
        }
        return text;
      }

      if (last.hasImage) {
        final mine = last.senderId == currentUserId;
        return mine ? 'You sent a photo' : 'Sent a photo';
      }

      // Ciphertext from before encryption was switched off, which the server
      // cannot preview and this device may not hold the keys for.
      if (last.isEncrypted) return 'Message';
    }

    return _emptyRoomSubtitle();
  }

  String _emptyRoomSubtitle() {
    switch (room.type) {
      case RoomType.group:
        final count = room.participants.where((p) => !p.isPending).length;
        return count > 1 ? '$count members' : 'No messages yet';
      case RoomType.direct:
        return 'No messages yet';
      case RoomType.event:
      case RoomType.eventPrivate:
        return 'Event discussion';
      case RoomType.photo:
        return 'Photo comments';
      case RoomType.sample:
        return 'Sample image chat';
      case RoomType.global:
      case RoomType.unknown:
        return 'No messages yet';
    }
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }

  /// Timestamps are UTC until [ChatTime] converts them — see that class. This
  /// method used to read the hour and the day off them directly, which showed
  /// every user outside UTC a time and a day that were not theirs.
  String _formatTime(DateTime dt) {
    final diff = ChatTime.daysAgo(dt);
    if (diff == 0) return ChatTime.clock12(dt);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return ChatTime.weekday(dt);
    // Older than a week gets a date — "Tuesday" three months ago tells you
    // nothing.
    return ChatTime.shortDate(dt);
  }
}
