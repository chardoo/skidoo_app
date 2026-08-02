import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_more_options_sheet.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';

/// Slim header row shown above a feed card's media: creator avatar + name,
/// an "owner" badge for the current user's own posts, a Follow pill, and a
/// more-options menu.
class PostHeader extends StatelessWidget {
  const PostHeader({
    super.key,
    required this.event,
    required this.ext,
    this.isOwner = false,
    this.isAuthenticated = false,
    this.onPhotographerTap,
    this.onHide,
    this.onLoginRequired,
    this.onImage = false,
  });
  final EventDiscovery event;
  final AppThemeExtension ext;
  final bool isOwner;
  final bool isAuthenticated;
  final VoidCallback? onPhotographerTap;
  final VoidCallback? onHide;
  final VoidCallback? onLoginRequired;
  final bool onImage;

  void _showMoreOptions(BuildContext context) {
    if (!isAuthenticated) {
      onLoginRequired?.call();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => EventMoreOptionsSheet(
        ext: ext,
        eventId: event.id,
        onHide: onHide,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = event.photographerName;
    final nameColor = onImage ? Colors.white : ext.greetingColor;
    final iconColor = onImage ? Colors.white : ext.greetingColor;
    final textShadows = onImage
        ? const [
            Shadow(blurRadius: 12, color: Colors.black87),
            Shadow(blurRadius: 4, color: Colors.black54),
          ]
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 9.h, 4.w, 9.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ─────────────────────────────────────────────────────
          Semantics(
              button: true,
              label: 'View profile',
              child: GestureDetector(
                onTap: onPhotographerTap,
                child: CreatorInitialsAvatar(
                  name: name,
                  imageUrl: event.photographerProfileUrl,
                  size: 36.w,
                  onImage: onImage,
                ),
              )),

          SizedBox(width: 10.w),

          // ── Name (no subtitle — keeps the header slim) ─────────────────
          Expanded(
            child: Semantics(
                button: true,
                label: 'View profile',
                child: GestureDetector(
                  onTap: onPhotographerTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: nameColor,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            shadows: textShadows,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner) ...[
                        SizedBox(width: 6.w),
                        OwnerPill(ext: ext),
                      ],
                    ],
                  ),
                )),
          ),

          // ── Follow pill — hidden for own posts ─────────────────────────
          if (!isOwner) ...[
            SizedBox(width: 10.w),
            FollowButton(
              photographerId: event.photographerId,
              onImage: onImage,
              initialFollowing: event.isFollowed,
              onLoginRequired: isAuthenticated ? null : onLoginRequired,
            ),
          ],

          // ── More options ───────────────────────────────────────────────
          Semantics(
              button: true,
              label: 'Show more options',
              child: GestureDetector(
                onTap: () => _showMoreOptions(context),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  child: Icon(Icons.more_horiz_rounded,
                      color: iconColor, size: 21.sp),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Owner pill badge ──────────────────────────────────────────────────────────

class OwnerPill extends StatelessWidget {
  const OwnerPill({super.key, required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ext.accentGold.withValues(alpha: 0.18),
            ext.accentGoldDark.withValues(alpha: 0.12),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        border: Border.all(
          color: ext.accentGold.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: 9.sp, color: ext.accentGold),
          SizedBox(width: 3.w),
          Text(
            'Your post',
            style: TextStyle(
              color: ext.accentGold,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Creator initials avatar — used on image overlays ─────────────────────────

class CreatorInitialsAvatar extends StatelessWidget {
  const CreatorInitialsAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    required this.size,
    this.onImage = false,
  });
  final String name;

  /// Photographer's real avatar — shown instead of the initials fallback
  /// when present (`profile_url` on the event's nested user object).
  final String? imageUrl;
  final double size;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    const borderPad = 2.5;

    final fallback = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [const Color(0xFF3DD9B4), ext.accentGoldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: (size - borderPad * 2) * 0.42,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );

    final url = imageUrl;
    final inner = (url == null || url.isEmpty)
        ? fallback
        : ClipOval(
            child: SkidooImage(
              imageUrl: url,
              fit: BoxFit.cover,
              logicalWidth: size,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [ext.accentGold, ext.accentGoldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ext.accentGold.withValues(alpha: 0.40),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(borderPad),
      child: inner,
    );
  }
}
