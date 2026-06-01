import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/widgets/emoji_panel.dart';

/// Shared text-input bar for both event and photo comments.
///
/// Accepts [replyingToName] as a plain string (no model dependency).
/// When non-null, a gold reply banner is shown above the text field.
class CommentInputBarWidget extends StatefulWidget {
  const CommentInputBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.ext,
    this.replyingToName,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final AppThemeExtension ext;

  /// Display name of the user being replied to. Null means no active reply.
  final String? replyingToName;
  final VoidCallback? onCancelReply;

  @override
  State<CommentInputBarWidget> createState() => _CommentInputBarWidgetState();
}

class _CommentInputBarWidgetState extends State<CommentInputBarWidget> {
  bool _emojiOpen = false;

  void _toggleEmoji() {
    setState(() => _emojiOpen = !_emojiOpen);
    if (_emojiOpen) {
      widget.focusNode.unfocus();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Emoji panel — rendered as sibling ABOVE the input row so it is
        //    never clipped by the parent sheet or obscured by the keyboard.
        if (_emojiOpen)
          EmojiPickerPanel(
            ext: ext,
            onEmojiSelected: (emoji) => insertEmoji(widget.controller, emoji),
          ),

        // ── Reply banner ─────────────────────────────────────────────────────
        if (widget.replyingToName != null)
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 8.w, 8.h),
            decoration: BoxDecoration(
              color: ext.accentGold.withValues(alpha: 0.08),
              border: Border(
                top: BorderSide(
                    color: ext.accentGold.withValues(alpha: 0.25), width: 1),
                left: BorderSide(color: ext.accentGold, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.reply_rounded, size: 14.sp, color: ext.accentGold),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Replying to ${widget.replyingToName}',
                    style: TextStyle(
                      color: ext.accentGold,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4.w),
                Semantics(button: true, label: 'Cancel reply', child: GestureDetector(
                  onTap: widget.onCancelReply,
                  child: Icon(Icons.close_rounded,
                      size: 16.sp, color: ext.searchHintColor),
                )),
              ],
            ),
          ),

        // ── Text input row ───────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 10.h),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            border: Border(
              top: BorderSide(
                  color: ext.searchHintColor.withValues(alpha: 0.10)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Emoji button ─────────────────────────────────────────────
              EmojiButton(
                isOpen: _emojiOpen,
                onToggle: _toggleEmoji,
                ext: ext,
                iconSize: 20.sp,
              ),
              SizedBox(width: 4.w),

              // ── Text field ────────────────────────────────────────────────
              Expanded(
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(
                        LogicalKeyboardKey.enter, shift: false): widget.onSend,
                    const SingleActivator(
                        LogicalKeyboardKey.numpadEnter,
                        shift: false): widget.onSend,
                  },
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    onTap: () {
                      if (_emojiOpen) setState(() => _emojiOpen = false);
                    },
                    style:
                        TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.replyingToName != null
                          ? 'Write a reply…'
                          : 'Add a comment…',
                      hintStyle:
                          TextStyle(color: ext.glassHint, fontSize: 14.sp),
                      filled: true,
                      fillColor: ext.glassFill,
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
              ),
              SizedBox(width: 8.w),

              // ── Send button ───────────────────────────────────────────────
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Semantics(button: true, label: 'Send', child: GestureDetector(
                  onTap: widget.onSend,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 42.w,
                    height: 42.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ext.accentGold, const Color(0xFFFF6B35)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ext.accentGold.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.send_rounded,
                        color: Colors.white, size: 18.sp),
                  ),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
