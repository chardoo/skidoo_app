import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jperg_app/core/common/widgets/xfile_image.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_media_limits.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/validators/media_validator.dart';
import 'package:jperg_app/core/widgets/emoji_panel.dart';
import 'package:jperg_app/features/chat/presentation/mentions.dart';
import 'package:jperg_app/features/chat/presentation/widgets/mention_picker.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.ext,
    this.replyingTo,
    this.onClearReply,
    this.editing,
    this.onCancelEdit,
    this.focusNode,
    this.onImagePicked,
    this.pendingImagePath,
    this.pendingIsVideo = false,
    this.pendingShareUrl,
    this.onClearImage,
    this.isUploadingImage = false,
    this.onTypingChanged,
    this.mentionCandidates = const [],
    this.mentionHandles = const {},
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final AppThemeExtension ext;

  final ChatMessage? replyingTo;
  final VoidCallback? onClearReply;

  /// The message being edited, if any. The composer holds its text, [onSend]
  /// applies the change, and the bar above says which message is being changed
  /// — no dialog, so the conversation stays visible while it is rewritten.
  final ChatMessage? editing;

  /// Leaves edit mode without applying anything.
  final VoidCallback? onCancelEdit;

  /// Focus for the text field, so the caller can put the caret in the composer
  /// when it loads a message in for editing.
  final FocusNode? focusNode;

  /// Called with the local file path, optional MIME type, and whether it is a video.
  /// On web [filePath] is a blob URL; [mimeType] is the browser-reported MIME type.
  final void Function(String filePath, {String? mimeType, bool isVideo})?
      onImagePicked;

  /// Path of the staged local image/video waiting to be uploaded and sent.
  final String? pendingImagePath;

  /// True when the staged file is a video.
  final bool pendingIsVideo;

  /// Remote URL of a staged image (e.g. from gallery share) waiting to be sent.
  final String? pendingShareUrl;

  final VoidCallback? onClearImage;

  /// True only while the media is being uploaded (after send is tapped).
  final bool isUploadingImage;

  /// Raised as the user types and again when they stop. Called on every
  /// keystroke — the bloc rate-limits what actually reaches the socket, so
  /// there is nothing to debounce here.
  final ValueChanged<bool>? onTypingChanged;

  /// Who can be mentioned here. Empty in a DM — there is one other person and
  /// naming them in a conversation with only them in it says nothing.
  final List<ChatParticipant> mentionCandidates;

  /// {userId: handle} for [mentionCandidates], resolved once by the caller so
  /// the same assignment is used by the picker and by the message renderer.
  final Map<String, String> mentionHandles;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _emojiOpen = false;

  /// The `@…` fragment under the caret, or null when the user isn't writing a
  /// mention. Recomputed on every change to the field — including caret moves,
  /// since clicking into an existing `@name` should reopen the picker.
  MentionQuery? _mentionQuery;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncMentionQuery);
  }

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncMentionQuery);
      widget.controller.addListener(_syncMentionQuery);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncMentionQuery);
    super.dispose();
  }

  void _syncMentionQuery() {
    if (widget.mentionCandidates.isEmpty) return;
    final selection = widget.controller.selection;
    // A collapsed selection is a caret. While text is selected there is no
    // single insertion point, so there is nothing to complete.
    final query = selection.isValid && selection.isCollapsed
        ? Mentions.queryAt(widget.controller.text, selection.baseOffset)
        : null;
    if (query?.query == _mentionQuery?.query &&
        query?.start == _mentionQuery?.start) {
      return;
    }
    setState(() => _mentionQuery = query);
  }

  /// Members matching what has been typed after the `@`.
  List<ChatParticipant> get _mentionMatches {
    final query = _mentionQuery;
    if (query == null || widget.mentionCandidates.isEmpty) return const [];
    return Mentions.matches(
      widget.mentionCandidates,
      widget.mentionHandles,
      query.query,
    );
  }

  void _insertMention(ChatParticipant participant) {
    final query = _mentionQuery;
    final handle = widget.mentionHandles[participant.userId];
    if (query == null || handle == null) return;

    final result = Mentions.insert(widget.controller.text, query, handle);
    widget.controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.caret),
    );
    setState(() => _mentionQuery = null);
    // The composer is no longer empty, and the field's own onChanged does not
    // fire for a programmatic edit.
    widget.onTypingChanged?.call(result.text.trim().isNotEmpty);
  }

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
    final limits = await sl<ChatMediaLimitsService>().get();
    final error = await MediaValidator.validate(picked,
        isVideo: false, maxBytes: limits.maxImageBytes);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    widget.onImagePicked
        ?.call(picked.path, mimeType: picked.mimeType, isVideo: false);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final limits = await sl<ChatMediaLimitsService>().get();
    final error = await MediaValidator.validate(picked,
        isVideo: true, maxBytes: limits.maxVideoBytes);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    widget.onImagePicked
        ?.call(picked.path, mimeType: picked.mimeType, isVideo: true);
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
    final isEditing = widget.editing != null;
    final mentionMatches = _mentionMatches;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Mention picker — above everything else in the composer stack, so
        // it sits directly over the conversation while an @ is being typed ──
        if (mentionMatches.isNotEmpty)
          MentionPicker(
            participants: mentionMatches,
            handles: widget.mentionHandles,
            onSelected: _insertMention,
          ),

        // ── Emoji panel — sibling above the input row so it's never clipped ─
        if (_emojiOpen)
          EmojiPickerPanel(
            ext: ext,
            onEmojiSelected: (emoji) => insertEmoji(widget.controller, emoji),
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

        // ── Editing / reply preview strip ───────────────────────────────────
        // Never both: loading a message in for editing clears any staged reply.
        if (widget.editing != null)
          _EditBar(
              message: widget.editing!,
              ext: ext,
              onCancel: widget.onCancelEdit)
        else if (widget.replyingTo != null)
          _ReplyBar(
              message: widget.replyingTo!,
              ext: ext,
              onClear: widget.onClearReply),

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
              // ...and while editing: an edit changes text, it cannot grow a
              // photo the original message never had.
              Semantics(
                  button: true,
                  label: 'Show media picker',
                  child: GestureDetector(
                    onTap: (widget.isUploadingImage || hasStaged || isEditing)
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
                        // A plus, not a paperclip: the designs draw it as
                        // "add something", and the sheet it opens offers a
                        // photo or a video rather than a file to attach.
                        Icons.add_rounded,
                        color:
                            (widget.isUploadingImage || hasStaged || isEditing)
                                ? ext.searchHintColor.withValues(alpha: 0.4)
                                : ext.searchHintColor,
                        size: 20.sp,
                      ),
                    ),
                  )),
              SizedBox(width: AppSpacing.xs.w),

              // Emoji button
              EmojiButton(
                isOpen: _emojiOpen,
                onToggle: _toggleEmoji,
                ext: ext,
                iconSize: 20.sp,
              ),
              SizedBox(width: AppSpacing.xs.w),

              // Text input
              Expanded(
                child: AppTextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onChanged: (value) =>
                      widget.onTypingChanged?.call(value.trim().isNotEmpty),
                  onTap: () {
                    if (_emojiOpen) setState(() => _emojiOpen = false);
                  },
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
                  dense: true,
                  borderRadius: 22.r,
                  hint: isEditing
                      ? 'Edit your message…'
                      : hasStaged
                          ? 'Add a caption… (optional)'
                          : widget.replyingTo != null
                              ? 'Reply…'
                              : 'Type a message…',
                  onFieldSubmitted: (_) => widget.onSend(),
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),

              // Send button
              // Send doubles as the edit's confirm, and says so: a check, not a
              // paper plane, since nothing new is being sent.
              //
              // The plane is [Icons.near_me_outlined] — an outlined dart angled
              // up and to the right. Not [Icons.send_rounded], which is filled
              // and lies flat: solid white on the accent circle reads as a
              // block at this size, where the outline keeps the circle's colour
              // showing through and stays a shape. Not `send_outlined` rotated
              // either — that glyph carries the paper plane's tail creases, and
              // rotating a horizontal icon to fake an angle leaves it visibly
              // off-axis inside a circle.
              Semantics(
                  button: true,
                  label: isEditing ? 'Save edit' : 'Send',
                  child: GestureDetector(
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
                          : Icon(
                              isEditing
                                  ? Icons.check_rounded
                                  : Icons.near_me_outlined,
                              color: Colors.white,
                              size: 20.sp),
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
    // Material carries the sheet's surface colour so the tiles' ink splashes
    // land on it; a decorated Container here would sit between them and the
    // nearest Material and swallow the ripple (and assert in debug).
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 24.h),
      child: Material(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppSpacing.sm.h),
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            ListTile(
              leading: Icon(Icons.image_rounded, color: ext.searchHintColor),
              title: Text('Photo',
                  style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
              onTap: onPickImage,
            ),
            ListTile(
              leading: Icon(Icons.videocam_rounded, color: ext.searchHintColor),
              title: Text('Video',
                  style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
              onTap: onPickVideo,
            ),
            SizedBox(height: AppSpacing.sm.h),
          ],
        ),
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
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // On web, filePath is a blob URL — Image.network handles it.
                    // On mobile, filePath is a local file path.
                    kIsWeb
                        ? Semantics(
                            image: true,
                            label: 'Selected image',
                            child: XFileImage(
                              XFile(filePath),
                              width: 64.w,
                              height: 64.w,
                              fit: BoxFit.cover,
                            ))
                        : XFileImage(
                            XFile(filePath),
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
              isUploading
                  ? 'Uploading…'
                  : 'Image ready — add a caption or send',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
          ),
          if (!isUploading)
            Semantics(
                button: true,
                label: 'Clear',
                child: GestureDetector(
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
                  child: XFileImage(XFile(filePath), fit: BoxFit.contain),
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
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
            child: SizedBox(
              width: 64.w,
              height: 64.w,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JpergVideoPlayer(
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
            Semantics(
                button: true,
                label: 'Clear',
                child: GestureDetector(
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
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
            child: Semantics(
                image: true,
                label: 'Selected image',
                child: JpergImage(
                  imageUrl: imageUrl,
                  width: 64.w,
                  height: 64.w,
                  logicalWidth: 64.w,
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
                          strokeWidth: 2, color: ext.searchHintColor),
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
          Semantics(
              button: true,
              label: 'Clear',
              child: GestureDetector(
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

// ── Edit banner ───────────────────────────────────────────────────────────────

/// Sits above the composer while a message is being rewritten: same tinted band
/// and accent rail as [_ReplyBar], a pencil instead of a name, and the original
/// text underneath so the change is visible against what was there before.
class _EditBar extends StatelessWidget {
  const _EditBar({
    required this.message,
    required this.ext,
    this.onCancel,
  });

  final ChatMessage message;
  final AppThemeExtension ext;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.sm.h, AppSpacing.md.w, AppSpacing.sm.h),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        border: Border(
          top: BorderSide(color: ext.searchHintColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34.h,
            decoration: BoxDecoration(
              color: ext.accentGold,
              borderRadius: BorderRadius.circular(2.r),
            ),
            margin: EdgeInsets.only(right: AppSpacing.md.w),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_rounded,
                        size: 12.sp, color: ext.accentGold),
                    SizedBox(width: AppSpacing.xs.w),
                    Text(
                      'Edit message',
                      style: TextStyle(
                        color: ext.accentGold,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  message.content,
                  style: TextStyle(color: ext.greetingColor, fontSize: 12.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Cancel edit',
            child: IconButton(
              onPressed: onCancel,
              tooltip: 'Cancel edit',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded,
                  size: 20.sp, color: ext.searchHintColor),
            ),
          ),
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
    // A tinted band rather than the plain composer surface: what is being
    // replied to has to be visible at a glance while typing, and the accent
    // wash is what tells the two states apart in the designs.
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.sm.h, AppSpacing.md.w, AppSpacing.sm.h),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        border: Border(
          top: BorderSide(color: ext.searchHintColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34.h,
            decoration: BoxDecoration(
              color: ext.accentGold,
              borderRadius: BorderRadius.circular(2.r),
            ),
            margin: EdgeInsets.only(right: AppSpacing.md.w),
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Text(
                  _preview,
                  style: TextStyle(color: ext.greetingColor, fontSize: 12.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Cancel reply',
            child: IconButton(
              onPressed: onClear,
              tooltip: 'Cancel reply',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.cancel_outlined,
                  size: 20.sp, color: ext.searchHintColor),
            ),
          ),
        ],
      ),
    );
  }
}
