import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The small overline above a group of rows — "SUGGESTED CREATORS",
/// "ACCOUNT", "PRIVACY".
///
/// Six screens each declared their own `_SectionLabel`, agreeing on the idea
/// and differing in every detail: 11 sp at weight 600 or 700, letter-spacing
/// 0.5, 0.8 or 1.4, uppercased by the widget or by the caller, hint colour at
/// full strength or 55%. Nothing chose those differences — they accumulated.
/// This is the one of them.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key, this.padding});

  final String text;

  /// Where a label needs to sit inside a list that has no padding of its own.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        color: ext.searchHintColor,
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        // The web sidebar renders above the Navigator, where there is no
        // Material ancestor to supply a default — without this its labels get
        // the debug underline.
        decoration: TextDecoration.none,
      ),
    );

    if (padding == null) return label;
    return Padding(padding: padding!, child: label);
  }
}
