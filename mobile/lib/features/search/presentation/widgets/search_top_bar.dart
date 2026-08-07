import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_input.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';

/// The Search screen's header: a back arrow and the query field, nothing else.
///
/// Colours come from the theme extension rather than the white-over-media
/// treatment the feed's own top bar uses — this bar always sits on the page
/// background, so it reads correctly in both light and dark mode.
class SearchTopBar extends StatelessWidget {
  const SearchTopBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onBack,
    this.hintText = 'event name, hashtag, photographer…',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBack;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.sm.w, AppSpacing.sm.h,
          AppSpacing.lg.w, AppSpacing.sm.h),
      child: Row(
        children: [
          AppBackButton(onPressed: onBack),
          SizedBox(width: AppSpacing.xs.w),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => Container(
                height: 44.h,
                decoration: BoxDecoration(
                  color: ext.searchFieldFill,
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  border: Border.all(color: ext.glassBorder, width: 0.8),
                ),
                child: Row(
                  children: [
                    SizedBox(width: AppSpacing.md.w),
                    Icon(Icons.search_rounded,
                        color: ext.searchHintColor, size: 19.sp),
                    SizedBox(width: AppSpacing.sm.w),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                            color: ext.greetingColor, fontSize: 14.5.sp),
                        // The pill above is the only outline this field gets —
                        // see [kBorderlessInput].
                        decoration: kBorderlessInput.copyWith(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: hintText,
                          hintStyle: TextStyle(
                              color: ext.searchHintColor, fontSize: 14.5.sp),
                        ),
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                      ),
                    ),
                    if (value.text.isNotEmpty)
                      Semantics(
                        button: true,
                        label: 'Clear search',
                        child: GestureDetector(
                          onTap: () {
                            controller.clear();
                            onChanged('');
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
                            child: Icon(Icons.close_rounded,
                                color: ext.searchHintColor, size: 18.sp),
                          ),
                        ),
                      )
                    else
                      SizedBox(width: AppSpacing.md.w),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
