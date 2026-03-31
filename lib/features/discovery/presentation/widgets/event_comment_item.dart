import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';

// ── Comment item ──────────────────────────────────────────────────────────────

class EventCommentItem extends StatelessWidget {
  const EventCommentItem({
    super.key,
    required this.msg,
    required this.isMe,
    required this.label,
    required this.timeLabel,
    required this.ext,
  });

  final ChatMessage msg;
  final bool isMe;
  final String label;
  final String timeLabel;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final avatarColor = isMe ? ext.accentGold : Colors.blueAccent;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              label[0].toUpperCase(),
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isMe ? ext.accentGold : ext.greetingColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      timeLabel,
                      style: TextStyle(
                          color: ext.searchHintColor, fontSize: 11.sp),
                    ),
                    if (msg.isLocal) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.access_time_rounded,
                          size: 10.sp, color: ext.searchHintColor),
                    ],
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  msg.content,
                  style: TextStyle(
                      color: ext.greetingColor, fontSize: 14.sp, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
