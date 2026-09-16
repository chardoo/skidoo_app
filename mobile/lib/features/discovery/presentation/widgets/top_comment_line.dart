import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The standout comment, drawn the way Shorts draws it: a dark translucent
/// capsule holding the commenter's avatar and what they said, sitting directly
/// above the post's own text.
///
/// It is **not** a replacement for the caption. This used to take the caption's
/// line for five seconds and then hand it back, which meant the post's own
/// description and hashtags were gone for as long as the comment was up, and
/// the comment was gone for the rest of the time. The reference puts the two on
/// top of each other — comment, then name, then caption — and nothing is ever
/// hidden to make room for anything else.
///
/// Its own file rather than a private class in the card, for a reason worth
/// keeping: `reaction_buttons_transparent_test` audits the rail files for
/// filled glyphs that are not the active half of a conditional. That rule is
/// right for a button somebody taps and wrong for the ornament of a label, so
/// this lives outside those files and the guard stays as strict as it was.
class TopCommentLine extends StatelessWidget {
  const TopCommentLine({
    super.key,
    required this.comment,
    required this.onTap,
  });

  final TopComment comment;
  final VoidCallback onTap;

  /// Matches the reference: big enough to recognise a face, small enough that
  /// the capsule stays one line tall for a short comment.
  static const double _avatarRadius = 13;

  /// The letter [UserAvatar] falls back to when the commenter has no picture,
  /// and for a comment whose author no longer exists. A letter rather than a
  /// silhouette: every capsule in a feed of these would otherwise carry the
  /// same grey outline of a person.
  String get _initial {
    final name = comment.authorName.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Top comment by ${comment.authorName}. '
          '${comment.likeCount} likes. Tap to open comments.',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Aligned left and sized to its content: a one-word comment gets a
        // short capsule rather than a bar across the photo. The card's own
        // `right:` inset is what stops a long one reaching the action rail.
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm.w,
              vertical: 6.h,
            ),
            decoration: BoxDecoration(
              // Dark enough to carry white text over a bright photo, sheer
              // enough to read as something laid on the image rather than a
              // panel cut out of it.
              color: Colors.black.withValues(alpha: 0.55),
              // A capsule at any height: the radius clamps to half the box, so
              // one line is a pill and two lines are a rounded rectangle with
              // fully round ends — which is what the reference shows.
              borderRadius: BorderRadius.circular(AppRadius.pill.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The shared avatar, which already cross-fades the picture in
                // over the initial and decodes it to the size drawn rather
                // than downloading a full portrait for a 26 px circle.
                UserAvatar(
                  initial: _initial,
                  imageUrl: comment.authorAvatarUrl,
                  radius: _avatarRadius,
                  // White on a translucent white disc: the capsule sits over
                  // an arbitrary photograph, where the theme's own avatar
                  // colours have no ground to sit on.
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                ),
                SizedBox(width: AppSpacing.sm.w),
                Flexible(
                  child: Padding(
                    // Optically centres a single line against the avatar
                    // without pushing a two-line comment off balance.
                    padding: EdgeInsets.only(top: 3.h, right: AppSpacing.xs.w),
                    child: Text(
                      comment.content,
                      // The same clamp the caption uses. A comment long enough
                      // to need a third line is a comment to open the sheet
                      // for, which is what tapping this does.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

