import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

// ── Comment input bar ─────────────────────────────────────────────────────────

class EventCommentInputBar extends StatelessWidget {
  const EventCommentInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.ext,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 20.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        border: Border(
            top:
                BorderSide(color: ext.searchHintColor.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                hintStyle:
                    TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                filled: true,
                fillColor: ext.searchFieldFill,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(22.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 10.h),
                isDense: true,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                  color: ext.accentGold, shape: BoxShape.circle),
              alignment: Alignment.center,
              child:
                  Icon(Icons.send_rounded, color: Colors.white, size: 20.sp),
            ),
          ),
        ],
      ),
    );
  }
}
