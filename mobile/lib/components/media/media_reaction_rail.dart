import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Which theme token tints a reaction once it is active.
///
/// Declared per reaction rather than passed in by each screen, which is how a
/// saved bookmark ended up amber on the feed card and gold everywhere else.
enum MediaReactionTint {
  /// [AppThemeExtension.likeRed] — the heart.
  like,

  /// [AppThemeExtension.accentGold] — bookmarks and anything else the viewer
  /// has put aside rather than reacted to.
  accent,
}

/// One action in a [MediaReactionRail].
///
/// Built through the named constructors below rather than directly, so a
/// reaction's glyphs are declared once. That is the whole point of this type:
/// the Found viewer and the feed card each used to assemble their own rail out
/// of raw [MediaRailAction]s, which meant the same five reactions were spelled
/// out twice — and a change made to one list silently skipped the other.
class MediaReaction {
  const MediaReaction({
    required this.icon,
    required this.onTap,
    this.activeIcon,
    this.active = false,
    this.tint = MediaReactionTint.like,
    this.count,
    this.busy = false,
    this.enabled = true,
    this.semanticLabel,
    this.anchorKey,
  });

  /// The resting glyph — an outline, always. A reaction that has not happened
  /// yet is drawn hollow.
  final IconData icon;

  /// The glyph once [active]. Filled, and only filled here: colour alone is a
  /// weak signal at this size and none at all to a viewer who cannot separate
  /// red from white, so the shape has to carry the state too.
  final IconData? activeIcon;

  final bool active;

  /// Which token colours the glyph once [active]. Ignored at rest — a resting
  /// reaction is always white.
  final MediaReactionTint tint;

  /// Number under the glyph. Null renders the icon alone — for actions that
  /// have no count rather than a count of zero.
  final int? count;

  /// Swaps the glyph for a spinner while an async action is in flight.
  final bool busy;

  /// False dims the glyph and its count and makes the tap do nothing — the
  /// action is on the rail, saying it exists and is unavailable. See
  /// [MediaReaction.commentsDisabled], the only thing that uses it.
  final bool enabled;

  final String? semanticLabel;

  /// Anchors an OS popover (the iPad share sheet) to this action.
  final Key? anchorKey;

  final VoidCallback onTap;

  MediaReaction.like({
    required bool liked,
    required int count,
    required VoidCallback onTap,
  }) : this(
          icon: Icons.favorite_border_rounded,
          activeIcon: Icons.favorite_rounded,
          active: liked,
          count: count,
          semanticLabel: liked ? 'Unlike' : 'Like',
          onTap: onTap,
        );

  MediaReaction.comment({
    required int count,
    required VoidCallback onTap,
  }) : this(
          icon: Icons.mode_comment_outlined,
          count: count,
          semanticLabel: 'Comments',
          onTap: onTap,
        );

  /// Comments, turned off by whoever owns the event or the picture.
  ///
  /// Drawn rather than dropped. A rail that simply loses its comment button
  /// reads as a rail that never had one, and "you can't comment here" is a
  /// thing worth saying — it is the owner's decision, not a fault. The crossed
  /// glyph and the dimming say it, and the count stays: how many comments were
  /// left before the thread closed is still true.
  ///
  /// The tap does nothing, deliberately. There is no sheet to open and nothing
  /// to explain that the glyph hasn't already said.
  MediaReaction.commentsDisabled({int? count})
      : this(
          icon: Icons.comments_disabled_rounded,
          count: count,
          enabled: false,
          semanticLabel: 'Comments disabled',
          onTap: _noop,
        );

  static void _noop() {}

