import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/validators/media_validator.dart';
import 'package:skidoo_app/core/widgets/emoji_panel.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.ext,
    this.replyingTo,
    this.onClearReply,
    this.onImagePicked,
    this.pendingImagePath,
    this.pendingIsVideo = false,
    this.pendingShareUrl,
    this.onClearImage,
    this.isUploadingImage = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final AppThemeExtension ext;

  final ChatMessage? replyingTo;
  final VoidCallback? onClearReply;

  /// Called with the local file path, optional MIME type, and whether it is a video.
  /// On web [filePath] is a blob URL; [mimeType] is the browser-reported MIME type.
  final void Function(String filePath, {String? mimeType, bool isVideo})? onImagePicked;

  /// Path of the staged local image/video waiting to be uploaded and sent.
  final String? pendingImagePath;

  /// True when the staged file is a video.
  final bool pendingIsVideo;

  /// Remote URL of a staged image (e.g. from gallery share) waiting to be sent.
  final String? pendingShareUrl;

  final VoidCallback? onClearImage;

  /// True only while the media is being uploaded (after send is tapped).
  final bool isUploadingImage;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _emojiOpen = false;

  void _toggleEmoji() {
    setState(() => _emojiOpen = !_emojiOpen);
    if (_emojiOpen) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final error = await MediaValidator.validate(picked, isVideo: false);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    widget.onImagePicked?.call(picked.path, mimeType: picked.mimeType, isVideo: false);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final error = await MediaValidator.validate(picked, isVideo: true);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    widget.onImagePicked?.call(picked.path, mimeType: picked.mimeType, isVideo: true);
  }

  void _showMediaPicker() {
    final ext = widget.ext;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaPickerSheet(
        ext: ext,
        onPickImage: () {
          Navigator.of(context).pop();
          _pickImage();
        },
        onPickVideo: () {
          Navigator.of(context).pop();
          _pickVideo();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final hasStaged =
        widget.pendingImagePath != null || widget.pendingShareUrl != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Emoji panel — sibling above the input row so it's never clipped ─
        if (_emojiOpen)
          EmojiPickerPanel(
            ext: ext,
            onEmojiSelected: (emoji) =>
                insertEmoji(widget.controller, emoji),
          ),

        // ── Staged media preview ────────────────────────────────────────────
        if (widget.pendingImagePath != null)
          widget.pendingIsVideo
              ? _StagedVideoPreview(
                  filePath: widget.pendingImagePath!,
                  isUploading: widget.isUploadingImage,
                  ext: ext,
                  onClear: widget.onClearImage,
                )
              : _StagedImagePreview(
                  filePath: widget.pendingImagePath!,
                  isUploading: widget.isUploadingImage,
                  ext: ext,
                  onClear: widget.onClearImage,
                )
        else if (widget.pendingShareUrl != null)
          _StagedNetworkImagePreview(
            imageUrl: widget.pendingShareUrl!,
            ext: ext,
            onClear: widget.onClearImage,
          ),

        // ── Reply preview strip ─────────────────────────────────────────────
        if (widget.replyingTo != null)
          _ReplyBar(
              message: widget.replyingTo!, ext: ext, onClear: widget.onClearReply),

        // ── Main input row ──────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 24.h),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            border: Border(
              top: BorderSide(
                  color: ext.searchHintColor.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Media picker — disabled while uploading or already staged
              Semantics(button: true, label: 'Show media picker', child: GestureDetector(
                onTap: (widget.isUploadingImage || hasStaged)
                    ? null
                    : _showMediaPicker,
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: ext.searchFieldFill,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.attach_file_rounded,
                    color: (widget.isUploadingImage || hasStaged)
                        ? ext.searchHintColor.withValues(alpha: 0.4)
                        : ext.searchHintColor,
                    size: 20.sp,
                  ),
                ),
              )),
              SizedBox(width: 4.w),

              // Emoji button
              EmojiButton(
                isOpen: _emojiOpen,
                onToggle: _toggleEmoji,
                ext: ext,
                iconSize: 20.sp,
              ),
              SizedBox(width: 4.w),

              // Text input
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onTap: () {
                    if (_emojiOpen) setState(() => _emojiOpen = false);
                  },
                  style:
                      TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                  maxLines: 4,
                  minLines: 1,
                  maxLength: 1000,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      currentLength >= 900
                          ? Text(
                              '$currentLength/$maxLength',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: currentLength >= 1000
                                    ? Colors.red
                                    : ext.searchHintColor,
                              ),
                            )
                          : null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: hasStaged
                        ? 'Add a caption… (optional)'
                        : widget.replyingTo != null
                            ? 'Reply…'
                            : 'Type a message…',
                    hintStyle: TextStyle(
                        color: ext.searchHintColor, fontSize: 14.sp),
                    filled: true,
                    fillColor: ext.searchFieldFill,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(22.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 10.h),
                    isDense: true,
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
              SizedBox(width: 8.w),

              // Send button
              Semantics(button: true, label: 'Send', child: GestureDetector(
                onTap: widget.isUploadingImage ? null : widget.onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: widget.isUploadingImage
                        ? ext.accentGold.withValues(alpha: 0.4)
                        : ext.accentGold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: widget.isUploadingImage
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.send_rounded,
                          color: Colors.white, size: 20.sp),
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Media picker sheet ────────────────────────────────────────────────────────

class _MediaPickerSheet extends StatelessWidget {
  const _MediaPickerSheet({
    required this.ext,
    required this.onPickImage,
    required this.onPickVideo,
  });

  final AppThemeExtension ext;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 24.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: ext.searchHintColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 8.h),
          ListTile(
            leading: Icon(Icons.image_rounded, color: ext.accentGold),
            title: Text('Photo',
                style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
            onTap: onPickImage,
          ),
          ListTile(
            leading: Icon(Icons.videocam_rounded, color: ext.accentGold),
            title: Text('Video',
                style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
            onTap: onPickVideo,
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}

// ── Staged image preview ──────────────────────────────────────────────────────

class _StagedImagePreview extends StatelessWidget {
  const _StagedImagePreview({
    required this.filePath,
    required this.isUploading,
    required this.ext,
    this.onClear,
  });

  final String filePath;
  final bool isUploading;
  final AppThemeExtension ext;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
      color: ext.cardSurface,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'View attached image full screen',
            child: GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => _StagedImageFullScreen(filePath: filePath),
                ),
              ),
              child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // On web, filePath is a blob URL — Image.network handles it.
                // On mobile, filePath is a local file path.
                kIsWeb
                    ? Semantics(image: true, label: 'Selected image', child: Image.network(
                        filePath,
                        width: 64.w,
                        height: 64.w,
                        fit: BoxFit.cover,
                      ))
                    : Image.file(
                        File(filePath),
                        width: 64.w,
                        height: 64.w,
                        fit: BoxFit.cover,
                      ),
                if (isUploading)
                  Container(
                    width: 64.w,
                    height: 64.w,
                    color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: ext.accentGold),
                    ),
                  ),
              ],
            ),
          ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              isUploading ? 'Uploading…' : 'Image ready — add a caption or send',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
          ),
          if (!isUploading)
            Semantics(button: true, label: 'Clear', child: GestureDetector(
              onTap: onClear,
              child: Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: ext.searchFieldFill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.close_rounded,
                    size: 16.sp, color: ext.searchHintColor),
              ),
            )),
        ],
      ),
    );
  }
}

