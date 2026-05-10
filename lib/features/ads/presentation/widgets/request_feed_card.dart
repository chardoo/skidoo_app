import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
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
    debugPrint(
        '$_tag build id=${widget.request.id} title="${widget.request.title}"');
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final r = widget.request;

    // Taller for video (like event card), square-ish for image/no-asset
    final isVideo = r.assetType == 'video';
    final aspectRatio = isVideo ? 4 / 5 : 1.0;

    return Container(
      color: ext.homeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Media area ──────────────────────────────────────────────────
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MediaBackground(
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
                  height: 100.h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xAA000000), Color(0x00000000)],
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

                // Header overlaid at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _RequestHeader(request: r),
                ),

                // Title + budget at bottom
                Positioned(
                  bottom: 14.h,
                  left: 14.w,
                  right: 14.w,
                  child: _RequestFooter(request: r),
                ),
              ],
            ),
          ),

          // ── Meta + description + CTA ─────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.eventType.isNotEmpty)
                  _MetaChip(
                    icon: Icons.event_rounded,
                    label: r.eventType,
                    color: const Color(0xFF8B5CF6),
                  ),

                if (r.description.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Text(
                    r.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context)
                          .extension<AppThemeExtension>()!
                          .searchHintColor,
                      fontSize: 13.sp,
                      height: 1.5,
                    ),
                  ),
                ],

                SizedBox(height: 12.h),

                _MessageCta(
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

          // ── Divider ──────────────────────────────────────────────────────
          Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context)
                .extension<AppThemeExtension>()!
                .searchHintColor
                .withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String type) =>
    type == 'photographer' ? 'Photographer' : 'Client';

// ── Request header (overlaid on image, like _PostHeader in event card) ─────────

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({required this.request});
  final FeedRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar — letter fallback uses requester_type initial
          Container(
            width: 32.w,
            height: 32.w,
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
                      size: 14.sp,
                    ),
                  )
                : null,
          ),

          SizedBox(width: 8.w),

          // Display name (or role label when API omits it) + badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.requesterName.isNotEmpty
                      ? r.requesterName
                      : _roleLabel(r.requesterType),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                  ),
                ),
                SizedBox(height: 3.h),
                _OpenRequestBadge(),
              ],
            ),
          ),

          // Asset type pill on the right
          if (r.assetType != null) ...[
            SizedBox(width: 8.w),
            _AssetTypePill(assetType: r.assetType!),
          ],
        ],
      ),
    );
  }
}

// ── Request footer (title + budget, like _ImageFooter in event card) ───────────

class _RequestFooter extends StatelessWidget {
  const _RequestFooter({required this.request});
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
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
            shadows: const [
              Shadow(blurRadius: 12, color: Colors.black87),
              Shadow(blurRadius: 4, color: Colors.black54),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            if (r.budgetAmount != null) ...[
              Icon(Icons.payments_outlined,
                  size: 11.sp, color: Colors.white60),
              SizedBox(width: 4.w),
              Text(
                '${r.currency} ${r.budgetAmount!.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
              ),
              SizedBox(width: 10.w),
            ],
            if (r.location.isNotEmpty) ...[
              Icon(Icons.location_on_outlined,
                  size: 11.sp, color: Colors.white60),
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
                    shadows: const [Shadow(blurRadius: 8, color: Colors.black87)],
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

// ── Media background ───────────────────────────────────────────────────────────

class _MediaBackground extends StatelessWidget {
  const _MediaBackground({
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
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ext.searchFieldFill, ext.cardSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.camera_alt_outlined,
            color: ext.searchHintColor.withValues(alpha: 0.4),
            size: 40.sp,
          ),
        ),
      );
    }

    if (request.assetType == 'video') {
      if (videoReady && videoCtrl != null) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoCtrl!.value.size.width,
            height: videoCtrl!.value.size.height,
            child: VideoPlayer(videoCtrl!),
          ),
        );
      }
      return Container(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white30, size: 40.sp),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: ext.searchFieldFill),
      errorWidget: (_, __, ___) => Container(
        color: ext.searchFieldFill,
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: ext.searchHintColor, size: 32.sp),
        ),
      ),
    );
  }
}

// ── "Open Request" badge ───────────────────────────────────────────────────────

class _OpenRequestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio_button_checked_rounded,
              size: 8.sp, color: const Color(0xFF3B82F6)),
          SizedBox(width: 3.w),
          Text(
            'Open Request',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Asset type pill ────────────────────────────────────────────────────────────

class _AssetTypePill extends StatelessWidget {
  const _AssetTypePill({required this.assetType});
  final String assetType;

  @override
  Widget build(BuildContext context) {
    final isVideo = assetType == 'video';
    final color = isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    final icon = isVideo ? Icons.play_circle_rounded : Icons.image_rounded;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            isVideo ? 'Video' : 'Image',
            style: TextStyle(
              color: color,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta chip ──────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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

// ── Message CTA button ─────────────────────────────────────────────────────────

class _MessageCta extends StatelessWidget {
  const _MessageCta({required this.onTap, required this.ext});
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_rounded, size: 16.sp, color: Colors.white),
            SizedBox(width: 7.w),
            Text(
              'Message Requester',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
