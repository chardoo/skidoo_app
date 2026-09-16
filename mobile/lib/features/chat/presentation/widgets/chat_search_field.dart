import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/search_field.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The search row used by the chat search and new-chat screens: the shared
/// [SearchField] with a trailing Cancel that leaves the screen.
///
/// Both screens replace the app bar with this rather than sitting under one —
/// searching is the whole screen, not a mode of the one behind it.
///
/// The field itself is no longer drawn here. This treatment — rounded
/// rectangle, opaque fill, hairline border that turns gold on focus — was the
/// one the rest of the app was meant to have, so it moved into [SearchField]
/// and every other search box now wears it. What is left over is the Cancel,
/// which is genuinely particular to a screen that *is* the search.
class ChatSearchField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md.w, AppSpacing.md.h, AppSpacing.md.w, AppSpacing.sm.h),
      child: Row(
        children: [
          Expanded(
            child: SearchField(
              controller: controller,
              hint: hint,
              autofocus: autofocus,
              onChanged: onChanged,
            ),
          ),
          TextButton(
            onPressed: onCancel,
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
