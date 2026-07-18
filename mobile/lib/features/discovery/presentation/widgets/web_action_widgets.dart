import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';

// ── Shared web UI primitives used by both the discovery feed and the
//    fullscreen picture viewer on web desktop/laptop. ──────────────────────────

// ── Creator pin — avatar with TikTok-style follow/unfollow badge ──────────────

class WebCreatorPin extends StatefulWidget {
  const WebCreatorPin({
    super.key,
    required this.name,
    this.imageUrl,
    required this.photographerId,
    required this.isFollowed,
    required this.isOwner,
    required this.isAuthenticated,
    required this.ext,
    this.onTap,
    this.onLoginRequired,
  });

  final String name;

  /// Photographer's real avatar — shown instead of the initials fallback
  /// when present (`profile_url` on the event's nested user object).
  final String? imageUrl;
  final String photographerId;
  final bool isFollowed;
  final bool isOwner;
  final bool isAuthenticated;
  final AppThemeExtension ext;
  final VoidCallback? onTap;
  final VoidCallback? onLoginRequired;

  @override
  State<WebCreatorPin> createState() => _WebCreatorPinState();
}

class _WebCreatorPinState extends State<WebCreatorPin> {
  late bool _following;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _following = widget.isFollowed ||
        FollowRepository.followedIds.contains(widget.photographerId);
  }

  Future<void> _toggle() async {
    if (_loading || widget.photographerId.isEmpty) return;
    if (!widget.isAuthenticated) {
      widget.onLoginRequired?.call();
      return;
    }
    final willFollow = !_following;
    setState(() {
      _following = willFollow;
      _loading = true;
    });
    try {
      if (willFollow) {
        await FollowRepository().follow(widget.photographerId);
      } else {
        await FollowRepository().unfollow(widget.photographerId);
      }
    } catch (_) {
      if (mounted) setState(() => _following = !willFollow);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _fallback(String initial) => Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF3DD9B4), Color(0xFF078368)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      );

  Widget _buildInner(String initial) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return _fallback(initial);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallback(initial),
        errorWidget: (_, __, ___) => _fallback(initial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    final ext = widget.ext;

    return SizedBox(
      width: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Semantics(
            button: true,
            label: widget.name.isNotEmpty
                ? "View ${widget.name}'s profile"
                : "View creator profile",
            child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [ext.accentGold, const Color(0xFF078368)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ext.accentGold.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: _buildInner(initial),
              ),
            ),
          ),
          ),

          if (!widget.isOwner)
            Positioned(
              bottom: -8,
              child: Semantics(
                button: true,
                label: _following ? 'Unfollow' : 'Follow',
                child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _following
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFFFF3B5C),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ext.homeBackground,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: _following
                                    ? Colors.black54
                                    : Colors.white,
                              ),
                            )
                          : Icon(
                              _following
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 13,
                              color:
                                  _following ? Colors.black54 : Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Single action button (icon + optional count, hover-scale) ─────────────────

class WebActionBtn extends StatefulWidget {
  const WebActionBtn({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.countColor,
    required this.onTap,
    this.iconSize,
    this.semanticLabel,
  });

  final IconData icon;
  final Color iconColor;
  final int? count;
  final Color countColor;
  final VoidCallback? onTap;
  final double? iconSize;

  /// Screen-reader label for this icon button (e.g. 'Like', 'Comment').
  final String? semanticLabel;

  @override
  State<WebActionBtn> createState() => _WebActionBtnState();
}

class _WebActionBtnState extends State<WebActionBtn> {
  bool _hovered = false;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final label = [
      if (widget.semanticLabel != null) widget.semanticLabel!,
      if (widget.count != null && widget.count! > 0) _fmt(widget.count!),
    ].join(', ');
    return Semantics(
      button: true,
      enabled: enabled,
      label: label.isEmpty ? null : label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) {
          if (enabled) setState(() => _hovered = true);
        },
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.14 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: (widget.iconSize ?? 28.sp) + 16,
                height: (widget.iconSize ?? 28.sp) + 16,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon,
                    color: widget.iconColor,
                    size: widget.iconSize ?? 28.sp),
              ),
              if (widget.count != null && widget.count! > 0) ...[
                const SizedBox(height: 4),
                Text(
                  _fmt(widget.count!),
                  style: TextStyle(
                    color: widget.countColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
