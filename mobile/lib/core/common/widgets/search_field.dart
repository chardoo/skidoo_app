import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_input.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// The "glass" search pill used across headers (home, photographers, chat,
/// gallery share, sidebar). One shape/tint recipe — change it here and every
/// search box in the app updates.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.onClear,
    this.height,
    this.loading = false,
  });

  final TextEditingController controller;
  final String hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onClear;
  final double? height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      height: height ?? 46.h,
      decoration: BoxDecoration(
        color: ext.glassFill,
        borderRadius: BorderRadius.circular(23.r),
        border: Border.all(color: ext.glassBorder, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(width: 14.w),
          Icon(Icons.search_rounded, color: ext.glassIcon, size: 20.sp),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
              // The pill above is the only outline this field gets — see
              // [kBorderlessInput] for why `border: InputBorder.none` alone
              // left a second one inside it whenever the field had focus.
              decoration: kBorderlessInput.copyWith(
                hintText: hint,
                hintStyle: TextStyle(color: ext.glassHint, fontSize: 14.sp),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              ),
            ),
          ),
          if (loading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
              child: SizedBox(
                width: 16.w,
                height: 16.w,
                child: CircularProgressIndicator(
                    color: ext.accentGold, strokeWidth: 2),
              ),
            )
          else if (onClear != null && controller.text.isNotEmpty)
            Semantics(
              button: true,
              label: 'Clear search',
              child: GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: Icon(Icons.close_rounded,
                      color: ext.glassIcon, size: 18.sp),
                ),
              ),
            )
          else
            SizedBox(width: 14.w),
        ],
      ),
    );
  }
}
