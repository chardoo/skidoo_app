import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// What the photographer chose to do about a request.
enum InvitationAction { send, withdraw }

/// The note that goes with it — empty is fine, the request itself is the point.
class InvitationResult {
  const InvitationResult(this.action, [this.message = '']);

  final InvitationAction action;
  final String message;
}

/// Sending an invitation for someone's request.
///
/// This is not a DM and deliberately cannot become one: a photographer offers,
/// and the requester reads through the invitations and starts the conversation
/// with whoever they like. Messaging a stranger because they posted a request
/// would be the whole board messaging one person.
class InvitationSheet extends StatefulWidget {
  const InvitationSheet({
    super.key,
    required this.requestTitle,
    required this.requesterName,
    this.existingMessage,
  });

  final String requestTitle;
  final String requesterName;

  /// Set when they have already sent one — the sheet becomes an edit, with a
  /// way to take the invitation back.
  final String? existingMessage;

  static Future<InvitationResult?> show(
    BuildContext context, {
    required String requestTitle,
    required String requesterName,
    String? existingMessage,
  }) {
    return showModalBottomSheet<InvitationResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InvitationSheet(
        requestTitle: requestTitle,
        requesterName: requesterName,
        existingMessage: existingMessage,
      ),
    );
  }

  @override
  State<InvitationSheet> createState() => _InvitationSheetState();
}

class _InvitationSheetState extends State<InvitationSheet> {
  late final _note = TextEditingController(text: widget.existingMessage ?? '');

  bool get _sent => widget.existingMessage != null;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      // Above the keyboard — the note is the only thing on this sheet.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                    decoration: BoxDecoration(
                      color: ext.searchHintColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Text(
                  _sent ? 'Your invitation' : 'Send an invitation',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  // Says plainly what happens next, because "Message
                  // Requester" reads like a chat and is not one.
                  '${widget.requesterName} will see that you can shoot '
                  '"${widget.requestTitle}", along with your profile and your '
                  'work. They start the conversation if they want to.',
                  style: TextStyle(
                    color: ext.searchHintColor, fontSize: 13.sp, height: 1.45,
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                TextField(
                  controller: _note,
                  maxLines: 4,
                  maxLength: 500,
                  style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Add a note (optional)',
                    hintStyle: TextStyle(
                      color: ext.searchHintColor, fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: ext.searchFieldFill,
                    counterStyle: TextStyle(
                      color: ext.searchHintColor, fontSize: 10.sp,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(
                      InvitationResult(
                        InvitationAction.send, _note.text.trim(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext.accentGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                    child: Text(
                      _sent ? 'Update note' : 'Send invitation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (_sent)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(
                        const InvitationResult(InvitationAction.withdraw),
                      ),
                      child: Text(
                        'Withdraw my invitation',
                        style: TextStyle(
                          color: ext.errorRed, fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
