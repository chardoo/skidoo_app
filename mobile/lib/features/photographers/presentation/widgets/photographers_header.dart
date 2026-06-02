import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class PhotographersHeader extends StatelessWidget {
  const PhotographersHeader({
    super.key,
    required this.textCtrl,
    required this.onSearchChanged,
  });

  final TextEditingController textCtrl;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creators',
            style: TextStyle(
              color: ext.greetingColor,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: ext.searchFieldFill,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: textCtrl,
              builder: (context, value, _) {
                return TextField(
                  controller: textCtrl,
                  style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Search creators...',
                    hintStyle:
                        TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: ext.searchHintColor, size: 20.sp),
                    suffixIcon: value.text.isNotEmpty
                        ? Semantics(button: true, label: 'Clear search', child: GestureDetector(
                            onTap: () {
                              textCtrl.clear();
                              onSearchChanged('');
                            },
                            child: Icon(Icons.close_rounded,
                                color: ext.searchHintColor, size: 18.sp),
                          ))
                        : null,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onChanged: onSearchChanged,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
