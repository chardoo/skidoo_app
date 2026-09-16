import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/search_field.dart';

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
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.sm.w, AppSpacing.sm.h,
          AppSpacing.lg.w, AppSpacing.sm.h),
      child: Row(
        children: [
          AppBackButton(onPressed: onBack),
          SizedBox(width: AppSpacing.xs.w),
          Expanded(
            // The one search box, not a second copy of it. This was a
            // hand-rolled duplicate that had drifted on every value that makes
            // it recognisable — a different height, fill, border weight, icon
            // colour and text size. Two search boxes that are nearly the same
            // read as a mistake rather than as a style.
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => SearchField(
                controller: controller,
                // On the page background, not over media — see
                // [SearchFieldSurface]. The glass tint is 5% black and would
                // be invisible here in light mode.
                surface: SearchFieldSurface.page,
                focusNode: focusNode,
                autofocus: true,
                hint: hintText,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                // Rebuilt by the listenable above, so the clear button appears
                // and disappears with the text.
                onClear: () {
                  controller.clear();
                  onChanged('');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
