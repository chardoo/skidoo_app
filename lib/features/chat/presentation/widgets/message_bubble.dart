import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onUserTap,
  });

  final ChatMessage message;
  final bool isMe;

  /// Called when another user's avatar is tapped. Not fired for own messages.
  final VoidCallback? onUserTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 12.w),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender label (only for other people's messages)
          if (!isMe)
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 2.h),
              child: Text(
                message.senderRole,
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                _Avatar(
                  senderId: message.senderId,
                  ext: ext,
                  onTap: onUserTap,
                ),
                SizedBox(width: 6.w),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isMe
                        ? ext.accentGold
                        : ext.cardSurface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18.r),
                      topRight: Radius.circular(18.r),
                      bottomLeft: Radius.circular(isMe ? 18.r : 4.r),
                      bottomRight: Radius.circular(isMe ? 4.r : 18.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : ext.greetingColor,
                          fontSize: 14.sp,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.createdAt),
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white70
                                  : ext.searchHintColor,
                              fontSize: 9.sp,
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: 3.w),
                            Icon(
                              message.isLocal
                                  ? Icons.access_time_rounded
                                  : Icons.done_all_rounded,
                              size: 11.sp,
                              color: Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.senderId, required this.ext, this.onTap});
  final String senderId;
  final AppThemeExtension ext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial =
        senderId.isNotEmpty ? senderId[0].toUpperCase() : '?';
    final avatar = CircleAvatar(
      radius: 14.r,
      backgroundColor: ext.avatarBackground,
      child: Text(
        initial,
        style: TextStyle(
          color: ext.avatarForeground,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }
}
