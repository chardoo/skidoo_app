import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/web_action_widgets.dart';

/// Vertical reactions column for the web desktop card layout — like /
/// dislike / comment / save / share, plus (on the external panel) the
/// creator pin and a hide/report menu.
class WebReactionsColumn extends StatelessWidget {
  const WebReactionsColumn({
    super.key,
    required this.liked,
    required this.disliked,
    required this.saved,
    required this.likeCount,
    required this.dislikeCount,
    required this.commentCount,
    this.commentTargetId,
    required this.commentsEnabled,
    this.reactionsEnabled = true,
    required this.ext,
    required this.isExternalPanel,
    required this.onLike,
    required this.onDislike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    this.photographerName = '',
    this.photographerId = '',
    this.photographerProfileUrl,
    this.isFollowed = false,
    this.isOwner = false,
    this.isAuthenticated = false,
    this.onPhotographerTap,
    this.onLoginRequired,
    this.mediaH,
    this.onMore,
  });

  final bool liked;
  final bool disliked;
  final bool saved;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;

  /// See [CardInteractionBar.commentTargetId] — same job, web layout.
  final String? commentTargetId;
  final bool commentsEnabled;

  /// Like and dislike, following the owner's `comments_enabled` setting — see
  /// CardInteractionBar.reactionsEnabled for the reasoning.
  final bool reactionsEnabled;
  final AppThemeExtension ext;
  final bool isExternalPanel;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback? onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  // Photographer badge shown at the bottom of the external panel (web desktop).
  final String photographerName;
  final String photographerId;
  final String? photographerProfileUrl;
  final bool isFollowed;
  final bool isOwner;
  final bool isAuthenticated;
  final VoidCallback? onPhotographerTap;
  final VoidCallback? onLoginRequired;
  // When provided, icon size and spacing scale with media height.
  final double? mediaH;
  // Opens the Hide / Report menu — shown beneath the reactions on web.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isExternalPanel
        ? null
        : Border(
            left: BorderSide(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              width: 0.5,
            ),
          );

    // Scale icon size and gap proportionally to the available media height.
    // Small cards (≈380px) get compact 20px icons; tall cards cap at 28px.
    // All values are slightly trimmed from the old fixed 32px.
    final h = mediaH;
    final iconSize = isExternalPanel
        ? (h != null ? (h * 0.040).clamp(16.0, 24.0) : 24.0)
        : null;
    final gap = h != null ? (h * 0.030).clamp(8.0, 14.0) : 14.0;

    return Container(
      decoration: BoxDecoration(color: ext.homeBackground, border: border),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // ── Photographer badge — external panel only (TikTok creator pin) ─
            if (isExternalPanel && photographerName.isNotEmpty) ...[
              WebCreatorPin(
                name: photographerName,
                imageUrl: photographerProfileUrl,
                photographerId: photographerId,
                isFollowed: isFollowed,
                isOwner: isOwner,
                isAuthenticated: isAuthenticated,
                ext: ext,
                onTap: onPhotographerTap,
                onLoginRequired: onLoginRequired,
              ),
              SizedBox(height: gap),
            ],

            // ── Reactions ─────────────────────────────────────────────────────
            if (reactionsEnabled) ...[
              WebActionBtn(
                icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: liked ? ext.likeRed : ext.greetingColor,
                count: likeCount,
                countColor: liked ? ext.likeRed : ext.greetingColor,
                iconSize: iconSize,
                onTap: onLike,
                semanticLabel: liked ? 'Unlike' : 'Like',
              ),
              SizedBox(height: gap),
              WebActionBtn(
                icon: disliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                iconColor: disliked ? ext.dislikeBlue : ext.greetingColor,
                count: dislikeCount,
                countColor: disliked ? ext.dislikeBlue : ext.greetingColor,
                iconSize: iconSize,
                onTap: onDislike,
                semanticLabel: disliked ? 'Remove dislike' : 'Dislike',
              ),
              SizedBox(height: gap),
            ],
            // Listens rather than reads: a bare lookup in a StatelessWidget
            // would be right once and then never move again.
            LiveCommentCount(
              targetId: commentTargetId,
              fallback: commentCount,
              builder: (_, liveCount) => WebActionBtn(
                icon: commentsEnabled
                    ? Icons.mode_comment_outlined
                    : Icons.comments_disabled_rounded,
                iconColor: commentsEnabled
                    ? ext.greetingColor
                    : ext.searchHintColor.withValues(alpha: 0.4),
                count: liveCount,
                countColor: commentsEnabled
                    ? ext.greetingColor
                    : ext.searchHintColor.withValues(alpha: 0.4),
                iconSize: iconSize,
                onTap: onComment,
                semanticLabel:
                    commentsEnabled ? 'Comments' : 'Comments disabled',
              ),
            ),
            SizedBox(height: gap),
            WebActionBtn(
              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              iconColor: saved ? ext.accentGold : ext.greetingColor,
              count: null,
              countColor: ext.greetingColor,
              iconSize: iconSize,
              onTap: onSave,
              semanticLabel: saved ? 'Remove from saved' : 'Save',
            ),
            SizedBox(height: gap),
            WebActionBtn(
              icon: Icons.near_me_outlined,
              iconColor: ext.greetingColor,
              count: null,
              countColor: ext.greetingColor,
              iconSize: iconSize,
              onTap: onShare,
              semanticLabel: 'Share',
            ),
            // ── Hide / Report — beneath the reactions (web) ───────────────────
            if (onMore != null) ...[
              SizedBox(height: gap),
              WebActionBtn(
                icon: Icons.more_horiz_rounded,
                iconColor: ext.greetingColor,
                count: null,
                countColor: ext.greetingColor,
                iconSize: iconSize,
                onTap: onMore,
                semanticLabel: 'More options',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