/// Full-screen, pinch/zoomable viewer for a staged (not-yet-sent) attachment.
/// Handles both web blob URLs (Image.network) and local file paths (Image.file).
class _StagedImageFullScreen extends StatelessWidget {
  const _StagedImageFullScreen({required this.filePath});
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Semantics(
                  image: true,
                  label: 'Attached photo',
                  child: kIsWeb
                      ? Image.network(filePath, fit: BoxFit.contain)
                      : Image.file(File(filePath), fit: BoxFit.contain),
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

// ── Staged video preview ──────────────────────────────────────────────────────

class _StagedVideoPreview extends StatefulWidget {
  const _StagedVideoPreview({
    required this.filePath,
    required this.isUploading,
    required this.ext,
    this.onClear,
  });

  final String filePath;
  final bool isUploading;
  final AppThemeExtension ext;
  final VoidCallback? onClear;

  @override
  State<_StagedVideoPreview> createState() => _StagedVideoPreviewState();
}

class _StagedVideoPreviewState extends State<_StagedVideoPreview> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
      color: widget.ext.cardSurface,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: SizedBox(
              width: 64.w,
              height: 64.w,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SkidooVideoPlayer(
                    // On web, filePath is a blob URL (no file:// prefix needed).
                    // On mobile, add file:// so the video player resolves it.
                    url: kIsWeb ? widget.filePath : 'file://${widget.filePath}',
                    autoPlay: false,
                    showControls: false,
                    fit: BoxFit.cover,
                    backgroundColor: Colors.black,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.35)),
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white70, size: 28),
                  ),
                  if (widget.isUploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: widget.ext.accentGold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              widget.isUploading
                  ? 'Uploading video…'
                  : 'Video ready — add a caption or send',
              style:
                  TextStyle(color: widget.ext.searchHintColor, fontSize: 12.sp),
            ),
          ),
          if (!widget.isUploading)
            Semantics(button: true, label: 'Clear', child: GestureDetector(
              onTap: widget.onClear,
              child: Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: widget.ext.searchFieldFill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.close_rounded,
                    size: 16.sp, color: widget.ext.searchHintColor),
              ),
            )),
        ],
      ),
    );
  }
}

// ── Staged network image preview (shared gallery URL) ─────────────────────────

class _StagedNetworkImagePreview extends StatelessWidget {
  const _StagedNetworkImagePreview({
    required this.imageUrl,
    required this.ext,
    this.onClear,
  });

  final String imageUrl;
  final AppThemeExtension ext;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
      color: ext.cardSurface,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Semantics(image: true, label: 'Selected image', child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 64.w,
              height: 64.w,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 64.w,
                height: 64.w,
                color: Colors.black12,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: ext.accentGold),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 64.w,
                height: 64.w,
                color: Colors.black12,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_rounded,
                    color: Colors.white54, size: 24.sp),
              ),
            )),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Image ready — add a caption or send',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
          ),
          Semantics(button: true, label: 'Clear', child: GestureDetector(
            onTap: onClear,
            child: Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: ext.searchFieldFill,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.close_rounded,
                  size: 16.sp, color: ext.searchHintColor),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Reply preview bar ─────────────────────────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.message,
    required this.ext,
    this.onClear,
  });

  final ChatMessage message;
  final AppThemeExtension ext;
  final VoidCallback? onClear;

  String get _preview {
    if (message.content.isNotEmpty) return message.content;
    if (message.imageUrl != null) {
      return message.isVideo ? '🎬 Video' : '📷 Photo';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        border: Border(
          top: BorderSide(color: ext.searchHintColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32.h,
            color: ext.accentGold,
            margin: EdgeInsets.only(right: 8.w),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.senderName.isNotEmpty
                      ? message.senderName
                      : message.senderRole,
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _preview,
                  style:
                      TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            tooltip: 'Clear',
            icon: Icon(Icons.close_rounded,
                size: 18.sp, color: ext.searchHintColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
