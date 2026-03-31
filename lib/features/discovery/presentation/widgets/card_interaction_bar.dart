import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class CardInteractionBar extends StatelessWidget {
  const CardInteractionBar({
    super.key,
    required this.liked,
    required this.saved,
    required this.likeCount,
    required this.commentCount,
    required this.ext,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  final bool liked;
  final bool saved;
  final int likeCount;
  final int commentCount;
  final AppThemeExtension ext;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Like ────────────────────────────────────────────────────────
          _AnimatedActionBtn(
            onTap: () {
              HapticFeedback.lightImpact();
              onLike();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.elasticOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(liked),
                    color: liked ? const Color(0xFFFF3B5C) : ext.greetingColor,
                    size: 26.sp,
                  ),
                ),
                if (likeCount > 0) ...[
                  SizedBox(width: 5.w),
                  Text(
                    _fmt(likeCount),
                    style: TextStyle(
                      color: liked ? const Color(0xFFFF3B5C) : ext.greetingColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(width: 18.w),

          // ── Comment ──────────────────────────────────────────────────────
          _AnimatedActionBtn(
            onTap: onComment,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mode_comment_outlined,
                    color: ext.greetingColor, size: 24.sp),
                if (commentCount > 0) ...[
                  SizedBox(width: 5.w),
                  Text(
                    _fmt(commentCount),
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(width: 18.w),

          // ── Share (paper plane) ──────────────────────────────────────────
          _AnimatedActionBtn(
            onTap: onShare,
            child: Icon(Icons.near_me_outlined,
                color: ext.greetingColor, size: 24.sp),
          ),

          const Spacer(),

          // ── Bookmark ─────────────────────────────────────────────────────
          _AnimatedActionBtn(
            onTap: () {
              HapticFeedback.selectionClick();
              onSave();
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.elasticOut,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: Icon(
                saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                key: ValueKey(saved),
                color: saved ? ext.accentGold : ext.greetingColor,
                size: 26.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Tap-scale wrapper ─────────────────────────────────────────────────────────

class _AnimatedActionBtn extends StatefulWidget {
  const _AnimatedActionBtn({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_AnimatedActionBtn> createState() => _AnimatedActionBtnState();
}

class _AnimatedActionBtnState extends State<_AnimatedActionBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.85,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(scale: _ctrl, child: widget.child),
    );
  }
}

// Keep for backward compat
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
          Icon(icon, color: iconColor, size: 22.sp),
          if (label.isNotEmpty) ...[
            SizedBox(width: 5.w),
            Text(label,
                style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}
