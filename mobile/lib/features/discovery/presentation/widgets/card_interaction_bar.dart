import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';

class CardInteractionBar extends StatelessWidget {
  const CardInteractionBar({
    super.key,
    required this.liked,
    required this.disliked,
    required this.saved,
    required this.likeCount,
    required this.dislikeCount,
    required this.commentCount,
    required this.ext,
    required this.onLike,
    required this.onDislike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    this.onMessage,
    this.onShareExternal,
    this.commentsEnabled = true,
  });

  final bool liked;
  final bool disliked;
  final bool saved;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final bool commentsEnabled;
  final AppThemeExtension ext;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  /// When non-null, a DM icon is shown between the spacer and the bookmark.
  final VoidCallback? onMessage;

  /// When non-null, a direct "share to other apps" icon (native OS share
  /// sheet) is shown right next to [onShare] — its own tap target, not
  /// nested inside whatever [onShare] opens. Shows a spinner while the
  /// download-then-share round trip is in flight.
  final Future<void> Function()? onShareExternal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Like ────────────────────────────────────────────────────────
          _AnimatedActionBtn(
            semanticLabel: 'Like',
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
                    Icons.favorite_rounded,
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

          SizedBox(width: 14.w),

          // ── Dislike ──────────────────────────────────────────────────────
          _AnimatedActionBtn(
            semanticLabel: 'Dislike',
            onTap: () {
              HapticFeedback.lightImpact();
              onDislike();
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
                    Icons.thumb_down_rounded,
                    key: ValueKey(disliked),
                    color: disliked
                        ? const Color(0xFF5B6EF5)
                        : ext.greetingColor,
                    size: 24.sp,
                  ),
                ),
                if (dislikeCount > 0) ...[
                  SizedBox(width: 5.w),
                  Text(
                    _fmt(dislikeCount),
                    style: TextStyle(
                      color: disliked
                          ? const Color(0xFF5B6EF5)
                          : ext.greetingColor,
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
          if (commentsEnabled)
            _AnimatedActionBtn(
              semanticLabel: 'Comment',
              onTap: onComment,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mode_comment_rounded,
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
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.comments_disabled_rounded,
                    color: ext.searchHintColor.withValues(alpha: 0.4),
                    size: 24.sp),
                if (commentCount > 0) ...[
                  SizedBox(width: 5.w),
                  Text(
                    _fmt(commentCount),
                    style: TextStyle(
                      color: ext.searchHintColor.withValues(alpha: 0.4),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),

          SizedBox(width: 18.w),

          // ── Share (paper plane) — send to a user via in-app DM ───────────
          _AnimatedActionBtn(
            semanticLabel: 'Send',
            onTap: onShare,
            child: Icon(Icons.near_me_rounded,
                color: ext.greetingColor, size: 24.sp),
          ),

          // ── Share externally — its own tap target, not nested inside the
          // "Send" sheet — direct native OS share sheet.
          if (onShareExternal != null) ...[
            SizedBox(width: 18.w),
            _ExternalShareAction(ext: ext, onTap: onShareExternal!),
          ],

          const Spacer(),

          // ── Message (DM) — optional, shown before bookmark ────────────────
          if (onMessage != null) ...[
            SizedBox(width: 6.w),
            _AnimatedActionBtn(
              semanticLabel: 'Message',
              onTap: () {
                HapticFeedback.lightImpact();
                onMessage!();
              },
              child: Icon(
                Icons.chat_bubble_rounded,
                color: ext.accentGold,
                size: 24.sp,
              ),
            ),
          ],

          // ── Bookmark ──────────────────────────────────────────────────────
          _AnimatedActionBtn(
            semanticLabel: 'Save',
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
                Icons.bookmark_rounded,
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

// ── External share (native OS share sheet) ────────────────────────────────────

class _ExternalShareAction extends StatefulWidget {
  const _ExternalShareAction({required this.ext, required this.onTap});
  final AppThemeExtension ext;
  final Future<void> Function() onTap;

  @override
  State<_ExternalShareAction> createState() => _ExternalShareActionState();
}

class _ExternalShareActionState extends State<_ExternalShareAction> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AnimatedActionBtn(
      semanticLabel: 'Share to other apps',
      onTap: _handleTap,
      child: _busy
          ? SizedBox(
              width: 20.sp,
              height: 20.sp,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: widget.ext.greetingColor),
            )
          : Icon(Icons.ios_share_rounded,
              color: widget.ext.greetingColor, size: 22.sp),
    );
  }
}

// ── Tap-scale wrapper ─────────────────────────────────────────────────────────

class _AnimatedActionBtn extends StatefulWidget {
  const _AnimatedActionBtn(
      {required this.child, required this.onTap, this.semanticLabel});
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;

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
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: ScaleTransition(scale: _ctrl, child: widget.child),
      ),
    );
  }
}

// ── Follow button — shared across event, campaign, and request cards ──────────

class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.photographerId,
    this.onImage = false,
    this.initialFollowing = false,
    this.onLoginRequired,
    this.compact = false,
  });

  /// The photographer/creator to follow or unfollow.
  final String photographerId;

  /// When true, colours are adjusted for use on a dark image overlay.
  final bool onImage;

  /// Seed state — set true when the viewer already follows this creator.
  final bool initialFollowing;

  /// When set, tapping the button calls this instead of attempting to follow.
  /// Use for unauthenticated users to show the login prompt.
  final VoidCallback? onLoginRequired;

  /// When true, renders as a small circular +/check badge (meant to overlay
  /// the bottom of an avatar, TikTok-style) instead of the "Follow" text pill.
  final bool compact;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton>
    with SingleTickerProviderStateMixin {
  late bool _following;
  bool _loading = false;
  final _repo = FollowRepository();

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.88,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void initState() {
    super.initState();
    _following = widget.initialFollowing ||
        FollowRepository.followedIds.contains(widget.photographerId);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.onLoginRequired != null) {
      widget.onLoginRequired!();
      return;
    }
    if (_loading || widget.photographerId.isEmpty) return;
    HapticFeedback.lightImpact();
    final willFollow = !_following;
    await _ctrl.reverse();
    if (!mounted) return;
    setState(() {
      _following = willFollow;
      _loading = true;
    });
    _ctrl.forward();
    try {
      if (willFollow) {
        await _repo.follow(widget.photographerId);
      } else {
        await _repo.unfollow(widget.photographerId);
      }
    } catch (_) {
      // Revert optimistic update on error.
      if (mounted) setState(() => _following = !willFollow);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final onImg = widget.onImage;

    if (widget.compact) {
      return Semantics(
        button: true,
        label: _following ? 'Unfollow' : 'Follow',
        child: GestureDetector(
          onTap: _toggle,
          child: ScaleTransition(
            scale: _ctrl,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                color: _following ? Colors.white24 : ext.accentGold,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: _loading
                  ? SizedBox(
                      width: 10.w,
                      height: 10.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _following ? Icons.check_rounded : Icons.add_rounded,
                      color: Colors.white,
                      size: 14.sp,
                    ),
            ),
          ),
        ),
      );
    }

    return Semantics(button: true, label: 'Toggle', child: GestureDetector(
      onTap: _toggle,
      child: ScaleTransition(
        scale: _ctrl,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: _following
                ? (onImg
                    ? Colors.white.withValues(alpha: 0.18)
                    : ext.glassFill)
                : (onImg ? Colors.white : ext.accentGold),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: _following
                  ? (onImg
                      ? Colors.white.withValues(alpha: 0.45)
                      : ext.glassBorder)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: _loading
              ? SizedBox(
                  width: 12.w,
                  height: 12.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _following
                        ? (onImg ? Colors.white70 : ext.searchHintColor)
                        : (onImg ? ext.accentGold : Colors.white),
                  ),
                )
              : Text(
                  _following ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: _following
                        ? (onImg ? Colors.white70 : ext.greetingColor)
                        : (onImg ? ext.accentGold : Colors.white),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
        ),
      ),
    ));
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
    return Semantics(button: true, label: label, child: GestureDetector(
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
    ));
  }
}
