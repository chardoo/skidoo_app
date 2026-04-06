import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_description_text.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_comment_sheet.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

class EventDiscoveryCard extends StatefulWidget {
  const EventDiscoveryCard({
    super.key,
    required this.event,
    required this.onTap,
    this.isAuthenticated = false,
    this.isOwner = false,
    this.onCommentTap,
  });

  final EventDiscovery event;
  final VoidCallback onTap;
  final bool isAuthenticated;
  final bool isOwner;
  final VoidCallback? onCommentTap;

  @override
  State<EventDiscoveryCard> createState() => _EventDiscoveryCardState();
}

class _EventDiscoveryCardState extends State<EventDiscoveryCard>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _liked = false;
  bool _disliked = false;
  bool _saved = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  bool _descExpanded = false;
  bool _showHeartBurst = false;

  late final AnimationController _heartCtrl;

  // Stored so we can safely dispatch from dispose() without using context.
  DiscoveryBloc? _discoveryBloc;

  void _syncReactionFromEvent(EventDiscovery event) {
    _liked = event.userReaction == 'like';
    _disliked = event.userReaction == 'dislike';
    _likeCount = event.likes;
    _dislikeCount = event.dislikes;
  }

  @override
  void initState() {
    super.initState();
    _syncReactionFromEvent(widget.event);
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _showHeartBurst = false);
          _heartCtrl.reset();
        }
      });
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage && mounted) setState(() => _currentPage = page);
    });
    // Notify the bloc that this card is now visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _discoveryBloc = context.read<DiscoveryBloc>();
      _discoveryBloc?.add(DiscoveryEventVisible(widget.event.id));
    });
  }

  @override
  void didUpdateWidget(EventDiscoveryCard old) {
    super.didUpdateWidget(old);
    // Sync when server-confirmed reaction data arrives for this event.
    if (old.event.id != widget.event.id ||
        old.event.likes != widget.event.likes ||
        old.event.dislikes != widget.event.dislikes ||
        old.event.userReaction != widget.event.userReaction) {
      setState(() => _syncReactionFromEvent(widget.event));
    }
  }

  @override
  void dispose() {
    // Notify the bloc that this card has left the viewport.
    _discoveryBloc?.add(DiscoveryEventHidden(widget.event.id));
    _heartCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    final wasLiked = _liked;
    setState(() {
      if (!_liked) {
        _liked = true;
        _likeCount++;
        if (_disliked) {
          _disliked = false;
          _dislikeCount = (_dislikeCount - 1).clamp(0, 999999999);
        }
      }
      _showHeartBurst = true;
    });
    _heartCtrl.forward(from: 0);
    if (!wasLiked) {
      context.read<DiscoveryBloc>().add(
            DiscoveryReactionToggled(widget.event.id, isLike: true),
          );
    }
  }

  void handleTap() {
     Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventPicturesPage(event:  widget.event)
      ),
    );
    
  }

  int get _visibleCount {
    if (widget.isAuthenticated) return widget.event.pictures.length;
    return math.min(3, widget.event.pictures.length);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final pics = widget.event.pictures;
    final size = MediaQuery.sizeOf(context);

    // Portrait ratio 4:5 — same as Instagram portrait posts
    final photoH = size.width * (5 / 4);

    return Container(
      color: ext.homeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Post header ─────────────────────────────────────────────
          _PostHeader(
            event: widget.event,
            ext: ext,
            isOwner: widget.isOwner,
            onPhotographerTap: () => _openPhotographerProfile(context),
          ),

          // ── 2. Photo area ──────────────────────────────────────────────
          GestureDetector(
            onTap: widget.isAuthenticated ? null : widget.onTap,
            child: SizedBox(
              width: double.infinity,
              height: photoH.clamp(360.0, 520.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photos or placeholder
                  pics.isEmpty
                      ? CardGradientPlaceholder(name: widget.event.eventName)
                      : PostPhotoCarousel(
                          pics: pics.take(_visibleCount).toList(),
                          pageController: _pageCtrl,
                          showBlur: !widget.isAuthenticated && pics.length > 3,
                          onTap: handleTap,
                          scrollable: widget.isAuthenticated,
                          onDoubleTap: widget.isAuthenticated
                              ? _handleDoubleTap
                              : widget.onTap,
                        ),

                  // Top gradient (header area legibility)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 80.h,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x88000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),

                  // Bottom gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120.h,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xCC000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),

                  // Photo counter badge (top right)
                  if (pics.length > 1)
                    Positioned(
                      top: 14.h,
                      right: 14.w,
                      child: _PhotoCountBadge(
                        current: _currentPage + 1,
                        total: widget.isAuthenticated
                            ? pics.length
                            : math.min(3, pics.length),
                      ),
                    ),

                  // Event name + location at bottom
                  Positioned(
                    bottom: 14.h,
                    left: 14.w,
                    right: 60.w,
                    child: _ImageFooter(event: widget.event),
                  ),

                  // Double-tap heart burst
                  if (_showHeartBurst)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(child: _HeartBurst(ctrl: _heartCtrl)),
                      ),
                    ),

                  // Unauthenticated full-blur CTA (only when no photos visible)
                  if (!widget.isAuthenticated && pics.isEmpty)
                    _UnauthCta(onTap: widget.onTap),
                ],
              ),
            ),
          ),

          // ── 3. Page dots ───────────────────────────────────────────────
          if (pics.length > 1) ...[
            SizedBox(height: 10.h),
            _PageDots(
              count: _visibleCount,
              current: _currentPage,
              ext: ext,
              onPageChanged: widget.isAuthenticated
                  ? (i) {
                      _pageCtrl.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : (_) => widget.onTap(),
            ),
          ] else
            SizedBox(height: 10.h),

          // ── 4. Interaction bar ─────────────────────────────────────────
          CardInteractionBar(
            liked: _liked,
            disliked: _disliked,
            saved: _saved,
            likeCount: _likeCount,
            dislikeCount: _dislikeCount,
            commentCount: 0,
            ext: ext,
            onLike: widget.isAuthenticated
                ? () {
                    setState(() {
                      if (!_liked && _disliked) {
                        _disliked = false;
                        _dislikeCount =
                            (_dislikeCount - 1).clamp(0, 999999999);
                      }
                      _liked = !_liked;
                      _likeCount += _liked ? 1 : -1;
                    });
                    context.read<DiscoveryBloc>().add(
                          DiscoveryReactionToggled(widget.event.id,
                              isLike: true),
                        );
                  }
                : widget.onTap,
            onDislike: widget.isAuthenticated
                ? () {
                    setState(() {
                      if (!_disliked && _liked) {
                        _liked = false;
                        _likeCount = (_likeCount - 1).clamp(0, 999999999);
                      }
                      _disliked = !_disliked;
                      _dislikeCount += _disliked ? 1 : -1;
                    });
                    context.read<DiscoveryBloc>().add(
                          DiscoveryReactionToggled(widget.event.id,
                              isLike: false),
                        );
                  }
                : widget.onTap,
            onComment: widget.isAuthenticated
                ? (widget.onCommentTap ?? () => _showCommentSheet(context, ext))
                : widget.onTap,
            onShare: widget.isAuthenticated ? () {} : widget.onTap,
            onSave: widget.isAuthenticated
                ? () => setState(() => _saved = !_saved)
                : widget.onTap,
          ),

          // ── 5. Caption ─────────────────────────────────────────────────
          CardDescriptionText(
            event: widget.event,
            ext: ext,
            expanded: _descExpanded,
            onToggle: () => setState(() => _descExpanded = !_descExpanded),
          ),

          SizedBox(height: 14.h),

          // ── 6. Thin divider ────────────────────────────────────────────
          Divider(
            height: 1,
            thickness: 0.5,
            color: ext.searchHintColor.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  void _openPhotographerProfile(BuildContext context) {
    final photographer = PhotographerModel(
      widget.event.photographerId,
      '',
      widget.event.photographerName,
      '',
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotographerProfilePage(photographer: photographer),
      ),
    );
  }

  void _showCommentSheet(BuildContext context, AppThemeExtension ext) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CardCommentSheet(ext: ext, eventName: widget.event.eventName),
    );
  }
}

