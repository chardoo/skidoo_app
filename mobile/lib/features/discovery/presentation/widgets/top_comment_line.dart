import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The standout comment, drawn the way Shorts draws it: a frosted capsule
/// holding the commenter's avatar and what they said, sitting directly above
/// the post's own text. See [_FrostedCapsule] for the glass.
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
          child: _FrostedCapsule(
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
                        fontSize: 14.sp,
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

/// The glass the comment sits on.
///
/// The reference is frosted, not tinted: the pitch is visible through it and
/// visibly *softened*, which is what tells you the capsule is a sheet laid over
/// the photograph rather than a hole cut in it. A flat black fill — which is
/// what this was — reads as a sticker, and over a dark photo it disappears
/// altogether while over a bright one it reads as a bar.
///
/// **Unconditionally blurred, unlike [GlassSurface].** That widget falls back
/// to an opaque tonal surface off iOS, deliberately, because it dresses
/// *chrome* — nav bars and icon buttons — where Material 3 wants a solid
/// surface and where the blur would be paid for the whole session. Neither
/// applies here: this is an overlay on media, the reference frosts it on every
/// platform, and it is a capsule on screen for as long as one card is. The
/// same reasoning already governs [MediaActionButtons] and the locked-photo
/// overlay, both of which blur everywhere.
class _FrostedCapsule extends StatelessWidget {
  const _FrostedCapsule({required this.child});

  final Widget child;

  /// Soft enough that the photograph behind goes to colour and light rather
  /// than staying a readable picture, which is what lets small white text sit
  /// on it. Wider than the app's chrome blur on purpose — chrome wants the
  /// content behind it recognisable, and this wants the opposite.
  static const double _blurSigma = 24;

  @override
  Widget build(BuildContext context) {
    // A capsule at any height: the radius clamps to half the box, so one line
    // is a pill and two lines are a rounded rectangle with fully round ends —
    // which is what the reference shows.
    final shape = BorderRadius.circular(AppRadius.pill.r);

    return DecoratedBox(
      // Under the glass, so the capsule lifts off the photograph instead of
      // lying flat on it. Wide and weak — a tight shadow would read as a
      // drawn border.
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              // A gradient rather than one flat tone. Real glass is lit from
              // somewhere: catching slightly more light at the top edge and
              // sitting darker at the bottom is the whole difference between
              // a pane and a rectangle of paint.
              //
              // Dark overall because the text on it is white and the
              // photograph behind could be anything — a snow scene has to
              // carry 13sp white type as readably as a night shot. Rendered
              // over a deliberately blown-out backdrop, 0.34/0.46 left the
              // type sitting on pale grey; these hold up over the brightest
              // thing a photo is likely to put behind them and still let the
              // colour through.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.46),
                  Colors.black.withValues(alpha: 0.58),
                ],
              ),
              // The lit edge. Barely visible by design — at anything stronger
              // it stops being a highlight and becomes an outline, and an
              // outlined capsule is a button.
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w,
                vertical: 6.h,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

