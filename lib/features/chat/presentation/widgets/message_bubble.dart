
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:video_player/video_player.dart';

/// Returns true when [url] points to a video, using both explicit path
/// patterns (Cloudinary /video/upload/) and file extensions as fallback.
bool _isVideoUrl(String url) {
  final lower = url.toLowerCase().split('?').first;
  if (lower.contains('/video/upload/')) return true;
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm');
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onUserTap,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onUserTap;

  /// Called when user long-presses to initiate a reply.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return GestureDetector(
      onLongPress: onLongPress,
      onHorizontalDragUpdate: (details) {
        onLongPress?.call();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 12.w),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender label
            if (!isMe)
              Padding(
                padding: EdgeInsets.only(left: 4.w, bottom: 2.h),
                child: Text(
                  message.senderName.isNotEmpty
                      ? message.senderName
                      : message.senderRole,
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe) ...[
                  _Avatar(
                    senderId: message.senderId,
                    ext: ext,
                    onTap: onUserTap,
                  ),
                  SizedBox(width: 6.w),
                ],
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? ext.accentGold : ext.cardSurface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18.r),
                      topRight: Radius.circular(18.r),
                      bottomLeft: Radius.circular(isMe ? 18.r : 4.r),
                      bottomRight: Radius.circular(isMe ? 4.r : 18.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply preview strip
                      if (message.replyPreview != null)
                        _ReplyPreviewStrip(
                          preview: message.replyPreview!,
                          isMe: isMe,
                          ext: ext,
                        ),
                      // Media (image or video)
                      if (message.imageUrl != null)
                        _isVideoUrl(message.imageUrl!)
                            ? _MessageVideo(videoUrl: message.imageUrl!)
                            : _MessageImage(imageUrl: message.imageUrl!),
                      // Text content + timestamp
                      if (message.content.isNotEmpty ||
                          message.imageUrl == null)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            14.w,
                            message.replyPreview != null ||
                                    message.imageUrl != null
                                ? 6.h
                                : 10.h,
                            14.w,
                            10.h,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.content.isNotEmpty)
                                Text(
                                  message.content,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : ext.greetingColor,
                                    fontSize: 14.sp,
                                    height: 1.4,
                                  ),
                                ),
                              SizedBox(height: 3.h),
                              _Timestamp(
                                  message: message, isMe: isMe, ext: ext),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding:
                              EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 6.h),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _Timestamp(
                                message: message, isMe: isMe, ext: ext),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
    final bg = isMe
        ? Colors.white.withValues(alpha: 0.18)
        : ext.homeBackground.withValues(alpha: 0.6);
    final accent = isMe ? Colors.white70 : ext.accentGold;

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
                      color: isMe ? Colors.white70 : ext.searchHintColor,
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
                        color: isMe ? Colors.white70 : ext.searchHintColor,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        preview.isVideo ? 'Video' : 'Photo',
                        style: TextStyle(
                          color: isMe ? Colors.white70 : ext.searchHintColor,
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
              borderRadius: BorderRadius.circular(4.r),
              child: CachedNetworkImage(
                imageUrl: preview.imageUrl!,
                width: 36.w,
                height: 36.w,
                fit: BoxFit.cover,
              ),
            )
          else if (preview.imageUrl != null && (preview.isVideo || _isVideoUrl(preview.imageUrl!)))
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
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
  const _MessageImage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: 180.h,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 80.h,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_rounded, color: Colors.white54),
      ),
    );
  }
}

// ── Video attachment ──────────────────────────────────────────────────────────

class _MessageVideo extends StatefulWidget {
  const _MessageVideo({required this.videoUrl});
  final String videoUrl;

  @override
  State<_MessageVideo> createState() => _MessageVideoState();
}

class _MessageVideoState extends State<_MessageVideo> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      }).catchError((Object e) {
        debugPrint('[VIDEO] init error for ${widget.videoUrl}: $e');
      });
  }

  @override
  void dispose() {
    _ctrl
      ..pause()
      ..dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_ctrl.value.isPlaying) {
        _ctrl.pause();
      } else {
        _ctrl.play();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _ctrl.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a fixed-height loading placeholder while initializing.
    if (!_initialized) {
      return Container(
        height: 200.h,
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white54),
      );
    }

    final aspect = _ctrl.value.aspectRatio;

    return GestureDetector(
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_ctrl),

            // Dark scrim + play/pause icon overlay
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _ctrl,
              builder: (_, value, __) {
                final playing = value.isPlaying;
                return AnimatedOpacity(
                  opacity: playing ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 48.sp,
                    ),
                  ),
                );
              },
            ),

            // Mute toggle — top-right corner
            Positioned(
              top: 8.h,
              right: 8.w,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 16.sp,
                  ),
                ),
              ),
            ),

            // Progress bar — bottom edge
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _ctrl,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.transparent,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Timestamp + read indicator ────────────────────────────────────────────────

class _Timestamp extends StatelessWidget {
  const _Timestamp({
    required this.message,
    required this.isMe,
    required this.ext,
  });
  final ChatMessage message;
  final bool isMe;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final h = message.createdAt.hour.toString().padLeft(2, '0');
    final m = message.createdAt.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: TextStyle(
            color: isMe ? Colors.white70 : ext.searchHintColor,
            fontSize: 9.sp,
          ),
        ),
        if (isMe) ...[
          SizedBox(width: 3.w),
          Icon(
            message.isLocal
                ? Icons.access_time_rounded
                : Icons.done_all_rounded,
            size: 11.sp,
            color: Colors.white70,
          ),
        ],
      ],
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.senderId, required this.ext, this.onTap});
  final String senderId;
  final AppThemeExtension ext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = senderId.isNotEmpty ? senderId[0].toUpperCase() : '?';
    final avatar = CircleAvatar(
      radius: 14.r,
      backgroundColor: ext.avatarBackground,
      child: Text(
        initial,
        style: TextStyle(
          color: ext.avatarForeground,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