// ── Post header ───────────────────────────────────────────────────────────────

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.event,
    required this.ext,
    this.isOwner = false,
    this.onPhotographerTap,
  });
  final EventDiscovery event;
  final AppThemeExtension ext;
  final bool isOwner;
  final VoidCallback? onPhotographerTap;

  @override
  Widget build(BuildContext context) {
    final name = event.photographerName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        children: [
          // Story-ring avatar (tappable) — crown badge when owner
          GestureDetector(
            onTap: onPhotographerTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _StoryRingAvatar(initial: initial, ext: ext),
                if (isOwner)
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      width: 18.w,
                      height: 18.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [ext.accentGold, const Color(0xFFFF8C00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: ext.homeBackground, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: ext.accentGold.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 10.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),

          // Name + sub-label (also tappable)
          Expanded(
            child: GestureDetector(
              onTap: onPhotographerTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: ext.greetingColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner) ...[
                        SizedBox(width: 6.w),
                        _OwnerPill(ext: ext),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.photo_camera_rounded,
                          size: 11.sp, color: ext.accentGold),
                      SizedBox(width: 3.w),
                      Text(
                        'Photographer',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // More options
          GestureDetector(
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: Icon(Icons.more_horiz_rounded,
                  color: ext.greetingColor, size: 22.sp),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Owner pill badge ──────────────────────────────────────────────────────────

class _OwnerPill extends StatelessWidget {
  const _OwnerPill({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ext.accentGold.withValues(alpha: 0.18),
            const Color(0xFFFF8C00).withValues(alpha: 0.12),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
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

// ── Story-ring avatar ─────────────────────────────────────────────────────────

class _StoryRingAvatar extends StatelessWidget {
  const _StoryRingAvatar({required this.initial, required this.ext});
  final String initial;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ext.accentGold,
            const Color(0xFFFF6B35),
            const Color(0xFFE53935),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ext.homeBackground,
        ),
        child: CircleAvatar(
          radius: 17.r,
          backgroundColor: ext.accentGold.withValues(alpha: 0.2),
          child: Text(
            initial,
            style: TextStyle(
              color: ext.accentGold,
              fontWeight: FontWeight.w800,
              fontSize: 14.sp,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Photo counter badge ───────────────────────────────────────────────────────

class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20.r),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8),
      ),
      child: Text(
        '$current / $total',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Image footer (event name + subtle location) ───────────────────────────────

class _ImageFooter extends StatelessWidget {
  const _ImageFooter({required this.event});
  final EventDiscovery event;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          event.eventName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            shadows: const [
              Shadow(blurRadius: 8, color: Colors.black87),
              Shadow(blurRadius: 2, color: Colors.black54),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Double-tap heart burst ────────────────────────────────────────────────────

class _HeartBurst extends StatelessWidget {
  const _HeartBurst({required this.ctrl});
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        // Scale: 0→1.4 in first half, 1.4→1.2 in second half
        final scale = t < 0.4 ? (t / 0.4) * 1.4 : 1.4 - ((t - 0.4) / 0.6) * 0.2;
        // Opacity: full until 0.6, then fade out
        final opacity = t < 0.6 ? 1.0 : 1.0 - ((t - 0.6) / 0.4);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale.clamp(0.0, 2.0),
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 90.sp,
              shadows: const [
                Shadow(blurRadius: 20, color: Colors.black54),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Page dots ─────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.ext,
    required this.onPageChanged,
  });

  final int count;
  final int current;
  final AppThemeExtension ext;
  final void Function(int) onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return GestureDetector(
          onTap: () => onPageChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: EdgeInsets.symmetric(horizontal: 3.w),
            width: isActive ? 20.w : 6.w,
            height: 6.h,
            decoration: BoxDecoration(
              color: isActive
                  ? ext.accentGold
                  : ext.searchHintColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
        );
      }),
    );
  }
}

// ── Unauthenticated full CTA ──────────────────────────────────────────────────

class _UnauthCta extends StatelessWidget {
  const _UnauthCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: Text(
            'Tap to explore',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
