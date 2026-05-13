import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/presentation/pages/feed_comment_sheet.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:video_player/video_player.dart';

const _tag = '[RequestFeedCard]';

class RequestFeedCard extends StatefulWidget {
  const RequestFeedCard({
    super.key,
    required this.request,
    required this.onMessageTap,
  });

  final FeedRequestModel request;
  final VoidCallback onMessageTap;

  @override
  State<RequestFeedCard> createState() => _RequestFeedCardState();
}

class _RequestFeedCardState extends State<RequestFeedCard> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  bool _liked = false;
  bool _disliked = false;
  bool _saved = false;

  void _handleLike() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      if (_liked) _disliked = false;
    });
  }

  void _handleDislike() {
    HapticFeedback.lightImpact();
    setState(() {
      _disliked = !_disliked;
      if (_disliked) _liked = false;
    });
  }

  void _handleSave() {
    HapticFeedback.selectionClick();
    setState(() => _saved = !_saved);
  }

  void _handleComment(BuildContext context) {
    FeedCommentSheet.show(
      context,
      targetType: 'request',
      targetId: widget.request.id,
      title: widget.request.title.isNotEmpty ? widget.request.title : 'Request',
      subtitle: widget.request.requesterName.isNotEmpty
          ? 'by ${widget.request.requesterName}'
          : null,
      commentsEnabled: widget.request.commentsEnabled,
    );
  }

  Future<void> _handleShare() async {
    final r = widget.request;
    final text = r.title.isNotEmpty ? r.title : 'Check out this request';
    await Share.share(text, subject: r.title);
  }

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    if (r.assetType == 'video' && r.assetUrl != null) {
      _initVideo(r.assetUrl!);
    }
  }

  Future<void> _initVideo(String url) async {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await ctrl.initialize();
      await ctrl.setVolume(0);
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) {
        setState(() {
          _videoCtrl = ctrl;
          _videoReady = true;
        });
      } else {
        ctrl.dispose();
      }
    } catch (e) {
      debugPrint('$_tag video init error: $e');
      ctrl.dispose();
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('$_tag build id=${widget.request.id} title="${widget.request.title}" '
        'assetUrl=${widget.request.assetUrl} assetType=${widget.request.assetType}');

    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final r = widget.request;
    final size = MediaQuery.sizeOf(context);

    final isVideo = r.assetType == 'video';
    final mediaH = isVideo
        ? (size.width * 1.45).clamp(480.0, 580.0)
        : (size.width * 1.0).clamp(340.0, 480.0);

    return Container(
      color: ext.homeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full-bleed media ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: mediaH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media background
                _MediaBg(
                  request: r,
                  videoCtrl: _videoCtrl,
                  videoReady: _videoReady,
                  ext: ext,
                ),

                // Top gradient
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 110.h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xBB000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),

                // Bottom gradient
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 150.h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xDD000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),

                // ── Top overlay: badge + requester ──────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 12.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _OpenRequestBadge(),
                        const Spacer(),
                        _RequesterChip(request: r),
                      ],
                    ),
                  ),
                ),

                // ── Bottom overlay: title + meta ────────────────────────
                Positioned(
                  bottom: 14.h,
                  left: 14.w,
                  right: 14.w,
                  child: _MediaFooter(request: r),
                ),
              ],
            ),
          ),

          // ── Below-fold content ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event type + asset type row
                Row(
                  children: [
                    if (r.eventType.isNotEmpty)
                      _Chip(
                        icon: Icons.event_rounded,
                        label: r.eventType,
                        color: const Color(0xFF8B5CF6),
                      ),
                    if (r.eventType.isNotEmpty && r.assetType != null)
                      SizedBox(width: 8.w),
                    if (r.assetType != null) _AssetTypeBadge(r.assetType!),
                  ],
                ),

                if (r.description.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Text(
                    r.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                      height: 1.5,
                    ),
                  ),
                ],

                SizedBox(height: 14.h),

                // CTA button
                _GoldCtaButton(
                  label: 'Message Requester',
                  onTap: () {
                    debugPrint(
                        '$_tag message tapped requestId=${widget.request.id}');
                    widget.onMessageTap();
                  },
                  ext: ext,
                ),

                SizedBox(height: 14.h),
              ],
            ),
          ),

          // ── Interaction bar ─────────────────────────────────────────────
          CardInteractionBar(
            liked: _liked,
            disliked: _disliked,
            saved: _saved,
            likeCount: 0,
            dislikeCount: 0,
            commentCount: 0,
            ext: ext,
            onLike: _handleLike,
            onDislike: _handleDislike,
            onComment: () => _handleComment(context),
            onShare: _handleShare,
            onSave: _handleSave,
          ),

          Divider(
            height: 1,
            thickness: 0.5,
            color: ext.searchHintColor.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

// ── Media background ───────────────────────────────────────────────────────────

class _MediaBg extends StatelessWidget {
  const _MediaBg({
    required this.request,
    required this.videoCtrl,
    required this.videoReady,
    required this.ext,
  });
  final FeedRequestModel request;
  final VideoPlayerController? videoCtrl;
  final bool videoReady;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final url = request.assetUrl;

    if (url == null || url.isEmpty) {
      return CardGradientPlaceholder(name: request.title);
    }

    if (request.assetType == 'video') {
      if (videoReady && videoCtrl != null) {
        final w = videoCtrl!.value.size.width > 0
            ? videoCtrl!.value.size.width
            : 1.0;
        final h = videoCtrl!.value.size.height > 0
            ? videoCtrl!.value.size.height
            : 1.0;
        return ColoredBox(
          color: const Color(0xFF0A0A0A),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: w,
                height: h,
                child: VideoPlayer(videoCtrl!),
              ),
            ),
          ),
        );
      }
      return const ColoredBox(
        color: Color(0xFF0A0A0A),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                color: Colors.white30, strokeWidth: 2),
          ),
        ),
      );
    }

    // Image — blurred background + colour-corrected contained foreground,
    // same technique as PostPhotoCarousel for a polished full-bleed look.
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            placeholder: (_, __) =>
                const ColoredBox(color: Color(0xFF111111)),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF111111)),
          ),
        ),
        const ColoredBox(color: Color(0x55000000)),
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            1.18, -0.06, -0.06, 0, 18,
            -0.05,  1.16, -0.05, 0, 18,
            -0.05, -0.05,  1.20, 0, 18,
            0,     0,     0,     1, 0,
          ]),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF111111)),
          ),
        ),
      ],
    );
  }
}

