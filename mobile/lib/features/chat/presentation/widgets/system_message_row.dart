import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/system_notice_text.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// A system notice in the conversation — "You created this group", "Devon
/// accepted group invite" — centred and italic, with no bubble.
///
/// Returns an empty box for a `system_type` this build doesn't recognise, so a
/// newer server can add one without leaving a gap in an older app's timeline.
class SystemMessageRow extends StatelessWidget {
  const SystemMessageRow({
    super.key,
    required this.message,
    required this.currentUserId,
  });

  final ChatMessage message;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final systemType = message.systemType;
    if (systemType == null) return const SizedBox.shrink();

    final text = systemNoticeText(
      systemType: systemType,
      actorName: message.senderName,
      isMe: message.senderId == currentUserId,
    );
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: 3.h, horizontal: AppSpacing.xl.w),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 12.sp,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
