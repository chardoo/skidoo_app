import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class CardCommentSheet extends StatefulWidget {
  const CardCommentSheet(
      {super.key, required this.ext, required this.eventName});
  final AppThemeExtension ext;
  final String eventName;

  @override
  State<CardCommentSheet> createState() => _CardCommentSheetState();
}

class _CardCommentSheetState extends State<CardCommentSheet> {
  final _ctrl = TextEditingController();
  final List<CardComment> _comments = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.insert(0, CardComment(text: text, author: 'You'));
    });
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55),
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppSpacing.lg.h),
            Text(
              'Comments',
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: AppSpacing.md.h),

            // Comment list
            Flexible(
              child: _comments.isEmpty
                  ? Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.xxxl.h),
                      child: Text(
                        'No comments yet. Be the first!',
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 14.sp),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      reverse: false,
                      padding:
                          EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                      itemCount: _comments.length,
                      itemBuilder: (_, i) =>
                          CardCommentTile(comment: _comments[i], ext: ext),
                    ),
            ),

            // Input
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 12.w, 16.h),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: ext.searchFieldFill, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _ctrl,
                      hint: 'Add a comment…',
                      dense: true,
                      borderRadius: 22.r,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                  Semantics(
                      button: true,
                      label: 'Submit',
                      child: GestureDetector(
                        onTap: _submit,
                        child: Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: ext.accentGold,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.send_rounded,
                              color: Colors.white, size: 18.sp),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardComment {
  const CardComment({required this.text, required this.author});
  final String text;
  final String author;
}

class CardCommentTile extends StatelessWidget {
  const CardCommentTile({super.key, required this.comment, required this.ext});
  final CardComment comment;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15.r,
            backgroundColor: ext.accentGold,
            child: Text(
              comment.author[0].toUpperCase(),
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.author,
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  comment.text,
                  style: TextStyle(color: ext.greetingColor, fontSize: 13.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