// ── "Open Request" badge — mirrors the Sponsored badge style ──────────────────

class _OpenRequestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x303B82F6), Color(0x301A56DB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio_button_checked_rounded,
              size: 10.sp, color: const Color(0xFF60A5FA)),
          SizedBox(width: 4.w),
          Text(
            'Open Request',
            style: TextStyle(
              color: const Color(0xFF93C5FD),
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Requester chip (top-right, mirrors AdvertiserChip in AdFeedCard) ──────────

class _RequesterChip extends StatelessWidget {
  const _RequesterChip({required this.request});
  final FeedRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final name = r.requesterName.isNotEmpty ? r.requesterName : 'Anonymous';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26.w,
          height: 26.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
            border: Border.all(color: Colors.white30, width: 0.8),
            image: r.requesterPhoto != null
                ? DecorationImage(
                    image: NetworkImage(r.requesterPhoto!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: r.requesterPhoto == null
              ? Center(
                  child: Icon(
                    r.requesterType == 'photographer'
                        ? Icons.camera_alt_rounded
                        : Icons.person_rounded,
                    color: Colors.white,
                    size: 13.sp,
                  ),
                )
              : null,
        ),
        SizedBox(width: 6.w),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 100.w),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Media footer: title + budget/location ─────────────────────────────────────

class _MediaFooter extends StatelessWidget {
  const _MediaFooter({required this.request});
  final FeedRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          r.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            height: 1.15,
            shadows: const [
              Shadow(blurRadius: 14, color: Colors.black87),
              Shadow(blurRadius: 4, color: Colors.black54),
            ],
          ),
        ),
        SizedBox(height: 5.h),
        Row(
          children: [
            if (r.budgetAmount != null) ...[
              Icon(Icons.payments_outlined,
                  size: 12.sp, color: Colors.white70),
              SizedBox(width: 4.w),
              Text(
                '${r.currency} ${r.budgetAmount!.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black87)
                  ],
                ),
              ),
              SizedBox(width: 12.w),
            ],
            if (r.location.isNotEmpty) ...[
              Icon(Icons.location_on_outlined,
                  size: 12.sp, color: Colors.white70),
              SizedBox(width: 3.w),
              Flexible(
                child: Text(
                  r.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black87)
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Gold gradient CTA button (matches AdFeedCard style) ───────────────────────

class _GoldCtaButton extends StatelessWidget {
  const _GoldCtaButton({
    required this.label,
    required this.onTap,
    required this.ext,
  });
  final String label;
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ext.accentGold, const Color(0xFFFF6B35)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_rounded,
                size: 15.sp, color: Colors.white),
            SizedBox(width: 7.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event type chip ───────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Asset type badge (Image / Video) ─────────────────────────────────────────

class _AssetTypeBadge extends StatelessWidget {
  const _AssetTypeBadge(this.assetType);
  final String assetType;

  @override
  Widget build(BuildContext context) {
    final isVideo = assetType == 'video';
    final color =
        isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    final icon =
        isVideo ? Icons.play_circle_rounded : Icons.image_rounded;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            isVideo ? 'Video' : 'Image',
            style: TextStyle(
              color: color,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
