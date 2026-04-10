import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/gallery/data/datasources/overlay_remote_data_source.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_overlay_usecase.dart';
import 'package:skidoo_app/features/photo_comments/data/picture_like_service.dart';
import 'package:skidoo_app/features/photo_comments/presentation/pages/photo_comment_sheet.dart';

/// Reusable **Like / Download / Share / Comment** action buttons for any media item.
///
/// [axis] controls layout:
///   • [Axis.vertical]   → TikTok-style sidebar (event pictures page).
///   • [Axis.horizontal] → flat row with dividers  (fullscreen page).
///
/// Provide [pictureId] (defaults to [imageId]) to show the Comment button.
///
/// [onLikeToggled] is called with the new liked state after an optimistic UI
/// update.  The callback is responsible for syncing the like to the server
/// (e.g. via a photo-room WebSocket).  When omitted the update is local-only.
class MediaActionButtons extends StatefulWidget {
  const MediaActionButtons({
    super.key,
    required this.imageId,
    required this.imageUrl,
    this.photographerName = '',
    this.eventName = '',
    this.axis = Axis.vertical,
    this.buttonSize,
    this.iconSize,
    this.initialLikeCount = 0,
    this.initialCommentCount = 0,
    this.initiallyLiked = false,
    this.onLikeToggled,
    String? pictureId,
  }) : pictureId = pictureId ?? imageId;

  final String imageId;
  final String imageUrl;
  final String photographerName;
  final String eventName;
  final Axis axis;
  final double? buttonSize;
  final double? iconSize;
  final int initialLikeCount;
  final int initialCommentCount;
  final bool initiallyLiked;

  /// Called after the optimistic like/unlike update with the new [liked] value.
  /// The callback owns server-sync responsibility.
  final void Function(bool liked)? onLikeToggled;

  /// The picture ID used for comments and likes. Defaults to [imageId].
  final String pictureId;

  @override
  State<MediaActionButtons> createState() => _MediaActionButtonsState();
}

