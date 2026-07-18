import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class PhotographerInfoRow extends StatelessWidget {
  const PhotographerInfoRow({super.key, required this.icon, required this.text, required this.ext});

  final IconData icon;
  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 16.sp, color: ext.searchHintColor),
        ),
        SizedBox(width: 12.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
