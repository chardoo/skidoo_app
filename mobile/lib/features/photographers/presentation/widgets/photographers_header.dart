import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/search_field.dart';
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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: textCtrl,
            builder: (context, value, _) {
              return SearchField(
                controller: textCtrl,
                hint: 'Search creators...',
                onChanged: onSearchChanged,
                onClear: () {
                  textCtrl.clear();
                  onSearchChanged('');
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
