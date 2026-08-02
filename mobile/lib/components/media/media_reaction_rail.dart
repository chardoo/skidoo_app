import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/media/media_rail_action.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

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

  /// The bookmark glyph. What the tap *does* is the caller's business — the
  /// viewer saves the photo to the device, the feed card adds the event to the
  /// user's saved items — but both read as a bookmark, and only the second has
  /// a state to be in.
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

  /// In-app: hands the photo to the DM picker.
  MediaReaction.send({required VoidCallback onTap})
      : this(
          icon: Icons.near_me_outlined,
          semanticLabel: 'Send',
          onTap: onTap,
        );

  /// Out of the app: the OS share sheet.
  MediaReaction.shareExternally({
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
        iconColor: r.active ? _tint(r.tint, ext) : Colors.white,
        label: r.count?.toString(),
        busy: r.busy,
        semanticLabel: r.semanticLabel,
        onTap: r.onTap,
      );

  static Color _tint(MediaReactionTint tint, AppThemeExtension ext) =>
      switch (tint) {
        MediaReactionTint.like => ext.likeRed,
        MediaReactionTint.accent => ext.accentGold,
      };
}
