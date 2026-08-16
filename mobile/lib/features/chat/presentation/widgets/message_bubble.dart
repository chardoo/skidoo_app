
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/cloudinary_transform.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';

/// Returns true when [url] points to a video, using both explicit path
/// patterns (Cloudinary /video/upload/) and file extensions as fallback.
bool _isVideoUrl(String url) => CloudinaryTransform.isVideoUrl(url);

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroup = false,
    this.senderImageUrl,
    this.onUserTap,
    this.onLongPress,
    this.readCount = 0,
    this.totalOthers = 0,
  });

  final ChatMessage message;
  final bool isMe;

  /// Whether to attribute the message to a person.
  ///
  /// A DM has exactly one other participant, whose name and face are already in
  /// the header — repeating them on every bubble is noise. A group needs both.
  final bool isGroup;

  /// Avatar for the sender, shown only in groups.
  final String? senderImageUrl;

  final VoidCallback? onUserTap;

  /// Called when user long-presses to initiate a reply.
  final VoidCallback? onLongPress;

  /// How many non-sender participants have read this message.
  final int readCount;

  /// Total non-sender participants in the room (1 for DM, N-1 for group).
  final int totalOthers;

  bool get _showsAttribution => isGroup && !isMe;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // Sent messages are a filled accent block with white text; received ones sit
    // on the neutral surface. The contrast is what separates the two sides at a
    // glance, so text colour has to follow the fill rather than the theme.
    final bubbleColor = isMe ? ext.accentGold : ext.cardSurface;
    final textColor = isMe ? Colors.white : ext.greetingColor;
    final mutedTextColor =
        isMe ? Colors.white.withValues(alpha: 0.75) : ext.searchHintColor;

    return GestureDetector(
      onLongPress: onLongPress,
      onHorizontalDragUpdate: (details) {
        onLongPress?.call();
      },
      child: Padding(
        padding:
            EdgeInsets.symmetric(vertical: 4.h, horizontal: AppSpacing.md.w),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showsAttribution)
              Padding(
                padding: EdgeInsets.only(left: 40.w, bottom: 3.h),
                child: Text(
                  message.displayName.isNotEmpty
                      ? message.displayName
                      : message.senderRole.isNotEmpty
                          ? message.senderRole[0].toUpperCase() +
                              message.senderRole.substring(1)
                          : '',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showsAttribution) ...[
                  UserAvatar(
                    imageUrl: senderImageUrl,
                    initial: message.displayName.isNotEmpty
                        ? message.displayName
                        : message.senderId,
                    radius: 14,
                    onTap: onUserTap,
                  ),
                  SizedBox(width: 6.w),
                ],
                Container(
                  constraints: BoxConstraints(
                    // 72% of the window on mobile, but capped so chat media
                    // doesn't balloon to fill the much wider desktop/laptop
                    // window (where the chat panel is only part of the screen).
                    // On web the chat lives in a ~460px side panel, so a 420px
                    // bubble nearly fills (or overflows) it — keep media moderate
                    // there with a tighter cap.
                    maxWidth: (MediaQuery.of(context).size.width * 0.72)
                        .clamp(0.0, kIsWeb ? 300.0 : 420.0),
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18.r),
                      topRight: Radius.circular(18.r),
                      bottomLeft: Radius.circular(isMe ? 18.r : 4.r),
                      bottomRight: Radius.circular(isMe ? 4.r : 18.r),
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    // Stretch, not start: media has to fill the bubble edge to
                    // edge. Under `start` a placeholder or error box — neither
                    // of which has an intrinsic width — collapsed to its own
                    // size and sat in a slab of bubble colour instead.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply preview strip
                      if (message.replyPreview != null)
                        _ReplyPreviewStrip(
                          preview: message.replyPreview!,
                          isMe: isMe,
                          ext: ext,
                        ),
                      // Media (image or video).
                      //
                      // On its own dark ground rather than the bubble's: a sent
                      // bubble is filled with the accent colour, and a photo
                      // still loading or failed to load would otherwise show
                      // that green through its placeholder.
                      if (message.imageUrl != null)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.06),
                          // message.isVideo first: it carries what the sender
                          // actually picked, and already falls back to the URL
                          // when the server had nothing stored. Asking the URL
                          // directly here threw that away, so a video whose URL
                          // does not look like one was handed to the image
                          // loader and rendered "Photo unavailable".
                          child: (message.isVideo ||
                                  _isVideoUrl(message.imageUrl!))
                              ? _MessageVideo(
                                  videoUrl: message.imageUrl!,
                                  aspectRatio: message.mediaAspectRatio,
                                )
                              : _MessageImage(
                                  imageUrl: message.imageUrl!,
                                  aspectRatio: message.mediaAspectRatio,
                                ),
                        ),
                      // Text content
                      if (message.isEncrypted || message.content.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            14.w,
                            message.replyPreview != null ||
                                    message.imageUrl != null
                                ? 8.h
                                : 10.h,
                            14.w,
                            10.h,
                          ),
                          child: message.isEncrypted
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 13.sp,
                                      color: mutedTextColor,
                                    ),
                                    SizedBox(width: AppSpacing.xs.w),
                                    Text(
                                      'Encrypted message',
                                      style: TextStyle(
                                        color: mutedTextColor,
                                        fontSize: 13.sp,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  message.content,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14.sp,
                                    height: 1.4,
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // The time sits under the bubble, outside it — so it never competes
            // with the message for space and reads the same on both sides.
            Padding(
              padding: EdgeInsets.only(
                top: 4.h,
                left: isMe ? 0 : (_showsAttribution ? 40.w : 4.w),
                right: isMe ? 4.w : 0,
              ),
              child: _Timestamp(
                message: message,
                isMe: isMe,
                ext: ext,
                readCount: readCount,
                totalOthers: totalOthers,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reply preview strip ───────────────────────────────────────────────────────

class _ReplyPreviewStrip extends StatelessWidget {
  const _ReplyPreviewStrip({
    required this.preview,
    required this.isMe,
    required this.ext,
  });

  final ReplyPreview preview;
  final bool isMe;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final bg = ext.homeBackground.withValues(alpha: 0.6);
    final accent = ext.searchHintColor;

    return Container(
      margin: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 0),
      padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 6.h),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preview.senderName,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                if (preview.content != null && preview.content!.isNotEmpty)
                  Text(
                    preview.content!,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 11.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (preview.imageUrl != null)
                  Row(
                    children: [
                      Icon(
                        (preview.isVideo || (preview.imageUrl != null && _isVideoUrl(preview.imageUrl!)))
                            ? Icons.videocam_rounded
                            : Icons.image_rounded,
                        size: 12.sp,
                        color: ext.searchHintColor,
                      ),
                      SizedBox(width: AppSpacing.xs.w),
                      Text(
                        preview.isVideo ? 'Video' : 'Photo',
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
          if (preview.imageUrl != null && !(preview.isVideo || _isVideoUrl(preview.imageUrl!)))
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs.r),
              child: JpergImage(
                imageUrl: preview.imageUrl!,
                width: 36.w,
                height: 36.w,
                logicalWidth: 36.w,
                fit: BoxFit.cover,
                semanticLabel: 'Shared photo',
              ),
            )
          else if (preview.imageUrl != null && (preview.isVideo || _isVideoUrl(preview.imageUrl!)))
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs.r),
              child: Container(
                width: 36.w,
                height: 36.w,
                color: Colors.black54,
                alignment: Alignment.center,
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white70, size: 20.sp),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Image attachment ──────────────────────────────────────────────────────────

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.imageUrl, this.aspectRatio});
  final String imageUrl;

  /// Server-supplied aspect ratio (width ÷ height). When present the
  /// placeholder renders at the correct height immediately — no layout jump.
  /// When null falls back to the legacy 180 dp placeholder.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final img = JpergImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      semanticLabel: 'Shared photo',
      placeholder: (_, __) => Container(
        // Use known aspect ratio so bubble height is correct before decode.
        height: aspectRatio != null ? null : 180.h,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      // A photo that will not load is a dead end for the reader: they can see
      // something was sent and have no way to know why it is not there. Say so,
      // and offer the tap that opens it full-screen — which retries the fetch.
      errorWidget: (context, __, ___) => Container(
        height: aspectRatio != null ? null : 140.h,
        color: Colors.black12,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded,
                color: Colors.white70, size: 26.sp),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              'Photo unavailable',
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              'Tap to retry',
              style: TextStyle(color: Colors.white54, fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
    final tappable = Semantics(
      button: true,
      label: 'Open photo',
      child: GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => _ZoomableImageView(imageUrl: imageUrl),
          ),
        ),
        child: img,
      ),
    );
    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio!, child: tappable);
    }
    return tappable;
  }
}

