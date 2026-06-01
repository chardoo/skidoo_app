
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';

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
    this.readCount = 0,
    this.totalOthers = 0,
  });

  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onUserTap;

  /// Called when user long-presses to initiate a reply.
  final VoidCallback? onLongPress;

  /// How many non-sender participants have read this message.
  final int readCount;

  /// Total non-sender participants in the room (1 for DM, N-1 for group).
  final int totalOthers;

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
                  message.displayName.isNotEmpty
                      ? message.displayName
                      : message.senderRole.isNotEmpty
                          ? message.senderRole[0].toUpperCase() +
                              message.senderRole.substring(1)
                          : '',
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
                            ? _MessageVideo(
                                videoUrl: message.imageUrl!,
                                aspectRatio: message.mediaAspectRatio,
                              )
                            : _MessageImage(
                                imageUrl: message.imageUrl!,
                                aspectRatio: message.mediaAspectRatio,
                              ),
                      // Text content + timestamp
                      if (message.isEncrypted ||
                          message.content.isNotEmpty ||
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
                              if (message.isEncrypted)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 13.sp,
                                      color: isMe
                                          ? Colors.white70
                                          : ext.searchHintColor,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'Encrypted message',
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white70
                                            : ext.searchHintColor,
                                        fontSize: 13.sp,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                )
                              else if (message.content.isNotEmpty)
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
                                message: message,
                                isMe: isMe,
                                ext: ext,
                                readCount: readCount,
                                totalOthers: totalOthers,
                              ),
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
  const _MessageImage({required this.imageUrl, this.aspectRatio});
  final String imageUrl;

  /// Server-supplied aspect ratio (width ÷ height). When present the
  /// placeholder renders at the correct height immediately — no layout jump.
  /// When null falls back to the legacy 180 dp placeholder.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final img = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      placeholder: (_, __) => Container(
        // Use known aspect ratio so bubble height is correct before decode.
        height: aspectRatio != null ? null : 180.h,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 80.h,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_rounded, color: Colors.white54),
      ),
    );
    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio!, child: img);
    }
    return img;
  }
}

// ── Video attachment ──────────────────────────────────────────────────────────

/// Thin wrapper: shows [SkidooVideoPlayer] inside a chat bubble.
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
    return SkidooVideoPlayer(
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
          color: allRead ? ext.accentGold : Colors.white70,
        );
      } else {
        // Group: double tick when all read; "Read by N" when partial; single tick when none.
        if (allRead) {
          readIndicator = Icon(
            Icons.done_all_rounded,
            size: 11.sp,
            color: ext.accentGold,
          );
        } else if (someRead) {
          readIndicator = Text(
            'Read by $readCount',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 9.sp,
            ),
          );
        } else {
          readIndicator = Icon(
            Icons.done_rounded,
            size: 11.sp,
            color: Colors.white70,
          );
        }
      }
    } else if (isMe) {
      // Fallback when participant count is unknown or message is local (pending).
      readIndicator = Icon(
        message.isLocal ? Icons.access_time_rounded : Icons.done_all_rounded,
        size: 11.sp,
        color: Colors.white70,
      );
    }

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
        if (message.isEdited) ...[
          SizedBox(width: 4.w),
          Text(
            'edited',
            style: TextStyle(
              color: isMe ? Colors.white54 : ext.searchHintColor,
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
    return Semantics(button: true, child: GestureDetector(onTap: onTap, child: avatar));
  }
}
