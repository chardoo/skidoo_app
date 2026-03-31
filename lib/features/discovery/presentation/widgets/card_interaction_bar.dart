import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class CardInteractionBar extends StatelessWidget {
  const CardInteractionBar({
    super.key,
    required this.liked,
    required this.saved,
    required this.likeCount,
    required this.ext,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  final bool liked;
  final bool saved;
  final int likeCount;
  final AppThemeExtension ext;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 4.h),
      child: Row(
        children: [
          // Like
          CardActionButton(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: liked ? const Color(0xFFE53935) : ext.searchHintColor,
            label: likeCount > 0 ? _fmt(likeCount) : '',
            onTap: onLike,
            ext: ext,
          ),
          SizedBox(width: 20.w),

          // Comment
          CardActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: ext.searchHintColor,
            label: '',
            onTap: onComment,
            ext: ext,
          ),
          SizedBox(width: 20.w),

          // Share
          CardActionButton(
            icon: Icons.share_outlined,
            iconColor: ext.searchHintColor,
            label: '',
            onTap: onShare,
            ext: ext,
          ),

          const Spacer(),

          // Save / Bookmark
          GestureDetector(
            onTap: onSave,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                key: ValueKey(saved),
                color: saved ? ext.accentGold : ext.searchHintColor,
                size: 24.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class CardActionButton extends StatelessWidget {
  const CardActionButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    required this.ext,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(icon,
                key: ValueKey(icon), color: iconColor, size: 22.sp),
          ),
          if (label.isNotEmpty) ...[
            SizedBox(width: 5.w),
            Text(
              label,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
