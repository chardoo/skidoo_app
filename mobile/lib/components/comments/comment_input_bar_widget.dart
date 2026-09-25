import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

/// Shared text-input bar for both event and photo comments.
///
/// Accepts [replyingToName] as a plain string (no model dependency).
/// When non-null, a gold reply banner is shown above the text field.
///
/// No emoji button. Every keyboard this app runs under has one of its own, so
/// a second door to the same picker cost a button beside the field, a panel
/// that had to be opened by taking focus off the composer, and a keyboard that
/// closed and reopened as the two traded places.
class CommentInputBarWidget extends StatelessWidget {
  const CommentInputBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.ext,
    this.replyingToName,
    this.onCancelReply,
    this.editingContent,
    this.onCancelEdit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final AppThemeExtension ext;

  /// Display name of the user being replied to. Null means no active reply.
  final String? replyingToName;
  final VoidCallback? onCancelReply;

  /// What the comment being edited said, or null when nothing is being edited.
  ///
  /// The composer holds the text and [onSend] applies the change — the same
  /// shape the chat room uses, and for the same reason: a dialog covers the
  /// thread the comment belongs to, so you rewrite it with no sight of what
  /// you were replying to or what you said above it.
  final String? editingContent;

  /// Leaves edit mode without applying anything.
  final VoidCallback? onCancelEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Editing / reply banner ───────────────────────────────────────────
        // Never both: loading a comment in for editing clears any staged reply,
        // which would otherwise be attached to nothing once the edit applies.
        if (editingContent != null)
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
                AppSvgIcon(AppIcons.edit, size: 14.sp, color: ext.accentGold),
                SizedBox(width: 6.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit comment',
                        style: TextStyle(
                          color: ext.accentGold,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      // What it said before. The composer already holds the
                      // same words, but they are about to be typed over —
                      // this is the only thing on screen that still says what
                      // is being changed.
                      Text(
                        editingContent!,
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.xs.w),
                Semantics(
                    button: true,
                    label: 'Cancel edit',
                    child: GestureDetector(
                      onTap: onCancelEdit,
                      child: AppSvgIcon(AppIcons.closeMd,
                          size: 16.sp, color: ext.searchHintColor),
                    )),
              ],
            ),
          )
        else if (replyingToName != null)
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
                    'Replying to $replyingToName',
                    style: TextStyle(
                      color: ext.accentGold,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: AppSpacing.xs.w),
                Semantics(
                    button: true,
                    label: 'Cancel reply',
                    child: GestureDetector(
                      onTap: onCancelReply,
                      child: AppSvgIcon(AppIcons.closeMd,
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
              // ── Text field ────────────────────────────────────────────────
              Expanded(
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.enter,
                        shift: false): onSend,
                    const SingleActivator(LogicalKeyboardKey.numpadEnter,
                        shift: false): onSend,
                  },
                  child: AppTextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    dense: true,
                    borderRadius: 22.r,
                    hint: editingContent != null
                        ? 'Edit your comment…'
                        : replyingToName != null
                            ? 'Write a reply…'
                            : 'Add a comment…',
                    onFieldSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),

              // ── Send button ───────────────────────────────────────────────
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Semantics(
                    button: true,
                    label: editingContent != null ? 'Save edit' : 'Send',
                    child: GestureDetector(
                      onTap: onSend,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 42.w,
                        height: 42.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [ext.accentGold, ext.accentGoldDark],
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
                        // A check rather than a plane while editing: nothing
                        // new is being sent.
                        child: Icon(
                            editingContent != null
                                ? Icons.check_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 18.sp),
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