  /// The bookmark glyph: add this to the user's saved items, or take it out.
  ///
  /// One meaning, everywhere. It used to have two — the feed card bookmarked
  /// the event, while the photo rails wrote the file to the device through the
  /// OS save sheet — and the second was not a bookmark at all. Nothing was
  /// saved, so there was no filled state to show and no way to un-save; the
  /// glyph simply downloaded the picture. Writing the file to the phone is
  /// [MediaReaction.download], with an arrow that says so.
  MediaReaction.bookmark({
    required VoidCallback onTap,
    bool saved = false,
    bool busy = false,
    String? semanticLabel,
    Key? anchorKey,
  }) : this(
          icon: Icons.bookmark_border_rounded,
          activeIcon: Icons.bookmark_rounded,
          active: saved,
          tint: MediaReactionTint.accent,
          busy: busy,
          semanticLabel: semanticLabel ?? (saved ? 'Remove from saved' : 'Save'),
          anchorKey: anchorKey,
          onTap: onTap,
        );

  /// Write the file to the phone — the OS save sheet, not a bookmark.
  ///
  /// A download arrow rather than the bookmark it used to borrow, because the
  /// two are different actions with different consequences and the user is
  /// entitled to know which one they are about to trigger. There is no state:
  /// having downloaded a photo once is not something the rail can know, and a
  /// filled glyph would claim it does.
  MediaReaction.download({
    required VoidCallback onTap,
    bool busy = false,
    Key? anchorKey,
  }) : this(
          icon: Icons.download_outlined,
          tint: MediaReactionTint.accent,
          busy: busy,
          semanticLabel: 'Download to device',
          anchorKey: anchorKey,
          onTap: onTap,
        );

  /// Pass the photo on — to someone in the app, or out of it.
  ///
  /// One button for one intention. The rail used to carry two: a paper plane
  /// for the DM picker and the OS share arrow beside it, with the whole
  /// difference between them resting on two similar glyphs. "Send" and "share"
  /// name the same act to anyone who has not read the code, so which button
  /// did what was a guess, and the answer only arrived after the tap.
  ///
  /// The destination is now chosen in [ShareTargetSheet], in words.
  MediaReaction.share({
    required VoidCallback onTap,
    bool busy = false,
    Key? anchorKey,
  }) : this(
          icon: Icons.ios_share_rounded,
          busy: busy,
          semanticLabel: 'Share photo',
          anchorKey: anchorKey,
          onTap: onTap,
        );

  MediaReaction.more({required VoidCallback onTap})
      : this(
          icon: Icons.more_horiz_rounded,
          semanticLabel: 'Show more options',
          onTap: onTap,
        );
}

/// The column of reactions that sits over media — the Found viewer's rail and
/// the feed card's are the same control.
///
/// Owns the parts that must not drift: the glyph set, outline at rest and fill
/// when active, the gap between actions, and where counts appear. A screen
/// supplies only which reactions it offers and what they do.
class MediaReactionRail extends StatelessWidget {
  const MediaReactionRail({super.key, required this.actions, this.gap});

  final List<MediaReaction> actions;

  /// Unscaled gap between actions. Defaults to [AppSpacing.lg].
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final spacing = SizedBox(height: (gap ?? AppSpacing.lg).h);

    final children = <Widget>[];
    for (final action in actions) {
      if (children.isNotEmpty) children.add(spacing);
      children.add(_build(action, ext));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _build(MediaReaction r, AppThemeExtension ext) => MediaRailAction(
        key: r.anchorKey,
        icon: r.active ? (r.activeIcon ?? r.icon) : r.icon,
        iconColor: r.enabled
            ? (r.active ? _tint(r.tint, ext) : Colors.white)
            : _unavailable,
        label: r.count?.toString(),
        labelColor: r.enabled ? null : _unavailable,
        enabled: r.enabled,
        busy: r.busy,
        semanticLabel: r.semanticLabel,
        onTap: r.onTap,
      );

  /// White at 40%, matching the alpha the card bar and the web column already
  /// dim an unavailable action to. Not a theme token: this rail is drawn over
  /// an arbitrary photo, where white is the only colour that reads, and every
  /// live glyph here is white for the same reason.
  static const _unavailable = Color(0x66FFFFFF);

  static Color _tint(MediaReactionTint tint, AppThemeExtension ext) =>
      switch (tint) {
        MediaReactionTint.like => ext.likeRed,
        MediaReactionTint.accent => ext.accentGold,
      };
}