class _MediaActionButtonsState extends State<MediaActionButtons> {
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  bool _downloading = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.initiallyLiked;
    _likeCount = widget.initialLikeCount;
    _commentCount = widget.initialCommentCount;
  }

  static String _fmt(int n) {
    if (n <= 0) return '';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  double get _btnSize =>
      widget.buttonSize ??
      (widget.axis == Axis.vertical ? 44.w : 52.w);

  double get _icnSize =>
      widget.iconSize ??
      (widget.axis == Axis.vertical ? 20.sp : 22.sp);

  // ── Core: fetch overlay → temp file → share sheet ─────────────────────────

  Future<void> _handleAction({required bool isDownload}) async {
    if (_downloading || _sharing) return;
    setState(() {
      if (isDownload) {
        _downloading = true;
      } else {
        _sharing = true;
      }
    });

    // Show the classy loading overlay.
    _showLoadingOverlay(isDownload: isDownload);

    try {
      final OverlayResult result = await sl<GetOverlayImageUseCase>()(
        widget.imageId,
        widget.photographerName,
      );

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/overlay_${widget.imageId}.${result.fileExtension}';
      await File(filePath).writeAsBytes(result.bytes, flush: true);

      // Dismiss the overlay before opening the share sheet.
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      final subject = widget.eventName.isNotEmpty ? widget.eventName : 'Photo';
      final text = widget.eventName.isNotEmpty
          ? 'Check out ${widget.eventName}!'
          : 'Check out this photo!';

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(filePath, mimeType: result.contentType)],
        subject: subject,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _snack('Could not prepare file: $e');
      }
    } finally {
      if (mounted) setState(() { _downloading = false; _sharing = false; });
    }
  }

  void _showLoadingOverlay({required bool isDownload}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => _ProcessingOverlay(
        label: isDownload ? 'Preparing download…' : 'Preparing to share…',
      ),
    );
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    final nowLiked = !_liked;
    setState(() {
      _liked = nowLiked;
      _likeCount = (_likeCount + (nowLiked ? 1 : -1)).clamp(0, 999999999);
    });
    if (widget.onLikeToggled != null) {
      widget.onLikeToggled!(nowLiked);
    } else if (widget.pictureId.isNotEmpty) {
      // Default: fire-and-forget via ephemeral photo-room WS.
      sl<PictureLikeService>().toggleLike(widget.pictureId, liked: nowLiked);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final btns = <Widget>[
      _MediaBtn(
        icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        label: _fmt(_likeCount),
        color: _liked ? const Color(0xFFFF3B5C) : Colors.white,
        size: _btnSize,
        iconSize: _icnSize,
        busy: false,
        onTap: _toggleLike,
      ),
      _MediaBtn(
        icon: Icons.download_rounded,
        label: '',
        color: const Color(0xFFF5A623),
        size: _btnSize,
        iconSize: _icnSize,
        busy: _downloading,
        onTap: () => _handleAction(isDownload: true),
      ),
      _MediaBtn(
        icon: Icons.ios_share_rounded,
        label: '',
        color: Colors.white.withValues(alpha: 0.9),
        size: _btnSize,
        iconSize: _icnSize,
        busy: _sharing,
        onTap: () => _handleAction(isDownload: false),
      ),
      _MediaBtn(
        icon: Icons.chat_bubble_outline_rounded,
        label: _fmt(_commentCount),
        color: Colors.white.withValues(alpha: 0.9),
        size: _btnSize,
        iconSize: _icnSize,
        busy: false,
        onTap: () => PhotoCommentSheet.show(
          context,
          pictureId: widget.pictureId,
          imageUrl: widget.imageUrl,
        ),
      ),
    ];

    if (widget.axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: btns
            .map((b) =>
                Padding(padding: EdgeInsets.only(bottom: 14.h), child: b))
            .toList(),
      );
    }

    final divider = Container(
      width: 1,
      height: 32.h,
      color: Colors.white24,
      margin: EdgeInsets.symmetric(horizontal: 10.w),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btns[0],
        divider,
        btns[1],
        divider,
        btns[2],
        divider,
        btns[3],
      ],
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.black87,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      margin: EdgeInsets.only(bottom: 80.h, left: 24.w, right: 24.w),
    ));
  }
}

// ── Classy full-screen processing overlay ─────────────────────────────────────

class _ProcessingOverlay extends StatefulWidget {
  const _ProcessingOverlay({required this.label});
  final String label;

  @override
  State<_ProcessingOverlay> createState() => _ProcessingOverlayState();
}

class _ProcessingOverlayState extends State<_ProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.88, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 36.w, vertical: 32.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated ring
                    SizedBox(
                      width: 56.w,
                      height: 56.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 56.w,
                            height: 56.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 56.w,
                            height: 56.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFF5A623),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: const Color(0xFFF5A623),
                            size: 22.sp,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    Text(
                      widget.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),

                    SizedBox(height: 6.h),

                    Text(
                      'Adding photographer branding',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11.sp,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single action button (circle icon + label) ────────────────────────────────

class _MediaBtn extends StatefulWidget {
  const _MediaBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final double iconSize;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_MediaBtn> createState() => _MediaBtnState();
}

class _MediaBtnState extends State<_MediaBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.82,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2C2C2E).withValues(alpha: 0.92),
                    const Color(0xFF1A1A1C).withValues(alpha: 0.96),
                  ],
                  center: Alignment.topLeft,
                  radius: 1.4,
                ),
                border: Border.all(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.08),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: widget.busy
                  ? Padding(
                      padding: EdgeInsets.all(widget.size * 0.22),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            widget.color.withValues(alpha: 0.8)),
                      ),
                    )
                  : Icon(widget.icon, color: widget.color, size: widget.iconSize),
            ),
            SizedBox(height: 4.h),
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
