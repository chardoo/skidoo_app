import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:jperg_app/core/celebration/comment_milestone_watcher.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Which end of the thread comes first.
///
/// Every comment surface in the app is fed a list that is already newest-first
/// — the chat room sorts its messages that way and the feed's endpoint returns
/// them that way — so this is a choice between that list and its reverse, and
/// [apply] is the only place that should be saying so.
enum CommentSort {
  newest('Newest', 'Newest first'),
  oldest('Oldest', 'Oldest first');

  const CommentSort(this.short, this.label);

  /// What the control reads when this one is chosen.
  final String short;

  /// The same thing said in full, for the menu row and the screen reader —
  /// "Newest" alone does not say first or last.
  final String label;

  /// [newestFirst] in this order. Takes the list the surface already has,
  /// which must be newest-first.
  List<T> apply<T>(List<T> newestFirst) =>
      this == CommentSort.newest ? newestFirst : newestFirst.reversed.toList();
}

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
    this.sort,
    this.onSortChanged,
  });

  final Widget child;

  /// The header. "Comments" everywhere, and deliberately not the name of the
  /// post: the thing being discussed is on screen directly above this — that
  /// is the whole point of the arrangement — so naming it again in the one
  /// line the sheet has says nothing the reader cannot see.
  final String? title;
  final String? subtitle;

  /// The order the thread is in, and how to change it. The control is drawn
  /// only when both are given, so a surface that has no say still gets a plain
  /// header.
  final CommentSort? sort;
  final ValueChanged<CommentSort>? onSortChanged;

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
    return CommentMilestoneWatcher(
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
                        if (sort != null && onSortChanged != null)
                          _SortControl(
                            sort: sort!,
                            onChanged: onSortChanged!,
                            ext: ext,
                            isDark: isDark,
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

// ── Sort control ─────────────────────────────────────────────────────────────

/// The pill on the right of the header: the order the thread is in, and a menu
/// to change it.
///
/// It shows the order rather than the word "Sort", so the header answers the
/// question without being opened — which is the question the reader of a busy
/// thread actually has.
class _SortControl extends StatelessWidget {
  const _SortControl({
    required this.sort,
    required this.onChanged,
    required this.ext,
    required this.isDark,
  });

  final CommentSort sort;
  final ValueChanged<CommentSort> onChanged;
  final AppThemeExtension ext;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CommentSort>(
      initialValue: sort,
      // The button's own label as well as its tooltip, and it has to carry the
      // order: "Sort comments" alone leaves a screen reader unable to say
      // which way round the thread already is.
      tooltip: 'Sort comments, ${sort.label}',
      position: PopupMenuPosition.under,
      color: ext.cardSurface,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final option in CommentSort.values)
          PopupMenuItem<CommentSort>(
            value: option,
            height: 40.h,
            child: Row(
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 16.sp,
                  // Held rather than hidden: dropping the tick on the
                  // inactive row shifts its label and the two read as
                  // different widths of the same word.
                  color: option == sort ? ext.accentGold : Colors.transparent,
                ),
                SizedBox(width: 8.w),
                // Flexible, because the menu is only as wide as the button it
                // hangs off: at a large text scale "Oldest first" is wider
                // than that box, and a bare Text in a Row overflows rather
                // than wrapping.
                Flexible(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      color: isDark ? Colors.white : ext.greetingColor,
                      fontSize: 14.sp,
                      fontWeight:
                          option == sort ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      padding: EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sort.short,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 2.w),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16.sp,
              color: ext.searchHintColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Milestones ───────────────────────────────────────────────────────────────

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

// ── Locked state ──────────────────────────────────────────────────────────────

/// The whole sheet body when the post has comments turned off.
///
/// Distinct from [CommentEmptyState], and the difference is the point: an empty
/// thread is an invitation — "be the first to say something", with an input bar
/// under it to do so. This is a closed door, so it replaces the thread *and*
/// the input bar rather than greying one out. A disabled text field still reads
/// as something to try.
///
/// It matters most on a post swiped to rather than opened: the sheet follows
/// the feed, so a reader can arrive here from a post where they were mid-
/// sentence, and the bar going away is what says the conversation is not on
/// offer here.
class CommentsLockedState extends StatelessWidget {
  const CommentsLockedState({super.key, required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sheds its parts as the room runs out, exactly as [CommentEmptyState]
    // does — this state has the sheet's full height rather than sharing it
    // with an input bar, but the keyboard can still be up from the post
    // before.
    return LayoutBuilder(builder: (context, constraints) {
      final room = constraints.maxHeight;
      final showIcon = !room.isFinite || room >= 124.h;
      final showReason = !room.isFinite || room >= 46.h;

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
                  Icons.lock_outline_rounded,
                  size: 26.sp,
                  color: ext.searchHintColor,
                ),
              ),
              SizedBox(height: 14.h),
            ],
            Text(
              'Comments are turned off',
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (showReason) ...[
              SizedBox(height: 5.h),
              // Flexible for the reason [CommentEmptyState] gives: this
              // sentence is longer than that one, so it wraps sooner, and the
              // threshold that let it through was measured on one line.
              Flexible(
                child: Text(
                  'The creator has closed this conversation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
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
              // Flexible, because the thresholds above are measured against a
              // sentence on one line. At a large text scale — or in any sheet
              // narrow enough — this wraps to two, and a fixed threshold that
              // has already decided there is room then overflows by the extra
              // line. This clips the second line instead, which is the same
              // bargain the icon and the invitation make above.
              Flexible(
                child: Text(
                  'Be the first to say something',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
