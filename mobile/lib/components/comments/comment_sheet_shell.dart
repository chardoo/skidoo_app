import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:jperg_app/core/celebration/celebration_overlay.dart';
import 'package:jperg_app/core/celebration/comment_milestone.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Shared bottom-sheet container for every comment surface — the photo sheet,
/// the event sheet, the ads feed sheet.
///
/// Presented like [ShareTargetSheet] and the Hide/Report sheet: flush to the
/// screen edges, rounded across the top two corners only, on the app's own
/// surface colour. It used to be a floating frosted card — inset from both
/// edges, rounded on all four corners, a 52-pixel backdrop blur behind a
/// half-transparent fill, a hairline border and a 28-pixel drop shadow. That
/// is a lot of chrome for a list of comments, and it made this the only sheet
/// in the app that looked like a different app.
///
/// The height is deliberate and shared: see [kCommentSheetFraction], which
/// [CommentPushArea] reads to work out how far to scale the page above it.
class CommentSheetShell extends StatelessWidget {
  const CommentSheetShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.sizeOf(context).height;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    // The sheet gives the keyboard its room out of its own height, so its top
    // edge stays on the same line whether the keyboard is up or down.
    //
    // It used to keep the full [kCommentSheetFraction] and take the keyboard as
    // padding underneath, which asked for `0.63 * screen + keyboard` — more than
    // the screen. A bottom-anchored box cannot grow downwards, so the excess
    // went off the top: the media band that [CommentPushArea] had just laid the
    // photo into was covered by the sheet, leaving a sliver behind the status
    // bar. The photo was still there and still the right size; the sheet was
    // simply on top of it.
    //
    // Which is the whole point of the arrangement — the thing being discussed
    // stays visible while you talk about it, and never more so than while you
    // are typing about it.
    final maxSheetH = screenH * kCommentSheetFraction;
    // The floor is the handle, the header and an input bar — the sheet's own
    // chrome, below which there is nothing left to shrink. Deliberately low:
    // an ordinary phone keyboard leaves about 195 here, and a floor above that
    // would clamp the common case and start eating the band on every device
    // rather than on the pathological one this is for.
    // ...but never more than the keyboard actually leaves. The padding below
    // already spends that space, so a floor above it is a height the sheet
    // cannot have — it would overflow its own column instead of clamping.
    final available = (screenH - keyboardH).clamp(0.0, maxSheetH);
    final minSheetH = 140.h.clamp(0.0, available);
    final sheetH = (maxSheetH - keyboardH).clamp(minSheetH, maxSheetH);

    // Every comment surface in the app is inside this shell, so watching for a
    // milestone here covers all of them at once — and covers only the ones
    // where somebody is actually looking at a comment thread.
    return _MilestoneWatcher(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        // Bottom only. The left/right inset was what made this a floating card
        // rather than a sheet.
        padding: EdgeInsets.only(bottom: keyboardH),
        // Animated on the same curve and duration as the padding above: both
        // are driven by the keyboard height, and a height that snapped while
        // the padding eased would show the sheet's top edge jumping.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: sheetH,
          child: _SheetSurface(
            ext: ext,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag handle ──────────────────────────────────────────────
                Center(
                  child: Container(
                    margin: EdgeInsets.only(
                      top: 14.h,
                      bottom: title != null ? 14.h : 20.h,
                    ),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // ── Header ───────────────────────────────────────────────────
                if (title != null) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 14.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          color: ext.searchHintColor,
                          size: 18.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title!,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white : ext.greetingColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.sp,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle != null) ...[
                                SizedBox(height: 1.h),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    color: ext.searchHintColor,
                                    fontSize: 11.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.10),
                  ),
                ],

                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Milestones ───────────────────────────────────────────────────────────────

/// Watches for "you are the 100th comment" and throws the confetti.
///
/// Mounted once, around every comment sheet, rather than at each of the three
/// call sites — and deliberately *not* at the app root: a celebration should
/// arrive while somebody is looking at the thread they just posted into, not
/// over whatever screen they had moved on to.
///
/// The overlay is opened from a post-frame callback. The notifier fires inside
/// a bloc's event handler, which can land mid-build, and inserting an
/// [OverlayEntry] during build throws.
class _MilestoneWatcher extends StatefulWidget {
  const _MilestoneWatcher({required this.child});

  final Widget child;

  @override
  State<_MilestoneWatcher> createState() => _MilestoneWatcherState();
}

class _MilestoneWatcherState extends State<_MilestoneWatcher> {
  @override
  void initState() {
    super.initState();
    CommentMilestones.instance.pending.addListener(_onMilestone);
  }

  @override
  void dispose() {
    CommentMilestones.instance.pending.removeListener(_onMilestone);
    super.dispose();
  }

  void _onMilestone() {
    final message = CommentMilestones.instance.pending.value;
    if (message == null) return;
    // Consumed straight away, before the frame it will be drawn in: two sheets
    // can be mounted at once during a transition, and both would otherwise
    // celebrate the same comment.
    CommentMilestones.instance.consume();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CelebrationOverlay.show(context, message);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Sheet surface ─────────────────────────────────────────────────────────────

/// The same surface [ShareTargetSheet] and the Hide/Report sheet sit on: the
/// app background, rounded across the top, flush everywhere else.
///
/// Opaque on purpose. The page behind is no longer dimmed — it scales up into
/// the strip above (see [CommentPushArea]) — so anything translucent here
/// would show the photo through the comments.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child, required this.ext});
  final Widget child;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(20.r));

    return Container(
      decoration:
          BoxDecoration(color: ext.homeBackground, borderRadius: radius),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class CommentEmptyState extends StatelessWidget {
  const CommentEmptyState({super.key, required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sheds its parts as the room runs out, rather than overflowing.
    //
    // The sheet is short in the ordinary case, not an exotic one: raising the
    // keyboard to write the first comment leaves this about 60 px, and the
    // full arrangement wants 113 — so the state that says "be the first to say
    // something" was painting a black-and-yellow overflow bar over itself at
    // exactly the moment somebody was being invited to type.
    //
    // The icon goes first: it is decoration, and the sentence is the message.
    // Below two lines' worth, the invitation goes too and the heading stands
    // alone, which still says the thread is empty.
    return LayoutBuilder(builder: (context, constraints) {
      final room = constraints.maxHeight;
      final showIcon = !room.isFinite || room >= 124.h;
      final showInvite = !room.isFinite || room >= 46.h;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 26.sp,
                  color: ext.searchHintColor,
                ),
              ),
              SizedBox(height: 14.h),
            ],
            Text(
              'No comments yet',
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (showInvite) ...[
              SizedBox(height: 5.h),
              Text(
                'Be the first to say something',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
