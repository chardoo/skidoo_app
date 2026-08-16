import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The search row used by the chat search and new-chat screens: a rounded
/// field with a trailing Cancel that leaves the screen.
///
/// Both screens replace the app bar with this rather than sitting under one —
/// searching is the whole screen, not a mode of the one behind it.
class ChatSearchField extends StatefulWidget {
  const ChatSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onCancel,
    this.hint = 'Search',
    this.autofocus = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;
  final String hint;
  final bool autofocus;

  @override
  State<ChatSearchField> createState() => _ChatSearchFieldState();
}

class _ChatSearchFieldState extends State<ChatSearchField> {
  @override
  void initState() {
    super.initState();
    // The clear button appears and disappears with the text, so it has to
    // rebuild on edits the parent doesn't cause.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final hasText = widget.controller.text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md.w, AppSpacing.md.h, AppSpacing.md.w, AppSpacing.sm.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
                filled: true,
                fillColor: ext.searchFieldFill,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w, vertical: 12.h),
                // The magnifier is the empty-state cue; once there is text to
                // clear, the clear button takes the slot instead.
                prefixIcon: hasText
                    ? null
                    : Icon(Icons.search_rounded,
                        color: ext.searchHintColor, size: 20.sp),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 40.w, minHeight: 20.h),
                suffixIcon: hasText
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: Icon(Icons.cancel,
                            color: ext.searchHintColor, size: 18.sp),
                        onPressed: _clear,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  borderSide: BorderSide(
                      color: ext.searchHintColor.withValues(alpha: 0.25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  borderSide: BorderSide(
                      color: ext.searchHintColor.withValues(alpha: 0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  borderSide: BorderSide(color: ext.accentGold),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(color: ext.accentGold, fontSize: 15.sp),
            ),
          ),
        ],
      ),
    );
  }
}