/// Full-screen, zoomable viewer for a shared chat photo.
///
/// Supports pinch / scroll-wheel zoom (1×–6×), double-tap to toggle zoom at the
/// tapped point, and swipe-down-to-dismiss while at rest.
class _ZoomableImageView extends StatefulWidget {
  const _ZoomableImageView({required this.imageUrl});
  final String imageUrl;

  @override
  State<_ZoomableImageView> createState() => _ZoomableImageViewState();
}

class _ZoomableImageViewState extends State<_ZoomableImageView>
    with SingleTickerProviderStateMixin {
  final TransformationController _ctrl = TransformationController();
  late final AnimationController _anim;
  Animation<Matrix4>? _zoomAnim;
  Offset _doubleTapPos = Offset.zero;

  /// Vertical offset while dragging to dismiss (only active at rest).
  double _dragDy = 0;

  bool get _isZoomed => _ctrl.value.getMaxScaleOnAxis() > 1.05;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        final a = _zoomAnim;
        if (a != null) _ctrl.value = a.value;
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _animateZoomTo(Matrix4 target) {
    _zoomAnim = Matrix4Tween(begin: _ctrl.value, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward(from: 0);
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _animateZoomTo(Matrix4.identity());
    } else {
      const scale = 2.5;
      _animateZoomTo(Matrix4.identity()
        ..translateByDouble(-_doubleTapPos.dx * (scale - 1),
            -_doubleTapPos.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, scale, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fade the backdrop out as the photo is dragged away.
    final dismissT = (_dragDy.abs() / 320).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1 - dismissT * 0.7),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
              onDoubleTap: _handleDoubleTap,
              child: Transform.translate(
                offset: Offset(0, _dragDy),
                child: InteractiveViewer(
                  transformationController: _ctrl,
                  minScale: 1,
                  maxScale: 6,
                  // One-finger vertical drag while at rest → swipe to dismiss.
                  // When zoomed in, InteractiveViewer pans instead.
                  onInteractionUpdate: (d) {
                    if (_isZoomed || d.pointerCount > 1) return;
                    setState(() => _dragDy += d.focalPointDelta.dy);
                  },
                  onInteractionEnd: (_) {
                    if (_dragDy.abs() > 130) {
                      Navigator.of(context).pop();
                    } else if (_dragDy != 0) {
                      setState(() => _dragDy = 0);
                    }
                  },
                  child: Center(
                    child: JpergImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                      semanticLabel: 'Shared photo',
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_rounded, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Semantics(
              button: true,
              label: 'Close',
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Video attachment ──────────────────────────────────────────────────────────

/// Thin wrapper: shows [JpergVideoPlayer] inside a chat bubble.
/// Keeps the current bubble-constrained size; aspect ratio hint avoids the
/// 16:9 default while the player reads the container headers.
class _MessageVideo extends StatelessWidget {
  const _MessageVideo({required this.videoUrl, this.aspectRatio});
  final String videoUrl;

  /// Server-supplied aspect ratio. Passed to the player so the correct height
  /// is reserved from the first frame instead of snapping once headers load.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return JpergVideoPlayer(
      url: videoUrl,
      showControls: true,
      autoPlay: false,
      loop: false,
      aspectRatio: aspectRatio,
      fit: BoxFit.contain,
      backgroundColor: Colors.black,
      borderRadius: BorderRadius.circular(12),
    );
  }
}
// ── Timestamp + read indicator ────────────────────────────────────────────────

class _Timestamp extends StatelessWidget {
  const _Timestamp({
    required this.message,
    required this.isMe,
    required this.ext,
    this.readCount = 0,
    this.totalOthers = 0,
  });
  final ChatMessage message;
  final bool isMe;
  final AppThemeExtension ext;
  final int readCount;
  final int totalOthers;

  @override
  Widget build(BuildContext context) {
    final h = message.createdAt.hour.toString().padLeft(2, '0');
    final m = message.createdAt.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m';

    // Read-status logic (only for my sent messages with known participant count).
    Widget? readIndicator;
    if (isMe && totalOthers > 0 && !message.isLocal) {
      final allRead = readCount >= totalOthers;
      final someRead = readCount > 0;
      if (totalOthers == 1) {
        // DM: single/double tick, coloured when read.
        readIndicator = Icon(
          allRead ? Icons.done_all_rounded : Icons.done_rounded,
          size: 11.sp,
          color: allRead ? ext.infoBlue : ext.searchHintColor,
        );
      } else {
        // Group: double tick when all read; "Read by N" when partial; single tick when none.
        if (allRead) {
          readIndicator = Icon(
            Icons.done_all_rounded,
            size: 11.sp,
            color: ext.infoBlue,
          );
        } else if (someRead) {
          readIndicator = Text(
            'Read by $readCount',
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 9.sp,
            ),
          );
        } else {
          readIndicator = Icon(
            Icons.done_rounded,
            size: 11.sp,
            color: ext.searchHintColor,
          );
        }
      }
    } else if (isMe) {
      // Fallback when participant count is unknown or message is local (pending).
      readIndicator = Icon(
        message.isLocal ? Icons.access_time_rounded : Icons.done_all_rounded,
        size: 11.sp,
        color: ext.searchHintColor,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 9.sp,
          ),
        ),
        if (message.isEdited) ...[
          SizedBox(width: AppSpacing.xs.w),
          Text(
            'edited',
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 9.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (readIndicator != null) ...[
          SizedBox(width: 3.w),
          readIndicator,
        ],
      ],
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

