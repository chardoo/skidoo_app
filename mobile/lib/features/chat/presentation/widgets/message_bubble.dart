import 'dart:io';

import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/purchase/paid_photo_watermark.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/cloudinary_transform.dart';
import 'package:jperg_app/features/chat/presentation/chat_time.dart';
import 'package:jperg_app/features/chat/presentation/widgets/mention_text.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

/// Returns true when [url] points to a video, using both explicit path
/// patterns (Cloudinary /video/upload/) and file extensions as fallback.
bool _isVideoUrl(String url) => CloudinaryTransform.isVideoUrl(url);

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroup = false,
    this.senderImageUrl,
    this.onUserTap,
    this.onLongPress,
    this.onReplyTap,
    this.readCount = 0,
    this.deliveredToCount = 0,
    this.totalOthers = 0,
    this.mentionHandles = const {},
    this.mentionNames = const {},
    this.myUserId = '',
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

  /// Jump to the message this one is quoting. Null when the quoted message
  /// isn't in the loaded history, which leaves the quote as context only.
  final VoidCallback? onReplyTap;

  /// How many non-sender participants have read this message.
  final int readCount;

  /// How many other participants the message has reached. Feeds the grey
  /// double tick — see the tick block in [_MessageMeta].
  final int deliveredToCount;

  /// Total non-sender participants in the room (1 for DM, N-1 for group).
  final int totalOthers;

  /// {userId: handle} for the room, so `@devon_a` in the body can be resolved
  /// to a member and drawn as a mention. Empty in rooms where mentions don't
  /// apply, which short-circuits the whole path.
  final Map<String, String> mentionHandles;

  /// {userId: display name}, so a mention renders as "@Devon" rather than the
  /// handle that was typed.
  final Map<String, String> mentionNames;

  /// Whose mentions read as "@You".
  final String myUserId;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  /// How far the current horizontal swipe has travelled. Only meaningful
  /// between a drag's start and its end.
  double _dragDx = 0;

  /// Whether this swipe has already opened the menu.
  ///
  /// The whole reason this widget has state: onHorizontalDragUpdate fires on
  /// every pointer move, and it used to call the handler each time. A single
  /// ordinary swipe delivers about ten of them, so it pushed ten stacked
  /// bottom sheets that all had to be dismissed one by one.
  bool _swipeHandled = false;

  /// Far enough to be a deliberate swipe rather than a slip while scrolling.
  static const double _swipeThreshold = 36;

  bool get _showsAttribution => widget.isGroup && !widget.isMe;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final message = widget.message;
    final isMe = widget.isMe;
    final readCount = widget.readCount;
    final deliveredToCount = widget.deliveredToCount;
    final totalOthers = widget.totalOthers;
    final onLongPress = widget.onLongPress;

    // Sent messages are a filled accent block with white text; received ones sit
    // on the neutral surface. The contrast is what separates the two sides at a
    // glance, so text colour has to follow the fill rather than the theme.
    final bubbleColor = isMe ? ext.accentGold : ext.cardSurface;
    final textColor = isMe ? Colors.white : ext.greetingColor;
    final mutedTextColor =
        isMe ? Colors.white.withValues(alpha: 0.75) : ext.searchHintColor;

    return GestureDetector(
      onLongPress: onLongPress,
      onHorizontalDragStart: (_) {
        _dragDx = 0;
        _swipeHandled = false;
      },
      onHorizontalDragUpdate: (details) {
        if (_swipeHandled) return;
        _dragDx += details.delta.dx;
        if (_dragDx.abs() >= _swipeThreshold) {
          _swipeHandled = true;
          onLongPress?.call();
        }
      },
      onHorizontalDragEnd: (_) => _swipeHandled = false,
      onHorizontalDragCancel: () => _swipeHandled = false,
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
                if (_showsAttribution) ...[
                  UserAvatar(
                    imageUrl: widget.senderImageUrl,
                    initial: message.displayName.isNotEmpty
                        ? message.displayName
                        : message.senderId,
                    radius: 14,
                    onTap: widget.onUserTap,
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
                        .clamp(0.0, 420.0),
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
                    // Stretch only when there is media to stretch. Media has to
                    // fill the bubble edge to edge — under `start` a placeholder
                    // or error box, neither of which has an intrinsic width,
                    // collapsed to its own size and sat in a slab of bubble
                    // colour. But stretch also hands the Column the full 72% it
                    // is allowed, so a text-only bubble grew to that width
                    // whatever it said: "Bro" drew the same slab as a paragraph.
                    // Text sizes itself, so let it, and the bubble hugs the words.
                    crossAxisAlignment: message.imageUrl != null
                        ? CrossAxisAlignment.stretch
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply preview strip
                      if (message.replyPreview != null)
                        _ReplyPreviewStrip(
                          preview: message.replyPreview!,
                          isMe: isMe,
                          ext: ext,
                          onTap: widget.onReplyTap,
                        ),
                      // Media (image or video).
                      //
                      // On its own dark ground rather than the bubble's: a sent
                      // bubble is filled with the accent colour, and a photo
                      // still loading or failed to load would otherwise show
                      // that green through its placeholder.
                      // `hasLocalMedia` as well as `imageUrl`: a photo or clip
                      // the sender just picked has no URL yet and is drawn from
                      // disk while it uploads. Waiting for the URL meant the
                      // bubble did not exist until the upload finished.
                      if (message.imageUrl != null || message.hasLocalMedia)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.06),
                          // message.isVideo first: it carries what the sender
                          // actually picked, and already falls back to the URL
                          // when the server had nothing stored. Asking the URL
                          // directly here threw that away, so a video whose URL
                          // does not look like one was handed to the image
                          // loader and rendered "Photo unavailable".
                          child: (message.isVideo ||
                                  (message.imageUrl != null &&
                                      _isVideoUrl(message.imageUrl!)))
                              ? _MessageVideo(
                                  // The local file wins while it exists: it is
                                  // already on this device, so it plays with no
                                  // download and does not re-fetch on the echo.
                                  videoUrl: message.localMediaPath != null
                                      ? Uri.file(message.localMediaPath!)
                                          .toString()
                                      : message.imageUrl!,
                                  aspectRatio: message.mediaAspectRatio,
                                  uploadProgress: message.uploadProgress,
                                )
                              // A shared photo that costs money and was not
                              // bought carries the same mark the gallery puts
                              // on it. The message is the one place the app
                              // cannot work this out for itself — it is handed
                              // a URL and nothing else — so the sender records
                              // it and it travels with the message.
                              //
                              // `price: 1` because the amount is not carried
                              // and is not needed: [paidPreview] already means
                              // "priced and unbought", and the widget's rule
                              // only asks whether the price is above zero.
                              : _MessageImage(
                                  imageUrl: message.imageUrl,
                                  localPath: message.localMediaPath,
                                  aspectRatio: message.mediaAspectRatio,
                                  uploadProgress: message.uploadProgress,
                                  // Handed down rather than wrapped here: the
                                  // tap opens a second, full-screen copy that
                                  // has to be marked too.
                                  paidPreview: message.paidPreview,
                                ),
                        ),
                      // Text content, with the timestamp tucked into its
                      // bottom-right corner — the designs put the time inside
                      // the bubble, where it reads as part of the message
                      // rather than a line of its own under every one.
                      if (message.isEncrypted || message.content.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            14.w,
                            message.replyPreview != null ||
                                    message.imageUrl != null
                                ? 8.h
                                : 10.h,
                            14.w,
                            8.h,
                          ),
                          child: Column(
                            // Two cases, because the bubble is sized two ways.
                            //
                            // Text only: the bubble hugs its content, so `end`
                            // is what puts the time in the corner. An Align
                            // here instead would take every pixel it is
                            // offered and drag "Bro" back out to the full 72%
                            // the bubble is allowed.
                            //
                            // With media above, the bubble is already as wide
                            // as the photo, so the caption must stay left —
                            // `end` would push a short caption to the right
                            // edge. There the time gets the Align, which costs
                            // nothing on a bubble that is full width anyway.
                            crossAxisAlignment: message.imageUrl != null
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              message.isEncrypted
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
                                            fontSize: 14.sp,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    )
                                  : MentionText(
                                      text: message.content,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14.sp,
                                        height: 1.4,
                                      ),
                                      mentionStyle: TextStyle(
                                        // On a filled bubble the accent green
                                        // would disappear into it, so a mention
                                        // there is carried by weight instead.
                                        color: isMe
                                            ? Colors.white
                                            : ext.accentGold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      // Underlined in the bubble's own text
                                      // colour rather than a link blue: the
                                      // two bubble fills are very different
                                      // and one colour cannot read on both,
                                      // where an underline reads on either.
                                      linkStyle: TextStyle(
                                        color: textColor,
                                        decoration: TextDecoration.underline,
                                        decorationColor:
                                            textColor.withValues(alpha: 0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      handles: widget.mentionHandles,
                                      displayNames: widget.mentionNames,
                                      myUserId: widget.myUserId,
                                    ),
                              SizedBox(height: 3.h),
                              if (message.imageUrl != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _Timestamp(
                                    message: message,
                                    isMe: isMe,
                                    ext: ext,
                                    color: mutedTextColor,
                                    readCount: readCount,
                                    deliveredToCount: deliveredToCount,
                                    totalOthers: totalOthers,
                                  ),
                                )
                              else
                                _Timestamp(
                                  message: message,
                                  isMe: isMe,
                                  ext: ext,
                                  color: mutedTextColor,
                                  readCount: readCount,
                                  deliveredToCount: deliveredToCount,
                                  totalOthers: totalOthers,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // A media-only bubble has no text block to put the time in, so it
            // keeps the line underneath. Overlaying it on the photo would put
            // grey-on-unknown text over whatever happens to be in that corner.
            if (!message.isEncrypted && message.content.isEmpty)
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
                  deliveredToCount: deliveredToCount,
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
    this.onTap,
  });

  final ReplyPreview preview;
  final bool isMe;
  final AppThemeExtension ext;

  /// Jump to the quoted message. Null when it isn't loaded.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // On a filled bubble the quote is a darker patch of the same colour with a
    // white rule down its edge — the designs treat it as a shadow of the bubble
    // rather than a card sitting on it. On a received bubble there is no fill to
    // darken, so it takes the accent green for the rule and a wash of the page
    // colour behind, which is the same relationship inverted.
    final bg = isMe
        ? Colors.black.withValues(alpha: 0.16)
        : ext.homeBackground.withValues(alpha: 0.7);
    final rule = isMe ? Colors.white.withValues(alpha: 0.9) : ext.accentGold;
    final nameColor = isMe ? Colors.white : ext.accentGold;
    final bodyColor =
        isMe ? Colors.white.withValues(alpha: 0.85) : ext.searchHintColor;

    final strip = Container(
      margin: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 0),
      padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 6.h),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          left: BorderSide(color: rule, width: 3),
        ),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        // Min + Flexible, not a bare Expanded: an Expanded fills every pixel the
        // bubble is allowed, which would drag a short reply back out to full
        // width now that the bubble sizes itself to its content. Flexible still
        // lets the two lines ellipsize when the quoted message is long.
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preview.senderName,
                  style: TextStyle(
                    color: nameColor,
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
                      color: bodyColor,
                      fontSize: 11.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (preview.imageUrl != null)
                  Row(
                    children: [
                      Icon(
                        (preview.isVideo ||
                                (preview.imageUrl != null &&
                                    _isVideoUrl(preview.imageUrl!)))
                            ? Icons.videocam_rounded
                            : Icons.image_rounded,
                        size: 12.sp,
                        color: bodyColor,
                      ),
                      SizedBox(width: AppSpacing.xs.w),
                      Text(
                        preview.isVideo ? 'Video' : 'Photo',
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (preview.imageUrl != null &&
              !(preview.isVideo || _isVideoUrl(preview.imageUrl!)))
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
          else if (preview.imageUrl != null &&
              (preview.isVideo || _isVideoUrl(preview.imageUrl!)))
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

    if (onTap == null) return strip;
    return Semantics(
      button: true,
      label: 'Go to replied message',
      child: GestureDetector(onTap: onTap, child: strip),
    );
  }
}

// ── Image attachment ──────────────────────────────────────────────────────────

class _MessageImage extends StatelessWidget {
  const _MessageImage({
    required this.imageUrl,
    this.localPath,
    this.aspectRatio,
    this.uploadProgress,
    this.paidPreview = false,
  }) : assert(imageUrl != null || localPath != null,
            'a photo has to come from somewhere');

  /// Null until the upload finishes — see [localPath].
  final String? imageUrl;

  /// The file on this device, while the upload is in flight and after.
  ///
  /// Takes precedence over [imageUrl] whenever it is set: it needs no network,
  /// so the photo is on screen in the frame the user hit send, and the echo
  /// that swaps in the URL costs no re-fetch and shows no placeholder.
  final String? localPath;

  /// Upload progress 0..1, or null when there is no upload in flight.
  final double? uploadProgress;

  /// Whether this is a paid photo the sender had not bought.
  ///
  /// Carried rather than wrapped from outside, because the tap opens a
  /// *second* copy of the photo full-screen and that one has to be marked too
  /// — otherwise the mark is a thing you get rid of by tapping the picture.
  final bool paidPreview;

  /// Server-supplied aspect ratio (width ÷ height). When present the
  /// placeholder renders at the correct height immediately — no layout jump.
  /// When null falls back to the legacy 180 dp placeholder.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final Widget img = localPath != null
        ? Image.file(
            File(localPath!),
            fit: BoxFit.cover,
            semanticLabel: 'Shared photo',
            // The picked file can be gone by the time this draws — a temp file
            // the OS reclaimed, or a share that copied and cleaned up. Fall
            // back to the URL when there is one rather than showing the grey
            // box of a broken decode.
            errorBuilder: (context, _, __) => imageUrl != null
                ? JpergImage(imageUrl: imageUrl!, fit: BoxFit.cover)
                : const SizedBox.shrink(),
          )
        : JpergImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            semanticLabel: 'Shared photo',
            placeholder: (_, __) => Container(
              // Use known aspect ratio so bubble height is correct before decode.
              height: aspectRatio != null ? null : 180.h,
              color: Colors.black12,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
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
    // `price: 1` because the amount is not carried on a message and is not
    // needed — [paidPreview] already means "priced and unbought", and the rule
    // only asks whether the price is above zero.
    Widget marked = PaidPhotoWatermark(
      price: paidPreview ? 1 : 0,
      isPurchased: false,
      child: img,
    );
    if (uploadProgress != null) {
      marked = _UploadProgressOverlay(progress: uploadProgress!, child: marked);
    }
    final tappable = Semantics(
      button: true,
      label: 'Open photo',
      child: GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => _ZoomableImageView(
              imageUrl: imageUrl,
              localPath: localPath,
              paidPreview: paidPreview,
            ),
          ),
        ),
        child: marked,
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
  const _ZoomableImageView({
    required this.imageUrl,
    this.localPath,
    this.paidPreview = false,
  });
  final String? imageUrl;

  /// The copy on this device, preferred over [imageUrl] when present — same
  /// reason as in [_MessageImage], and it is the only source there is while an
  /// upload is still in flight.
  final String? localPath;

  /// Whether to mark this as a paid photo — see the overlay in [build], and
  /// why it sits outside the zoom.
  final bool paidPreview;

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
                    child: widget.localPath != null
                        ? Image.file(
                            File(widget.localPath!),
                            fit: BoxFit.contain,
                            semanticLabel: 'Shared photo',
                            errorBuilder: (_, __, ___) =>
                                widget.imageUrl != null
                                    ? JpergImage(
                                        imageUrl: widget.imageUrl!,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(Icons.broken_image_rounded,
                                        color: Colors.white54, size: 48),
                          )
                        : JpergImage(
                            imageUrl: widget.imageUrl!,
                            fit: BoxFit.contain,
                            semanticLabel: 'Shared photo',
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white54),
                          ),
                  ),
                ),
              ),
            ),
          ),
          // The mark: pinned to the screen, sized to the zoom.
          //
          // Deliberately *outside* the InteractiveViewer. Inside, it would
          // travel with the image — and at 6x on a corner the logo would be
          // somewhere off-screen, which hands back exactly the clean
          // screenshot it exists to prevent. Fixed to the viewport it is in
          // every frame, at every zoom, wherever the photo has been dragged.
          //
          // It still takes the zoom, because pinning alone was not enough: at
          // 6× the window holds a sixth of the picture, so a mark held at its
          // resting size covered a sixth as much of it. This grows to match,
          // driven off the same controller the viewer is transformed by.
          if (widget.paidPreview)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => PaidPhotoWatermark(
                    price: 1,
                    isPurchased: false,
                    scale: _ctrl.value.getMaxScaleOnAxis(),
                    child: const SizedBox.expand(),
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
                  child: const AppSvgIcon(AppIcons.closeMd, color: Colors.white),
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
  const _MessageVideo({
    required this.videoUrl,
    this.aspectRatio,
    this.uploadProgress,
  });

  /// Either a remote URL or a `file://` path — [JpergVideoPlayer] picks the
  /// right controller for each, which is what lets a clip play from disk while
  /// it is still uploading.
  final String videoUrl;

  /// Upload progress 0..1, or null when nothing is in flight.
  final double? uploadProgress;

  /// Server-supplied aspect ratio. Passed to the player so the correct height
  /// is reserved from the first frame instead of snapping once headers load.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final player = JpergVideoPlayer(
      url: videoUrl,
      // Not while it is uploading: the controls offer a scrub bar and a
      // fullscreen button for something that is not finished being sent, and
      // the progress bar is sitting in the same corner.
      showControls: uploadProgress == null,
      autoPlay: false,
      loop: false,
      aspectRatio: aspectRatio,
      fit: BoxFit.contain,
      backgroundColor: Colors.black,
      borderRadius: BorderRadius.circular(12),
    );
    if (uploadProgress == null) return player;
    return _UploadProgressOverlay(progress: uploadProgress!, child: player);
  }
}

