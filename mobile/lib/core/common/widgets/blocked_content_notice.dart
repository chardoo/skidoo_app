import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// What a creator sees where their blocked album or photo used to be.
///
/// Blocked content leaves every other surface in the app — feeds, search,
/// albums, link previews, libraries — and stays on exactly one: its creator's
/// own library. That is deliberate. A takedown nobody can see is a takedown
/// that becomes a support ticket: the album is missing, nothing says why, and
/// the only reading left is that the platform lost it.
///
/// So the tile stays where it was, the picture is covered rather than removed,
/// and the reason the moderator gave is printed on it. Covered and not deleted
/// because the creator knows what they posted; what they do not know is what
/// happened to it.
///
/// Two shapes, one explanation:
///
///   [BlockedOverlay]      over a tile or a grid cell, as a scrim with a label.
///   [BlockedContentNotice] a block of text for a detail screen, where there is
///                          room for the whole reason.
class BlockedOverlay extends StatelessWidget {
  const BlockedOverlay({super.key, this.label = 'Blocked', this.compact = false});

  final String label;

  /// Drops the label to an icon alone, for a cell too small to read on.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        // Deliberately not swallowing taps: the creator can still open the
        // album to read the full reason, and a tile that does nothing when
        // tapped is indistinguishable from a broken one.
        child: Container(
          // Heavy enough that the photograph underneath is not legible —
          // the content is blocked, and a thin scrim would leave it on show
          // to anyone looking over a shoulder. Not opaque, because which
          // album this is still has to be recognisable to its owner.
          color: Colors.black.withValues(alpha: 0.72),
          alignment: Alignment.center,
          padding: EdgeInsets.all(AppSpacing.sm.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block_rounded,
                color: Colors.white,
                size: compact ? 18.sp : 26.sp,
              ),
              if (!compact) ...[
                SizedBox(height: 6.h),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The full explanation, for a screen with room for it.
class BlockedContentNotice extends StatelessWidget {
  const BlockedContentNotice({
    super.key,
    required this.reason,
    this.subject = 'This content',
  });

  /// What the moderator gave as the reason. The server always sends one — a
  /// marked album with an empty explanation reads as a rendering fault rather
  /// than a decision — so this is never usefully empty, and an empty one still
  /// renders the heading alone rather than a blank box.
  final String? reason;

  /// "This album", "This photo". Named by the caller because only it knows.
  final String subject;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final text = (reason ?? '').trim();

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSpacing.lg.w),
        decoration: BoxDecoration(
          // The app's own error ground rather than a red of its own: this is
          // information, not an alarm, and it has to sit inside a page the
          // reader is otherwise using normally.
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(color: const Color(0xFFE25C5C), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.block_rounded, color: const Color(0xFFE25C5C), size: 20.sp),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$subject is blocked',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                  if (text.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      text,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 12.sp,
                        height: 1.35,
                      ),
                    ),
                  ],
                  SizedBox(height: 6.h),
                  Text(
                    // Said plainly, because the next thing a creator does is
                    // look for the button that fixes it — and there isn't one.
                    'Only you can see it. Nobody else can find it in the app.',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 12.sp,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