/// What a send looks like while it is still going out.
///
/// Sits over the media rather than replacing it — the whole point is that the
/// picture or clip is visible from the moment it is picked, so this has to be
/// something laid on top and not something shown instead.
class _UploadProgressOverlay extends StatelessWidget {
  const _UploadProgressOverlay({
    required this.progress,
    required this.child,
  });

  /// 0..1.
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Dimmed while it is not really sent yet, which reads as "pending"
        // without needing a word for it.
        Opacity(opacity: 0.75, child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Semantics(
                label: 'Sending, ${(progress * 100).round()} percent',
                child: SizedBox(
                  width: 44.w,
                  height: 44.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // A determinate ring rather than a spinner: on a clip
                      // over a slow connection a spinner and a hang look
                      // exactly the same, and the difference is the only thing
                      // the sender wants to know.
                      CircularProgressIndicator(
                        value: progress == 0 ? null : progress,
                        strokeWidth: 3,
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 16.sp,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// ── Timestamp + read indicator ────────────────────────────────────────────────

class _Timestamp extends StatelessWidget {
  const _Timestamp({
    required this.message,
    required this.isMe,
    required this.ext,
    this.color,
    this.readCount = 0,
    this.deliveredToCount = 0,
    this.totalOthers = 0,
  });
  final ChatMessage message;
  final bool isMe;
  final AppThemeExtension ext;

  /// Set when the timestamp sits inside the bubble, where the theme's muted
  /// grey is unreadable on a filled accent ground. Null keeps the muted grey
  /// used under a media-only bubble.
  final Color? color;

  final int readCount;

  /// How many other participants the message has reached. Feeds the grey
  /// double tick — see the tick block in [_MessageMeta].
  final int deliveredToCount;
  final int totalOthers;

  @override
  Widget build(BuildContext context) {
    // createdAt is UTC; ChatTime puts it on the phone's clock.
    final timeStr = ChatTime.bubbleClock(message.createdAt);
    final tint = color ?? ext.searchHintColor;

    // ── Ticks ────────────────────────────────────────────────────────────────
    //
    // Three states, and the app used to be able to draw only two of them:
    //
    //   ✓        sent       the server has it
    //   ✓✓ grey  delivered  it reached every other participant's device
    //   ✓✓ blue  read       every one of them has opened it
    //
    // The middle state needs `delivered_to`, which the server has always sent
    // and the client never parsed — so anything not actively read sat on a
    // single tick forever. That is the "always one tick" report: not a bug in
    // this widget's logic so much as a state it had no data to reach.
    //
    // Delivery is counted as max(delivered, read) rather than from
    // `deliveredTo` alone. A read implies delivery and the bloc now writes
    // both, but history fetched from REST can carry a read with no matching
    // delivery row, and without the max a blue message would fall back to one
    // grey tick on reload — a tick going *backwards*, which reads as the
    // message having been un-delivered.
    Widget? readIndicator;
    if (isMe && totalOthers > 0 && !message.isLocal) {
      final allRead = readCount >= totalOthers;
      final deliveredCount =
          deliveredToCount > readCount ? deliveredToCount : readCount;
      final allDelivered = deliveredCount >= totalOthers;

      if (allRead) {
        readIndicator =
            Icon(Icons.done_all_rounded, size: 11.sp, color: ext.infoBlue);
      } else if (totalOthers > 1 && readCount > 0) {
        // Partial in a group: the number is more use than a tick, because "some
        // of the nine" is not a state two ticks can express.
        readIndicator = Text(
          'Read by $readCount',
          style: TextStyle(color: tint, fontSize: 9.sp),
        );
      } else if (allDelivered) {
        readIndicator = Icon(Icons.done_all_rounded, size: 11.sp, color: tint);
      } else {
        readIndicator = Icon(Icons.done_rounded, size: 11.sp, color: tint);
      }
    } else if (isMe) {
      // Local means still in flight — a clock, not a tick. Otherwise the
      // participant count is unknown (a room whose roster has not loaded), and
      // one tick is the honest answer there: the server has it, and nothing is
      // known about anyone else. It used to draw a confident double tick.
      readIndicator = Icon(
        message.isLocal ? Icons.access_time_rounded : Icons.done_rounded,
        size: 11.sp,
        color: tint,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: TextStyle(
            color: tint,
            fontSize: 10.sp,
          ),
        ),
        if (message.isEdited) ...[
          SizedBox(width: AppSpacing.xs.w),
          Text(
            'edited',
            style: TextStyle(
              color: tint,
              fontSize: 10.sp,
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
